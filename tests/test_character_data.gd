## Validates character data files, so mistakes in .tres files are caught
## by tests instead of during a match.
extends GutTest

const PATHS := ["res://data/characters/dummy/character.tres"]


func test_characters_are_valid():
	for path in PATHS:
		var def: CharacterDef = load(path)
		assert_ne(def.id, "", "%s has an id" % path)
		assert_gt(def.moves.size(), 0)
		var ids := {}
		for move in def.moves:
			var where := "%s/%s" % [def.id, move.id]
			assert_false(ids.has(move.id), "%s: duplicate move id" % where)
			ids[move.id] = true
			assert_gt(move.startup, 0, where)
			assert_gt(move.active, 0, "%s: needs at least 1 active frame" % where)
			assert_gte(move.recovery, 0, where)
			assert_gt(move.hitbox_width, 0, where)
			assert_gt(move.hitbox_height, 0, where)
			assert_gt(move.get_command().buttons, 0, "%s: command '%s' has a button" % [where, move.command])
			for target in move.cancels_into:
				assert_gte(def.find_move(target), 0, "%s cancels into missing move '%s'" % [where, target])
