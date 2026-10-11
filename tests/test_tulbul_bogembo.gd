## Tulbul Pandey and Bogembo: checks for the moves that rely on special
## settings (unbreakable grabs, charge input), using the real character data.
extends GutTest

const H := preload("res://tests/helpers.gd")
const S := FighterState.State
const ALL_BUTTONS := InputFrame.LP | InputFrame.RP | InputFrame.LK | InputFrame.RK

var defs: Array[CharacterDef]
var state: FightState


func before_each():
	defs = [CharacterRegistry.get_def("bogembo"), CharacterRegistry.get_def("tulbul_pandey")]
	state = FightState.create(defs)
	H.place_p2_at_wall(state, defs, 600)


func _p1_move() -> String:
	var f := state.fighters[0]
	return defs[0].moves[f.move_index].id if f.state == S.ATTACK else ""


func test_both_are_in_the_roster():
	var ids := CharacterRegistry.all().map(func(d): return d.id)
	assert_has(ids, "tulbul_pandey")
	assert_has(ids, "bogembo")


func test_tezaab_drop_cannot_be_broken():
	var tezaab: MoveDef = defs[0].moves[defs[0].find_move("tezaab_drop")]
	for step in 100:
		var p1 := (InputFrame.LEFT | InputFrame.LP | InputFrame.RP) if step == 0 else 0
		# P2 mashes every button (a fresh press every other frame) once grabbed.
		var p2 := ALL_BUTTONS if step > tezaab.startup and step % 2 == 0 else 0
		MatchSim.step(state, defs, p1, p2)
	assert_eq(state.fighters[1].health, defs[1].max_health - tezaab.damage)


func test_henchman_charge_needs_a_charge():
	MatchSim.step(state, defs, InputFrame.RIGHT | InputFrame.RP, 0)
	assert_eq(_p1_move(), "tyrant_fist", "uncharged: plain RP")


func test_henchman_charge_after_holding_back():
	H.run(state, defs, 35, InputFrame.LEFT)
	MatchSim.step(state, defs, InputFrame.RIGHT, 0)
	MatchSim.step(state, defs, InputFrame.RIGHT | InputFrame.RP, 0)
	assert_eq(_p1_move(), "henchman_charge")
