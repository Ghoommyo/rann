## Builds each character's animation library from downloaded animation files,
## and links the model and animations into the character's data.
##
## For every folder assets/characters/<id>/:
##   model.fbx (or .glb)  → CharacterDef.model_scene
##   anims/<name>.fbx     → animation "<name>" in data/characters/<id>/animations.res
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
## Their hip positions are in the source's proportions, so they are scaled by
## (model hip height ÷ source hip height) to keep the feet on the floor.
extends SceneTree

const ASSETS := "res://assets/characters"
const LOOPING := ["idle", "walk_forward", "walk_back", "crouch"]
const MODEL_NAMES := ["model.fbx", "model.glb", "model.gltf"]
const HIPS := "mixamorig_Hips"


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

	var model_hips := 0.0
	for model_name in MODEL_NAMES:
		var model_path := "%s/%s" % [folder, model_name]
		if ResourceLoader.exists(model_path):
			def.model_scene = load(model_path)
			model_hips = _hips_height(def.model_scene)
			print("%s: model %s" % [id, model_path])
			break

	var anim_folder := folder + "/anims"
	if DirAccess.dir_exists_absolute(anim_folder):
		var library := AnimationLibrary.new()
		var files := Array(DirAccess.get_files_at(anim_folder))
		files.sort()
		for file in files:
			if file.get_extension() not in ["fbx", "glb", "gltf"]:
				continue
			var anim_path := "%s/%s" % [anim_folder, file]
			var anim := _first_animation(anim_path)
			if anim == null:
				printerr("%s: no animation found in %s" % [id, file])
				continue
			var anim_name: String = file.get_basename()
			anim.loop_mode = Animation.LOOP_LINEAR if anim_name in LOOPING else Animation.LOOP_NONE
			_lock_root_motion(anim)
			var source_hips := _hips_height(load(anim_path))
			if model_hips > 0.0 and source_hips > 0.0 and absf(model_hips / source_hips - 1.0) > 0.01:
				_scale_hips(anim, model_hips / source_hips)
			library.add_animation(anim_name, anim)
		var library_path := "res://data/characters/%s/animations.res" % id
		ResourceSaver.save(library, library_path)
		def.animation_library = load(library_path)
		print("%s: %d animations → %s" % [id, library.get_animation_list().size(), library_path])
		_report_missing(id, def, library)

	ResourceSaver.save(def, def_path)


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
	if not scene is PackedScene:
		return 0.0
	var root: Node = scene.instantiate()
	var height := 0.0
	var skeletons := root.find_children("*", "Skeleton3D", true, false)
	if not skeletons.is_empty():
		var skeleton: Skeleton3D = skeletons[0]
		var bone := skeleton.find_bone(HIPS)
		if bone >= 0:
			height = skeleton.get_bone_global_rest(bone).origin.y
	root.free()
	return height


## Scales the hips' position so an animation fits a taller or shorter body.
func _scale_hips(anim: Animation, ratio: float) -> void:
	for t in anim.get_track_count():
		if anim.track_get_type(t) == Animation.TYPE_POSITION_3D and str(anim.track_get_path(t)).ends_with("Hips"):
			for k in anim.track_get_key_count(t):
				anim.track_set_key_value(t, k, anim.track_get_key_value(t, k) * ratio)


## Lists the animations the character still needs.
func _report_missing(id: String, def: CharacterDef, library: AnimationLibrary) -> void:
	var needed := {}
	for entry in FighterView.STATE_ANIMS.values():
		needed[entry[0]] = true
	for move in def.moves:
		needed[move.animation_name] = true
	var missing := needed.keys().filter(func(n): return not library.has_animation(n))
	if missing.is_empty():
		print("%s: all animations present ✓" % id)
	else:
		print("%s: missing (will fall back to idle): %s" % [id, ", ".join(missing)])
