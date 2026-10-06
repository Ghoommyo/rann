## Character select. The list comes from CharacterRegistry, so new characters
## appear here without any changes to this screen.
##
## Flow: P1 picks, then P2 picks (the CPU / training dummy is picked by P1).
## In Versus CPU, a difficulty row is shown.
extends Control

var _roster: Array[CharacterDef] = []
var _picking := 0  # 0 = choosing P1, 1 = choosing P2
var _title: Label
var _cards: HBoxContainer
var _info: Label
var _level_row: HBoxContainer
var _level_buttons: Array[Button] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(MenuStyle.background())
	_roster = CharacterRegistry.all()

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 40
	column.offset_right = -40
	column.offset_top = 30
	column.offset_bottom = -30
	column.add_theme_constant_override("separation", 18)
	add_child(column)

	var header := MenuStyle.label(Game.mode_name(), 22, MenuStyle.ACCENT)
	column.add_child(header)
	_title = MenuStyle.label("", 44)
	column.add_child(_title)

	_cards = HBoxContainer.new()
	_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards.add_theme_constant_override("separation", 24)
	_cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_cards)
	for def in _roster:
		_cards.add_child(_make_card(def))

	_info = MenuStyle.label("", 20)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_info)

	_level_row = HBoxContainer.new()
	_level_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_level_row.add_theme_constant_override("separation", 12)
	_level_row.add_child(MenuStyle.label("CPU:", 22))
	for level in ["Easy", "Normal", "Hard"]:
		var index := _level_buttons.size()
		var b := MenuStyle.button(level, func(): _set_level(index), 140)
		_level_row.add_child(b)
		_level_buttons.append(b)
	_level_row.visible = Game.mode == Game.Mode.VERSUS_CPU
	column.add_child(_level_row)
	_set_level(Game.cpu_level)

	var bottom := HBoxContainer.new()
	bottom.add_child(MenuStyle.button("Back", _back, 160))
	column.add_child(bottom)

	_update_title()


func _make_card(def: CharacterDef) -> Button:
	var card := MenuStyle.button(def.display_name.to_upper(), func(): _pick(def), 260)
	card.custom_minimum_size = Vector2(260, 300)
	card.add_theme_font_size_override("font_size", 34)
	for state in ["font_color", "font_focus_color", "font_hover_color", "font_pressed_color"]:
		card.add_theme_color_override(state, def.color.lightened(0.35))
	card.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	card.expand_icon = true
	if def.portrait:
		card.icon = def.portrait
	card.focus_entered.connect(func(): _info.text = def.description)
	card.mouse_entered.connect(func(): _info.text = def.description)
	return card


func _update_title() -> void:
	var who := "PLAYER 1"
	if _picking == 1:
		who = "PLAYER 2" if Game.mode == Game.Mode.LOCAL_VERSUS else \
			("CPU OPPONENT" if Game.mode == Game.Mode.VERSUS_CPU else "TRAINING DUMMY")
	_title.text = "%s — choose your fighter" % who
	if _cards.get_child_count() > 0:
		(_cards.get_child(0) as Control).grab_focus.call_deferred()


func _pick(def: CharacterDef) -> void:
	if _picking == 0:
		Game.p1_id = def.id
		_picking = 1
		_update_title()
	else:
		Game.p2_id = def.id
		Game.start_fight()


func _set_level(level: int) -> void:
	Game.cpu_level = level
	for i in _level_buttons.size():
		_level_buttons[i].modulate = Color.WHITE if i == level else Color(1, 1, 1, 0.45)


func _back() -> void:
	if _picking == 1:
		_picking = 0
		_update_title()
	else:
		Game.go_to_main_menu()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_back()
		get_viewport().set_input_as_handled()
