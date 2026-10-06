## Pause menu, plus an on-screen pause button for touch screens.
## Opened with Esc / Start (gamepad) / the ❚❚ button.
##
## 💡 Pausing just stops calling MatchSim.step() (see fight.gd). Because the
## whole fight is in FightState, nothing else needs to be frozen.
class_name PauseMenu
extends Control

signal resumed
signal restart_requested
signal dummy_mode_requested

var _panel: PanelContainer
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

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_panel.add_child(column)
	column.add_child(MenuStyle.label("PAUSED", 40, MenuStyle.ACCENT))
	_first_button = MenuStyle.button("Resume", close)
	column.add_child(_first_button)
	column.add_child(MenuStyle.button("Restart match", _restart))
	if Game.mode == Game.Mode.TRAINING:
		_dummy_button = MenuStyle.button("", func(): dummy_mode_requested.emit())
		column.add_child(_dummy_button)
	column.add_child(MenuStyle.button("Character select", func(): Game.go_to_character_select(Game.mode)))
	column.add_child(MenuStyle.button("Main menu", Game.go_to_main_menu))

	var overlay := Control.new()
	overlay.name = "Overlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	overlay.add_child(_panel)
	overlay.visible = false
	add_child(overlay)


func is_open() -> bool:
	return $Overlay.visible


func open() -> void:
	$Overlay.visible = true
	_first_button.grab_focus()


func close() -> void:
	$Overlay.visible = false
	resumed.emit()


func _restart() -> void:
	close()
	restart_requested.emit()


func set_dummy_text(text: String) -> void:
	if _dummy_button:
		_dummy_button.text = text
