## Lets a character switch between stances, each with its own moves
## (e.g. Mira's Tiger and Crane).
##
## - MoveDef.required_stance: the move only works in that stance ("" = any stance).
## - MoveDef.enters_stance: starting the move switches to that stance.
## - Getting hit knocks the fighter back to the first stance.
##
## style_data keys: "stance.index" (index into `stances`)
class_name StanceComponent
extends StyleComponent

const INDEX := "stance.index"

## Stance names. The first one is the default stance at round start.
@export var stances: Array[String] = ["normal"]


func init_state(f: FighterState) -> void:
	f.style_data[INDEX] = 0


func can_use_move(f: FighterState, move: MoveDef) -> bool:
	return move.required_stance == "" or move.required_stance == current(f)


func on_move_started(f: FighterState, move: MoveDef) -> void:
	if move.enters_stance == "":
		return
	var index := stances.find(move.enters_stance)
	if index < 0:
		push_error("Move '%s' enters unknown stance '%s'" % [move.id, move.enters_stance])
		return
	f.style_data[INDEX] = index


func on_hit_received(f: FighterState, _move: MoveDef) -> void:
	f.style_data[INDEX] = 0


func hud_values(f: FighterState) -> Array[Dictionary]:
	return [{"label": "STANCE", "text": current(f).capitalize()}]


## Name of the fighter's current stance.
func current(f: FighterState) -> String:
	return stances[f.style_data[INDEX]]
