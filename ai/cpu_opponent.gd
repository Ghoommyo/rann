## A computer-controlled player.
##
## 💡 The CPU plays through the same door as a human: each frame it looks at
## the FightState and returns an InputFrame int, exactly like a controller.
## It never changes the state directly, so it can't cheat at the rules, and
## every character works with it automatically (it reads MoveDef data).
##
## How it thinks, in priority order each frame:
##  1. Finish any input sequence already in progress (e.g. 2, 3, 6 + RP).
##  2. Stuck (hit, blocking, mid-move)? Keep guarding or try to break throws.
##  3. Saw an attack coming (after its reaction time)? Maybe block it.
##  4. Opponent recovering from a blocked/missed move? Maybe punish.
##  5. Opponent launched? Maybe juggle.
##  6. Otherwise: approach, poke, guard or back off, chosen at random.
##
## Difficulty only changes the numbers (reaction time and the chances).
## It uses its own seeded random generator, so the same seed and the same
## fight give the same choices (handy for tests and replays).
class_name CpuOpponent
extends RefCounted

enum Level { EASY, NORMAL, HARD }

const State := FighterState.State

const PRESETS := {
	Level.EASY: {
		"reaction_frames": 26, "block_chance": 0.25, "punish_chance": 0.15,
		"combo_chance": 0.15, "aggression": 0.35, "throw_break_chance": 0.1,
	},
	Level.NORMAL: {
		"reaction_frames": 16, "block_chance": 0.55, "punish_chance": 0.5,
		"combo_chance": 0.5, "aggression": 0.5, "throw_break_chance": 0.4,
	},
	Level.HARD: {
		"reaction_frames": 9, "block_chance": 0.85, "punish_chance": 0.9,
		"combo_chance": 0.9, "aggression": 0.6, "throw_break_chance": 0.75,
	},
}

## Frames before the CPU "notices" an opponent's attack. Humans react in
## roughly 15–20 frames, so a 10-frame jab can't be reacted to on Normal.
var reaction_frames := 16
var block_chance := 0.5
var punish_chance := 0.5
var combo_chance := 0.5
## Chance to attack (rather than move or guard) when in range.
var aggression := 0.5
var throw_break_chance := 0.4

var _rng := RandomNumberGenerator.new()
var _queue: Array[int] = []      # input frames still to send
var _last_output := 0
var _hold_bits := 0              # a direction held for a while (walking, guarding)
var _hold_frames := 0
# Remember decisions so each situation is rolled for only once.
var _guard_decided_for := -1
var _guard_bits := 0
var _punish_decided_for := -1
var _cancel_decided_for := -1
var _juggle_decided_for := -1
var _break_decided_for := -1


func _init(level := Level.NORMAL, seed_value := 1) -> void:
	var preset: Dictionary = PRESETS[level]
	for key in preset:
		set(key, preset[key])
	_rng.seed = seed_value


## Returns this frame's input for fighter `me` (0 = P1, 1 = P2).
func next_input(state: FightState, defs: Array[CharacterDef], me: int) -> int:
	var bits := _think(state, defs, me)
	_last_output = bits
	return bits


## Queues the inputs that perform `move`. Public so tests can drive it.
func perform(move: MoveDef, facing: int) -> void:
	var cmd := move.get_command()
	_queue.clear()
	if (_last_output & InputFrame.BUTTONS) != 0:
		_queue.append(0)  # release buttons first, or the press won't register
	for i in maxi(0, cmd.motion.size() - 1):
		_queue.append(InputFrame.from_numpad(cmd.motion[i], facing))
	var final_dir := cmd.motion[cmd.motion.size() - 1] if cmd.motion.size() > 0 else 5
	_queue.append(InputFrame.from_numpad(final_dir, facing) | cmd.buttons)
	_hold_frames = 0


