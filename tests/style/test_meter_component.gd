extends GutTest

const H := preload("res://tests/helpers.gd")
const VALUE := MeterComponent.VALUE

var defs: Array[CharacterDef]
var state: FightState


func before_each():
	var kael := CharacterRegistry.get_def("kael")
	defs = [kael, CharacterRegistry.get_def("mira")]
	state = FightState.create(defs)
	H.place_p2_at_wall(state, defs, 700)


func test_starts_empty_and_gains_on_hit():
	assert_eq(state.fighters[0].style_data[VALUE], 0)
	H.run(state, defs, 1, InputFrame.RK)
	H.run(state, defs, 30)
	assert_eq(state.fighters[0].style_data[VALUE], 70, "gain_on_hit")


func test_super_needs_full_meter():
	var kael := state.fighters[0]
	_do_super()
	assert_ne(_current_move(), "rage_burst", "no meter: no super")
	before_each()
	state.fighters[0].style_data[VALUE] = 1000
	_do_super()
	assert_eq(_current_move(), "rage_burst")
	assert_eq(state.fighters[0].style_data[VALUE], 0, "meter spent")


func _do_super():
	for bits in [InputFrame.DOWN, InputFrame.DOWN | InputFrame.RIGHT, InputFrame.RIGHT | InputFrame.LP | InputFrame.RP]:
		MatchSim.step(state, defs, bits, 0)


func _current_move() -> String:
	var f := state.fighters[0]
	return defs[0].moves[f.move_index].id if f.state == FighterState.State.ATTACK else ""
