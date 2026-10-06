extends GutTest

const H := preload("res://tests/helpers.gd")
var RP := InputFrame.RP
var LP := InputFrame.LP


## Builds a buffer from a list of inputs (oldest first).
func _buffer(frames: Array) -> InputBuffer:
	var buf := InputBuffer.new()
	for bits in frames:
		buf.push(bits)
	return buf


func test_parse():
	var c := MoveCommand.parse("236+RP")
	assert_eq(Array(c.motion), [2, 3, 6])
	assert_eq(c.buttons, RP)
	assert_eq(c.priority, 31)
	assert_eq(MoveCommand.parse("LP+LK").buttons, LP | InputFrame.LK)
	assert_gt(MoveCommand.parse("3+RP").priority, MoveCommand.parse("RP").priority)


func test_quarter_circle_detected():
	var buf := _buffer([H.DOWN, H.DOWN | H.RIGHT, H.RIGHT | RP])
	assert_gt(MoveCommand.parse("236+RP").find_press(buf, 1, -1), 0)


func test_sloppy_but_in_time_still_works():
	# Extra frames on each direction and the button 3 frames after the motion.
	var buf := _buffer([H.DOWN, H.DOWN, H.DOWN | H.RIGHT, H.DOWN | H.RIGHT, H.RIGHT, 0, 0, RP])
	assert_gt(MoveCommand.parse("236+RP").find_press(buf, 1, -1), 0)


func test_too_slow_fails():
	var frames := [H.DOWN]
	for i in 15:
		frames.append(0)
	frames += [H.DOWN | H.RIGHT, H.RIGHT | RP]
	assert_eq(MoveCommand.parse("236+RP").find_press(_buffer(frames), 1, -1), -1)


func test_motion_mirrors_when_facing_left():
	# Facing left, "forward" is LEFT on screen.
	var buf := _buffer([H.DOWN, H.DOWN | H.LEFT, H.LEFT | RP])
	assert_gt(MoveCommand.parse("236+RP").find_press(buf, -1, -1), 0)
	assert_eq(MoveCommand.parse("236+RP").find_press(buf, 1, -1), -1)


func test_single_direction_command():
	var cmd := MoveCommand.parse("3+RP")
	assert_gt(cmd.find_press(_buffer([H.DOWN | H.RIGHT | RP]), 1, -1), 0)
	assert_eq(cmd.find_press(_buffer([H.RIGHT | RP]), 1, -1), -1)


func test_buffered_press_window():
	var cmd := MoveCommand.parse("LP")
	var frames := [LP]
	for i in MoveCommand.BUFFER_WINDOW - 1:
		frames.append(0)
	assert_gt(cmd.find_press(_buffer(frames), 1, -1), 0, "still inside the buffer")
	frames.append(0)
	assert_eq(cmd.find_press(_buffer(frames), 1, -1), -1, "too old")


func test_holding_a_button_is_not_a_new_press():
	var buf := _buffer([LP, LP, LP])
	var cmd := MoveCommand.parse("LP")
	var press := cmd.find_press(buf, 1, -1)
	assert_eq(press, 1, "only the first frame counts as the press")
	assert_eq(cmd.find_press(buf, 1, press), -1, "a press can't be used twice")


func test_two_button_command_needs_both():
	var cmd := MoveCommand.parse("LP+LK")
	assert_eq(cmd.find_press(_buffer([LP]), 1, -1), -1)
	assert_gt(cmd.find_press(_buffer([LP | InputFrame.LK]), 1, -1), 0)


func test_priority_order_in_character():
	var def: CharacterDef = load(H.DUMMY_PATH)
	var order := def.moves_by_priority()
	assert_eq(def.moves[order[0]].command, "236+RP", "motion input checked first")
