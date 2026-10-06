extends GutTest


func test_stable():
	assert_eq(DataHash.compute(), DataHash.compute())
	assert_eq(DataHash.compute().length(), 64, "sha-256 hex")


func test_changes_with_gameplay_data():
	var jab: MoveDef = CharacterRegistry.get_def("kael").moves[0]
	var before := DataHash.compute()
	jab.damage += 1
	var after := DataHash.compute()
	jab.damage -= 1
	assert_ne(before, after)
	assert_eq(DataHash.compute(), before)


func test_ignores_visual_data():
	var kael := CharacterRegistry.get_def("kael")
	var before := DataHash.compute()
	var old_color := kael.color
	kael.color = Color.HOT_PINK
	var after := DataHash.compute()
	kael.color = old_color
	assert_eq(before, after)
