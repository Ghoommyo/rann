## Drag the touch buttons to where your thumbs want them. Save keeps the
## layout (Settings.touch_layout); Cancel throws the changes away.
extends Control

var _touch: TouchControls


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(MenuStyle.background())

	var info := MenuStyle.label("Drag the buttons to move them. The stick appears wherever you touch the left side.", 20)
	info.position = Vector2(40, 30)
	add_child(info)

	_touch = TouchControls.new()
	add_child(_touch)
	_touch.visible = true  # always shown here, even on desktop (the mouse acts as a finger)
	_touch.editing = true

	var row := HBoxContainer.new()
	row.position = Vector2(40, 80)
	row.add_theme_constant_override("separation", 12)
	row.add_child(MenuStyle.button("Save", _save, 160))
	row.add_child(MenuStyle.button("Reset", _reset, 160))
	row.add_child(MenuStyle.button("Cancel", _cancel, 160))
	add_child(row)


func _save() -> void:
	Settings.save()
	_leave()


func _reset() -> void:
	Settings.reset_touch_layout()
	_touch.queue_redraw()


func _cancel() -> void:
	Settings.load_settings()  # back to what was saved
	_leave()


func _leave() -> void:
	get_tree().change_scene_to_file("res://ui/menus/settings_menu.tscn")
