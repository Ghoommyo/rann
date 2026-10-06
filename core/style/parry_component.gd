## Tap forward just before an attack lands to parry it (e.g. Mira).
##
## 💡 A parry is a high-risk, high-reward defence: tap too early or too late
## and you get hit; get it right and the attacker is left stunned and open.
## The cooldown stops players from just mashing forward.
##
## style_data keys: "parry.window" (frames left in the parry window),
##                  "parry.cooldown" (frames until the next attempt is allowed)
class_name ParryComponent
extends StyleComponent

const WINDOW := "parry.window"
const COOLDOWN := "parry.cooldown"

## How long a forward tap stays "ready to parry".
@export var window_frames := 5
## Frames after an attempt before another one is possible.
@export var cooldown_frames := 40
## Lows are usually not parryable this way.
@export var parries_lows := false


func init_state(f: FighterState) -> void:
	f.style_data[WINDOW] = 0
	f.style_data[COOLDOWN] = 0


func on_tick(f: FighterState) -> void:
	f.style_data[WINDOW] = maxi(0, f.style_data[WINDOW] - 1)
	f.style_data[COOLDOWN] = maxi(0, f.style_data[COOLDOWN] - 1)

	var tapped_forward := direction(f) == 6 and direction(f, 1) != 6
	if tapped_forward and is_free(f) and f.style_data[COOLDOWN] == 0:
		f.style_data[WINDOW] = window_frames
		f.style_data[COOLDOWN] = cooldown_frames


func try_parry(f: FighterState, move: MoveDef) -> bool:
	if f.style_data[WINDOW] <= 0:
		return false
	if move.hit_level == MoveDef.HitLevel.THROW:
		return false
	if move.hit_level == MoveDef.HitLevel.LOW and not parries_lows:
		return false
	f.style_data[WINDOW] = 0
	return true
