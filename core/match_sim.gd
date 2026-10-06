## Advances a whole match by one frame. This is the heart of the game.
##
## 💡 step() is a pure function of (state, inputs): the same state and the
## same inputs always give the same result, on any device. That is what
## "deterministic" means, and it is what makes rollback netcode, replays
## and reliable tests possible. Nothing in here may read the clock, use
## randf(), touch scene nodes, or use floats.
class_name MatchSim


## Runs one 1/60 s tick. `defs` holds the CharacterDef for P1 and P2.
## The inputs are packed InputFrame ints.
static func step(state: FightState, defs: Array[CharacterDef], input_p1: int, input_p2: int) -> void:
	var p1 := state.fighters[0]
	var p2 := state.fighters[1]

	# 1. Record this frame's inputs.
	p1.input.push(input_p1)
	p2.input.push(input_p2)

	# 2. Turn to face the opponent (only when free to act on the ground).
	_update_facing(p1, p2)
	_update_facing(p2, p1)

	# 3. Each fighter decides what to do, then moves.
	for i in 2:
		FighterSim.update_intent(state.fighters[i], defs[i])
	for i in 2:
		FighterSim.integrate(state.fighters[i], defs[i])

	# 4. Keep fighters on stage and out of each other.
	Collision.resolve_pushboxes(p1, defs[0], p2, defs[1], state.stage_left, state.stage_right)

	# 5. Advance clocks.
	for f in state.fighters:
		f.state_frame += 1
	state.frame += 1


static func _update_facing(f: FighterState, opponent: FighterState) -> void:
	match f.state:
		FighterState.State.IDLE, FighterState.State.WALK_FORWARD, \
		FighterState.State.WALK_BACK, FighterState.State.CROUCH:
			var dir := signi(opponent.pos_x - f.pos_x)
			if dir != 0:
				f.facing = dir
