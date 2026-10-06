## "Dusk Dojo": a stage built from simple shapes in code, so it needs no art
## files. It can be replaced later with a modelled stage scene; the fight only
## needs the stage to be a Node3D.
##
## 💡 Stages are pure decoration. The real fighting area is the integer
## stage_left/stage_right in FightState (±6 m), and the walls drawn here just
## line up with it.
##
## Tuned for the Mobile renderer: one shadow-casting light, a few small
## omni lights, simple materials.
class_name DojoStage
extends Node3D

const FLOOR_WOOD := Color(0.42, 0.27, 0.16)
const MAT_COLOR := Color(0.55, 0.38, 0.22)
const LACQUER := Color(0.55, 0.08, 0.06)
const DARK_WOOD := Color(0.18, 0.1, 0.06)
const PAPER := Color(1.0, 0.86, 0.62)
const LANTERN := Color(1.0, 0.55, 0.2)


func _ready() -> void:
	_add_environment()
	_add_sun()
	_add_floor()
	_add_back_wall()
	_add_pillars()
	_add_lanterns()
	_add_mountains()


func _add_environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.12, 0.1, 0.28)
	sky_material.sky_horizon_color = Color(0.95, 0.5, 0.3)
	sky_material.ground_bottom_color = Color(0.05, 0.04, 0.06)
	sky_material.ground_horizon_color = Color(0.5, 0.3, 0.25)
	var sky := Sky.new()
	sky.sky_material = sky_material

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# Glow and fog cost GPU time: only on Medium and High quality.
	env.glow_enabled = Settings.quality != Settings.Quality.LOW
	env.glow_intensity = 0.6
	env.fog_enabled = Settings.quality != Settings.Quality.LOW
	env.fog_light_color = Color(0.6, 0.4, 0.35)
	env.fog_density = 0.008
	env.fog_sky_affect = 0.0  # keep the sunset gradient visible

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)


func _add_sun() -> void:
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.8, 0.6)
	sun.light_energy = 1.1
	sun.shadow_enabled = Settings.quality != Settings.Quality.LOW  # shadows are the most expensive effect
	sun.rotation_degrees = Vector3(-35, 30, 0)
	add_child(sun)


func _add_floor() -> void:
	_box(Vector3(30, 0.2, 14), Vector3(0, -0.1, 0), FLOOR_WOOD, 0.8)
	_box(Vector3(12.4, 0.02, 3.2), Vector3(0, 0.01, 0), MAT_COLOR, 0.9)  # the fighting mat
	# Dark strips at the mat edges, which also mark the walls at ±6 m.
	for x in [-6.2, 6.2]:
		_box(Vector3(0.2, 0.03, 3.2), Vector3(x, 0.015, 0), DARK_WOOD, 0.9)
	for z in [-1.6, 1.6]:
		_box(Vector3(12.4, 0.03, 0.1), Vector3(0, 0.015, z), DARK_WOOD, 0.9)


func _add_back_wall() -> void:
	_box(Vector3(30, 2.6, 0.3), Vector3(0, 1.3, -4.5), DARK_WOOD, 0.9)
	# Glowing paper screens (shoji).
	for i in range(-6, 7):
		var panel := _box(Vector3(1.6, 1.8, 0.05), Vector3(i * 2.2, 1.3, -4.33), PAPER, 1.0)
		var mat: StandardMaterial3D = panel.material_override
		mat.emission_enabled = true
		mat.emission = PAPER
		mat.emission_energy_multiplier = 0.35
	_box(Vector3(30, 0.25, 0.5), Vector3(0, 2.7, -4.4), LACQUER, 0.6)  # top beam


func _add_pillars() -> void:
	for x in [-8.0, -3.5, 3.5, 8.0]:
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.22
		mesh.bottom_radius = 0.22
		mesh.height = 3.4
		_mesh(mesh, Vector3(x, 1.7, -3.9), LACQUER, 0.5)


func _add_lanterns() -> void:
	for x in [-5.75, 0.0, 5.75]:
		var lantern := _box(Vector3(0.35, 0.5, 0.35), Vector3(x, 2.2, -3.9), LANTERN, 0.5)
		var mat: StandardMaterial3D = lantern.material_override
		mat.emission_enabled = true
		mat.emission = LANTERN
		mat.emission_energy_multiplier = 2.5
		if Settings.quality == Settings.Quality.LOW:
			continue  # emissive lanterns still glow; skip their extra lights
		var light := OmniLight3D.new()
		light.light_color = LANTERN
		light.light_energy = 1.2
		light.omni_range = 5.0
		light.position = Vector3(x, 2.0, -3.4)
		add_child(light)


## Distant silhouettes above the wall, to give the scene depth.
func _add_mountains() -> void:
	var peaks := [[-22.0, 9.0], [-12.0, 6.0], [-2.0, 11.0], [9.0, 7.0], [20.0, 10.0]]
	for peak in peaks:
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.0
		mesh.bottom_radius = peak[1] * 0.9
		mesh.height = peak[1]
		mesh.radial_segments = 6
		_mesh(mesh, Vector3(peak[0], peak[1] / 2.0 - 1.0, -40), Color(0.2, 0.12, 0.2), 1.0)


func _box(size: Vector3, pos: Vector3, color: Color, roughness: float) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(mesh, pos, color, roughness)


func _mesh(mesh: Mesh, pos: Vector3, color: Color, roughness: float) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	add_child(node)
	return node
