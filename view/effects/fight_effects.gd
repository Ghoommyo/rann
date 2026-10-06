## Spawns visual effects for sim events: hit sparks, block sparks, parry flashes.
##
## 💡 The sim leaves notes in FightState.events (HIT at x/y, BLOCK, …) and this
## node turns them into particles. Effects are fire-and-forget: each one
## deletes itself when it finishes.
class_name FightEffects
extends Node3D

const Event := FightState.Event

const COLORS := {
	Event.HIT: Color(1.0, 0.6, 0.15),
	Event.BLOCK: Color(0.4, 0.8, 1.0),
	Event.PARRY: Color(1.0, 1.0, 1.0),
	Event.THROW_BREAK: Color(0.85, 0.5, 1.0),
	Event.KO: Color(1.0, 0.25, 0.15),
}


func play(event: Dictionary) -> void:
	var type: int = event.type
	if not COLORS.has(type):
		return
	var pos := Vector3(FixedMath.to_meters(event.x), FixedMath.to_meters(event.y), 0.3)
	# Bigger hits throw more, faster sparks.
	var power := clampf(event.amount / 100.0, 0.4, 2.5)
	if type == Event.KO:
		power = 3.0
	elif type == Event.PARRY or type == Event.THROW_BREAK:
		power = 1.5
	_spawn_sparks(pos, COLORS[type], power, type == Event.BLOCK)


func _spawn_sparks(pos: Vector3, color: Color, power: float, flat: bool) -> void:
	var p := CPUParticles3D.new()
	p.position = pos
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = int(10 + 10 * power)
	p.lifetime = 0.25 + 0.1 * power
	p.direction = Vector3(0, 1, 0)
	p.spread = 70.0 if flat else 180.0
	p.initial_velocity_min = 2.0 * power
	p.initial_velocity_max = 5.0 * power
	p.gravity = Vector3(0, -6, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2

	var mesh := SphereMesh.new()
	mesh.radius = 0.03
	mesh.height = 0.06
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.0
	mesh.material = mat
	p.mesh = mesh

	add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
