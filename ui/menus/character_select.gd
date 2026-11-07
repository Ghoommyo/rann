## Character select: one screen for both players. Player 1 picks on the left,
## the other side (Player 2, the CPU or the training dummy) on the right, with
## VS in the middle. FIGHT starts once both sides have a fighter.
##
## Each side has SLOTS boxes. Fighters come from CharacterRegistry, but only
## the ones the admin opened (Roster) can be picked, and they come first;
## locked fighters and empty slots show a padlock with a "?". In Versus CPU, a difficulty row (0–10) is shown.
extends Control

const SLOTS := 15
const COLUMNS := 5
const SLOT_SIZE := Vector2(92, 84)
const GAP := 8

## The side a box belongs to.
const LEFT := 0
const RIGHT := 1

var _roster: Array[CharacterDef] = []
var _picks: Array[String] = ["", ""]           # fighter id per side, "" = none yet
var _slots: Array[Array] = [[], []]            # the SLOTS buttons of each side
var _picked_labels: Array[Label] = []
var _info_labels: Array[Label] = []
var _fight: Button
var _locked_icon := MenuStyle.icon("locked")
var _level_label: Label
var _level_down: Button
var _level_up: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(MenuStyle.background())

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 40
	column.offset_right = -40
	column.offset_top = 24
	column.offset_bottom = -24
	column.add_theme_constant_override("separation", 12)
	add_child(column)

	var top := HBoxContainer.new()
	top.add_child(MenuStyle.label(Game.mode_name(), 22, MenuStyle.ACCENT))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	if Game.mode == Game.Mode.VERSUS_CPU:
		top.add_child(_make_level_row())
	column.add_child(top)

	var middle := HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.alignment = BoxContainer.ALIGNMENT_CENTER
	middle.add_theme_constant_override("separation", 24)
	middle.add_child(_make_side(LEFT))
	var vs := MenuStyle.label("VS", 72, MenuStyle.ACCENT)
	vs.custom_minimum_size.x = 120
	vs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	middle.add_child(vs)
	middle.add_child(_make_side(RIGHT))
	column.add_child(middle)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 24)
	bottom.add_child(MenuStyle.button("Back", _back, 160))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(gap)
	_fight = MenuStyle.button("Find match" if _online() else "FIGHT", _start, 300)
	bottom.add_child(_fight)
	var gap2 := Control.new()
	gap2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(gap2)
	var balance := Control.new()
	balance.custom_minimum_size.x = 160  # as wide as Back, so FIGHT sits in the middle
	bottom.add_child(balance)
	column.add_child(bottom)

	_refresh_slots()
	Roster.changed.connect(_refresh_slots)
	Roster.refresh()  # the admin may have opened or locked fighters since


func _online() -> bool:
	return Game.mode == Game.Mode.ONLINE


func _side_title(side: int) -> String:
	if side == LEFT:
		return "YOU" if _online() else "PLAYER 1"
	match Game.mode:
		Game.Mode.LOCAL_VERSUS: return "PLAYER 2"
		Game.Mode.VERSUS_CPU: return "CPU"
		Game.Mode.ONLINE: return "OPPONENT"
	return "TRAINING DUMMY"


func _make_side(side: int) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var align := HORIZONTAL_ALIGNMENT_LEFT if side == LEFT else HORIZONTAL_ALIGNMENT_RIGHT

	var title := MenuStyle.label(_side_title(side), 22, MenuStyle.ACCENT)
	title.horizontal_alignment = align
	box.add_child(title)
	var picked := MenuStyle.label("", 34)
	picked.horizontal_alignment = align
	box.add_child(picked)
	_picked_labels.append(picked)

	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", GAP)
	grid.add_theme_constant_override("v_separation", GAP)
	box.add_child(grid)
	for i in SLOTS:
		var slot := Button.new()
		slot.custom_minimum_size = SLOT_SIZE
		slot.clip_text = true
		slot.pressed.connect(_on_slot_pressed.bind(side, i))
		slot.focus_entered.connect(_show_info.bind(side, i))
		slot.mouse_entered.connect(_show_info.bind(side, i))
		grid.add_child(slot)
		_slots[side].append(slot)

	var info := MenuStyle.label("", 18)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.horizontal_alignment = align
	info.custom_minimum_size = Vector2(COLUMNS * SLOT_SIZE.x + (COLUMNS - 1) * GAP, 54)
	box.add_child(info)
	_info_labels.append(info)
	return box


func _make_level_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(MenuStyle.label("CPU:", 22))
	_level_down = MenuStyle.button("−", func(): _set_level(Game.cpu_level - 1), 64)
	row.add_child(_level_down)
	_level_label = MenuStyle.label("", 24)
	_level_label.custom_minimum_size.x = 200
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_level_label)
	_level_up = MenuStyle.button("+", func(): _set_level(Game.cpu_level + 1), 64)
	row.add_child(_level_up)
	_set_level(Game.cpu_level)
	return row


## The fighter in a box, or null for an empty slot.
func _def_at(index: int) -> CharacterDef:
	return _roster[index] if index < _roster.size() else null


