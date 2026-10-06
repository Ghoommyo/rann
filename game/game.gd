## Global game flow: which mode and characters the next fight uses, and
## moving between screens. Registered as the "Game" autoload, so any scene
## can reach it as `Game`.
##
## 💡 An autoload is a node Godot creates once at startup and keeps alive
## across scene changes, which makes it a good place for settings that the
## menus choose and the fight scene reads, and for the online connection.
extends Node

enum Mode { VERSUS_CPU, LOCAL_VERSUS, TRAINING, ONLINE }

## Bump when gameplay changes. Online players must have the same version.
const GAME_VERSION := "0.4.0"

const MAIN_MENU := "res://ui/menus/main_menu.tscn"
const CHARACTER_SELECT := "res://ui/menus/character_select.tscn"
const ONLINE_LOBBY := "res://ui/menus/online_lobby.tscn"
const FIGHT := "res://scenes/fight.tscn"

var mode := Mode.VERSUS_CPU
var p1_id := "kael"
var p2_id := "mira"
var cpu_level: int = CpuOpponent.Level.NORMAL

## The connection to the other player in online mode.
var online: OnlineConnection

## Command-line options for testing online play without menus, e.g.
##   godot --path . -- --net-host --net-bot --net-frames=1800
##   godot --path . -- --net-join=127.0.0.1 --net-lag=120 --net-bot --net-frames=1800
var cli := {"host": false, "join": "", "lag": 0, "bot": false, "frames": 0, "character": "", "delay": 2}

var _data_hash := ""


func _ready() -> void:
	InputRouter.register_default_actions()
	_parse_command_line()
	if cli.host or cli.join != "":
		mode = Mode.ONLINE
		p1_id = cli.character if cli.character != "" else ("kael" if cli.host else "mira")
		_change_scene.call_deferred(ONLINE_LOBBY)


func _exit_tree() -> void:
	close_online()


## Fingerprint of all gameplay data (computed once).
func data_hash() -> String:
	if _data_hash == "":
		_data_hash = DataHash.compute()
	return _data_hash


func go_to_main_menu() -> void:
	close_online()
	_change_scene(MAIN_MENU)


func go_to_character_select(new_mode: Mode) -> void:
	mode = new_mode
	close_online()
	_change_scene(CHARACTER_SELECT)


func go_to_online_lobby() -> void:
	close_online()
	_change_scene(ONLINE_LOBBY)


func start_fight() -> void:
	_change_scene(FIGHT)


func close_online() -> void:
	if online:
		online.close()
		online = null


func mode_name() -> String:
	return ["VERSUS CPU", "LOCAL VERSUS", "TRAINING", "ONLINE"][mode]


func _change_scene(path: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(path)


func _parse_command_line() -> void:
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		var key := parts[0]
		var value := parts[1] if parts.size() > 1 else ""
		match key:
			"net-host": cli.host = true
			"net-join": cli.join = value
			"net-lag": cli.lag = int(value)
			"net-bot": cli.bot = true
			"net-frames": cli.frames = int(value)
			"net-char": cli.character = value
			"net-delay": cli.delay = int(value)
