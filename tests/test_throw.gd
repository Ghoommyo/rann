extends GutTest

const H := preload("res://tests/helpers.gd")
const S := FighterState.State
const GRAB := InputFrame.LP | InputFrame.LK

var defs: Array[CharacterDef]
var state: FightState


func before_each():
	defs = H.dummy_defs()
	state = FightState.create(defs)
	H.place_p2_at_wall(state, defs, 600)


func _grab(p2_press_on_step: int, p2_button: int) -> void:
	for step in 80:
		var p2 := p2_button if step == p2_press_on_step else 0
		MatchSim.step(state, defs, GRAB if step == 0 else 0, p2)


func test_throw_lands():
	_grab(-1, 0)
	assert_eq(state.fighters[1].health, defs[1].max_health - 120)


func test_throw_break_with_correct_button():
	_grab(20, InputFrame.LP)  # throw connects on step 12, break 8 frames later
	assert_eq(state.fighters[1].health, defs[1].max_health, "broken: no damage")


func test_wrong_button_does_not_break():
	_grab(20, InputFrame.RP)
	assert_eq(state.fighters[1].health, defs[1].max_health - 120)


func test_too_late_does_not_break():
	_grab(12 + Rules.THROW_BREAK_WINDOW + 2, InputFrame.LP)
	assert_eq(state.fighters[1].health, defs[1].max_health - 120)
