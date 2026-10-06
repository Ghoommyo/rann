extends GutTest

const H := preload("res://tests/helpers.gd")
const S := FighterState.State

var defs: Array[CharacterDef]
var state: FightState


func before_each():
	# Kael (P1) attacks, Mira (P2) defends.
	defs = [CharacterRegistry.get_def("kael"), CharacterRegistry.get_def("mira")]
	state = FightState.create(defs)
	H.place_p2_at_wall(state, defs, 700)


## Kael jabs (hits on frame 10). Mira taps forward on `tap_step`.
func _jab_with_tap(tap_step: int, tap: int = InputFrame.LEFT) -> void:
	for step in 40:
		MatchSim.step(state, defs, InputFrame.LP if step == 0 else 0, tap if step == tap_step else 0)


func test_well_timed_tap_parries():
	_jab_with_tap(7)  # tap 3 frames before the hit (window 5)
	assert_eq(state.fighters[1].health, defs[1].max_health, "no damage")
	assert_eq(state.fighters[0].state, S.HITSTUN, "attacker left stunned")


func test_early_tap_fails():
	_jab_with_tap(1)  # window long gone by frame 10
	assert_lt(state.fighters[1].health, defs[1].max_health)


func test_lows_are_not_parried():
	for step in 40:
		var p1 := (InputFrame.DOWN | InputFrame.LK) if step == 0 else InputFrame.DOWN
		MatchSim.step(state, defs, p1, InputFrame.LEFT if step == 9 else 0)
	assert_lt(state.fighters[1].health, defs[1].max_health)


func test_cooldown_stops_mashing():
	# Tap forward every few frames: only the first tap opens a window, so a
	# later attack still hits.
	for step in 60:
		var tap := InputFrame.LEFT if step % 4 == 0 else 0
		MatchSim.step(state, defs, InputFrame.LP if step == 20 else 0, tap)
	assert_lt(state.fighters[1].health, defs[1].max_health)
