## The fighter list from the admin portal (Roster) and the character select
## screen that uses it.
extends GutTest

const PATH := "user://roster_test.cfg"

var _saved_unlocked: Array[String]
var _saved_mode: int


func before_each():
	_saved_unlocked = Roster.unlocked.duplicate()
	_saved_mode = Game.mode
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	Roster.load_cache(PATH)


func after_each():
	Roster.load_cache()  # back to the real file
	Roster.unlocked = _saved_unlocked
	Game.mode = _saved_mode as Game.Mode
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_first_launch_opens_kael_and_mira():
	assert_eq(Roster.unlocked, ["kael", "mira"] as Array[String])
	assert_true(Roster.is_unlocked("kael"))
	assert_false(Roster.is_unlocked("tulbul_pandey"), "new fighters are locked")
	assert_false(Roster.is_unlocked("someone_new"))


func test_the_last_list_is_kept_for_offline():
	watch_signals(Roster)
	Roster.set_unlocked(["kael", "tulbul_pandey"] as Array[String])
	assert_signal_emitted(Roster, "changed")
	Roster.load_cache(PATH)
	assert_eq(Roster.unlocked, ["kael", "tulbul_pandey"] as Array[String])
	assert_false(Roster.is_unlocked("mira"))


func _open_select(mode: Game.Mode) -> Control:
	Game.mode = mode
	var screen: Control = load(Game.CHARACTER_SELECT).instantiate()
	add_child_autofree(screen)
	return screen


func _slot_of(screen: Control, side: int, id: String) -> Button:
	for i in screen.SLOTS:
		var def: CharacterDef = screen._def_at(i)
		if def and def.id == id:
			return screen._slots[side][i]
	return null


func test_both_sides_have_15_boxes_and_locked_ones_show_a_question_mark():
	Roster.set_unlocked(["kael", "tulbul_pandey"] as Array[String])
	var screen := _open_select(Game.Mode.LOCAL_VERSUS)
	for side in [0, 1]:
		assert_eq(screen._slots[side].size(), 15)
		var open := 0
		for slot: Button in screen._slots[side]:
			if slot.disabled:
				assert_eq(slot.text, "?")
			else:
				open += 1
		assert_eq(open, 2, "only the open fighters can be picked")
		assert_false(_slot_of(screen, side, "tulbul_pandey").disabled)
		assert_true(_slot_of(screen, side, "mira").disabled)


func test_fight_needs_both_sides():
	var screen := _open_select(Game.Mode.VERSUS_CPU)
	assert_true(screen._fight.disabled)
	_slot_of(screen, 0, "kael").pressed.emit()
	assert_true(screen._fight.disabled, "the right side isn't picked yet")
	_slot_of(screen, 1, "mira").pressed.emit()
	assert_false(screen._fight.disabled)
	assert_eq(screen._picks, ["kael", "mira"] as Array[String])


func test_a_fighter_locked_while_picking_is_dropped():
	var screen := _open_select(Game.Mode.LOCAL_VERSUS)
	_slot_of(screen, 0, "mira").pressed.emit()
	Roster.set_unlocked(["kael"] as Array[String])
	assert_eq(screen._picks[0], "")
	assert_true(_slot_of(screen, 0, "mira").disabled)


func test_online_the_opponent_side_is_all_question_marks():
	var screen := _open_select(Game.Mode.ONLINE)
	for slot: Button in screen._slots[1]:
		assert_true(slot.disabled)
		assert_eq(slot.text, "?")
	_slot_of(screen, 0, "kael").pressed.emit()
	assert_false(screen._fight.disabled, "online only needs your own pick")
	assert_eq(screen._fight.text, "Find match")
