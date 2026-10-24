## Cleaning up clips made from your own videos (tools/clip_cleanup.gd).
extends GutTest

const ClipCleanup := preload("res://tools/clip_cleanup.gd")


## A 3 s clip: still for 1 s, the arm swings for 1 s, still again for 1 s.
## The whole body is turned `yaw` degrees, as if filmed at an angle.
func _recorded_clip(yaw: float) -> Animation:
	var anim := Animation.new()
	anim.length = 3.0
	var turn := Quaternion(Vector3.UP, deg_to_rad(yaw))
	var hips := anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(hips, "Skeleton3D:mixamorig_Hips")
	var hips_pos := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(hips_pos, "Skeleton3D:mixamorig_Hips")
	var arm := anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(arm, "Skeleton3D:mixamorig_RightArm")
	for i in 31:
		var t := i * 0.1
		anim.rotation_track_insert_key(hips, t, turn)
		anim.position_track_insert_key(hips_pos, t, turn * Vector3(0.1, 1.0, 0.0))
		var swing := 0.0 if t <= 1.0 or t >= 2.0 else sin((t - 1.0) * PI) * 90.0
		anim.rotation_track_insert_key(arm, t, Quaternion(Vector3.RIGHT, deg_to_rad(swing)))
	return anim


func test_turns_the_clip_to_face_like_the_reference():
	var anim := _recorded_clip(50.0)
	assert_almost_eq(rad_to_deg(ClipCleanup.start_yaw(anim, Quaternion.IDENTITY)), 50.0, 0.1)
	ClipCleanup.face_like(anim, Quaternion.IDENTITY, deg_to_rad(-20.0))
	assert_almost_eq(rad_to_deg(ClipCleanup.start_yaw(anim, Quaternion.IDENTITY)), -20.0, 0.1)
	var hips_pos := ClipCleanup.hips_track(anim, Animation.TYPE_POSITION_3D)
	var pos: Vector3 = anim.track_get_key_value(hips_pos, 0)
	assert_almost_eq(pos.y, 1.0, 0.001, "height unchanged")
	assert_almost_eq(Vector2(pos.x, pos.z).length(), 0.1, 0.001, "offset turned, not stretched")


func test_yaw_is_relative_to_the_rest_pose():
	var rest := Quaternion(Vector3.UP, deg_to_rad(30.0))
	var anim := _recorded_clip(30.0)
	assert_almost_eq(ClipCleanup.start_yaw(anim, rest), 0.0, 0.001, "standing at rest = facing forward")


func test_trims_the_still_start_and_end():
	var anim := _recorded_clip(0.0)
	var kept := ClipCleanup.trim_still(anim)
	assert_between(kept[0], 0.9, 1.2, "starts just before the swing")
	assert_between(kept[1], 1.8, 2.1, "ends just after it")
	assert_almost_eq(anim.length, kept[1] - kept[0], 0.001)
	var arm := 2
	assert_almost_eq(anim.rotation_track_interpolate(arm, 0.0).angle_to(Quaternion.IDENTITY), 0.0, 0.2,
		"begins near the stance pose")
	var peak := anim.rotation_track_interpolate(arm, 1.5 - kept[0])
	assert_almost_eq(rad_to_deg(peak.angle_to(Quaternion.IDENTITY)), 90.0, 2.0, "the swing is kept")


func test_leaves_a_clip_without_motion_alone():
	var anim := Animation.new()
	anim.length = 2.0
	var t := anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(t, "Skeleton3D:mixamorig_Hips")
	anim.rotation_track_insert_key(t, 0.0, Quaternion.IDENTITY)
	anim.rotation_track_insert_key(t, 2.0, Quaternion.IDENTITY)
	assert_eq(ClipCleanup.trim_still(anim), [0.0, 2.0])
	assert_eq(anim.length, 2.0)
