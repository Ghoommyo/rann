## Finds every playable character in data/characters/.
##
## 💡 Nothing in the game keeps a hard-coded character list. Drop a new folder
## with a character.tres into data/characters/ and it shows up in character
## select automatically. Folders starting with "_" (like _shared) are skipped.
##
## Characters are looked up by `id`, never by list position, so adding a
## fighter never changes what an existing id means (important for online play
## and replays).
class_name CharacterRegistry

const ROOT := "res://data/characters"

static var _by_id := {}
static var _ordered: Array[CharacterDef] = []


## All characters, sorted by folder name.
static func all() -> Array[CharacterDef]:
	_ensure_loaded()
	return _ordered


## The character with this id, or null.
static func get_def(id: String) -> CharacterDef:
	_ensure_loaded()
	return _by_id.get(id)


static func _ensure_loaded() -> void:
	if not _ordered.is_empty():
		return
	var folders := Array(DirAccess.get_directories_at(ROOT))
	folders.sort()
	for folder in folders:
		if folder.begins_with("_"):
			continue
		var path := "%s/%s/character.tres" % [ROOT, folder]
		# ResourceLoader.exists also works in exported games, where files are remapped.
		if not ResourceLoader.exists(path):
			push_warning("CharacterRegistry: %s has no character.tres" % folder)
			continue
		var def: CharacterDef = load(path)
		if def.id == "" or _by_id.has(def.id):
			push_error("CharacterRegistry: missing or duplicate id '%s' in %s" % [def.id, path])
			continue
		_by_id[def.id] = def
		_ordered.append(def)
