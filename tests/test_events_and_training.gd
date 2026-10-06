extends GutTest

const H := preload("res://tests/helpers.gd")
const Event := FightState.Event

var defs: Array[CharacterDef]
var state: FightState


func before_each():
	defs = H.dummy_defs()


func _collect(steps: int, p1_first: int) -> Array:
	var types := []
	for step in steps:
		MatchSim.step(state, defs, p1_first if step == 0 else 0, 0)
		for e in state.events:
			types.append(e.type)
	return types


func test_hit_event_once_at_contact():
	state = FightState.create(defs)
	H.place_p2_at_wall(state, defs, 700)
	var types := _collect(40, InputFrame.LP)
	assert_eq(types.count(Event.HIT), 1)


func test_round_start_and_ko_events():
	state = FightState.create(defs, true)
	var types := _collect(Rules.READY_FRAMES + 1, 0)
	assert_has(types, Event.ROUND_START)
	H.place_p2_at_wall(state, defs, 700)
	state.fighters[1].health = 1
	assert_has(_collect(30, InputFrame.LP), Event.KO)


func test_training_never_ends_and_refills_health():
	state = FightState.create(defs, false, true)
	H.place_p2_at_wall(state, defs, 700)
	state.fighters[1].health = 1
	_collect(60, InputFrame.LP)
	assert_eq(state.phase, FightState.Phase.FIGHTING, "no KO in training")
	assert_eq(state.fighters[1].health, defs[1].max_health, "refilled after the combo")
	H.run(state, defs, 6000)
	assert_eq(state.round_timer, Rules.ROUND_FRAMES, "timer frozen")
