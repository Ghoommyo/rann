## Cleans up animations made from your own videos (AI motion capture, see
## plans/11-guide-recording-moves.md) so they fit the game:
##  - face_like(): turns the whole clip so its starting stance faces the same
##    way as a reference stance (the fighter's Mixamo idle). The camera angle
##    you filmed at then doesn't matter.
##  - trim_still(): cuts the still second at the start and end of the clip,
##    so the move begins on its first moving frame.
##
## Used by tools/build_animation_libraries.gd. Works on the Hips bone, the
## root of Mixamo skeletons.
extends RefCounted

## How far (degrees) any bone must turn from the starting pose to count as moving.
const MOVE_THRESHOLD_DEG := 8.0
## Kept before the first and after the last moving frame (seconds).
const MARGIN_S := 0.1
const SAMPLE_S := 1.0 / 30.0


## The track index of the Hips bone's rotation (or position), -1 if none.
static func hips_track(anim: Animation, type: Animation.TrackType) -> int:
	for t in anim.get_track_count():
		if anim.track_get_type(t) == type and str(anim.track_get_path(t)).ends_with("Hips"):
			return t
	return -1


## Which way (radians around the up axis) the hips face at the clip's start,
## compared with the skeleton's rest pose.
static func start_yaw(anim: Animation, hips_rest: Quaternion) -> float:
	var t := hips_track(anim, Animation.TYPE_ROTATION_3D)
	if t < 0 or anim.track_get_key_count(t) == 0:
		return 0.0
	var q: Quaternion = anim.track_get_key_value(t, 0)
	var forward := (q * hips_rest.inverse()) * Vector3.BACK  # +Z: where Mixamo models face
	return atan2(forward.x, forward.z)


## Turns the whole clip around the up axis so its start faces `target_yaw`.
## Returns the turn applied (radians).
static func face_like(anim: Animation, hips_rest: Quaternion, target_yaw: float) -> float:
	var turn := wrapf(target_yaw - start_yaw(anim, hips_rest), -PI, PI)
	var spin := Quaternion(Vector3.UP, turn)
	var rot := hips_track(anim, Animation.TYPE_ROTATION_3D)
	if rot >= 0:
		for k in anim.track_get_key_count(rot):
			anim.track_set_key_value(rot, k, spin * (anim.track_get_key_value(rot, k) as Quaternion))
	var pos := hips_track(anim, Animation.TYPE_POSITION_3D)
	if pos >= 0:
		for k in anim.track_get_key_count(pos):
			anim.track_set_key_value(pos, k, spin * (anim.track_get_key_value(pos, k) as Vector3))
	return turn


## Cuts the still start and end. Returns [start, end] (seconds, in the
## original clip) of the part that was kept.
static func trim_still(anim: Animation) -> Array[float]:
	var length := anim.length
	var first_pose := _pose(anim, 0.0)
	var last_pose := _pose(anim, length)
	var start := 0.0
	var end := length
	var moved := false
	var time := 0.0
	while time <= length:
		var pose := _pose(anim, time)
		if _differs(pose, first_pose):
			if not moved:
				start = maxf(time - MARGIN_S, 0.0)
				moved = true
		if _differs(pose, last_pose):
			end = minf(time + MARGIN_S, length)
		time += SAMPLE_S
	var kept: Array[float] = [start, end]
	if not moved or end - start < 0.1:
		return [0.0, length]  # no clear motion: leave the clip alone
	_cut(anim, start, end)
	return kept


static func _pose(anim: Animation, time: float) -> Array[Quaternion]:
	var pose: Array[Quaternion] = []
	for t in anim.get_track_count():
		if anim.track_get_type(t) == Animation.TYPE_ROTATION_3D and anim.track_get_key_count(t) > 0:
			pose.append(anim.rotation_track_interpolate(t, time))
	return pose


static func _differs(a: Array[Quaternion], b: Array[Quaternion]) -> bool:
	for i in a.size():
		if rad_to_deg(a[i].angle_to(b[i])) > MOVE_THRESHOLD_DEG:
			return true
	return false


## Keeps only [start, end] of every track, shifted to begin at 0.
static func _cut(anim: Animation, start: float, end: float) -> void:
	for t in anim.get_track_count():
		var type := anim.track_get_type(t)
		if anim.track_get_key_count(t) == 0:
			continue
		var at_start: Variant = _value_at(anim, t, type, start)
		var at_end: Variant = _value_at(anim, t, type, end)
		var keys: Array = []
		for k in anim.track_get_key_count(t):
			var time := anim.track_get_key_time(t, k)
			if time > start and time < end:
				keys.append([time - start, anim.track_get_key_value(t, k)])
		while anim.track_get_key_count(t) > 0:
			anim.track_remove_key(t, 0)
		anim.track_insert_key(t, 0.0, at_start)
		for key in keys:
			anim.track_insert_key(t, key[0], key[1])
		anim.track_insert_key(t, end - start, at_end)
	anim.length = end - start


static func _value_at(anim: Animation, t: int, type: Animation.TrackType, time: float) -> Variant:
	match type:
		Animation.TYPE_ROTATION_3D: return anim.rotation_track_interpolate(t, time)
		Animation.TYPE_POSITION_3D: return anim.position_track_interpolate(t, time)
		Animation.TYPE_SCALE_3D: return anim.scale_track_interpolate(t, time)
		Animation.TYPE_BLEND_SHAPE: return anim.blend_shape_track_interpolate(t, time)
	return anim.value_track_interpolate(t, time)
