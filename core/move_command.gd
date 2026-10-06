## A parsed move input such as "236+RP", and the code that finds it in the
## input buffer.
##
## 💡 Text commands are split on "+":
##  - button names (LP RP LK RK): all must be held, at least one newly pressed
##  - one digit ("3"): the stick must be in that direction when pressing
##  - several digits ("236"): a motion. Those directions must appear in that
##    order within MOTION_WINDOW frames before the button press.
##
## Directions are numpad notation relative to facing (6 = forward).
class_name MoveCommand
extends RefCounted

## A press up to this many frames old still counts.
## 💡 This is "input buffering": pressing slightly before a move ends (or
## during hitstop) still works, which makes combos feel fair.
const BUFFER_WINDOW := 8
## A motion like 236 must be finished within this many frames.
const MOTION_WINDOW := 12

const BUTTON_NAMES := {
	"LP": InputFrame.LP, "RP": InputFrame.RP, "LK": InputFrame.LK, "RK": InputFrame.RK,
	"SP": InputFrame.SP,
}

var motion := PackedInt32Array()
var buttons := 0
## Higher = checked first. "236+RP" beats "3+RP", which beats "RP".
var priority := 0


static func parse(text: String) -> MoveCommand:
	var c := MoveCommand.new()
	for raw in text.to_upper().split("+"):
		var token := raw.strip_edges()
		if BUTTON_NAMES.has(token):
			c.buttons |= BUTTON_NAMES[token]
		elif token.is_valid_int():
			for ch in token:
				c.motion.append(int(ch))
		else:
			push_error("Unknown token '%s' in move command '%s'" % [token, text])
	var button_count := 0
	for flag in BUTTON_NAMES.values():
		if c.buttons & flag:
			button_count += 1
	c.priority = c.motion.size() * 10 + button_count
	return c


## Looks for this command in the buffer. Returns the press time (the
## buffer's frame number) if found, or -1. Presses at or before
## `after_press_time` are ignored, so one button press can't trigger two moves.
func find_press(buffer: InputBuffer, facing: int, after_press_time: int) -> int:
	for ago in BUFFER_WINDOW:
		var press_time := buffer.frame_count - ago
		if press_time <= after_press_time:
			break
		var bits := buffer.get_ago(ago)
		if (bits & buttons) != buttons:
			continue  # not all buttons held on this frame
		if (buffer.get_ago(ago + 1) & buttons) == buttons:
			continue  # all were already held: not a new press
		if _motion_matches(buffer, facing, ago):
			return press_time
	return -1


func _motion_matches(buffer: InputBuffer, facing: int, press_ago: int) -> bool:
	if motion.is_empty():
		return true
	if motion.size() == 1:
		return InputFrame.to_numpad(buffer.get_ago(press_ago), facing) == motion[0]

	# Walk backwards in time from the press, finding the directions newest-first.
	var ago := press_ago
	var limit := mini(press_ago + MOTION_WINDOW, InputBuffer.SIZE - 1)
	for i in range(motion.size() - 1, -1, -1):
		while ago <= limit and InputFrame.to_numpad(buffer.get_ago(ago), facing) != motion[i]:
			ago += 1
		if ago > limit:
			return false
		ago += 1
	return true
