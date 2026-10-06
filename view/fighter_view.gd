## Draws one fighter. Phase 1–2 use a placeholder capsule; Phase 3 swaps in
## the real 3D model and animations.
##
## 💡 Views only READ the simulation state, never change it. If every view is
## deleted, the fight still runs correctly, just invisibly (that's how the tests run).
class_name FighterView
extends Node3D

const State := FighterState.State
const HIT_TINT := Color(1, 1, 1)
const BLOCK_TINT := Color(0.4, 0.9, 1.0)
const THROWN_TINT := Color(0.8, 0.4, 1.0)
const LIMB_ACTIVE_COLOR := Color(1.0, 0.85, 0.2)

var _def: CharacterDef
var _base_color: Color
var _material: StandardMaterial3D
var _body_pivot: Node3D  # sits at the feet, squashed and tilted per state
var _nose: MeshInstance3D  # small box showing which way the fighter faces
var _limb: MeshInstance3D  # stand-in for an arm/leg while attacking
var _limb_material: StandardMaterial3D


func setup(def: CharacterDef, color: Color) -> void:
	_def = def
	_base_color = color
	var height := FixedMath.to_meters(def.stand_height)
	var radius := FixedMath.to_meters(def.pushbox_half_width)

	_material = StandardMaterial3D.new()
	_material.albedo_color = color

	_body_pivot = Node3D.new()
	add_child(_body_pivot)

	var capsule := CapsuleMesh.new()
	capsule.height = height
	capsule.radius = radius
	var body := MeshInstance3D.new()
	body.mesh = capsule
	body.material_override = _material
	body.position.y = height / 2.0  # capsule origin is its center; lift so feet sit at y = 0
	_body_pivot.add_child(body)

	var nose_mesh := BoxMesh.new()
	nose_mesh.size = Vector3(0.2, 0.12, 0.12)
	_nose = MeshInstance3D.new()
	_nose.mesh = nose_mesh
	_nose.material_override = _material
	_nose.position.y = height * 0.85
	_body_pivot.add_child(_nose)

	_limb_material = StandardMaterial3D.new()
	_limb = MeshInstance3D.new()
	_limb.mesh = BoxMesh.new()  # 1 m cube, scaled to the hitbox each frame
	_limb.material_override = _limb_material
	add_child(_limb)


## Places the fighter between the previous and current tick.
## `alpha` (0..1) is how far we are between the two ticks.
## 💡 The sim ticks 60 times a second but screens may refresh at 90 or 120 Hz.
## Interpolating keeps motion smooth without changing the simulation.
func show_state(prev: FighterState, cur: FighterState, alpha: float) -> void:
	var x := lerpf(prev.pos_x, cur.pos_x, alpha)
	var y := lerpf(prev.pos_y, cur.pos_y, alpha)
	position = Vector3(FixedMath.to_meters(int(x)), FixedMath.to_meters(int(y)), 0.0)

	_nose.position.x = cur.facing * FixedMath.to_meters(_def.pushbox_half_width)
	_show_posture(cur)
	_show_tint(cur)
	_show_limb(cur)


func _show_posture(cur: FighterState) -> void:
	# Tilt backwards when knocked down or launched (pivot is at the feet).
	var tilt := 0.0
	match cur.state:
		State.KNOCKDOWN: tilt = 90.0
		State.WAKEUP: tilt = 45.0
		State.JUGGLE: tilt = 60.0
	_body_pivot.rotation_degrees.z = tilt * cur.facing
	# Otherwise squash the capsule to the pushbox height (crouch, jump tuck).
	var height := Collision.body_height(cur, _def) if tilt == 0.0 else _def.stand_height
	_body_pivot.scale.y = float(height) / _def.stand_height


func _show_tint(cur: FighterState) -> void:
	var color := _base_color
	match cur.state:
		State.HITSTUN, State.JUGGLE: color = _base_color.lerp(HIT_TINT, 0.55)
		State.BLOCKSTUN: color = _base_color.lerp(BLOCK_TINT, 0.5)
		State.THROWN: color = _base_color.lerp(THROWN_TINT, 0.5)
	_material.albedo_color = color


## Shows the attack's hitbox area as a solid block: bright while the attack
## is active, dim during recovery, hidden during startup.
func _show_limb(cur: FighterState) -> void:
	_limb.visible = false
	if cur.state != State.ATTACK and cur.state != State.THROWING:
		return
	var move := _def.moves[cur.move_index]
	var frame := cur.state_frame + 1
	if cur.state == State.ATTACK and frame < move.startup:
		return
	var rect := move.hitbox_of(cur)
	var center := Vector3(
		FixedMath.to_meters(rect.position.x + rect.size.x / 2 - cur.pos_x),
		FixedMath.to_meters(rect.position.y + rect.size.y / 2 - cur.pos_y),
		0.0)
	_limb.position = center
	_limb.scale = Vector3(FixedMath.to_meters(rect.size.x), FixedMath.to_meters(rect.size.y), 0.25)
	var active := cur.state == State.ATTACK and move.is_active_frame(frame)
	_limb_material.albedo_color = LIMB_ACTIVE_COLOR if active else _base_color.darkened(0.3)
	_limb.visible = true