func _think(state: FightState, defs: Array[CharacterDef], me: int) -> int:
	var f := state.fighters[me]
	var opp := state.fighters[1 - me]
	var def := defs[me]
	var opp_def := defs[1 - me]

	if state.phase != FightState.Phase.FIGHTING:
		_queue.clear()
		_hold_frames = 0
		return 0
	if not _queue.is_empty():
		return _queue.pop_front()

	# --- Busy states ---
	match f.state:
		State.THROWN:
			return _try_throw_break(f, opp, opp_def)
		State.ATTACK:
			_try_cancel(f, def)
			return _queue.pop_front() if not _queue.is_empty() else 0
		State.BLOCKSTUN:
			return _guard_bits  # keep blocking the same way
		State.IDLE, State.WALK_FORWARD, State.WALK_BACK, State.CROUCH:
			pass  # free to act: keep thinking below
		_:
			return 0

	# --- Defend ---
	var guard := _decide_guard(opp, opp_def, f.facing)
	if guard != 0:
		return guard

	# --- Punish / juggle ---
	if _try_punish(f, def, opp, opp_def) or _try_juggle(f, def, opp, opp_def):
		return _queue.pop_front()

	# --- Neutral ---
	if _hold_frames > 0:
		_hold_frames -= 1
		return _hold_bits
	_choose_neutral_action(f, def, opp, opp_def)
	if not _queue.is_empty():
		return _queue.pop_front()
	return _hold_bits


## Block an attack once it has been "seen" (after reaction_frames).
func _decide_guard(opp: FighterState, opp_def: CharacterDef, facing: int) -> int:
	if opp.state != State.ATTACK or opp.move_connected:
		return 0
	var move := opp_def.moves[opp.move_index]
	if move.active == 0 or opp.state_frame < reaction_frames:
		return 0
	var attack_id := opp.input.frame_count - opp.state_frame  # when the move started
	if _guard_decided_for != attack_id:
		_guard_decided_for = attack_id
		_guard_bits = 0
		if _rng.randf() < block_chance:
			_guard_bits = _guard_for(move, facing)
	if opp.state_frame + 1 < move.startup + move.active:
		return _guard_bits
	return 0


## Which way to guard against a move.
func _guard_for(move: MoveDef, facing: int) -> int:
	match move.hit_level:
		MoveDef.HitLevel.LOW, MoveDef.HitLevel.THROW:
			return InputFrame.from_numpad(1, facing)  # down-back: blocks lows, ducks throws
	return InputFrame.from_numpad(4, facing)  # back: blocks highs and mids


func _try_throw_break(f: FighterState, opp: FighterState, opp_def: CharacterDef) -> int:
	var throw_id := f.input.frame_count - f.state_frame
	if _break_decided_for == throw_id or f.state_frame < mini(reaction_frames, Rules.THROW_BREAK_WINDOW - 2):
		return 0
	_break_decided_for = throw_id
	if _rng.randf() < throw_break_chance:
		return opp_def.moves[opp.move_index].throw_break_mask()
	return 0


## Continue a string (e.g. jab → straight) once the move has connected.
func _try_cancel(f: FighterState, def: CharacterDef) -> void:
	if not f.move_connected:
		return
	var move_id := f.input.frame_count - f.state_frame
	if _cancel_decided_for == move_id:
		return
	_cancel_decided_for = move_id
	var options := def.cancel_options(f.move_index).filter(
		func(i): return def.get_style().can_use_move(f, def.moves[i]))
	if options.is_empty() or _rng.randf() >= combo_chance:
		return
	perform(def.moves[options[_rng.randi_range(0, options.size() - 1)]], f.facing)


## Hit the opponent while they recover from a blocked or missed move.
func _try_punish(f: FighterState, def: CharacterDef, opp: FighterState, opp_def: CharacterDef) -> bool:
	if opp.state != State.ATTACK:
		return false
	var move := opp_def.moves[opp.move_index]
	if opp.state_frame + 1 < move.startup + move.active:
		return false  # not recovering yet
	var attack_id := opp.input.frame_count - opp.state_frame
	if _punish_decided_for == attack_id:
		return false
	_punish_decided_for = attack_id
	if _rng.randf() >= punish_chance:
		return false
	var frames_left := move.total_frames() - opp.state_frame
	var best := _best_move(f, def, opp, opp_def, frames_left)
	if best:
		perform(best, f.facing)
	return best != null


