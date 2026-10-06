## Turns real devices (keyboard now; gamepad and touch in Phase 2) into InputFrame ints.
##
## 💡 The simulation only ever sees InputFrame ints. It can't tell whether
## they came from a keyboard, a touch screen, the CPU opponent or the network,
## which keeps the core simple and testable.
class_name InputRouter

## Default keyboard layout for two players on one keyboard.
## Physical keys are used, so the layout is the same on AZERTY/QWERTZ keyboards.
const KEYBOARD := {
	1: {
		"up": KEY_W, "down": KEY_S, "left": KEY_A, "right": KEY_D,
		"lp": KEY_U, "rp": KEY_I, "lk": KEY_J, "rk": KEY_K,
	},
	2: {
		"up": KEY_UP, "down": KEY_DOWN, "left": KEY_LEFT, "right": KEY_RIGHT,
		"lp": KEY_KP_4, "rp": KEY_KP_5, "lk": KEY_KP_1, "rk": KEY_KP_2,
	},
}


## Registers actions such as "p1_up" in Godot's InputMap. Safe to call twice.
static func register_default_actions() -> void:
	for player in KEYBOARD:
		var keys: Dictionary = KEYBOARD[player]
		for control in keys:
			var action := _action(player, control)
			if InputMap.has_action(action):
				continue
			InputMap.add_action(action)
			var event := InputEventKey.new()
			event.physical_keycode = keys[control]
			InputMap.action_add_event(action, event)


## Reads what `player` (1 or 2) is holding right now.
static func read(player: int) -> int:
	return InputFrame.pack(
		Input.is_action_pressed(_action(player, "up")),
		Input.is_action_pressed(_action(player, "down")),
		Input.is_action_pressed(_action(player, "left")),
		Input.is_action_pressed(_action(player, "right")),
		Input.is_action_pressed(_action(player, "lp")),
		Input.is_action_pressed(_action(player, "rp")),
		Input.is_action_pressed(_action(player, "lk")),
		Input.is_action_pressed(_action(player, "rk")),
	)


static func _action(player: int, control: String) -> String:
	return "p%d_%s" % [player, control]
