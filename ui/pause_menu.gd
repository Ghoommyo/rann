## Pause menu, plus an on-screen pause button for touch screens.
## Opened with Esc / Start (gamepad) / the ❚❚ button.
##
## 💡 Pausing just stops calling MatchSim.step() (see fight.gd). Because the
## whole fight is in FightState, nothing else needs to be frozen.
## Online matches can't be paused (the other player keeps playing), so there
## the menu only offers to leave.
class_name PauseMenu
extends Control

signal resumed
signal restart_requested
signal dummy_mode_requested

var _overlay: Control
var _dummy_button: Button
var _first_button: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var pause_button := MenuStyle.button("❚❚", func(): open(), 64)
	pause_button.position = Vector2(get_viewport_rect().size.x / 2 - 32, 68)
	pause_button.visible = OS.has_feature("mobile")
	pause_button.focus_mode = Control.FOCUS_NONE
	add_child(pause_button)

	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	add_child(_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_overlay.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)

	var online := Game.mode == Game.Mode.ONLINE
	column.add_child(MenuStyle.label("MENU" if online else "PAUSED", 40, MenuStyle.ACCENT))
	_first_button = MenuStyle.button("Back to the fight" if online else "Resume", close)
	column.add_child(_first_button)
	if online:
		column.add_child(MenuStyle.button("Leave match", Game.go_to_main_menu))
		return
	column.add_child(MenuStyle.button("Restart match", _restart))
	if Game.mode == Game.Mode.TRAINING:
		_dummy_button = MenuStyle.button("", func(): dummy_mode_requested.emit())
		column.add_child(_dummy_button)
	column.add_child(MenuStyle.button("Character select", func(): Game.go_to_character_select(Game.mode)))
	column.add_child(MenuStyle.button("Main menu", Game.go_to_main_menu))


## True when the game should stop simulating (never online).
func is_paused() -> bool:
	return _overlay.visible and Game.mode != Game.Mode.ONLINE


func is_open() -> bool:
	return _overlay.visible


func open() -> void:
	_overlay.visible = true
	_first_button.grab_focus()


func close() -> void:
	_overlay.visible = false
	resumed.emit()


func _restart() -> void:
	close()
	restart_requested.emit()


func set_dummy_text(text: String) -> void:
	if _dummy_button:
		_dummy_button.text = text
