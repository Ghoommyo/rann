extends GutTest

const H := preload("res://tests/helpers.gd")
const S := FighterState.State

var defs: Array[CharacterDef]
var state: FightState


func before_each():
	defs = H.dummy_defs()
	state = FightState.create(defs)
	H.place_p2_at_wall(state, defs, 700)


## Presses `p1_input` on frame 1 and returns the step number on which P2 was
## first hit or blocked (or -1).
func _contact_step(p1_input: int, p2_input: int, max_steps := 40) -> int:
	for step in range(1, max_steps + 1):
		MatchSim.step(state, defs, p1_input if step == 1 else 0, p2_input)
		var p2 := state.fighters[1]
		if p2.state == S.HITSTUN or p2.state == S.BLOCKSTUN or p2.state == S.KNOCKDOWN \
				or p2.state == S.JUGGLE or p2.state == S.THROWN:
			return step
	return -1


func test_jab_hits_on_its_startup_frame():
	var jab: MoveDef = defs[0].moves[defs[0].find_move("jab")]
	assert_eq(_contact_step(InputFrame.LP, 0), jab.startup)


func test_mid_kick_hits_on_its_startup_frame():
	var kick: MoveDef = defs[0].moves[defs[0].find_move("mid_kick")]
	assert_eq(_contact_step(InputFrame.RK, 0), kick.startup)


func test_jab_advantage_on_hit_and_block():
	_contact_step(InputFrame.LP, 0)
	assert_eq(state.last_advantage, 8, "jab is +8 on hit")
	before_each()
	_contact_step(InputFrame.LP, H.RIGHT)  # P2 faces left: RIGHT = back = block
	assert_true(state.last_blocked)
	assert_eq(state.last_advantage, 1, "jab is +1 on block")


## The advantage shown in the HUD must match what really happens.
func test_recorded_advantage_matches_reality():
	for p2_input in [0, H.RIGHT]:
		before_each()
		_contact_step(InputFrame.RK, p2_input)
		var predicted := state.last_advantage
		var p1_free := -1
		var p2_free := -1
		for step in 200:
			MatchSim.step(state, defs, 0, p2_input)
			if p1_free < 0 and state.fighters[0].state != S.ATTACK:
				p1_free = step
			var p2 := state.fighters[1]
			if p2_free < 0 and p2.state != S.HITSTUN and p2.state != S.BLOCKSTUN:
				p2_free = step
		assert_eq(p2_free - p1_free, predicted, "input %d" % p2_input)


func test_hitstop_freezes_both_fighters():
	_contact_step(InputFrame.LP, 0)
	var before := state.copy()
	MatchSim.step(state, defs, 0, 0)
	assert_gt(state.hitstop, 0)
	assert_eq(state.fighters[0].state_frame, before.fighters[0].state_frame)
	assert_eq(state.fighters[1].pos_x, before.fighters[1].pos_x)


func test_move_hits_only_once():
	_contact_step(InputFrame.RK, 0)  # mid kick has 3 active frames
	TestHelpers.run(state, defs, 40)
	assert_eq(state.fighters[1].combo_hits, 0, "combo over, P2 recovered")
	assert_eq(state.fighters[1].health, defs[1].max_health - 90)


func test_trade_both_get_hit():
	# Both jab on the same frame at a range where both reach.
	state.fighters[0].pos_x = -350
	state.fighters[1].pos_x = 350
	for step in 12:
		MatchSim.step(state, defs, InputFrame.LP if step == 0 else 0, InputFrame.LP if step == 0 else 0)
	assert_eq(state.fighters[0].health, defs[0].max_health - 50)
	assert_eq(state.fighters[1].health, defs[1].max_health - 50)


func test_dash_punch_moves_forward():
	var start := state.fighters[0].pos_x
	state.fighters[0].pos_x -= 2000  # far away so it whiffs
	start = state.fighters[0].pos_x
	MatchSim.step(state, defs, H.DOWN, 0)
	MatchSim.step(state, defs, H.DOWN | H.RIGHT, 0)
	MatchSim.step(state, defs, H.RIGHT | InputFrame.RP, 0)
	assert_eq(state.fighters[0].state, S.ATTACK)
	assert_eq(defs[0].moves[state.fighters[0].move_index].id, "dash_punch")
	TestHelpers.run(state, defs, 20)
	assert_gt(state.fighters[0].pos_x, start + 500)
