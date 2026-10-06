## Debug drawing of collision boxes, toggled with F1.
##
## 💡 Seeing the invisible boxes is the main way to debug and balance a
## fighting game. Phase 1 draws pushboxes (yellow). Phase 2 adds hurtboxes
## (green) and hitboxes (red).
class_name HitboxOverlay
extends MeshInstance3D

const PUSHBOX_COLOR := Color(1.0, 0.85, 0.1)

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
		_add_rect(Collision.pushbox_of(state.fighters[i], defs[i]), PUSHBOX_COLOR)
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
