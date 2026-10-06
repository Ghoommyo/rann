## On-screen controls for phones: a virtual stick (left) and 4 attack buttons (right).
##
## 💡 This is the basic version. Phase 5 adds a floating stick, a block
## button, a simple-controls mode and a customizable layout.
##
## Multi-touch is tracked per finger, so the player can hold a direction
## and press buttons at the same time. get_bits() returns an InputFrame int.
class_name TouchControls
extends Control

const STICK_RADIUS := 90.0
## How far (as a fraction of the radius) the stick must move to count as a direction.
const STICK_DEADZONE := 0.4
const BUTTON_RADIUS := 46.0
const BUTTON_SPACING := 82.0

## Diamond layout like a PlayStation pad: □ LP left, △ RP top, ✕ LK bottom, ○ RK right.
const BUTTONS := {
	InputFrame.LP: {"label": "LP", "offset": Vector2(-1, 0)},
	InputFrame.RP: {"label": "RP", "offset": Vector2(0, -1)},
	InputFrame.LK: {"label": "LK", "offset": Vector2(0, 1)},
	InputFrame.RK: {"label": "RK", "offset": Vector2(1, 0)},
}

var _stick_finger := -1
var _stick_vector := Vector2.ZERO  # -1..1 on each axis
var _button_fingers := {}  # finger index → button flag


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Shown by default on phones only. On desktop, F2 toggles them (the mouse acts
	# as a finger thanks to the emulate_touch_from_mouse project setting).
	visible = OS.has_feature("mobile")


## The currently held stick direction and buttons, as an InputFrame int.
func get_bits() -> int:
	if not visible:
		return 0
	var held := 0
	for flag in _button_fingers.values():
		held |= flag
	return InputFrame.pack(
		_stick_vector.y < -STICK_DEADZONE, _stick_vector.y > STICK_DEADZONE,
		_stick_vector.x < -STICK_DEADZONE, _stick_vector.x > STICK_DEADZONE,
		(held & InputFrame.LP) != 0, (held & InputFrame.RP) != 0,
		(held & InputFrame.LK) != 0, (held & InputFrame.RK) != 0)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_on_finger_down(event.index, event.position)
		else:
			_on_finger_up(event.index)
	elif event is InputEventScreenDrag and event.index == _stick_finger:
		_update_stick(event.position)


func _on_finger_down(finger: int, pos: Vector2) -> void:
	if _stick_finger < 0 and pos.distance_to(_stick_center()) <= STICK_RADIUS * 1.6:
		_stick_finger = finger
		_update_stick(pos)
		return
	for flag in BUTTONS:
		if pos.distance_to(_button_center(flag)) <= BUTTON_RADIUS * 1.15:
			_button_fingers[finger] = flag
			queue_redraw()
			return


func _on_finger_up(finger: int) -> void:
	if finger == _stick_finger:
		_stick_finger = -1
		_stick_vector = Vector2.ZERO
	_button_fingers.erase(finger)
	queue_redraw()


func _update_stick(pos: Vector2) -> void:
	_stick_vector = ((pos - _stick_center()) / STICK_RADIUS).limit_length(1.0)
	queue_redraw()


func _stick_center() -> Vector2:
	return Vector2(size.x * 0.13, size.y * 0.72)


func _button_center(flag: int) -> Vector2:
	var base := Vector2(size.x * 0.86, size.y * 0.70)
	return base + BUTTONS[flag]["offset"] * BUTTON_SPACING


func _draw() -> void:
	var stick := _stick_center()
	draw_circle(stick, STICK_RADIUS, Color(1, 1, 1, 0.12))
	draw_arc(stick, STICK_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.35), 2.0)
	draw_circle(stick + _stick_vector * STICK_RADIUS * 0.6, STICK_RADIUS * 0.4, Color(1, 1, 1, 0.45))

	var held := _button_fingers.values()
	var font := get_theme_default_font()
	for flag in BUTTONS:
		var center := _button_center(flag)
		var alpha := 0.55 if flag in held else 0.2
		draw_circle(center, BUTTON_RADIUS, Color(1, 1, 1, alpha))
		draw_arc(center, BUTTON_RADIUS, 0, TAU, 40, Color(1, 1, 1, 0.5), 2.0)
		var label: String = BUTTONS[flag]["label"]
		draw_string(font, center + Vector2(-14, 7), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
