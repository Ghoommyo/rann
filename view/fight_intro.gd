## The short intro before a fight: Player 1's fighter walks in from the left
## and says their line, then Player 2's walks in from the right and answers.
## Then the round's 3-2-1 countdown starts.
##
## 💡 View only. The fight (FightState) doesn't tick while the intro plays;
## this just works out where to draw each fighter, so online players stay in
## step: both play the same fixed-length intro.
class_name FightIntro
extends RefCounted

const WALK_FRAMES := 70
const LINE_FRAMES := 80
## Each fighter's part: walking in, then saying the line.
const PART_FRAMES := WALK_FRAMES + LINE_FRAMES
const TOTAL_FRAMES := PART_FRAMES * 2
## How far off the start mark each fighter starts walking (sim units, 4.5 m).
const WALK_DISTANCE := 4500

var frame := 0
var _start: Array[FighterState] = []
var _defs: Array[CharacterDef] = []


## `start` is the round's first state: the fighters end up where it puts them.
func _init(start: FightState, defs: Array[CharacterDef]) -> void:
	for f in start.fighters:
		_start.append(f.copy())
	_defs = defs


func tick() -> void:
	frame += 1


func skip() -> void:
	frame = TOTAL_FRAMES


func done() -> bool:
	return frame >= TOTAL_FRAMES


## Whether fighter `i` has started walking in yet.
func on_stage(i: int, at := frame) -> bool:
	return at >= i * PART_FRAMES


## The fighter saying their line now, or -1 (while someone walks in).
func speaker() -> int:
	for i in 2:
		var t := frame - i * PART_FRAMES
		if t >= WALK_FRAMES and t < PART_FRAMES:
			return i
	return -1


## What the speaker says, e.g. "TULBUL PANDEY: Darr nahi lagta… swag lagta hai!".
func caption() -> String:
	var i := speaker()
	if i < 0:
		return ""
	var line := _defs[i].intro_line if _defs[i].intro_line != "" else "Let's fight!"
	return "%s\n“%s”" % [_defs[i].display_name.to_upper(), line]


## Fighter `i` as it should be drawn at frame `at`.
func fighter(i: int, at := frame) -> FighterState:
	var f := _start[i].copy()
	var t := at - i * PART_FRAMES
	if t < 0:
		f.pos_x -= f.facing * WALK_DISTANCE  # waiting off screen (and hidden)
	elif t < WALK_FRAMES:
		var left := 1.0 - float(t) / WALK_FRAMES
		f.pos_x -= f.facing * int(WALK_DISTANCE * left)
		f.state = FighterState.State.WALK_FORWARD
		f.state_frame = t
	return f
