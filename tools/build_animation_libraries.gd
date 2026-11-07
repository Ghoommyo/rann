## Builds each character's animation library from downloaded animation files,
## and links the model and animations into the character's data.
##
## For every folder assets/characters/<id>/:
##   model.fbx (or .glb)  → CharacterDef.model_scene
##   anims/<name>.fbx     → animation "<name>" in data/characters/<id>/animations.res
##   recorded/<name>.fbx  → the same, made from your own video (replaces anims/<name>);
##                          turned to face forward and trimmed (tools/clip_cleanup.gd)
##
## The file name becomes the animation name, so name the files after the
## STATE_ANIMS in view/fighter_view.gd (idle.fbx, walk_forward.fbx, …) and after
## each MoveDef.animation_name (jab.fbx, uppercut.fbx, …).
##
## Run it after adding or changing files (the import step lets Godot convert
## the new FBX files first):
##     godot --headless --path . --import
##     godot --headless --path . -s tools/build_animation_libraries.gd
##
## 💡 The sim decides where fighters stand, so the tool removes the hips'
## sideways/forward movement from every animation ("root motion"). Up/down
## movement is kept, so crouches and jumps still look right.
##
## Animations may come from another character (e.g. Kael's anims on Tulbul).
## Each one records its source skeleton's hip height ("source_hips" metadata);
## FighterView uses it to fit the hips to whatever model is loaded, so a
## model can be swapped without rebuilding.
extends SceneTree

const ASSETS := "res://assets/characters"
const LOOPING := ["idle", "walk_forward", "walk_back", "crouch"]  # and any "<stance>_idle"
const MODEL_NAMES := ["model.fbx", "model.glb", "model.gltf"]
const HIPS := "mixamorig_Hips"
const ClipCleanup := preload("res://tools/clip_cleanup.gd")


func _init() -> void:
	if not DirAccess.dir_exists_absolute(ASSETS):
		printerr("No %s folder yet. See plans/07-guide-mixamo-import.md" % ASSETS)
		quit(1)
		return
	for folder in DirAccess.get_directories_at(ASSETS):
		if folder != folder.to_lower():
			# res:// paths are case-sensitive on Android, iOS and Linux.
			printerr("%s/%s: rename the folder to lowercase '%s' to match the character id" % [ASSETS, folder, folder.to_lower()])
			continue
		_build_character(folder)
	quit()


func _build_character(id: String) -> void:
	var def_path := "res://data/characters/%s/character.tres" % id
	if not ResourceLoader.exists(def_path):
		printerr("%s: no data/characters/%s/character.tres, skipping" % [id, id])
		return
	var def: CharacterDef = load(def_path)
	var folder := "%s/%s" % [ASSETS, id]

	for model_name in MODEL_NAMES:
		var model_path := "%s/%s" % [folder, model_name]
		if ResourceLoader.exists(model_path):
			def.model_scene = load(model_path)
			print("%s: model %s" % [id, model_path])
			break

	var anim_folder := folder + "/anims"
	var recorded_folder := folder + "/recorded"
	if DirAccess.dir_exists_absolute(anim_folder) or DirAccess.dir_exists_absolute(recorded_folder):
		var library := AnimationLibrary.new()
		for anim_path in _clip_files(anim_folder):
			_add_clip(id, library, anim_path, false, 0.0)
		# Your own recordings replace the borrowed clip of the same name. They're
		# turned so their stance faces like the fighter's Mixamo idle.
		var reference := 0.0
		if ResourceLoader.exists(anim_folder + "/idle.fbx"):
			var idle := _first_animation(anim_folder + "/idle.fbx")
			reference = ClipCleanup.start_yaw(idle, _hips_rest(load(anim_folder + "/idle.fbx")))
		var recorded := {}
		for anim_path in _clip_files(recorded_folder):
			if _add_clip(id, library, anim_path, true, reference):
				recorded[anim_path.get_file().get_basename()] = true
		var library_path := "res://data/characters/%s/animations.res" % id
		ResourceSaver.save(library, library_path)
		def.animation_library = load(library_path)
		print("%s: %d animations → %s" % [id, library.get_animation_list().size(), library_path])
		_report(id, def, library, recorded)

	ResourceSaver.save(def, def_path)


func _clip_files(dir: String) -> Array[String]:
	var paths: Array[String] = []
	if DirAccess.dir_exists_absolute(dir):
		var files := Array(DirAccess.get_files_at(dir))
		files.sort()
		for file in files:
			if file.get_extension() in ["fbx", "glb", "gltf"]:
				paths.append("%s/%s" % [dir, file])
	return paths


