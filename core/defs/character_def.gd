## Everything that makes one fighter different from another, stored as data.
##
## 💡 One .tres file per character lives in data/characters/<id>/character.tres.
## Adding a character means making new files, not new code
## (plans/00-architecture.md, Rule 4). Edit the numbers in the Godot inspector.
##
## All distances are in sim units (1000 = 1 meter); speeds are units per frame.
class_name CharacterDef
extends Resource

## Unique, never-changing id. Online play and replays refer to characters by this.
@export var id := ""
@export var display_name := ""
@export var max_health := 1000

@export_group("Walking")
## 40 units/frame × 60 frames = 2.4 m per second.
@export var walk_forward_speed := 40
## Walking back is usually slower than forward, which rewards being aggressive.
@export var walk_back_speed := 30

@export_group("Jumping")
## Frames on the ground before leaving it. The fighter is committed during them.
@export var jump_squat_frames := 4
## Upward speed on the first airborne frame.
@export var jump_velocity := 120
## Subtracted from vertical speed every frame. 120 / 8 → 15 frames up, 15 down.
@export var gravity := 8
## Horizontal speed for diagonal jumps (7 or 9).
@export var jump_forward_speed := 35
## Frames of landing recovery before the fighter can act again.
@export var landing_frames := 3

@export_group("Body")
## Half the width of the pushbox (the box that stops fighters overlapping).
@export var pushbox_half_width := 300
## Half the width of the hurtbox (where the fighter can be hit). Slightly
## wider than the pushbox, so attacks at point-blank range still connect.
@export var hurtbox_half_width := 350
@export var stand_height := 1700
@export var crouch_height := 1000
## Smaller box in the air (the legs tuck in). It still reaches the opponent's
## standing box at the jump's peak, so fighters can't jump over each other,
## like in Tekken.
@export var air_height := 1200

@export_group("Moves")
## Every attack this character has. Order doesn't matter: the input parser
## checks the most complex commands first (see MoveCommand.priority).
@export var moves: Array[MoveDef] = []

# Caches built on first use (not saved to the .tres file).
var _priority_order: Array[int] = []
var _cancel_cache := {}


## Indices into `moves`, most specific command first.
func moves_by_priority() -> Array[int]:
	if _priority_order.size() != moves.size():
		_priority_order = _sorted_by_priority(range(moves.size()))
	return _priority_order


## Indices of the moves that `moves[index]` can cancel into, most specific first.
func cancel_options(index: int) -> Array[int]:
	if not _cancel_cache.has(index):
		var targets: Array[int] = []
		for move_id in moves[index].cancels_into:
			var target := find_move(move_id)
			if target >= 0:
				targets.append(target)
			else:
				push_error("%s: move '%s' cancels into unknown move '%s'" % [id, moves[index].id, move_id])
		_cancel_cache[index] = _sorted_by_priority(targets)
	return _cancel_cache[index]


## Index of the move with this id, or -1.
func find_move(move_id: String) -> int:
	for i in moves.size():
		if moves[i].id == move_id:
			return i
	return -1


func _sorted_by_priority(indices: Array) -> Array[int]:
	var result: Array[int] = []
	result.assign(indices)
	# Ties keep list order, so the result is the same on every device.
	result.sort_custom(func(a: int, b: int) -> bool:
		var pa := moves[a].get_command().priority
		var pb := moves[b].get_command().priority
		return pa > pb or (pa == pb and a < b))
	return result
