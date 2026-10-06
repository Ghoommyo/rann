extends GutTest

const H := preload("res://tests/helpers.gd")
const S := FighterState.State

var defs: Array[CharacterDef]
var state: FightState


func before_each():
	defs = H.dummy_defs()
	state = FightState.create(defs)
	H.place_p2_at_wall(state, defs, 700)


func test_jab_cancels_into_straight_with_damage_scaling():
	# Press LP, then RP during hitstop (buffered).
	for step in 60:
		var bits := 0
		if step == 0:
			bits = InputFrame.LP
		elif step == 12:
			bits = InputFrame.RP
		MatchSim.step(state, defs, bits, 0)
	# 50 + 70 × 90% = 113
	assert_eq(state.fighters[1].health, defs[1].max_health - 113)


func test_straight_does_not_cancel_into_jab():
	# straight has no cancels_into, so a buffered LP waits until it ends.
	for step in 20:
		MatchSim.step(state, defs, InputFrame.RP if step == 0 else (InputFrame.LP if step == 16 else 0), 0)
	assert_eq(defs[0].moves[state.fighters[0].move_index].id, "straight")


func test_launcher_juggle():
	var p2 := state.fighters[1]
	MatchSim.step(state, defs, InputFrame.DOWN | InputFrame.RIGHT | InputFrame.RP, 0)
	var launched := false
	var max_combo := 0
	# Alternate LP and RP presses while P2 is in the air: jab → straight cancel.
	# (Two plain jabs are too slow to both hit before P2 lands.)
	for step in 150:
		var bits := 0
		if step % 4 == 0:
			bits = InputFrame.LP
		elif step % 4 == 2:
			bits = InputFrame.RP
		MatchSim.step(state, defs, bits, 0)
		launched = launched or p2.state == S.JUGGLE
		max_combo = maxi(max_combo, p2.combo_hits)
		if launched and p2.state == S.KNOCKDOWN:
			break
	assert_true(launched, "launcher launches")
	assert_gte(max_combo, 3, "launcher + juggle hits")
	assert_eq(p2.state, S.KNOCKDOWN, "lands in a knockdown")


func test_damage_scaling_has_a_floor():
	var p2 := state.fighters[1]
	p2.combo_hits = 50
	p2.set_state(S.HITSTUN)
	p2.stun_frames = 100
	H.run(state, defs, 1, InputFrame.RK)
	H.run(state, defs, 20)
	# mid kick 90 × 30% minimum = 27
	assert_eq(p2.health, defs[1].max_health - 27)


func test_sweep_knocks_down_and_get_up():
	var p2 := state.fighters[1]
	MatchSim.step(state, defs, InputFrame.DOWN | InputFrame.RK, 0)
	var knocked := false
	for step in 200:
		MatchSim.step(state, defs, InputFrame.DOWN, 0)
		knocked = knocked or p2.state == S.KNOCKDOWN
	assert_true(knocked)
	assert_eq(p2.state, S.IDLE, "got back up")
