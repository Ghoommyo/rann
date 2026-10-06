## ChargeInputComponent isn't used by the starting roster yet, so this test
## builds a small character in code to prove it works.
extends GutTest

const S := FighterState.State

var defs: Array[CharacterDef]
var state: FightState


func before_each():
	var def := CharacterDef.new()
	def.id = "charger"
	var punch := MoveDef.new()
	punch.id = "punch"
	punch.command = "RP"
	var charge_punch := MoveDef.new()
	charge_punch.id = "charge_punch"
	charge_punch.command = "6+RP"
	charge_punch.requires_charge = true
	def.moves = [punch, charge_punch]
	def.style = FightStyle.new()
	var charge := ChargeInputComponent.new()
	charge.charge_frames = 30
	def.style.components = [charge]
	defs = [def, def]
	state = FightState.create(defs)


func _move() -> String:
	var f := state.fighters[0]
	return defs[0].moves[f.move_index].id if f.state == S.ATTACK else ""


func test_uncharged_falls_back_to_normal_move():
	MatchSim.step(state, defs, InputFrame.RIGHT | InputFrame.RP, 0)
	assert_eq(_move(), "punch")


func test_charged_move_after_holding_back():
	TestHelpers.run(state, defs, 35, InputFrame.LEFT)  # P1 faces right: LEFT = back
	MatchSim.step(state, defs, InputFrame.RIGHT, 0)
	MatchSim.step(state, defs, InputFrame.RIGHT | InputFrame.RP, 0)
	assert_eq(_move(), "charge_punch")


func test_short_charge_is_not_enough():
	TestHelpers.run(state, defs, 10, InputFrame.LEFT)
	MatchSim.step(state, defs, InputFrame.RIGHT | InputFrame.RP, 0)
	assert_eq(_move(), "punch")


func test_charge_expires_after_grace():
	TestHelpers.run(state, defs, 35, InputFrame.LEFT)
	TestHelpers.run(state, defs, 20, 0)
	MatchSim.step(state, defs, InputFrame.RIGHT | InputFrame.RP, 0)
	assert_eq(_move(), "punch")
