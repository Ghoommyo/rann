## One frame of input for one player, packed into a single int.
##
## 💡 Each direction and button is one bit. One small int per player per
## frame is cheap to store in the input buffer, cheap to send over the network
## (Phase 4) and easy to compare.
##
## Directions are stored as absolute screen directions (LEFT/RIGHT).
## to_numpad() converts them to forward/back relative to the way the fighter faces.
class_name InputFrame

const UP := 1 << 0
const DOWN := 1 << 1
const LEFT := 1 << 2
const RIGHT := 1 << 3
const LP := 1 << 4  # left punch
const RP := 1 << 5  # right punch
const LK := 1 << 6  # left kick
const RK := 1 << 7  # right kick

const DIRECTIONS := UP | DOWN | LEFT | RIGHT
const BUTTONS := LP | RP | LK | RK


## Builds an input int from held directions/buttons.
## Opposite directions held together cancel out ("SOCD cleaning"), so
## left+right = neutral and up+down = neutral. This blocks a classic exploit
## on keyboards and touch screens.
static func pack(up: bool, down: bool, left: bool, right: bool,
		lp := false, rp := false, lk := false, rk := false) -> int:
	var bits := 0
	if up != down:
		bits |= UP if up else DOWN
	if left != right:
		bits |= LEFT if left else RIGHT
	if lp: bits |= LP
	if rp: bits |= RP
	if lk: bits |= LK
	if rk: bits |= RK
	return bits


static func has(bits: int, flag: int) -> bool:
	return (bits & flag) != 0


## Converts the directions in `bits` to numpad notation, relative to `facing`
## (+1 = facing right, -1 = facing left):
##
##     7 8 9      ↖ ↑ ↗
##     4 5 6  =   ← · →     (6 is always "forward", towards the opponent)
##     1 2 3      ↙ ↓ ↘
static func to_numpad(bits: int, facing: int) -> int:
	var x := 0
	if has(bits, RIGHT):
		x = 1
	elif has(bits, LEFT):
		x = -1
	x *= facing  # now +1 = forward, -1 = back

	var y := 0
	if has(bits, UP):
		y = 1
	elif has(bits, DOWN):
		y = -1

	return 5 + x + y * 3
