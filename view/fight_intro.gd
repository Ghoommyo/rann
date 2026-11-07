## The short intro before a fight: Player 1's fighter walks out from the back
## of the stage straight towards the camera and says their line, then Player
## 2's does the same. Then the shot cuts to the fight and the 3-2-1 countdown
## starts.
##
## 💡 View only. The fight (FightState) doesn't tick while the intro plays;
## this just works out where to draw each fighter, so online players stay in
## step: both play the same fixed-length intro.
class_name FightIntro
extends RefCounted

const WALK_FRAMES := 90
const LINE_FRAMES := 80
## Each fighter's part: walking up to the camera, then saying the line.
const PART_FRAMES := WALK_FRAMES + LINE_FRAMES
const TOTAL_FRAMES := PART_FRAMES * 2
## How far from the fight line (meters, + is towards the camera) a fighter
## starts walking (near the back wall) and where they stop to talk.
const FAR_DEPTH := -2.6
const NEAR_DEPTH := 0.6
## The camera during the intro: in front of where they stop, looking at them.
const CAMERA_POSITION := Vector3(0, 1.45, NEAR_DEPTH + 3.3)
const CAMERA_LOOK_AT := Vector3(0, 1.1, NEAR_DEPTH)

var frame := 0
var _start: Array[FighterState] = []
var _defs: Array[CharacterDef] = []


## `start` is the round's first state (the fighters' moves and styles come from it).
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


## Whether fighter `i` is on screen: only during their own part.
func on_stage(i: int, at := frame) -> bool:
	return at >= i * PART_FRAMES and at < (i + 1) * PART_FRAMES


## The fighter saying their line now, or -1 (while someone walks up).
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


## Fighter `i` as it should be drawn at frame `at`: in the middle of the
## stage, walking until they reach the camera, then standing.
func fighter(i: int, at := frame) -> FighterState:
	var f := _start[i].copy()
	f.pos_x = 0
	f.pos_y = 0
	var t := at - i * PART_FRAMES
	if t >= 0 and t < WALK_FRAMES:
		f.state = FighterState.State.WALK_FORWARD
		f.state_frame = t
	return f


## How far towards the camera fighter `i` is at frame `at` (meters).
func depth(i: int, at := frame) -> float:
	var t := clampf(float(at - i * PART_FRAMES) / WALK_FRAMES, 0.0, 1.0)
	# Slow down a little at the end, as if stopping on purpose.
	return lerpf(FAR_DEPTH, NEAR_DEPTH, 1.0 - pow(1.0 - t, 1.6))
