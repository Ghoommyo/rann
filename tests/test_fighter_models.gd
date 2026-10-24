## Every fighter's 3D model, posed in its idle animation, stands on the floor
## and is about as tall as its stand_height.
##
## 💡 Catches model problems that tests on the simulation can't see: borrowed
## animations lifting a model off the floor (or 100 m into the sky when the
## skeleton is scaled differently), and wrong auto-sizing (giants).
extends GutTest

const FLOOR_TOLERANCE := 0.15  # meters


func _posed_bounds(def: CharacterDef) -> Vector2:
	var view := FighterView.new()
	add_child_autofree(view)
	view.setup(def, def.color)
	view._anim.play("moves/idle")
	view._anim.seek(0.0, true)
	var skeleton: Skeleton3D = view._model.find_children("*", "Skeleton3D", true, false)[0]
	var low := INF
	var high := -INF
	for bone in skeleton.get_bone_count():
		var y := (skeleton.global_transform * skeleton.get_bone_global_pose(bone)).origin.y
		low = minf(low, y)
		high = maxf(high, y)
	return Vector2(low, high)


func test_models_stand_on_the_floor_at_their_height():
	for def in CharacterRegistry.all():
		if def.model_scene == null or def.animation_library == null:
			continue
		var bounds := _posed_bounds(def)
		var stand := FixedMath.to_meters(def.stand_height)
		assert_almost_eq(bounds.x, 0.0, FLOOR_TOLERANCE, "%s: feet on the floor (lowest bone at %.2f m)" % [def.id, bounds.x])
		var height := bounds.y - bounds.x
		assert_between(height, stand * 0.7, stand * 1.3, "%s: height %.2f m vs stand_height %.2f m" % [def.id, height, stand])
