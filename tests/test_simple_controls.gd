## Simple controls: the SP button performs special moves without motion inputs.
extends GutTest

const H := preload("res://tests/helpers.gd")
const S := FighterState.State

var defs: Array[CharacterDef]
var state: FightState


func before_each():
	defs = [CharacterRegistry.get_def("kael"), CharacterRegistry.get_def("mira")]
	state = FightState.create(defs)


func _move(i := 0) -> String:
	var f := state.fighters[i]
	return defs[i].moves[f.move_index].id if f.state == S.ATTACK else ""


func test_sp_parses():
	var c := MoveCommand.parse("6+SP")
	assert_eq(c.buttons, InputFrame.SP)
	assert_eq(Array(c.motion), [6])


func test_sp_does_signature_move():
	MatchSim.step(state, defs, InputFrame.SP, 0)
	assert_eq(_move(), "dash_punch")


func test_forward_sp_does_launcher():
	MatchSim.step(state, defs, InputFrame.RIGHT | InputFrame.SP, 0)
	assert_eq(_move(), "uppercut")


func test_classic_input_still_works():
	for bits in [InputFrame.DOWN, InputFrame.DOWN | InputFrame.RIGHT, InputFrame.RIGHT | InputFrame.RP]:
		MatchSim.step(state, defs, bits, 0)
	assert_eq(_move(), "dash_punch")


func test_simple_super_still_needs_meter():
	MatchSim.step(state, defs, InputFrame.DOWN | InputFrame.SP, 0)
	assert_ne(_move(), "rage_burst", "no meter")
	before_each()
	state.fighters[0].style_data[MeterComponent.VALUE] = 1000
	MatchSim.step(state, defs, InputFrame.DOWN | InputFrame.SP, 0)
	assert_eq(_move(), "rage_burst")


func test_mira_sp_toggles_stance():
	defs = [CharacterRegistry.get_def("mira"), CharacterRegistry.get_def("kael")]
	state = FightState.create(defs)
	MatchSim.step(state, defs, InputFrame.SP, 0)
	assert_eq(_move(), "to_crane")
	H.run(state, defs, 15)
	MatchSim.step(state, defs, InputFrame.SP, 0)
	assert_eq(_move(), "to_tiger")


func test_touch_block_button_holds_back():
	var held := {"block": true}
	# Facing right: back = LEFT.
	assert_eq(TouchControls.compose_bits(Vector2.ZERO, held, 1), InputFrame.LEFT)
	assert_eq(TouchControls.compose_bits(Vector2.ZERO, held, -1), InputFrame.RIGHT)
	# Stick down + block = down-back (crouch block); stick up is ignored (no jumping).
	assert_eq(TouchControls.compose_bits(Vector2(0, 1), held, 1), InputFrame.LEFT | InputFrame.DOWN)
	assert_eq(TouchControls.compose_bits(Vector2(0, -1), held, 1), InputFrame.LEFT)


func test_touch_stick_and_buttons():
	assert_eq(TouchControls.compose_bits(Vector2(1, 0.1), {"lp": true, "sp": true}, 1),
		InputFrame.RIGHT | InputFrame.LP | InputFrame.SP)
	assert_eq(TouchControls.compose_bits(Vector2(0.2, 0.2), {}, 1), 0, "inside the deadzone")