## Follow a launcher with a juggle.
func _try_juggle(f: FighterState, def: CharacterDef, opp: FighterState, opp_def: CharacterDef) -> bool:
	if opp.state != State.JUGGLE or opp.vel_y > 0:
		return false  # wait until they start falling
	var juggle_id := opp.input.frame_count - opp.state_frame
	if _juggle_decided_for == juggle_id:
		return false
	_juggle_decided_for = juggle_id
	if _rng.randf() >= combo_chance:
		return false
	var best := _best_move(f, def, opp, opp_def, 999)
	if best:
		perform(best, f.facing)
	return best != null


## The most damaging move that reaches the opponent and starts within `max_startup` frames.
func _best_move(f: FighterState, def: CharacterDef, opp: FighterState, opp_def: CharacterDef,
		max_startup: int) -> MoveDef:
	var best: MoveDef = null
	for move in _usable_attacks(f, def, opp, opp_def):
		if move.hit_level == MoveDef.HitLevel.THROW or move.startup > max_startup:
			continue
		if best == null or move.damage > best.damage:
			best = move
	return best


func _choose_neutral_action(f: FighterState, def: CharacterDef, opp: FighterState, opp_def: CharacterDef) -> void:
	var distance := absi(opp.pos_x - f.pos_x)
	var in_range := _usable_attacks(f, def, opp, opp_def)
	var roll := _rng.randf()

	if not in_range.is_empty() and roll < aggression:
		perform(_pick_attack(in_range, opp), f.facing)
	elif roll < aggression + 0.08:
		_try_utility_move(f, def)  # e.g. switch stance
	elif distance > 1300 and roll < 0.85:
		_hold(InputFrame.from_numpad(6, f.facing), 10, 25)  # walk in
	elif roll < 0.9:
		var low_guard := _rng.randf() < 0.3
		_hold(InputFrame.from_numpad(1 if low_guard else 4, f.facing), 8, 20)  # guard and wait
	else:
		_hold(InputFrame.from_numpad(4 if _rng.randf() < 0.5 else 5, f.facing), 6, 15)


## Prefer lows against a standing guard and mids against a crouching one.
func _pick_attack(moves: Array[MoveDef], opp: FighterState) -> MoveDef:
	var preferred: Array[MoveDef] = []
	for move in moves:
		if opp.state == State.WALK_BACK and move.hit_level in [MoveDef.HitLevel.LOW, MoveDef.HitLevel.THROW]:
			preferred.append(move)
		elif opp.state == State.CROUCH and move.hit_level == MoveDef.HitLevel.MID:
			preferred.append(move)
	var pool := preferred if not preferred.is_empty() and _rng.randf() < 0.7 else moves
	return pool[_rng.randi_range(0, pool.size() - 1)]


func _try_utility_move(f: FighterState, def: CharacterDef) -> void:
	var utilities: Array[MoveDef] = []
	for move in def.moves:
		if move.active == 0 and def.get_style().can_use_move(f, move):
			utilities.append(move)
	if not utilities.is_empty():
		perform(utilities[_rng.randi_range(0, utilities.size() - 1)], f.facing)


## Attacks that are allowed right now and would reach the opponent.
func _usable_attacks(f: FighterState, def: CharacterDef, opp: FighterState, opp_def: CharacterDef) -> Array[MoveDef]:
	var distance := absi(opp.pos_x - f.pos_x)
	var result: Array[MoveDef] = []
	for move in def.moves:
		if move.active == 0 or not def.get_style().can_use_move(f, move):
			continue
		var reach := move.hitbox_offset_x + move.hitbox_width + opp_def.hurtbox_half_width \
			+ move.forward_speed * move.startup - 50
		if reach >= distance:
			result.append(move)
	return result


func _hold(bits: int, min_frames: int, max_frames: int) -> void:
	_hold_bits = bits
	_hold_frames = _rng.randi_range(min_frames, max_frames)
