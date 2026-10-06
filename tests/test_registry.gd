extends GutTest


func test_finds_roster():
	var ids := CharacterRegistry.all().map(func(d): return d.id)
	assert_has(ids, "kael")
	assert_has(ids, "mira")
	assert_does_not_have(ids, "dummy", "test fixture is not playable")


func test_lookup_by_id():
	assert_eq(CharacterRegistry.get_def("mira").display_name, "Mira")
	assert_null(CharacterRegistry.get_def("nobody"))


func test_ids_are_unique():
	var seen := {}
	for def in CharacterRegistry.all():
		assert_false(seen.has(def.id), "duplicate id %s" % def.id)
		seen[def.id] = true
