## Draws one fighter: the character's 3D model if it has one
## (CharacterDef.model_scene), otherwise a placeholder capsule.
##
## 💡 Views only READ the simulation state, never change it. If every view is
## deleted, the fight still runs correctly, just invisibly (that's how the tests run).
##
## ## How animations are driven
## The animation doesn't decide anything: it is posed to match the sim each
## frame ("frame 7 of the uppercut"). After a rollback (Phase 4) it just
## jumps to the right pose.
##  - Attacks play MoveDef.animation_name, stretched over the move's total frames.
##  - Other states play the standard names in STATE_ANIMS.
## Missing animations fall back to "idle", so a half-finished character still works.
class_name FighterView
extends Node3D

const State := FighterState.State

## Standard animation names every character model should have
## (see plans/07-guide-mixamo-import.md). [name, loops]
const STATE_ANIMS := {
	State.IDLE: ["idle", true],
	State.WALK_FORWARD: ["walk_forward", true],
	State.WALK_BACK: ["walk_back", true],
	State.CROUCH: ["crouch", true],
	State.JUMP_SQUAT: ["jump", false],
	State.AIRBORNE: ["jump", false],
	State.LANDING: ["land", false],
	State.HITSTUN: ["hit", false],
	State.BLOCKSTUN: ["block", false],
	State.JUGGLE: ["juggle", false],
	State.KNOCKDOWN: ["knockdown", false],
	State.WAKEUP: ["wakeup", false],
	State.THROWN: ["thrown", false],
}

const HIT_TINT := Color(1, 1, 1)
const BLOCK_TINT := Color(0.4, 0.9, 1.0)
const THROWN_TINT := Color(0.8, 0.4, 1.0)
const LIMB_ACTIVE_COLOR := Color(1.0, 0.85, 0.2)

var _def: CharacterDef
var _base_color: Color

# Model mode
var _model: Node3D
var _anim: AnimationPlayer

# Capsule mode
var _material: StandardMaterial3D
var _body_pivot: Node3D  # sits at the feet, squashed and tilted per state
var _nose: MeshInstance3D  # shows which way the fighter faces
var _limb: MeshInstance3D  # stand-in for an arm/leg while attacking
var _limb_material: StandardMaterial3D


func setup(def: CharacterDef, color: Color) -> void:
	_def = def
	_base_color = color
	if def.model_scene:
		_setup_model()
	if _anim == null:
		if _model:
			push_warning("%s: model has no AnimationPlayer, using a capsule" % def.id)
			_model.queue_free()
			_model = null
		_setup_capsule()


## Places the fighter between the previous and current tick.
## `alpha` (0..1) is how far we are between the two ticks.
## 💡 The sim ticks 60 times a second but screens may refresh at 90 or 120 Hz.
## Interpolating keeps motion smooth without changing the simulation.
func show_state(prev: FighterState, cur: FighterState, alpha: float, global_frame: int) -> void:
	var x := lerpf(prev.pos_x, cur.pos_x, alpha)
	var y := lerpf(prev.pos_y, cur.pos_y, alpha)
	position = Vector3(FixedMath.to_meters(int(x)), FixedMath.to_meters(int(y)), 0.0)
	if _model:
		_show_model(cur, global_frame)
	else:
		_show_capsule(cur)


# --- Model ---

func _setup_model() -> void:
	_model = _def.model_scene.instantiate()
	_model.scale = Vector3.ONE * _def.model_scale
	add_child(_model)
	_anim = _find_animation_player(_model)
	if _anim:
		_anim.speed_scale = 0.0  # we pose it manually every frame


