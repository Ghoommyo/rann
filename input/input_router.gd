## Turns real devices (keyboard, gamepad) into InputFrame ints.
## Touch controls are read separately (ui/touch_controls.gd) and combined in fight.gd.
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

## Gamepad buttons, using the Tekken layout on a PlayStation pad:
## □ = LP, △ = RP, ✕ = LK, ○ = RK (Xbox: X, Y, A, B).
const GAMEPAD_BUTTONS := {
	"up": JOY_BUTTON_DPAD_UP, "down": JOY_BUTTON_DPAD_DOWN,
	"left": JOY_BUTTON_DPAD_LEFT, "right": JOY_BUTTON_DPAD_RIGHT,
	"lp": JOY_BUTTON_X, "rp": JOY_BUTTON_Y, "lk": JOY_BUTTON_A, "rk": JOY_BUTTON_B,
}

## Left stick directions: [axis, sign].
const GAMEPAD_STICK := {
	"up": [JOY_AXIS_LEFT_Y, -1.0], "down": [JOY_AXIS_LEFT_Y, 1.0],
	"left": [JOY_AXIS_LEFT_X, -1.0], "right": [JOY_AXIS_LEFT_X, 1.0],
}

## How far the stick must be pushed to count as a direction.
const STICK_DEADZONE := 0.5


## Registers actions such as "p1_up" in Godot's InputMap. Safe to call twice.
## Player 1 uses the first connected gamepad, player 2 the second.
static func register_default_actions() -> void:
	for player in KEYBOARD:
		var keys: Dictionary = KEYBOARD[player]
		var device: int = player - 1
		for control in keys:
			var action := _action(player, control)
			if InputMap.has_action(action):
				continue
			InputMap.add_action(action, STICK_DEADZONE)

			var key := InputEventKey.new()
			key.physical_keycode = keys[control]
			InputMap.action_add_event(action, key)

			var button := InputEventJoypadButton.new()
			button.device = device
			button.button_index = GAMEPAD_BUTTONS[control]
			InputMap.action_add_event(action, button)

			if GAMEPAD_STICK.has(control):
				var stick := InputEventJoypadMotion.new()
				stick.device = device
				stick.axis = GAMEPAD_STICK[control][0]
				stick.axis_value = GAMEPAD_STICK[control][1]
				InputMap.action_add_event(action, stick)


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
