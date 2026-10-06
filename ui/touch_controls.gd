## On-screen controls for phones.
##
##  - Left half: a FLOATING stick. It appears wherever your thumb lands, so you
##    never have to find it on the glass.
##  - Right side: LP, RP, LK, RK, SP (special) and BLOCK, positioned by the
##    player's layout (Settings.touch_layout, editable in Settings).
##
## 💡 BLOCK holds "back" (or "down-back" when the stick is down) for you, so
## players don't have to pull away from the opponent on a slippery screen.
## Since "back" depends on which way your fighter faces, get_bits() needs it.
##
## Multi-touch is tracked per finger, so a direction and buttons can be held
## at the same time.
class_name TouchControls
extends Control

const STICK_RADIUS := 90.0
## How far (as a fraction of the radius) the stick must move to count as a direction.
const STICK_DEADZONE := 0.4
const BUTTON_RADIUS := 44.0

const BUTTONS := {
	"lp": {"label": "LP", "bit": InputFrame.LP},
	"rp": {"label": "RP", "bit": InputFrame.RP},
	"lk": {"label": "LK", "bit": InputFrame.LK},
	"rk": {"label": "RK", "bit": InputFrame.RK},
	"sp": {"label": "SP", "bit": InputFrame.SP},
	"block": {"label": "BLK", "bit": 0},
}

## When true, buttons can be dragged to new positions (layout editor).
var editing := false

var _stick_finger := -1
var _stick_origin := Vector2.ZERO
var _stick_vector := Vector2.ZERO  # -1..1 on each axis
var _button_fingers := {}  # finger index → button name
## Buttons pressed since the last get_bits(). A very quick tap can go down and
## up between two simulation ticks; latching it makes sure it still counts.
var _tapped := {}
var _drag_finger := -1     # editing: finger moving a button
var _drag_button := ""


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = Settings.show_touch_controls()
	Settings.changed.connect(queue_redraw)


## The held stick direction and buttons as an InputFrame int.
## `facing` is the local fighter's facing, needed for BLOCK.
func get_bits(facing: int) -> int:
	if not visible or editing:
		return 0
	var held := _tapped
	_tapped = {}
	for button in _button_fingers.values():
		held[button] = true
	return compose_bits(_stick_vector, held, facing)


## Turns a stick vector and held buttons into InputFrame bits (pure, testable).
static func compose_bits(stick: Vector2, held: Dictionary, facing: int) -> int:
	var up := stick.y < -STICK_DEADZONE
	var down := stick.y > STICK_DEADZONE
	var left := stick.x < -STICK_DEADZONE
	var right := stick.x > STICK_DEADZONE
	if held.has("block"):
		# Hold back; keep "down" if the stick is down (crouch block). No jumping.
		up = false
		left = facing > 0
		right = facing < 0
	var bits := InputFrame.pack(up, down, left, right)
	for button in held:
		bits |= BUTTONS[button].bit
	return bits


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_on_finger_down(event.index, event.position)
		else:
			_on_finger_up(event.index)
	elif event is InputEventScreenDrag:
		if editing and event.index == _drag_finger:
			var safe := _safe_rect()
			Settings.touch_layout[_drag_button] = [
				clampf((event.position.x - safe.position.x) / safe.size.x, 0.05, 0.95),
				clampf((event.position.y - safe.position.y) / safe.size.y, 0.05, 0.95)]
			queue_redraw()
		elif event.index == _stick_finger:
			_update_stick(event.position)


func _on_finger_down(finger: int, pos: Vector2) -> void:
	var button := _button_at(pos)
	if editing:
		if button != "":
			_drag_finger = finger
			_drag_button = button
		return
	if button != "":
		_button_fingers[finger] = button
		_tapped[button] = true
		queue_redraw()
		return
	# Anywhere else on the left 45% of the screen: the stick appears under the thumb.
	if _stick_finger < 0 and pos.x < size.x * 0.45:
		_stick_finger = finger
		_stick_origin = pos
		_update_stick(pos)


func _on_finger_up(finger: int) -> void:
	if finger == _drag_finger:
		_drag_finger = -1
		_drag_button = ""
	if finger == _stick_finger:
		_stick_finger = -1
		_stick_vector = Vector2.ZERO
	_button_fingers.erase(finger)
	queue_redraw()


func _update_stick(pos: Vector2) -> void:
	var offset := pos - _stick_origin
	# If the thumb slides far, drag the stick base along so it stays responsive.
	if offset.length() > STICK_RADIUS:
		_stick_origin = pos - offset.normalized() * STICK_RADIUS
		offset = pos - _stick_origin
	_stick_vector = offset / STICK_RADIUS
	queue_redraw()


func _button_at(pos: Vector2) -> String:
	for button in BUTTONS:
		if pos.distance_to(button_center(button)) <= _radius() * 1.15:
			return button
	return ""


func button_center(button: String) -> Vector2:
	var safe := _safe_rect()
	var spot: Array = Settings.touch_layout[button]
	return safe.position + Vector2(spot[0] * safe.size.x, spot[1] * safe.size.y)


func _radius() -> float:
	return BUTTON_RADIUS * Settings.touch_scale


## The part of the screen not covered by notches or rounded corners.
func _safe_rect() -> Rect2:
	var full := Rect2(Vector2.ZERO, size)
	if not OS.has_feature("mobile"):
		return full
	var safe := Rect2(DisplayServer.get_display_safe_area())
	var screen := Vector2(DisplayServer.screen_get_size())
	if screen.x <= 0 or screen.y <= 0:
		return full
	# Convert from screen pixels to this control's coordinates.
	var ratio := size / screen
	return Rect2(safe.position * ratio, safe.size * ratio)


func _draw() -> void:
	if _stick_finger >= 0:
		draw_circle(_stick_origin, STICK_RADIUS, Color(1, 1, 1, 0.12))
		draw_arc(_stick_origin, STICK_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.35), 2.0)
		draw_circle(_stick_origin + _stick_vector * STICK_RADIUS * 0.6, STICK_RADIUS * 0.4, Color(1, 1, 1, 0.45))
	elif not editing:
		# A hint where the stick lives.
		var hint := Vector2(size.x * 0.15, size.y * 0.72)
		draw_arc(hint, STICK_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.12), 2.0)

	var held := _button_fingers.values()
	var font := get_theme_default_font()
	var r := _radius()
	for button in BUTTONS:
		var center := button_center(button)
		var alpha := 0.55 if button in held or button == _drag_button else 0.2
		var color := Color(0.6, 0.85, 1.0) if button == "block" else (Color(1.0, 0.7, 0.3) if button == "sp" else Color.WHITE)
		draw_circle(center, r, Color(color, alpha))
		draw_arc(center, r, 0, TAU, 40, Color(color, 0.6), 2.0)
		var label: String = BUTTONS[button].label
		draw_string(font, center + Vector2(-r, 7), label, HORIZONTAL_ALIGNMENT_CENTER, r * 2, 20)
