## A meter that fills by fighting and is spent on special moves (e.g. Kael's "Rage").
##
## Settings: below. Moves spend it through MoveDef.meter_cost.
## style_data keys: "meter.value"
class_name MeterComponent
extends StyleComponent

const VALUE := "meter.value"

## Name shown on the HUD.
@export var display_name := "METER"
@export var max_value := 1000
@export var gain_on_hit := 60
@export var gain_on_block := 25
## Getting hit also builds meter, which helps the losing player come back.
@export var gain_on_damage_taken := 40


func init_state(f: FighterState) -> void:
	f.style_data[VALUE] = 0


func can_use_move(f: FighterState, move: MoveDef) -> bool:
	return move.meter_cost <= f.style_data[VALUE]


func on_move_started(f: FighterState, move: MoveDef) -> void:
	f.style_data[VALUE] -= move.meter_cost


func on_contact(f: FighterState, _move: MoveDef, blocked: bool) -> void:
	_add(f, gain_on_block if blocked else gain_on_hit)


func on_hit_received(f: FighterState, _move: MoveDef) -> void:
	_add(f, gain_on_damage_taken)


func hud_values(f: FighterState) -> Array[Dictionary]:
	return [{"label": display_name, "value": f.style_data[VALUE], "max": max_value}]


func _add(f: FighterState, amount: int) -> void:
	f.style_data[VALUE] = mini(max_value, f.style_data[VALUE] + amount)