## Adds one clip to the library (replacing one of the same name). Recorded
## clips are cleaned up first. Returns false if the file has no animation.
func _add_clip(id: String, library: AnimationLibrary, path: String, recorded: bool, reference_yaw: float) -> bool:
	var anim := _first_animation(path)
	if anim == null:
		printerr("%s: no animation found in %s" % [id, path.get_file()])
		return false
	var anim_name := path.get_file().get_basename()
	var looping := anim_name in LOOPING or anim_name.ends_with("_idle")
	anim.loop_mode = Animation.LOOP_LINEAR if looping else Animation.LOOP_NONE
	var scene: Resource = load(path)
	if recorded:
		var turn := ClipCleanup.face_like(anim, _hips_rest(scene), reference_yaw)
		var note := "turned %d°" % roundi(rad_to_deg(turn))
		if not looping:
			var length := anim.length
			var kept := ClipCleanup.trim_still(anim)
			note += ", kept %.2f–%.2f s of %.2f s" % [kept[0], kept[1], length]
		print("%s: recorded %s (%s)" % [id, anim_name, note])
	_lock_root_motion(anim)
	var source_hips := _hips_height(scene)
	if source_hips > 0.0:
		anim.set_meta("source_hips", source_hips)
	if library.has_animation(anim_name):
		library.remove_animation(anim_name)
	library.add_animation(anim_name, anim)
	return true


## The first animation in an imported file (imported as a scene or as a library).
func _first_animation(path: String) -> Animation:
	var res := load(path)
	if res is AnimationLibrary:
		var names: Array = res.get_animation_list()
		return res.get_animation(names[0]).duplicate(true) if not names.is_empty() else null
	if res is PackedScene:
		var root: Node = res.instantiate()
		var players := root.find_children("*", "AnimationPlayer", true, false)
		var anim: Animation = null
		if not players.is_empty():
			var player: AnimationPlayer = players[0]
			var names := player.get_animation_list()
			for anim_name in names:
				if anim_name != "RESET":
					anim = player.get_animation(anim_name).duplicate(true)
					break
		root.free()
		return anim
	return null


## Keeps the hips' height but pins their horizontal position to the first key.
func _lock_root_motion(anim: Animation) -> void:
	for t in anim.get_track_count():
		if anim.track_get_type(t) != Animation.TYPE_POSITION_3D:
			continue
		if not str(anim.track_get_path(t)).ends_with("Hips"):
			continue
		var first: Vector3 = anim.track_get_key_value(t, 0)
		for k in anim.track_get_key_count(t):
			var v: Vector3 = anim.track_get_key_value(t, k)
			anim.track_set_key_value(t, k, Vector3(first.x, v.y, first.z))


## Rest height of the hips bone in its skeleton's own units (0 if not found).
func _hips_height(scene: Resource) -> float:
	return _hips_rest_transform(scene).origin.y


## Rest rotation of the hips bone (identity if not found).
func _hips_rest(scene: Resource) -> Quaternion:
	return _hips_rest_transform(scene).basis.get_rotation_quaternion()


func _hips_rest_transform(scene: Resource) -> Transform3D:
	if not scene is PackedScene:
		return Transform3D()
	var root: Node = scene.instantiate()
	var rest := Transform3D()
	var skeletons := root.find_children("*", "Skeleton3D", true, false)
	if not skeletons.is_empty():
		var skeleton: Skeleton3D = skeletons[0]
		var bone := skeleton.find_bone(HIPS)
		if bone >= 0:
			rest = skeleton.get_bone_global_rest(bone)
	root.free()
	return rest


## Which animations are your own recordings, which are still borrowed
## (anims/: Mixamo or another fighter's), and which are missing.
func _report(id: String, def: CharacterDef, library: AnimationLibrary, recorded: Dictionary) -> void:
	var needed := {}
	for entry in FighterView.STATE_ANIMS.values():
		needed[entry[0]] = true
	for move in def.moves:
		needed[move.animation_name] = true
	var own: Array = needed.keys().filter(func(n): return recorded.has(n))
	var borrowed: Array = needed.keys().filter(func(n): return not recorded.has(n) and library.has_animation(n))
	var missing: Array = needed.keys().filter(func(n): return not library.has_animation(n))
	print("%s: recorded %d/%d%s" % [id, own.size(), needed.size(), (": " + ", ".join(own)) if not own.is_empty() else ""])
	if not borrowed.is_empty():
		print("%s: borrowed (anims/): %s" % [id, ", ".join(borrowed)])
	if not missing.is_empty():
		print("%s: missing (will fall back to idle): %s" % [id, ", ".join(missing)])
