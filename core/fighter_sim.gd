## The fighter state machine: turns input into states and movement.
##
## 💡 This code knows nothing about specific characters. All the numbers
## (speeds, moves, frame data, …) come from CharacterDef and MoveDef, so every
## fighter runs through this same code.
##
## Contact between fighters (hits, blocks, throws) is handled in Combat.
class_name FighterSim

const State := FighterState.State


## Step 1 of a tick: read input and choose the state and velocity.
static func update_intent(f: FighterState, def: CharacterDef) -> void:
	var dir := InputFrame.to_numpad(f.input.latest(), f.facing)

	match f.state:
		State.IDLE, State.WALK_FORWARD, State.WALK_BACK, State.CROUCH:
			_free_intent(f, def, dir)

		State.JUMP_SQUAT:
			# Committed to the jump: wait out the wind-up, then take off.
			if f.state_frame >= def.jump_squat_frames:
				f.set_state(State.AIRBORNE)
				f.vel_y = def.jump_velocity
				f.vel_x = f.jump_dir * def.jump_forward_speed * f.facing

		State.AIRBORNE, State.JUGGLE:
			pass  # no air control: the arc is decided at take-off (or by the hit)

		State.LANDING:
			if f.state_frame >= def.landing_frames:
				_free_intent(f, def, dir)

		State.ATTACK:
			_attack_intent(f, def, dir)

		State.HITSTUN, State.BLOCKSTUN:
			_apply_friction(f)
			if f.state_frame > f.stun_frames:
				_free_intent(f, def, dir)

		State.KNOCKDOWN:
			_apply_friction(f)
			# A KO'd fighter stays down.
			if f.health > 0 and f.state_frame >= Rules.KNOCKDOWN_FRAMES:
				f.set_state(State.WAKEUP)

		State.WAKEUP:
			if f.state_frame >= Rules.WAKEUP_FRAMES:
				_free_intent(f, def, dir)

		State.THROWING:
			f.vel_x = 0
			if f.state_frame >= def.moves[f.move_index].throw_duration:
				_free_intent(f, def, dir)

		State.THROWN:
			f.vel_x = 0  # Combat.update_throws() decides how this ends


## Step 2 of a tick: apply gravity and velocity, then land.
static func integrate(f: FighterState, def: CharacterDef) -> void:
	if f.state == State.AIRBORNE:
		f.vel_y -= def.gravity
	elif f.state == State.JUGGLE:
		f.vel_y -= Rules.JUGGLE_GRAVITY + f.combo_hits  # gravity scaling

	f.pos_x += f.vel_x
	f.pos_y += f.vel_y

	if f.is_airborne() and f.pos_y <= 0:
		var was_juggled := f.state == State.JUGGLE
		f.pos_y = 0
		f.vel_x = 0
		f.vel_y = 0
		f.set_state(State.KNOCKDOWN if was_juggled else State.LANDING)


## Starts moves[index]. `press_time` is the buffer timestamp of the button press.
static func start_move(f: FighterState, def: CharacterDef, index: int, press_time: int) -> void:
	f.set_state(State.ATTACK)
	f.move_index = index
	f.move_connected = false
	f.last_press_time = press_time
	f.vel_x = def.moves[index].forward_speed * f.facing
	f.vel_y = 0


## The fighter is free to act: try an attack first, otherwise move.
static func _free_intent(f: FighterState, def: CharacterDef, dir: int) -> void:
	f.combo_hits = 0  # free again = the combo against this fighter is over
	if _try_start_move(f, def, def.moves_by_priority()):
		return
	_movement_intent(f, def, dir)


## Starts the first move in `candidates` whose command was just entered.
static func _try_start_move(f: FighterState, def: CharacterDef, candidates: Array[int]) -> bool:
	for index in candidates:
		var press := def.moves[index].get_command().find_press(f.input, f.facing, f.last_press_time)
		if press >= 0:
			start_move(f, def, index, press)
			return true
	return false


static func _attack_intent(f: FighterState, def: CharacterDef, dir: int) -> void:
	var move := def.moves[f.move_index]
	var frame := f.state_frame + 1  # the move's frame number this tick (1-based)

	if frame > move.total_frames():
		_free_intent(f, def, dir)
		return

	# 💡 Cancel: once the move has connected, a listed follow-up can
	# interrupt the rest of it. This is what makes strings and combos.
	if f.move_connected and _try_start_move(f, def, def.cancel_options(f.move_index)):
		return

	f.vel_x = move.forward_speed * f.facing if frame < move.startup + move.active else 0


## Walking, crouching and jumping, picked by the numpad direction.
static func _movement_intent(f: FighterState, def: CharacterDef, dir: int) -> void:
	if dir >= 7:  # 7 8 9 = any up direction → jump
		f.jump_dir = dir - 8  # 7 → -1 (back), 8 → 0, 9 → +1 (forward)
		f.vel_x = 0
		f.set_state(State.JUMP_SQUAT)
	elif dir <= 3:  # 1 2 3 = any down direction → crouch
		f.vel_x = 0
		f.enter_state(State.CROUCH)
	elif dir == 6:
		f.vel_x = def.walk_forward_speed * f.facing
		f.enter_state(State.WALK_FORWARD)
	elif dir == 4:
		f.vel_x = -def.walk_back_speed * f.facing
		f.enter_state(State.WALK_BACK)
	else:
		f.vel_x = 0
		f.enter_state(State.IDLE)


## Slows a sliding fighter (pushback) towards a stop.
static func _apply_friction(f: FighterState) -> void:
	if f.vel_x > 0:
		f.vel_x = maxi(0, f.vel_x - Rules.PUSHBACK_FRICTION)
	elif f.vel_x < 0:
		f.vel_x = mini(0, f.vel_x + Rules.PUSHBACK_FRICTION)