func _show_model(cur: FighterState, global_frame: int) -> void:
	# Mixamo models face +Z; turn them to face along the fight line.
	_model.rotation.y = deg_to_rad(90.0 * cur.facing)

	var anim_name := ""
	var progress := -1.0  # 0..1 through a one-shot animation; -1 = looping
	if cur.state == State.ATTACK or cur.state == State.THROWING:
		var move := _def.moves[cur.move_index]
		anim_name = move.animation_name
		var length := move.throw_duration if cur.state == State.THROWING else move.total_frames()
		progress = float(cur.state_frame) / maxi(1, length)
	else:
		var entry: Array = STATE_ANIMS.get(cur.state, ["idle", true])
		anim_name = entry[0]
		if not entry[1]:
			progress = _state_progress(cur)

	var full_name := _resolve(anim_name)
	if full_name == "":
		full_name = _resolve("idle")
		progress = -1.0
	if full_name == "":
		return
	if _anim.current_animation != full_name:
		_anim.play(full_name)
	var length_s := _anim.get_animation(full_name).length
	var time := fmod(global_frame / 60.0, length_s) if progress < 0.0 else clampf(progress, 0.0, 1.0) * length_s
	_anim.seek(time, true)


## How far through a one-shot state the fighter is (0..1).
func _state_progress(cur: FighterState) -> float:
	match cur.state:
		State.HITSTUN, State.BLOCKSTUN:
			return float(cur.state_frame) / maxi(1, cur.stun_frames)
		State.KNOCKDOWN:
			return float(cur.state_frame) / Rules.KNOCKDOWN_FRAMES
		State.WAKEUP:
			return float(cur.state_frame) / Rules.WAKEUP_FRAMES
		State.LANDING:
			return float(cur.state_frame) / maxi(1, _def.landing_frames)
		State.AIRBORNE:
			return 0.3 + 0.6 * float(cur.state_frame) / 30.0
		State.JUMP_SQUAT:
			return 0.3 * float(cur.state_frame) / maxi(1, _def.jump_squat_frames)
	return float(cur.state_frame) / 30.0


## Finds an animation by name in any of the player's libraries ("jab" or "moves/jab").
func _resolve(anim_name: String) -> String:
	if anim_name == "":
		return ""
	if _anim.has_animation(anim_name):
		return anim_name
	for library in _anim.get_animation_library_list():
		var full := "%s/%s" % [library, anim_name]
		if _anim.has_animation(full):
			return full
	return ""


static func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null


# --- Capsule (placeholder) ---

func _setup_capsule() -> void:
	var height := FixedMath.to_meters(_def.stand_height)
	var radius := FixedMath.to_meters(_def.pushbox_half_width)

	_material = StandardMaterial3D.new()
	_material.albedo_color = _base_color

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


func _show_capsule(cur: FighterState) -> void:
	_nose.position.x = cur.facing * FixedMath.to_meters(_def.pushbox_half_width)

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

	var color := _base_color
	match cur.state:
		State.HITSTUN, State.JUGGLE: color = _base_color.lerp(HIT_TINT, 0.55)
		State.BLOCKSTUN: color = _base_color.lerp(BLOCK_TINT, 0.5)
		State.THROWN: color = _base_color.lerp(THROWN_TINT, 0.5)
	_material.albedo_color = color

	_show_limb(cur)


## Shows the attack's hitbox area as a solid block: bright while the attack
## is active, dim during recovery, hidden during startup.
func _show_limb(cur: FighterState) -> void:
	_limb.visible = false
	if cur.state != State.ATTACK and cur.state != State.THROWING:
		return
	var move := _def.moves[cur.move_index]
	var frame := cur.state_frame + 1
	if move.active == 0 or (cur.state == State.ATTACK and frame < move.startup):
		return
	var rect := move.hitbox_of(cur)
	_limb.position = Vector3(
		FixedMath.to_meters(rect.position.x + rect.size.x / 2 - cur.pos_x),
		FixedMath.to_meters(rect.position.y + rect.size.y / 2 - cur.pos_y),
		0.0)
	_limb.scale = Vector3(FixedMath.to_meters(rect.size.x), FixedMath.to_meters(rect.size.y), 0.25)
	var active := cur.state == State.ATTACK and move.is_active_frame(frame)
	_limb_material.albedo_color = LIMB_ACTIVE_COLOR if active else _base_color.darkened(0.3)
	_limb.visible = true
