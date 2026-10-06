## Charge moves: hold back for a while, then press forward + a button.
##
## 💡 Charge characters trade speed for safety: their best moves need you to
## hold back (which also blocks) before they become available.
##
## Mark moves with MoveDef.requires_charge. After the charge is released, it
## stays ready for `grace_frames` so the forward + button input has time.
##
## style_data keys: "charge.frames" (how long back has been held),
##                  "charge.ready" (frames left to use a released charge)
class_name ChargeInputComponent
extends StyleComponent

const FRAMES := "charge.frames"
const READY := "charge.ready"
## Caps the counter so it can't grow forever.
const MAX_COUNT := 999

@export var charge_frames := 30
@export var grace_frames := 8


func init_state(f: FighterState) -> void:
	f.style_data[FRAMES] = 0
	f.style_data[READY] = 0


func on_tick(f: FighterState) -> void:
	var dir := direction(f)
	if dir == 1 or dir == 4 or dir == 7:  # any "back" direction
		f.style_data[FRAMES] = mini(MAX_COUNT, f.style_data[FRAMES] + 1)
		return
	if f.style_data[FRAMES] >= charge_frames:
		f.style_data[READY] = grace_frames  # just released a full charge
	else:
		f.style_data[READY] = maxi(0, f.style_data[READY] - 1)
	f.style_data[FRAMES] = 0


func can_use_move(f: FighterState, move: MoveDef) -> bool:
	if not move.requires_charge:
		return true
	return f.style_data[READY] > 0 or f.style_data[FRAMES] >= charge_frames


func on_move_started(f: FighterState, move: MoveDef) -> void:
	if move.requires_charge:
		f.style_data[READY] = 0
		f.style_data[FRAMES] = 0


func hud_values(f: FighterState) -> Array[Dictionary]:
	var value := mini(f.style_data[FRAMES], charge_frames)
	if f.style_data[READY] > 0:
		value = charge_frames  # released but still usable: show as full
	return [{"label": "CHARGE", "value": value, "max": charge_frames}]
