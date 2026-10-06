## The fight camera: keeps both fighters in view, zooms out when they move
## apart, rises a little for juggles, and shakes on big hits.
##
## 💡 View only. The camera reads FightState and never affects the fight, so
## it can use floats, smoothing and randomness freely.
class_name CameraRig
extends Camera3D

@export var min_distance := 4.6
@export var max_distance := 8.0
## Extra camera distance per meter between the fighters.
@export var zoom_per_meter := 0.55
@export var height := 1.35
@export var look_height := 1.05
## Higher = snappier following.
@export var follow_speed := 6.0

var _base := Vector3(0, 1.35, 6.0)  # where the camera is, before shake
var _look := Vector3(0, 1.05, 0)
var _shake := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	fov = 50.0


## Moves the camera towards where it should be for this state.
func follow(state: FightState, delta: float) -> void:
	var a := state.fighters[0]
	var b := state.fighters[1]
	var mid_x := FixedMath.to_meters((a.pos_x + b.pos_x) / 2)
	var spread := FixedMath.to_meters(absi(a.pos_x - b.pos_x))
	var top := FixedMath.to_meters(maxi(a.pos_y, b.pos_y))

	var target_z := clampf(3.3 + spread * zoom_per_meter, min_distance, max_distance)
	# Don't show much past the stage walls.
	var edge := maxf(0.0, FixedMath.to_meters(state.stage_right) - target_z * 0.45)
	var target := Vector3(clampf(mid_x, -edge, edge), height + top * 0.35, target_z)

	var t := 1.0 - exp(-follow_speed * delta)  # frame-rate independent smoothing
	_base = _base.lerp(target, t)
	_look = Vector3(_base.x, look_height + top * 0.3, 0)

	_shake = maxf(0.0, _shake - delta * 2.5)
	var jolt := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), 0) * _shake * 0.12
	position = _base + jolt
	look_at(_look + jolt * 0.5)


## Starts a shake. Bigger `strength` = stronger jolt (1.0 is a heavy hit).
func shake(strength: float) -> void:
	_shake = maxf(_shake, strength)


## Jumps straight to the right spot (e.g. when a match starts).
func snap(state: FightState) -> void:
	follow(state, 100.0)
