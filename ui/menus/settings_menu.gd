## Settings screen: sound, graphics, controls. Saved when leaving the screen.
extends Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(MenuStyle.background())

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 60
	scroll.offset_right = -60
	scroll.offset_top = 24
	scroll.offset_bottom = -24
	add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 14)
	scroll.add_child(column)

	column.add_child(MenuStyle.label("SETTINGS", 40, MenuStyle.ACCENT))

	column.add_child(_slider_row("Volume", Settings.master_volume, 0.0, 1.0, _set_volume))
	column.add_child(_choice_row("Graphics", ["Low", "Medium", "High"], Settings.quality, _set_quality))
	column.add_child(_hint("Low renders fewer pixels and turns off shadows and glow: smoother on older phones."))
	column.add_child(_choice_row("Frame rate", ["30 fps (saves battery)", "60 fps"],
		0 if Settings.fps_limit == 30 else 1, _set_fps))
	column.add_child(_hint("The fight itself always runs at 60 updates per second; this only changes drawing."))
	column.add_child(_choice_row("Touch controls", ["Auto", "On", "Off"], Settings.touch_mode, _set_touch_mode))
	column.add_child(_slider_row("Button size", Settings.touch_scale, 0.6, 1.6, _set_touch_scale))
	column.add_child(_choice_row("Vibration", ["Off", "On"], 1 if Settings.haptics else 0, _set_haptics))

	var layout := MenuStyle.button("Edit touch layout", _edit_layout, 320)
	layout.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(layout)
	var back := MenuStyle.button("Back", _back, 160)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(back)
	MenuStyle.focus_later(back)


func _slider_row(title: String, value: float, lo: float, hi: float, on_change: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var label := MenuStyle.label(title, 22)
	label.custom_minimum_size = Vector2(240, 0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = lo
	slider.max_value = hi
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(360, 40)
	slider.value_changed.connect(on_change)
	row.add_child(slider)
	return row


## A row of option buttons; the picked one is highlighted.
func _choice_row(title: String, options: Array, selected: int, on_pick: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var label := MenuStyle.label(title, 22)
	label.custom_minimum_size = Vector2(240, 0)
	row.add_child(label)
	var buttons: Array[Button] = []
	for i in options.size():
		var b := MenuStyle.button(options[i], _on_choice.bind(i, buttons, on_pick), 120)
		b.custom_minimum_size.x = 0
		buttons.append(b)
		row.add_child(b)
	_highlight(buttons, selected)
	return row


func _on_choice(index: int, buttons: Array[Button], on_pick: Callable) -> void:
	on_pick.call(index)
	_highlight(buttons, index)


func _highlight(buttons: Array[Button], index: int) -> void:
	for j in buttons.size():
		buttons[j].modulate = Color.WHITE if j == index else Color(1, 1, 1, 0.45)


func _set_volume(v: float) -> void:
	Settings.master_volume = v
	Settings.apply()


func _set_quality(i: int) -> void:
	Settings.quality = i as Settings.Quality
	Settings.apply()


func _set_fps(i: int) -> void:
	Settings.fps_limit = 30 if i == 0 else 60
	Settings.apply()


func _set_touch_mode(i: int) -> void:
	Settings.touch_mode = i as Settings.TouchMode


func _set_touch_scale(v: float) -> void:
	Settings.touch_scale = v


func _set_haptics(i: int) -> void:
	Settings.haptics = i == 1


func _hint(text: String) -> Label:
	var l := MenuStyle.label("💡 " + text, 15)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _edit_layout() -> void:
	Settings.save()
	get_tree().change_scene_to_file("res://ui/menus/touch_layout_editor.tscn")


func _back() -> void:
	Settings.save()
	Game.go_to_main_menu()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_back()
