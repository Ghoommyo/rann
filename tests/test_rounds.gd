extends GutTest

const H := preload("res://tests/helpers.gd")
const Phase := FightState.Phase

var defs: Array[CharacterDef]
var state: FightState


func before_each():
	defs = H.dummy_defs()
	state = FightState.create(defs)
	H.place_p2_at_wall(state, defs, 700)


func _ko_p2() -> void:
	state.fighters[1].health = 1
	H.run(state, defs, 1, InputFrame.LP)
	H.run(state, defs, 20)


func test_ko_wins_round_and_next_round_starts():
	_ko_p2()
	assert_eq(state.phase, Phase.ROUND_OVER)
	assert_eq(state.round_winner, 0)
	assert_eq(state.wins[0], 1)
	H.run(state, defs, Rules.ROUND_OVER_FRAMES)
	assert_eq(state.phase, Phase.READY)
	assert_eq(state.round_number, 2)
	assert_eq(state.fighters[1].health, defs[1].max_health, "health reset")
	assert_eq(state.fighters[0].pos_x, -FightState.START_DISTANCE / 2, "positions reset")


func test_ko_fighter_stays_down():
	_ko_p2()
	H.run(state, defs, 100)
	assert_eq(state.fighters[1].state, FighterState.State.KNOCKDOWN)


func test_time_out_more_health_wins():
	state.fighters[0].health = 500
	state.round_timer = 1
	H.run(state, defs, 1)
	assert_eq(state.phase, Phase.ROUND_OVER)
	assert_eq(state.round_winner, 1)


func test_time_out_draw_gives_both_a_win():
	state.round_timer = 1
	H.run(state, defs, 1)
	assert_eq(state.round_winner, -1)
	assert_eq(Array(state.wins), [1, 1])


func test_two_wins_ends_the_match():
	state.wins[0] = 1
	_ko_p2()
	H.run(state, defs, Rules.ROUND_OVER_FRAMES)
	assert_eq(state.phase, Phase.MATCH_OVER)
	assert_eq(state.match_winner, 0)


func test_ready_phase_ignores_input():
	state = FightState.create(defs, true)
	H.run(state, defs, Rules.READY_FRAMES - 1, InputFrame.RIGHT)
	assert_eq(state.phase, Phase.READY)
	assert_eq(state.fighters[0].pos_x, -FightState.START_DISTANCE / 2)
	H.run(state, defs, 1)
	assert_eq(state.phase, Phase.FIGHTING)


func test_timer_counts_down_only_while_fighting():
	H.run(state, defs, 60)
	assert_eq(state.round_timer, Rules.ROUND_FRAMES - 60)
