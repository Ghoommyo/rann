## Advances a whole match by one frame. This is the heart of the game.
##
## 💡 step() is a pure function of (state, inputs): the same state and the
## same inputs always give the same result, on any device. That is what
## "deterministic" means, and it is what makes rollback netcode, replays
## and reliable tests possible. Nothing in here may read the clock, use
## randf(), touch scene nodes, or use floats.
class_name MatchSim

const Phase := FightState.Phase


## Runs one 1/60 s tick. `defs` holds the CharacterDef for P1 and P2.
## The inputs are packed InputFrame ints.
static func step(state: FightState, defs: Array[CharacterDef], input_p1: int, input_p2: int) -> void:
	var p1 := state.fighters[0]
	var p2 := state.fighters[1]

	# 1. Record this frame's inputs. Outside of the fight itself (intro, KO
	#    pause) players have no control, so neutral input is recorded instead.
	var live := state.phase == Phase.FIGHTING
	p1.input.push(input_p1 if live else 0)
	p2.input.push(input_p2 if live else 0)
	state.frame += 1

	if state.phase == Phase.READY:
		state.phase_frame += 1
		if state.phase_frame >= Rules.READY_FRAMES:
			state.set_phase(Phase.FIGHTING)
		return

	# 2. Hitstop: everything freezes for a few frames after a hit. Inputs are
	#    still recorded above, so buttons pressed now are buffered.
	if state.hitstop > 0:
		state.hitstop -= 1
		return

	# 3. Turn to face the opponent (only when free to act on the ground).
	_update_facing(p1, p2)
	_update_facing(p2, p1)

	# 4. Each fighter decides what to do, throws progress, then everyone moves.
	for i in 2:
		FighterSim.update_intent(state.fighters[i], defs[i])
	Combat.update_throws(state, defs)
	for i in 2:
		FighterSim.integrate(state.fighters[i], defs[i])

	# 5. Keep fighters on stage and out of each other.
	Collision.resolve_pushboxes(p1, defs[0], p2, defs[1], state.stage_left, state.stage_right)

	# 6. Attacks: hits, blocks, throws.
	Combat.resolve(state, defs)

	# 7. Advance clocks and the round flow.
	for f in state.fighters:
		f.state_frame += 1
	_update_round(state, defs)


static func _update_round(state: FightState, defs: Array[CharacterDef]) -> void:
	state.phase_frame += 1
	match state.phase:
		Phase.FIGHTING:
			state.round_timer -= 1
			var ko1 := state.fighters[0].health <= 0
			var ko2 := state.fighters[1].health <= 0
			if ko1 or ko2 or state.round_timer <= 0:
				_end_round(state, ko1, ko2)

		Phase.ROUND_OVER:
			if state.phase_frame >= Rules.ROUND_OVER_FRAMES:
				_next_round_or_finish(state, defs)


static func _end_round(state: FightState, ko1: bool, ko2: bool) -> void:
	var winner := -1  # draw
	if ko1 != ko2:
		winner = 1 if ko1 else 0
	elif not ko1:  # time-out: more health wins
		var h1 := state.fighters[0].health
		var h2 := state.fighters[1].health
		if h1 != h2:
			winner = 0 if h1 > h2 else 1

	# 💡 A draw gives both players a round win (like Tekken).
	if winner >= 0:
		state.wins[winner] += 1
	else:
		state.wins[0] += 1
		state.wins[1] += 1
	state.round_winner = winner
	state.set_phase(Phase.ROUND_OVER)


static func _next_round_or_finish(state: FightState, defs: Array[CharacterDef]) -> void:
	var p1_won := state.wins[0] >= Rules.WINS_TO_WIN_MATCH
	var p2_won := state.wins[1] >= Rules.WINS_TO_WIN_MATCH
	if p1_won or p2_won:
		state.match_winner = -1 if p1_won and p2_won else (0 if p1_won else 1)
		state.set_phase(Phase.MATCH_OVER)
		return

	state.round_number += 1
	state.round_timer = Rules.ROUND_FRAMES
	state.round_winner = -1
	state.hitstop = 0
	# Keep each fighter's input history so the buffer timestamps continue.
	var inputs := [state.fighters[0].input, state.fighters[1].input]
	state.reset_fighters(defs)
	for i in 2:
		state.fighters[i].input = inputs[i]
	state.set_phase(Phase.READY)


static func _update_facing(f: FighterState, opponent: FighterState) -> void:
	match f.state:
		FighterState.State.IDLE, FighterState.State.WALK_FORWARD, \
		FighterState.State.WALK_BACK, FighterState.State.CROUCH:
			var dir := signi(opponent.pos_x - f.pos_x)
			if dir != 0:
				f.facing = dir
