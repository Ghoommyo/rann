## Debug drawing of collision boxes, toggled with F1.
##
## 💡 Seeing the invisible boxes is the main way to debug and balance a
## fighting game:
##  - yellow = pushbox (body collision)
##  - green  = hurtbox (where you can be hit; missing while invincible)
##  - red    = hitbox (only drawn on the attack's active frames)
class_name HitboxOverlay
extends MeshInstance3D

const PUSHBOX_COLOR := Color(1.0, 0.85, 0.1)
const HURTBOX_COLOR := Color(0.2, 1.0, 0.3)
const HITBOX_COLOR := Color(1.0, 0.15, 0.15)
const THROWBOX_COLOR := Color(0.8, 0.3, 1.0)

var _lines := ImmediateMesh.new()


func _ready() -> void:
	mesh = _lines
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = true  # always draw on top of the models
	material_override = material


## Redraws the boxes for the current (not interpolated) sim state.
func draw_state(state: FightState, defs: Array[CharacterDef]) -> void:
	_lines.clear_surfaces()
	if not visible:
		return
	_lines.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in state.fighters.size():
		var f := state.fighters[i]
		var def := defs[i]
		_add_rect(Collision.pushbox_of(f, def), PUSHBOX_COLOR)
		if Collision.has_hurtbox(f):
			_add_rect(Collision.hurtbox_of(f, def), HURTBOX_COLOR)
		if f.state == FighterState.State.ATTACK:
			var move := def.moves[f.move_index]
			if move.is_active_frame(f.state_frame + 1):
				var color := THROWBOX_COLOR if move.hit_level == MoveDef.HitLevel.THROW else HITBOX_COLOR
				_add_rect(move.hitbox_of(f), color)
	_lines.surface_end()


func _add_rect(r: Rect2i, color: Color) -> void:
	var x0 := FixedMath.to_meters(r.position.x)
	var y0 := FixedMath.to_meters(r.position.y)
	var x1 := FixedMath.to_meters(r.end.x)
	var y1 := FixedMath.to_meters(r.end.y)
	var corners := [Vector3(x0, y0, 0), Vector3(x1, y0, 0), Vector3(x1, y1, 0), Vector3(x0, y1, 0)]
	for i in 4:
		_lines.surface_set_color(color)
		_lines.surface_add_vertex(corners[i])
		_lines.surface_set_color(color)
		_lines.surface_add_vertex(corners[(i + 1) % 4])
