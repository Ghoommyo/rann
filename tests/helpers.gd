## Shared helpers for tests: build a match without any scene or views.
class_name TestHelpers

const DUMMY_PATH := "res://tests/fixtures/dummy/character.tres"

# Inputs written from P1's point of view (P1 starts on the left, facing right).
const NONE := 0
const UP := InputFrame.UP
const DOWN := InputFrame.DOWN
const LEFT := InputFrame.LEFT
const RIGHT := InputFrame.RIGHT


## Two characters with no moves: for pure movement tests.
static func default_defs() -> Array[CharacterDef]:
	var d := CharacterDef.new()
	d.id = "dummy"
	var defs: Array[CharacterDef] = [d, d]
	return defs


## Two copies of the real dummy character (with its moves).
static func dummy_defs() -> Array[CharacterDef]:
	var d: CharacterDef = load(DUMMY_PATH)
	var defs: Array[CharacterDef] = [d, d]
	return defs


## Runs `frames` ticks with the same inputs every tick.
static func run(state: FightState, defs: Array[CharacterDef], frames: int, in1 := 0, in2 := 0) -> void:
	for i in frames:
		MatchSim.step(state, defs, in1, in2)


## Places the fighters `distance` apart with P2's back against the right
## wall, so P2 holding back doesn't walk away.
static func place_p2_at_wall(state: FightState, defs: Array[CharacterDef], distance: int) -> void:
	state.fighters[1].pos_x = state.stage_right - defs[1].pushbox_half_width
	state.fighters[0].pos_x = state.fighters[1].pos_x - distance
