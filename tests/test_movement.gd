extends GutTest

const S := FighterState.State
var RIGHT := InputFrame.pack(false, false, false, true)
var LEFT := InputFrame.pack(false, false, true, false)
var DOWN := InputFrame.pack(false, true, false, false)
var UP := InputFrame.pack(true, false, false, false)
var UP_RIGHT := InputFrame.pack(true, false, false, true)

var defs: Array[CharacterDef]
var state: FightState


func before_each():
	defs = TestHelpers.default_defs()
	state = FightState.create(defs)


func test_start_positions():
	assert_eq(state.fighters[0].pos_x, -1500)
	assert_eq(state.fighters[1].pos_x, 1500)
	assert_eq(state.fighters[0].facing, 1)
	assert_eq(state.fighters[1].facing, -1)


func test_walk_forward_moves_exact_distance():
	var p1 := state.fighters[0]
	TestHelpers.run(state, defs, 20, RIGHT)
	assert_eq(p1.state, S.WALK_FORWARD)
	assert_eq(p1.pos_x, -1500 + defs[0].walk_forward_speed * 20)


func test_walk_back_is_relative_to_facing():
	# P2 faces left, so holding RIGHT means walking back (away from P1).
	var p2 := state.fighters[1]
	TestHelpers.run(state, defs, 10, 0, RIGHT)
	assert_eq(p2.state, S.WALK_BACK)
	assert_eq(p2.pos_x, 1500 + defs[1].walk_back_speed * 10)


func test_crouch_stops_movement():
	TestHelpers.run(state, defs, 5, DOWN)
	assert_eq(state.fighters[0].state, S.CROUCH)
	assert_eq(state.fighters[0].pos_x, -1500)


func test_neutral_jump_full_arc():
	var p1 := state.fighters[0]
	var d := defs[0]
	MatchSim.step(state, defs, UP, 0)
	assert_eq(p1.state, S.JUMP_SQUAT)
	TestHelpers.run(state, defs, d.jump_squat_frames, UP)
	assert_eq(p1.state, S.AIRBORNE)
	assert_gt(p1.pos_y, 0)

	var peak := 0
	var frames_in_air := 0
	while p1.state == S.AIRBORNE:
		peak = maxi(peak, p1.pos_y)
		frames_in_air += 1
		MatchSim.step(state, defs, 0, 0)
		assert_lt(frames_in_air, 120, "jump never landed")

	assert_eq(p1.state, S.LANDING)
	assert_eq(p1.pos_y, 0)
	assert_eq(p1.pos_x, -1500, "neutral jump lands where it started")
	# v=120, g=8: peak is the sum 112 + 104 + ... + 8 = 840
	assert_eq(peak, 840)


func test_landing_recovery_then_free():
	var p1 := state.fighters[0]
	MatchSim.step(state, defs, UP, 0)
	while p1.state != S.LANDING:
		MatchSim.step(state, defs, 0, 0)
	# The touchdown frame is landing frame 1, so landing_frames - 1 remain.
	TestHelpers.run(state, defs, defs[0].landing_frames - 1, RIGHT)
	assert_eq(p1.state, S.LANDING, "can't act during landing recovery")
	MatchSim.step(state, defs, RIGHT, 0)
	assert_eq(p1.state, S.WALK_FORWARD)


func test_forward_jump_moves_forward():
	var p1 := state.fighters[0]
	MatchSim.step(state, defs, UP_RIGHT, 0)
	while p1.state != S.LANDING:
		MatchSim.step(state, defs, 0, 0)
	assert_gt(p1.pos_x, -1500)


func test_facing_follows_opponent():
	# Put P1 to the right of P2; after one tick they should turn around.
	state.fighters[0].pos_x = 3000
	MatchSim.step(state, defs, 0, 0)
	assert_eq(state.fighters[0].facing, -1)
	assert_eq(state.fighters[1].facing, 1)


func test_stage_walls():
	TestHelpers.run(state, defs, 600, LEFT)
	var p1 := state.fighters[0]
	assert_eq(p1.pos_x, state.stage_left + defs[0].pushbox_half_width)
