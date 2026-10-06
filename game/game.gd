## Global game flow: which mode and characters the next fight uses, and
## moving between screens. Registered as the "Game" autoload, so any scene
## can reach it as `Game`.
##
## 💡 An autoload is a node Godot creates once at startup and keeps alive
## across scene changes, which makes it a good place for settings that the
## menus choose and the fight scene reads.
extends Node

enum Mode { VERSUS_CPU, LOCAL_VERSUS, TRAINING }

const MAIN_MENU := "res://ui/menus/main_menu.tscn"
const CHARACTER_SELECT := "res://ui/menus/character_select.tscn"
const FIGHT := "res://scenes/fight.tscn"

var mode := Mode.VERSUS_CPU
var p1_id := "kael"
var p2_id := "mira"
var cpu_level: int = CpuOpponent.Level.NORMAL


func _ready() -> void:
	InputRouter.register_default_actions()


func go_to_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU)


func go_to_character_select(new_mode: Mode) -> void:
	mode = new_mode
	get_tree().paused = false
	get_tree().change_scene_to_file(CHARACTER_SELECT)


func start_fight() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(FIGHT)


func mode_name() -> String:
	return ["VERSUS CPU", "LOCAL VERSUS", "TRAINING"][mode]
