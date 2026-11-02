## Which fighters players can pick. The admin opens and locks them in the
## admin portal; the game downloads the list (GET /roster) and keeps the last
## one it got, so it also works offline.
extends Node

signal changed

## Open on a first launch that has never reached the server.
const DEFAULT_UNLOCKED: Array[String] = ["kael", "mira"]
const DEFAULT_PATH := "user://roster.cfg"

var unlocked: Array[String] = DEFAULT_UNLOCKED.duplicate()
var _path := DEFAULT_PATH
var _refreshing := false


func _ready() -> void:
	load_cache()


## Unknown and new fighters are locked until the admin opens them.
func is_unlocked(id: String) -> bool:
	return id in unlocked


## Reads the last downloaded list. `path` is for tests.
func load_cache(path := DEFAULT_PATH) -> void:
	_path = path
	var cfg := ConfigFile.new()
	unlocked = DEFAULT_UNLOCKED.duplicate()
	if cfg.load(_path) == OK:
		var saved: Array = cfg.get_value("roster", "unlocked", [])
		unlocked.assign(saved.map(func(id): return str(id)))


## Downloads the list in the background; emits `changed` if it's different.
## Without a connection the cached list stays.
func refresh() -> void:
	if _refreshing:
		return
	_refreshing = true
	var result: Dictionary = await Api.send(HTTPClient.METHOD_GET, "/roster")
	_refreshing = false
	if result.ok and result.data is Dictionary and result.data.get("unlocked") is Array:
		var ids: Array[String] = []
		ids.assign((result.data.unlocked as Array).map(func(id): return str(id)))
		set_unlocked(ids)


func set_unlocked(ids: Array[String]) -> void:
	if ids == unlocked:
		return
	unlocked = ids
	var cfg := ConfigFile.new()
	cfg.set_value("roster", "unlocked", unlocked)
	cfg.save(_path)
	changed.emit()