## Whether a box on this side can be picked.
func _can_pick(side: int, index: int) -> bool:
	if side == RIGHT and _online():
		return false  # the opponent picks on their own device
	var def := _def_at(index)
	return def != null and Roster.is_unlocked(def.id)


## Redraws every box (at the start, and when the roster changes). A pick that
## got locked is dropped.
func _refresh_slots() -> void:
	var all := CharacterRegistry.all()
	_roster = all.filter(func(d: CharacterDef): return Roster.is_unlocked(d.id))
	_roster.append_array(all.filter(func(d: CharacterDef): return not Roster.is_unlocked(d.id)))
	for side in [LEFT, RIGHT]:
		if _picks[side] != "" and not Roster.is_unlocked(_picks[side]):
			_picks[side] = ""
		for i in SLOTS:
			var slot: Button = _slots[side][i]
			var def := _def_at(i)
			var open := _can_pick(side, i)
			slot.disabled = not open
			slot.focus_mode = Control.FOCUS_ALL if open else Control.FOCUS_NONE
			var hidden_pick: bool = side == RIGHT and _online()  # not locked: just not known here
			slot.icon = null
			slot.text = ""
			slot.expand_icon = true
			slot.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			if open:
				slot.icon = def.portrait
				slot.text = def.display_name.to_upper().replace(" ", "\n")
			elif hidden_pick:
				slot.text = "?"
			else:
				slot.icon = _locked_icon  # a padlock with a "?" on it
			slot.add_theme_color_override("icon_disabled_color", Color(1, 1, 1, 0.45))
			if open:
				for state in ["font_color", "font_focus_color", "font_hover_color", "font_pressed_color"]:
					slot.add_theme_color_override(state, def.color.lightened(0.35))
			else:
				slot.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.25))
			_style_slot(slot, open and _picks[side] == def.id)
	_update_picks()
	var first := _first_open(LEFT)
	if first and get_viewport().gui_get_focus_owner() == null:
		MenuStyle.focus_later(first)


func _first_open(side: int) -> Button:
	for i in SLOTS:
		if _can_pick(side, i):
			return _slots[side][i]
	return null


func _style_slot(slot: Button, picked: bool) -> void:
	MenuStyle.style_button(slot)
	slot.add_theme_font_size_override("font_size", 15 if not slot.disabled else 36)
	if picked:
		var box := StyleBoxFlat.new()
		box.bg_color = MenuStyle.ACCENT.darkened(0.55)
		box.border_color = MenuStyle.ACCENT.lightened(0.2)
		box.set_border_width_all(4)
		box.set_corner_radius_all(6)
		for state in ["normal", "hover", "focus"]:
			slot.add_theme_stylebox_override(state, box)


func _on_slot_pressed(side: int, index: int) -> void:
	if not _can_pick(side, index):
		return
	_picks[side] = _def_at(index).id
	for i in SLOTS:
		var def := _def_at(i)
		_style_slot(_slots[side][i], def != null and _can_pick(side, i) and def.id == _picks[side])
	_update_picks()
	# After Player 1 picks, move on to the other side's boxes.
	if side == LEFT and _picks[RIGHT] == "" and _first_open(RIGHT):
		MenuStyle.focus_later(_first_open(RIGHT))
	elif _ready_to_start():
		MenuStyle.focus_later(_fight)


func _show_info(side: int, index: int) -> void:
	var def := _def_at(index)
	if def and _can_pick(side, index):
		_info_labels[side].text = def.description


func _update_picks() -> void:
	for side in [LEFT, RIGHT]:
		var def := CharacterRegistry.get_def(_picks[side]) if _picks[side] != "" else null
		if side == RIGHT and _online():
			_picked_labels[side].text = "?"
			_info_labels[side].text = "Picks on their own device."
		elif def:
			_picked_labels[side].text = def.display_name.to_upper()
			_info_labels[side].text = def.description
		else:
			_picked_labels[side].text = "—"
			_info_labels[side].text = "Choose a fighter."
	_fight.disabled = not _ready_to_start()


func _ready_to_start() -> bool:
	return _picks[LEFT] != "" and (_online() or _picks[RIGHT] != "")


func _start() -> void:
	if not _ready_to_start():
		return
	Game.p1_id = _picks[LEFT]
	if _online():
		Game.go_to_online_lobby()
		return
	Game.p2_id = _picks[RIGHT]
	Game.start_fight()


func _set_level(level: int) -> void:
	level = clampi(level, CpuOpponent.MIN_LEVEL, CpuOpponent.MAX_LEVEL)
	_level_label.text = "%d · %s" % [level, CpuOpponent.level_name(level)]
	_level_down.modulate.a = 0.35 if level == CpuOpponent.MIN_LEVEL else 1.0
	_level_up.modulate.a = 0.35 if level == CpuOpponent.MAX_LEVEL else 1.0
	if level != Game.cpu_level:
		Game.cpu_level = level
		Settings.cpu_level = level
		Settings.save()


func _back() -> void:
	Game.go_to_main_menu()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_back()
		get_viewport().set_input_as_handled()
