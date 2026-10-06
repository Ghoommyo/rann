extends GutTest


func test_pack_sets_each_flag():
	var bits := InputFrame.pack(true, false, false, true, true, false, false, true)
	assert_true(InputFrame.has(bits, InputFrame.UP))
	assert_true(InputFrame.has(bits, InputFrame.RIGHT))
	assert_true(InputFrame.has(bits, InputFrame.LP))
	assert_true(InputFrame.has(bits, InputFrame.RK))
	assert_false(InputFrame.has(bits, InputFrame.DOWN))
	assert_false(InputFrame.has(bits, InputFrame.LEFT))
	assert_false(InputFrame.has(bits, InputFrame.RP))
	assert_false(InputFrame.has(bits, InputFrame.LK))


func test_opposite_directions_cancel():
	assert_eq(InputFrame.pack(false, false, true, true), 0, "left+right = neutral")
	assert_eq(InputFrame.pack(true, true, false, false), 0, "up+down = neutral")


func test_numpad_facing_right():
	var cases := {
		InputFrame.pack(false, false, false, false): 5,
		InputFrame.pack(false, false, false, true): 6,
		InputFrame.pack(false, false, true, false): 4,
		InputFrame.pack(true, false, false, true): 9,
		InputFrame.pack(false, true, true, false): 1,
		InputFrame.pack(false, true, false, false): 2,
		InputFrame.pack(true, false, false, false): 8,
	}
	for bits in cases:
		assert_eq(InputFrame.to_numpad(bits, 1), cases[bits])


func test_numpad_flips_when_facing_left():
	var right := InputFrame.pack(false, false, false, true)
	assert_eq(InputFrame.to_numpad(right, -1), 4, "holding right while facing left = back")
	var down_left := InputFrame.pack(false, true, true, false)
	assert_eq(InputFrame.to_numpad(down_left, -1), 3, "down-left while facing left = down-forward")


func test_input_buffer_history_and_copy():
	var buf := InputBuffer.new()
	for i in 40:  # more than SIZE, so it wraps around
		buf.push(i)
	assert_eq(buf.latest(), 39)
	assert_eq(buf.get_ago(5), 34)
	var c := buf.copy()
	buf.push(100)
	assert_eq(c.latest(), 39, "copy is independent of the original")


func test_input_buffer_just_pressed():
	var buf := InputBuffer.new()
	buf.push(InputFrame.LP)
	assert_true(buf.just_pressed(InputFrame.LP))
	buf.push(InputFrame.LP)
	assert_false(buf.just_pressed(InputFrame.LP), "held, not newly pressed")
