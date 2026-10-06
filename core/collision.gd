## Box collision for the simulation, using Rect2i (integer rectangles).
##
## 💡 Fighting games don't use realistic physics. Each fighter has a few
## invisible boxes:
##  - pushbox: stops fighters walking through each other (Phase 1)
##  - hurtbox: where the fighter can be hit (Phase 2)
##  - hitbox:  the damaging part of an attack (Phase 2)
##
## Boxes are in sim units. x grows to the right, y grows upwards, and
## Rect2i.position is the bottom-left corner.
class_name Collision


## The fighter's pushbox for its current state (shorter when crouching or jumping).
static func pushbox_of(f: FighterState, def: CharacterDef) -> Rect2i:
	var height := def.stand_height
	if f.state == FighterState.State.CROUCH:
		height = def.crouch_height
	elif f.is_airborne():
		height = def.air_height
	var half := def.pushbox_half_width
	return Rect2i(f.pos_x - half, f.pos_y, half * 2, height)


## How far two boxes overlap horizontally (0 if they don't touch).
static func overlap_x(a: Rect2i, b: Rect2i) -> int:
	if not a.intersects(b):
		return 0
	return mini(a.end.x, b.end.x) - maxi(a.position.x, b.position.x)


## Keeps the fighter's pushbox inside the stage walls.
## Returns true if the fighter is touching a wall.
static func clamp_to_stage(f: FighterState, def: CharacterDef, left: int, right: int) -> bool:
	var lo := left + def.pushbox_half_width
	var hi := right - def.pushbox_half_width
	var clamped := clampi(f.pos_x, lo, hi)
	var at_wall := clamped != f.pos_x or f.pos_x == lo or f.pos_x == hi
	f.pos_x = clamped
	return at_wall


## Keeps both fighters on the stage, then pushes them apart if their
## pushboxes overlap. Each fighter moves half of the overlap. If one is
## against a wall, the other one takes the whole push.
static func resolve_pushboxes(a: FighterState, a_def: CharacterDef,
		b: FighterState, b_def: CharacterDef, stage_left: int, stage_right: int) -> void:
	clamp_to_stage(a, a_def, stage_left, stage_right)
	clamp_to_stage(b, b_def, stage_left, stage_right)

	var overlap := overlap_x(pushbox_of(a, a_def), pushbox_of(b, b_def))
	if overlap <= 0:
		return

	# Which way to push `a`: away from `b`. If they're exactly on top of each
	# other, use facing so the result is still deterministic.
	var dir := signi(a.pos_x - b.pos_x)
	if dir == 0:
		dir = -a.facing

	var half := overlap / 2
	a.pos_x += dir * (overlap - half)
	b.pos_x -= dir * half

	var a_at_wall := clamp_to_stage(a, a_def, stage_left, stage_right)
	var b_at_wall := clamp_to_stage(b, b_def, stage_left, stage_right)

	# A wall stopped part of the push: move the other fighter the rest of the way.
	overlap = overlap_x(pushbox_of(a, a_def), pushbox_of(b, b_def))
	if overlap > 0:
		if a_at_wall:
			b.pos_x -= dir * overlap
		elif b_at_wall:
			a.pos_x += dir * overlap
