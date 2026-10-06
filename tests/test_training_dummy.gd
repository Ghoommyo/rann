extends GutTest

const H := preload("res://tests/helpers.gd")

var defs: Array[CharacterDef]
var state: FightState


func before_each():
	defs = [CharacterRegistry.get_def("kael"), CharacterRegistry.get_def("mira")]
	state = FightState.create(defs, false, true)
	H.place_p2_at_wall(state, defs, 700)


func _run(dummy: TrainingDummy, p1_sequence: Array, steps: int) -> int:
	var blocks := 0
	for step in steps:
		var p1: int = p1_sequence[step] if step < p1_sequence.size() else 0
		var both := dummy.inputs(state, defs, p1)
		MatchSim.step(state, defs, both[0], both[1])
		for e in state.events:
			if e.type == FightState.Event.BLOCK:
				blocks += 1
	return blocks


func test_block_all_blocks_high_mid_and_low():
	var dummy := TrainingDummy.new()
	dummy.mode = TrainingDummy.Mode.BLOCK_ALL
	assert_eq(_run(dummy, [InputFrame.LP], 40), 1, "high")
	before_each()  # pushback moved the fighters apart: start fresh for each attack
	assert_eq(_run(dummy, [InputFrame.RK], 40), 1, "mid")
	before_each()
	assert_eq(_run(dummy, [InputFrame.DOWN | InputFrame.LK, InputFrame.DOWN], 40), 1, "low")


func test_record_and_playback():
	var dummy := TrainingDummy.new()
	dummy.toggle_recording()
	# While recording, P1's input drives P2: walk right for 10 frames.
	_run(dummy, [InputFrame.LEFT, InputFrame.LEFT, InputFrame.LEFT], 3)
	dummy.toggle_recording()
	assert_eq(dummy.mode, TrainingDummy.Mode.PLAYBACK)
	var x_before := state.fighters[1].pos_x
	_run(dummy, [], 3)
	assert_lt(state.fighters[1].pos_x, x_before, "dummy repeats the recorded walk")
