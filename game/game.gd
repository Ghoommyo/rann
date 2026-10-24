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
const GAME_VERSION := "0.6.0"

## The loading screen before every fight. It's also where an ad will go,
## so it stays up for LOADING_SECONDS even when loading is faster.
## LOADING_SKIPPABLE shows a "Skip" button once the fight has loaded.
const LOADING_SECONDS := 60.0
const LOADING_SKIPPABLE := false

const MAIN_MENU := "res://ui/menus/main_menu.tscn"
const CHARACTER_SELECT := "res://ui/menus/character_select.tscn"
const ONLINE_LOBBY := "res://ui/menus/online_lobby.tscn"
const FIGHT := "res://scenes/fight.tscn"
const LOADING := "res://ui/menus/loading_screen.tscn"
const LOGIN := "res://ui/menus/login.tscn"
const SIGNUP := "res://ui/menus/signup.tscn"
const FORGOT_PASSWORD := "res://ui/menus/forgot_password.tscn"
const PROFILE := "res://ui/menus/profile.tscn"
const ACCOUNT_SETTINGS := "res://ui/menus/account_settings.tscn"
const SETTINGS := "res://ui/menus/settings_menu.tscn"

var mode := Mode.VERSUS_CPU
var p1_id := "kael"
var p2_id := "mira"
## Versus CPU difficulty, 0..10 (remembered in Settings).
var cpu_level: int = CpuOpponent.Level.NORMAL

## A one-off message for the next screen to show (e.g. "Password changed").
var notice := ""

## The connection to the other player in online mode.
var online: OnlineConnection

## Command-line options for testing online play without menus, e.g.
##   godot --path . -- --net-host --net-bot --net-frames=1800
##   godot --path . -- --net-join=127.0.0.1 --net-lag=120 --net-bot --net-frames=1800
## --loading=SECONDS changes how long the loading screen stays (e.g. 0).
var cli := {"host": false, "join": "", "lag": 0, "bot": false, "frames": 0, "character": "", "delay": 2,
	"loading": -1.0}

var _data_hash := ""


func _ready() -> void:
	cpu_level = Settings.cpu_level
	InputRouter.register_default_actions()
	_parse_command_line()
	if started_from_cli():
		mode = Mode.ONLINE
		p1_id = cli.character if cli.character != "" else ("kael" if cli.host else "mira")
		if Account.has_saved_session():
			await Account.restore()  # log in first, so the match can be ranked
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


## Opens a menu screen, e.g. `Game.go_to(Game.LOGIN)`.
func go_to(scene: String) -> void:
	close_online()
	_change_scene(scene)


## Whether the game was started from the command line straight into online play.
func started_from_cli() -> bool:
	return cli.host or cli.join != ""


func go_to_character_select(new_mode: Mode) -> void:
	mode = new_mode
	close_online()
	_change_scene(CHARACTER_SELECT)


func go_to_online_lobby() -> void:
	close_online()
	_change_scene(ONLINE_LOBBY)


## Goes to the fight, through the loading screen.
func start_fight() -> void:
	_change_scene(LOADING)


## How long the loading screen stays up.
func loading_seconds() -> float:
	return cli.loading if cli.loading >= 0.0 else LOADING_SECONDS


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
			"loading": cli.loading = maxf(float(value), 0.0)
