extends GutTest

var RIGHT := InputFrame.pack(false, false, false, true)
var LEFT := InputFrame.pack(false, false, true, false)
var UP_RIGHT := InputFrame.pack(true, false, false, true)

var defs: Array[CharacterDef]
var state: FightState


func before_each():
	defs = TestHelpers.default_defs()
	state = FightState.create(defs)


func _overlap() -> int:
	return Collision.overlap_x(
		Collision.pushbox_of(state.fighters[0], defs[0]),
		Collision.pushbox_of(state.fighters[1], defs[1]))


func test_walking_into_each_other_never_overlaps():
	for i in 200:
		MatchSim.step(state, defs, RIGHT, LEFT)
		assert_eq(_overlap(), 0, "overlap on frame %d" % i)
	# Equal speeds: they meet in the middle.
	assert_eq(state.fighters[0].pos_x, -state.fighters[1].pos_x)


func test_walking_pushes_idle_opponent():
	var start_p2 := state.fighters[1].pos_x
	TestHelpers.run(state, defs, 200, RIGHT)
	assert_eq(_overlap(), 0)
	assert_gt(state.fighters[1].pos_x, start_p2, "P2 got pushed back")


func test_cornered_opponent_pushes_attacker_back():
	# P2 against the right wall; P1 walks into them.
	state.fighters[1].pos_x = state.stage_right - defs[1].pushbox_half_width
	state.fighters[0].pos_x = state.fighters[1].pos_x - 2000
	TestHelpers.run(state, defs, 120, RIGHT)
	assert_eq(_overlap(), 0)
	assert_eq(state.fighters[1].pos_x, state.stage_right - defs[1].pushbox_half_width,
		"cornered fighter stays at the wall")


func test_cannot_jump_over_opponent():
	# Start close together and jump forward repeatedly.
	state.fighters[0].pos_x = -400
	state.fighters[1].pos_x = 400
	for i in 300:
		MatchSim.step(state, defs, UP_RIGHT, 0)
		assert_eq(_overlap(), 0)
		assert_lt(state.fighters[0].pos_x, state.fighters[1].pos_x, "P1 crossed over on frame %d" % i)
