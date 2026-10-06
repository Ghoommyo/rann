## Draws one fighter. Phase 1 uses a placeholder capsule; Phase 3 swaps in
## the real 3D model and animations.
##
## 💡 Views only READ the simulation state, never change it. If every view is
## deleted, the fight still runs correctly, just invisibly (that's how the tests run).
class_name FighterView
extends Node3D

var _def: CharacterDef
var _body_pivot: Node3D  # sits at the feet, scaled to squash for crouch/jump
var _nose: MeshInstance3D  # small box showing which way the fighter faces


func setup(def: CharacterDef, color: Color) -> void:
	_def = def
	var height := FixedMath.to_meters(def.stand_height)
	var radius := FixedMath.to_meters(def.pushbox_half_width)

	var material := StandardMaterial3D.new()
	material.albedo_color = color

	_body_pivot = Node3D.new()
	add_child(_body_pivot)

	var capsule := CapsuleMesh.new()
	capsule.height = height
	capsule.radius = radius
	var body := MeshInstance3D.new()
	body.mesh = capsule
	body.material_override = material
	body.position.y = height / 2.0  # capsule origin is its center; lift so feet sit at y = 0
	_body_pivot.add_child(body)

	var nose_mesh := BoxMesh.new()
	nose_mesh.size = Vector3(0.2, 0.12, 0.12)
	_nose = MeshInstance3D.new()
	_nose.mesh = nose_mesh
	_nose.material_override = material
	_nose.position.y = height * 0.85
	_body_pivot.add_child(_nose)


## Places the fighter between the previous and current tick.
## `alpha` (0..1) is how far we are between the two ticks.
## 💡 The sim ticks 60 times a second but screens may refresh at 90 or 120 Hz.
## Interpolating keeps motion smooth without changing the simulation.
func show_state(prev: FighterState, cur: FighterState, alpha: float) -> void:
	var x := lerpf(prev.pos_x, cur.pos_x, alpha)
	var y := lerpf(prev.pos_y, cur.pos_y, alpha)
	position = Vector3(FixedMath.to_meters(int(x)), FixedMath.to_meters(int(y)), 0.0)

	# Squash the capsule to match the pushbox height (crouch, jump tuck).
	var box := Collision.pushbox_of(cur, _def)
	_body_pivot.scale.y = float(box.size.y) / _def.stand_height
	_nose.position.x = cur.facing * FixedMath.to_meters(_def.pushbox_half_width)
