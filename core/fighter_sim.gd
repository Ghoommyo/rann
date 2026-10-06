## The fighter state machine: turns input into states and movement.
##
## 💡 This code knows nothing about specific characters. All the numbers
## (speeds, jump height, …) come from CharacterDef, so every fighter runs
## through this same code.
class_name FighterSim

const State := FighterState.State


## Step 1 of a tick: read input and choose the state and velocity.
static func update_intent(f: FighterState, def: CharacterDef) -> void:
	var dir := InputFrame.to_numpad(f.input.latest(), f.facing)

	match f.state:
		State.IDLE, State.WALK_FORWARD, State.WALK_BACK, State.CROUCH:
			_grounded_intent(f, def, dir)

		State.JUMP_SQUAT:
			# Committed to the jump: wait out the wind-up, then take off.
			if f.state_frame >= def.jump_squat_frames:
				f.set_state(State.AIRBORNE)
				f.vel_y = def.jump_velocity
				f.vel_x = f.jump_dir * def.jump_forward_speed * f.facing

		State.AIRBORNE:
			pass  # no air control: a jump's arc is decided at take-off

		State.LANDING:
			if f.state_frame >= def.landing_frames:
				_grounded_intent(f, def, dir)


## Step 2 of a tick: apply gravity and velocity, then land.
static func integrate(f: FighterState, def: CharacterDef) -> void:
	if f.is_airborne():
		f.vel_y -= def.gravity

	f.pos_x += f.vel_x
	f.pos_y += f.vel_y

	if f.is_airborne() and f.pos_y <= 0:
		f.pos_y = 0
		f.vel_x = 0
		f.vel_y = 0
		f.set_state(State.LANDING)


## Free to act on the ground: the numpad direction picks what happens.
static func _grounded_intent(f: FighterState, def: CharacterDef, dir: int) -> void:
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
