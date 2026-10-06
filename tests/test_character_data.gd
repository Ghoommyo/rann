## Validates character data files, so mistakes in .tres files are caught
## by tests instead of during a match.
extends GutTest

const FIXTURES := ["res://tests/fixtures/dummy/character.tres"]


func _all_defs() -> Array[CharacterDef]:
	var defs: Array[CharacterDef] = CharacterRegistry.all().duplicate()
	for path in FIXTURES:
		defs.append(load(path))
	return defs


func test_characters_are_valid():
	for def in _all_defs():
		assert_ne(def.id, "", "character has an id")
		assert_gt(def.moves.size(), 0, "%s has moves" % def.id)
		var ids := {}
		for move in def.moves:
			var where := "%s/%s" % [def.id, move.id]
			assert_false(ids.has(move.id), "%s: duplicate move id" % where)
			ids[move.id] = true
			assert_gt(move.startup, 0, where)
			assert_gte(move.active, 0, where)
			assert_gte(move.recovery, 0, where)
			assert_gt(move.total_frames(), 0, where)
			if move.active > 0:
				assert_gt(move.hitbox_width, 0, "%s: active move needs a hitbox" % where)
				assert_gt(move.hitbox_height, 0, where)
			assert_gt(move.get_command().buttons, 0, "%s: command '%s' has a button" % [where, move.command])
			for target in move.cancels_into:
				assert_gte(def.find_move(target), 0, "%s cancels into missing move '%s'" % [where, target])


func test_stance_moves_use_known_stances():
	for def in _all_defs():
		var stances: Array[String] = []
		for c in def.get_style().components:
			if c is StanceComponent:
				stances = c.stances
		for move in def.moves:
			for stance in [move.required_stance, move.enters_stance]:
				if stance != "":
					assert_has(stances, stance, "%s/%s uses unknown stance '%s'" % [def.id, move.id, stance])


func test_meter_moves_have_a_meter():
	for def in _all_defs():
		var has_meter := def.get_style().components.any(func(c): return c is MeterComponent)
		for move in def.moves:
			if move.meter_cost > 0:
				assert_true(has_meter, "%s/%s costs meter but %s has no MeterComponent" % [def.id, move.id, def.id])
