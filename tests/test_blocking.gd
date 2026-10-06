## The Tekken-style blocking table from plans/02-phase-combat-system.md.
extends GutTest

const H := preload("res://tests/helpers.gd")
const S := FighterState.State

# P2 faces left, so for P2: RIGHT = back, DOWN+RIGHT = down-back.
const STAND := 0
const BACK := InputFrame.RIGHT
const DOWN_BACK := InputFrame.DOWN | InputFrame.RIGHT


## Does the move, with P2 holding `guard`. Returns "hit", "block" or "whiff".
func _result(p1_input: int, guard: int) -> String:
	var defs := H.dummy_defs()
	var state := FightState.create(defs)
	H.place_p2_at_wall(state, defs, 700)
	var blocked := false
	for step in 60:
		var bits := p1_input if step == 0 else p1_input & InputFrame.DIRECTIONS
		MatchSim.step(state, defs, bits, guard)
		if state.fighters[1].state == S.BLOCKSTUN:
			blocked = true
	if blocked:
		return "block"
	if state.fighters[1].health < defs[1].max_health:
		return "hit"
	return "whiff"


func test_high():
	var jab := InputFrame.LP
	assert_eq(_result(jab, STAND), "hit")
	assert_eq(_result(jab, BACK), "block")
	assert_eq(_result(jab, DOWN_BACK), "whiff", "crouching ducks highs")


func test_mid():
	var kick := InputFrame.RK
	assert_eq(_result(kick, STAND), "hit")
	assert_eq(_result(kick, BACK), "block")
	assert_eq(_result(kick, DOWN_BACK), "hit", "mids hit crouchers")


func test_low():
	var low := InputFrame.DOWN | InputFrame.LK
	assert_eq(_result(low, STAND), "hit")
	assert_eq(_result(low, BACK), "hit", "lows can't be blocked standing")
	assert_eq(_result(low, DOWN_BACK), "block")


func test_throw():
	var grab := InputFrame.LP | InputFrame.LK
	assert_eq(_result(grab, STAND), "hit")
	assert_eq(_result(grab, BACK), "hit", "throws can't be blocked")
	assert_eq(_result(grab, DOWN_BACK), "whiff", "crouching ducks throws")


func test_low_profile_move_ducks_highs():
	# P2 jabs while P1 does a low kick (low profile): the jab whiffs.
	var defs := H.dummy_defs()
	var state := FightState.create(defs)
	state.fighters[0].pos_x = -350
	state.fighters[1].pos_x = 350
	for step in 30:
		MatchSim.step(state, defs,
			(InputFrame.DOWN | InputFrame.LK) if step == 0 else InputFrame.DOWN,
			InputFrame.LP if step == 0 else 0)
	assert_eq(state.fighters[0].health, defs[0].max_health, "jab went over the low kick")
	assert_lt(state.fighters[1].health, defs[1].max_health, "low kick landed")
