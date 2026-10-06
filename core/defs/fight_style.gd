## A character's unique mechanics: a list of StyleComponents.
##
## 💡 Build a style in the Godot inspector: create a FightStyle resource, add
## components to the list and set their options. The engine calls FightStyle,
## which forwards each call to every component.
class_name FightStyle
extends Resource

@export var components: Array[StyleComponent] = []


func init_state(f: FighterState) -> void:
	for c in components:
		c.init_state(f)


func on_tick(f: FighterState) -> void:
	for c in components:
		c.on_tick(f)


## A move is allowed only if every component allows it.
func can_use_move(f: FighterState, move: MoveDef) -> bool:
	for c in components:
		if not c.can_use_move(f, move):
			return false
	return true


func on_move_started(f: FighterState, move: MoveDef) -> void:
	for c in components:
		c.on_move_started(f, move)


func on_contact(f: FighterState, move: MoveDef, blocked: bool) -> void:
	for c in components:
		c.on_contact(f, move, blocked)


func on_hit_received(f: FighterState, move: MoveDef) -> void:
	for c in components:
		c.on_hit_received(f, move)


## True if any component parries the move.
func try_parry(f: FighterState, move: MoveDef) -> bool:
	for c in components:
		if c.try_parry(f, move):
			return true
	return false


func hud_values(f: FighterState) -> Array[Dictionary]:
	var values: Array[Dictionary] = []
	for c in components:
		values.append_array(c.hud_values(f))
	return values
