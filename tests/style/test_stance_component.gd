extends GutTest

const H := preload("res://tests/helpers.gd")
const INDEX := StanceComponent.INDEX
const S := FighterState.State

var defs: Array[CharacterDef]
var state: FightState


func before_each():
	# Mira is P1 here.
	defs = [CharacterRegistry.get_def("mira"), CharacterRegistry.get_def("kael")]
	state = FightState.create(defs)
	H.place_p2_at_wall(state, defs, 700)


func _move_id() -> String:
	var f := state.fighters[0]
	return defs[0].moves[f.move_index].id if f.state == S.ATTACK else ""


func test_starts_in_tiger_and_switches_to_crane():
	assert_eq(state.fighters[0].style_data[INDEX], 0)
	H.run(state, defs, 1, InputFrame.LK | InputFrame.RK)
	assert_eq(_move_id(), "to_crane")
	assert_eq(state.fighters[0].style_data[INDEX], 1)


func test_same_button_different_move_per_stance():
	H.run(state, defs, 1, InputFrame.LP)
	assert_eq(_move_id(), "tiger_claw")
	before_each()
	H.run(state, defs, 1, InputFrame.LK | InputFrame.RK)
	H.run(state, defs, 15)
	H.run(state, defs, 1, InputFrame.LP)
	assert_eq(_move_id(), "crane_peck")


func test_getting_hit_resets_stance():
	H.run(state, defs, 1, InputFrame.LK | InputFrame.RK)
	H.run(state, defs, 15)
	assert_eq(state.fighters[0].style_data[INDEX], 1)
	state.fighters[1].pos_x = state.fighters[0].pos_x + 700
	H.run(state, defs, 1, 0, InputFrame.LP)  # Kael jabs Mira
	H.run(state, defs, 15)
	assert_eq(state.fighters[0].style_data[INDEX], 0, "back to tiger")
