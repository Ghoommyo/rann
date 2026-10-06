## The complete state of a match. If you have this object, you can resume
## the fight from exactly this moment.
##
## 💡 Rollback netcode (Phase 4) saves a copy() of this every frame. When a
## late network input arrives, it restores an older copy and replays.
## checksum() lets two players' games prove they agree on the state.
class_name FightState
extends RefCounted

## Distance between the fighters when a round starts (3 m).
const START_DISTANCE := 3000

var frame := 0
var stage_left := -6000   # wall positions, sim units (a 12 m stage)
var stage_right := 6000
var fighters: Array[FighterState] = []


## Builds the starting state for a match between two characters.
static func create(defs: Array[CharacterDef]) -> FightState:
	var s := FightState.new()
	for i in 2:
		var f := FighterState.new()
		f.character_id = defs[i].id
		f.health = defs[i].max_health
		f.facing = 1 if i == 0 else -1  # P1 on the left facing right, P2 mirrored
		f.pos_x = -f.facing * START_DISTANCE / 2
		s.fighters.append(f)
	return s


func copy() -> FightState:
	var c := FightState.new()
	c.frame = frame
	c.stage_left = stage_left
	c.stage_right = stage_right
	for f in fighters:
		c.fighters.append(f.copy())
	return c


## A number that summarizes the entire state. Two games with the same
## checksum on the same frame are in sync.
func checksum() -> int:
	var h := FixedMath.HASH_SEED
	h = FixedMath.hash_mix(h, frame)
	h = FixedMath.hash_mix(h, stage_left)
	h = FixedMath.hash_mix(h, stage_right)
	for f in fighters:
		h = f.mix_checksum(h)
	return h
