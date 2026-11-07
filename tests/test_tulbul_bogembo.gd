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


func test_new_fighters_are_in_the_roster():
	var ids := CharacterRegistry.all().map(func(d): return d.id)
	for id in ["tulbul_pandey", "bogembo", "ravan", "aswashthama"]:
		assert_has(ids, id)
		var def := CharacterRegistry.get_def(id)
		assert_not_null(def.model_scene, "%s has a model" % id)
		assert_not_null(def.animation_library, "%s has animations" % id)


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


# --- Tulbul's SWAG stance (plans/10-tulbul-bogembo-moveset.md) ---

func _tulbul_first() -> void:
	defs = [CharacterRegistry.get_def("tulbul_pandey"), CharacterRegistry.get_def("bogembo")]
	state = FightState.create(defs)
	H.place_p2_at_wall(state, defs, 600)


func _stance() -> String:
	for c in defs[0].get_style().components:
		if c is StanceComponent:
			return (c as StanceComponent).current(state.fighters[0])
	return ""


func _chashma_flip() -> void:
	for bits in [InputFrame.DOWN, InputFrame.DOWN | InputFrame.LEFT, InputFrame.LEFT | InputFrame.LP]:
		MatchSim.step(state, defs, bits, 0)


func _wait_until_free() -> void:
	for i in 60:
		if state.fighters[0].state != S.ATTACK:
			return
		MatchSim.step(state, defs, 0, 0)


func test_chashma_flip_enters_swag_and_changes_rp_and_rk():
	_tulbul_first()
	MatchSim.step(state, defs, InputFrame.RP, 0)
	assert_eq(_p1_move(), "thappad", "normal stance: Thappad")
	_wait_until_free()
	_chashma_flip()
	assert_eq(_p1_move(), "chashma_flip")
	assert_eq(_stance(), "swag")
	_wait_until_free()
	MatchSim.step(state, defs, InputFrame.RP, 0)
	assert_eq(_p1_move(), "double_thappad", "SWAG: Double Thappad")
	assert_eq(_stance(), "normal", "the finisher ends SWAG")


func test_kursi_kick_and_back_on_duty_only_in_swag():
	_tulbul_first()
	MatchSim.step(state, defs, InputFrame.RK, 0)
	assert_eq(_p1_move(), "police_boot")
	_wait_until_free()
	_chashma_flip()
	_wait_until_free()
	MatchSim.step(state, defs, InputFrame.RK, 0)
	assert_eq(_p1_move(), "chair_kick")
	_wait_until_free()
	_chashma_flip()
	_wait_until_free()
	MatchSim.step(state, defs, InputFrame.LK | InputFrame.RK, 0)
	assert_eq(_p1_move(), "duty_reset")
	assert_eq(_stance(), "normal")


func test_getting_hit_knocks_tulbul_out_of_swag():
	_tulbul_first()
	_chashma_flip()
	_wait_until_free()
	state.fighters[1].pos_x = state.fighters[0].pos_x + 600
	for i in 20:
		MatchSim.step(state, defs, 0, InputFrame.LP if i == 0 else 0)
	assert_eq(_stance(), "normal")


func test_shin_kick_and_cop_arrest():
	_tulbul_first()
	MatchSim.step(state, defs, InputFrame.LK, 0)
	assert_eq(_p1_move(), "shin_kick")
	assert_ne(defs[0].find_move("cop_arrest"), -1)


func test_royal_shove_pushes_far():
	var shove: MoveDef = defs[0].moves[defs[0].find_move("royal_shove")]
	var backhand: MoveDef = defs[0].moves[defs[0].find_move("backhand")]
	MatchSim.step(state, defs, InputFrame.LK, 0)
	assert_eq(_p1_move(), "royal_shove")
	assert_gt(shove.pushback, backhand.pushback * 3)


func test_new_moves_borrow_a_clip_until_recorded():
	var tulbul := CharacterRegistry.get_def("tulbul_pandey")
	for id in ["double_thappad", "chair_kick", "shin_kick", "cop_arrest"]:
		var move: MoveDef = tulbul.moves[tulbul.find_move(id)]
		assert_true(tulbul.animation_library.has_animation(move.placeholder_animation), id)


func test_view_plays_placeholder_and_celebration_only_when_the_clip_exists():
	var tulbul := CharacterRegistry.get_def("tulbul_pandey")
	var view := FighterView.new()
	add_child_autofree(view)
	view.setup(tulbul, tulbul.color)
	var f := FightState.create([tulbul, tulbul] as Array[CharacterDef]).fighters[0]
	f.state = S.ATTACK
	f.move_index = tulbul.find_move("double_thappad")
	view.show_state(f, f, 0.0, 0)
	assert_string_ends_with(view._anim.current_animation, "thappad", "borrows Thappad")
	f.state = S.IDLE
	view.pose = "victory"  # not recorded yet: stays on idle
	view.show_state(f, f, 0.0, 1)
	assert_string_ends_with(view._anim.current_animation, "idle")
