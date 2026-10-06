## Base class for one pluggable fight-style mechanic (stances, meter, parry, …).
##
## 💡 A character's unique mechanics are built from these small pieces instead
## of a custom script per character (plans/00-architecture.md, Rule 4). Two
## characters with stances share StanceComponent and only differ in its settings.
##
## ⚠️ Rules for every component (they keep rollback netcode working):
##  - The component itself is shared data (both fighters may use the same
##    resource). NEVER store match state in the component's own variables.
##  - Store per-fighter state in `f.style_data`, as ints only, with keys
##    prefixed by the component name (e.g. "meter.value").
##  - No floats, no randomness, no timers, no scene nodes.
##
## The engine calls these hooks at fixed points each tick. Override only the
## ones you need; the defaults do nothing.
class_name StyleComponent
extends Resource


## Round start: put this component's starting values into f.style_data.
func init_state(_f: FighterState) -> void:
	pass


## Every tick, before the fighter picks its action. Count timers and read inputs here.
func on_tick(_f: FighterState) -> void:
	pass


## May the fighter start this move right now? Return false to block it
## (wrong stance, not enough meter, not charged, …).
func can_use_move(_f: FighterState, _move: MoveDef) -> bool:
	return true


## The fighter just started `move`.
func on_move_started(_f: FighterState, _move: MoveDef) -> void:
	pass


## The fighter's `move` hit (blocked = false) or was blocked (blocked = true).
func on_contact(_f: FighterState, _move: MoveDef, _blocked: bool) -> void:
	pass


## The fighter just got hit by `move` (including throws).
func on_hit_received(_f: FighterState, _move: MoveDef) -> void:
	pass


## Called right before `move` would hit or be blocked by this fighter.
## Return true to parry it instead (see Combat for what a parry does).
func try_parry(_f: FighterState, _move: MoveDef) -> bool:
	return false


## Values for the HUD (view only). Each entry is either
## {"label": "RAGE", "value": 500, "max": 1000} for a bar, or
## {"label": "STANCE", "text": "Crane"} for text.
func hud_values(_f: FighterState) -> Array[Dictionary]:
	return []


# --- Helpers for subclasses ---

## True when the fighter is free to act on the ground (not attacking or stunned).
static func is_free(f: FighterState) -> bool:
	match f.state:
		FighterState.State.IDLE, FighterState.State.WALK_FORWARD, \
		FighterState.State.WALK_BACK, FighterState.State.CROUCH:
			return true
	return false


## The numpad direction held `frames_ago` frames back (see InputFrame.to_numpad).
static func direction(f: FighterState, frames_ago := 0) -> int:
	return InputFrame.to_numpad(f.input.get_ago(frames_ago), f.facing)
