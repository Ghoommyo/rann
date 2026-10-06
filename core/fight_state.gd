## The complete state of a match. If you have this object, you can resume
## the fight from exactly this moment.
##
## 💡 Rollback netcode (Phase 4) saves a copy() of this every frame. When a
## late network input arrives, it restores an older copy and replays.
## checksum() lets two players' games prove they agree on the state.
## Every field must be copied in copy() and hashed in checksum().
class_name FightState
extends RefCounted

## Where the match is in its round flow.
enum Phase {
	READY,       # "ROUND 1 … FIGHT!", players can't act yet
	FIGHTING,
	ROUND_OVER,  # KO or time-out, short pause before the next round
	MATCH_OVER,  # someone won the match
}

## Things that happened this tick, for sounds and effects (view only).
## 💡 The sim can't play sounds itself (that's the view's job), so it leaves
## notes here. They're cleared at the start of every tick.
enum Event { HIT, BLOCK, PARRY, THROW, THROW_BREAK, KO, ROUND_START }

## Distance between the fighters when a round starts (3 m).
const START_DISTANCE := 3000

var frame := 0
var stage_left := -6000   # wall positions, sim units (a 12 m stage)
var stage_right := 6000
var fighters: Array[FighterState] = []

var phase := Phase.FIGHTING
var phase_frame := 0      # frames spent in the current phase
var round_number := 1
var wins := PackedInt32Array([0, 0])
var round_timer := Rules.ROUND_FRAMES  # frames left in the round
## Frames left in the current hitstop freeze (see MoveDef.hitstop).
var hitstop := 0
var round_winner := -1    # 0 = P1, 1 = P2, -1 = draw / none yet
var match_winner := -1
## Training mode: no timer, no KOs, health refills after each combo.
var training := false
## This tick's events: {type, fighter, x, y, amount}. Not part of the checksum,
## because they're a by-product of the state, not part of it.
var events: Array[Dictionary] = []

# The last hit or block, shown by the debug HUD. Part of the state so that
# replays and rollback show the same info.
var last_attacker := -1
var last_move_index := -1
var last_blocked := false
var last_advantage := 0


## Builds the starting state for a match between two characters.
## With `intro`, the first round starts with the READY countdown.
static func create(defs: Array[CharacterDef], intro := false, training_mode := false) -> FightState:
	var s := FightState.new()
	s.training = training_mode
	s.reset_fighters(defs)
	if intro:
		s.phase = Phase.READY
	return s


## Puts both fighters back at their start positions with full health.
func reset_fighters(defs: Array[CharacterDef]) -> void:
	fighters.clear()
	for i in 2:
		var f := FighterState.new()
		f.character_id = defs[i].id
		f.health = defs[i].max_health
		f.facing = 1 if i == 0 else -1  # P1 on the left facing right, P2 mirrored
		f.pos_x = -f.facing * START_DISTANCE / 2
		defs[i].get_style().init_state(f)
		fighters.append(f)


func set_phase(new_phase: Phase) -> void:
	phase = new_phase
	phase_frame = 0


func emit(type: Event, fighter: int, x: int, y: int, amount: int) -> void:
	events.append({"type": type, "fighter": fighter, "x": x, "y": y, "amount": amount})


func record_contact(attacker: int, move_index: int, blocked: bool, advantage: int) -> void:
	last_attacker = attacker
	last_move_index = move_index
	last_blocked = blocked
	last_advantage = advantage


func copy() -> FightState:
	var c := FightState.new()
	c.frame = frame
	c.stage_left = stage_left
	c.stage_right = stage_right
	for f in fighters:
		c.fighters.append(f.copy())
	c.phase = phase
	c.phase_frame = phase_frame
	c.round_number = round_number
	c.wins = wins.duplicate()
	c.round_timer = round_timer
	c.hitstop = hitstop
	c.round_winner = round_winner
	c.match_winner = match_winner
	c.training = training
	c.events = events.duplicate(true)
	c.last_attacker = last_attacker
	c.last_move_index = last_move_index
	c.last_blocked = last_blocked
	c.last_advantage = last_advantage
	return c


## A number that summarizes the entire state. Two games with the same
## checksum on the same frame are in sync.
func checksum() -> int:
	var h := FixedMath.HASH_SEED
	for value in [frame, stage_left, stage_right, phase, phase_frame, round_number,
			wins[0], wins[1], round_timer, hitstop, round_winner, match_winner, int(training),
			last_attacker, last_move_index, int(last_blocked), last_advantage]:
		h = FixedMath.hash_mix(h, value)
	for f in fighters:
		h = f.mix_checksum(h)
	return h
