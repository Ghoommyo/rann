## Shared helpers for tests: build a match without any scene or views.
class_name TestHelpers


## Two default (dummy) characters, as a typed array MatchSim accepts.
static func default_defs() -> Array[CharacterDef]:
	var d := CharacterDef.new()
	d.id = "dummy"
	var defs: Array[CharacterDef] = [d, d]
	return defs


## Runs `frames` ticks with the same inputs every tick.
static func run(state: FightState, defs: Array[CharacterDef], frames: int, in1 := 0, in2 := 0) -> void:
	for i in frames:
		MatchSim.step(state, defs, in1, in2)
