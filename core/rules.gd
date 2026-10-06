## Game-wide rules that are the same for every character.
##
## 💡 Per-character numbers live in CharacterDef / MoveDef. Numbers that
## define the game itself (round length, how combos scale, …) live here,
## in one place, so the whole game can be tuned without hunting through code.
## All durations are in frames (60 frames = 1 second).
class_name Rules

# --- Rounds ---
const ROUND_FRAMES := 99 * 60        # 99-second round timer
const READY_FRAMES := 90             # "ROUND 1 … FIGHT!" before control is given
const ROUND_OVER_FRAMES := 150       # pause after a KO / time-out
const WINS_TO_WIN_MATCH := 2         # best of 3

# --- Getting hit ---
## Pushback slows down by this much per frame (units/frame²).
const PUSHBACK_FRICTION := 3
## Lying on the floor after a knockdown. No hurtbox: can't be hit.
const KNOCKDOWN_FRAMES := 40
## Standing back up. Also can't be hit.
const WAKEUP_FRAMES := 20

# --- Combos ---
## 💡 Damage scaling: each extra hit in a combo does 10% less damage, down to
## 30%. Without it one long combo could take a whole health bar.
const DAMAGE_SCALE_STEP := 10
const MIN_DAMAGE_SCALE := 30
## A launched opponent falls slower than a jump, which gives time to juggle.
const JUGGLE_GRAVITY := 4
## 💡 Gravity scaling: every hit in a combo makes the juggled fighter fall
## faster (gravity + combo hits), so juggles can't go on forever.
## Each hit on a juggled fighter pops them up by this much.
const JUGGLE_POP := 45
## Sideways drift of a juggled fighter, away from the attacker.
const JUGGLE_DRIFT := 6

# --- Throws ---
## Frames the thrown fighter has to press the break button.
const THROW_BREAK_WINDOW := 20
## After a break, both fighters are pushed apart and briefly stunned.
const THROW_BREAK_STUN := 12
const THROW_BREAK_PUSH := 40

## Shown in the debug HUD when frame advantage doesn't apply (knockdowns, launches).
const NO_ADVANTAGE := 9999
