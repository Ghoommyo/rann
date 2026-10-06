## One attack: its input, frame data, hitbox and what happens on contact.
##
## 💡 Every move of every character is one of these .tres files
## (data/characters/<id>/moves/). Tuning a move means editing numbers in the
## Godot inspector, not code.
##
## ## Frame data (Tekken-style)
## `startup` is the frame the hitbox FIRST appears. "i10" = hits on frame 10.
##
##     frame:  1 ........ 9 | 10 11 | 12 ................ 25
##             [ startup   ] [active] [ recovery           ]
##
##     total frames = (startup - 1) + active + recovery
##
## ## Frame advantage
## After a hit or block: advantage = stun − (frames the attacker still needs).
## +1 = the attacker can act 1 frame before the defender. The debug HUD shows it.
##
## Distances are sim units (1000 = 1 m). Hitbox x is measured forward from
## the fighter's center (mirrored automatically when facing left); y is up from the feet.
class_name MoveDef
extends Resource

## What blocks this attack.
## HIGH: blocked standing; ducked under (whiffs) by crouching fighters.
## MID: blocked standing; hits crouching fighters.
## LOW: blocked crouching; hits standing fighters.
## THROW: can't be blocked, but can be ducked or broken.
enum HitLevel { HIGH, MID, LOW, THROW }

## Special result on a clean hit.
enum OnHit { NONE, LAUNCH, KNOCKDOWN }

@export var id := ""
@export var display_name := ""
## Animation to play in Phase 3. Must exist in the character's AnimationLibrary.
@export var animation_name := ""
## Input that performs the move, in numpad notation (see plans/02-phase-combat-system.md).
## Examples: "LP", "2+LK", "3+RP", "236+RP", "LP+LK".
@export var command := "LP"
## The attacker counts as crouching during this move, so high attacks whiff over them.
@export var low_profile := false

@export_group("Frame data")
@export var startup := 10
## 0 = no hitbox at all (e.g. a stance change).
@export var active := 2
@export var recovery := 14

@export_group("Hitbox")
@export var hitbox_offset_x := 250
@export var hitbox_offset_y := 1300
@export var hitbox_width := 500
@export var hitbox_height := 250

@export_group("On contact")
@export var hit_level := HitLevel.HIGH
@export var damage := 50
@export var hitstun := 20
@export var blockstun := 12
## Starting speed the defender slides away with (slows by Rules.PUSHBACK_FRICTION).
@export var pushback := 30
## 💡 Hitstop: both fighters freeze for this many frames on contact. That short
## pause is what makes hits feel heavy.
@export var hitstop := 8
@export var on_hit := OnHit.NONE
## Upward speed given to the defender by a LAUNCH.
@export var launch_velocity := 110

@export_group("Movement")
## Forward speed during startup and active frames (for lunging moves).
@export var forward_speed := 0

@export_group("Combos")
## Move ids this move can be cancelled into once it has hit or been blocked.
## 💡 This is how strings and combos are made: jab → straight.
@export var cancels_into: Array[String] = []

@export_group("Fight style")
## Meter spent to do this move (used by MeterComponent).
@export var meter_cost := 0
## Only usable in this stance; "" = any stance (used by StanceComponent).
@export var required_stance := ""
## Starting this move switches to this stance (used by StanceComponent).
@export var enters_stance := ""
## Needs a charged input first (used by ChargeInputComponent).
@export var requires_charge := false

@export_group("Throw")
## Button that breaks this throw (only used when hit_level is THROW).
@export_flags("LP", "RP", "LK", "RK") var throw_break_buttons := 1
## Total frames the throw animation holds both fighters.
@export var throw_duration := 40

var _command: MoveCommand


func total_frames() -> int:
	return startup - 1 + active + recovery


## `frame` is 1-based: the first frame of the move is frame 1.
func is_active_frame(frame: int) -> bool:
	return frame >= startup and frame < startup + active


## The hitbox in world space for a fighter doing this move.
func hitbox_of(f: FighterState) -> Rect2i:
	var x := f.pos_x + hitbox_offset_x
	if f.facing < 0:
		x = f.pos_x - hitbox_offset_x - hitbox_width
	return Rect2i(x, f.pos_y + hitbox_offset_y, hitbox_width, hitbox_height)


## The break button(s) as InputFrame bits. The inspector flags use bits 0–3;
## InputFrame buttons start at bit 4 (LP).
func throw_break_mask() -> int:
	return throw_break_buttons << 4


## The parsed `command` (parsed once, then cached).
func get_command() -> MoveCommand:
	if _command == null:
		_command = MoveCommand.parse(command)
	return _command
