## Integer-only math helpers for the deterministic simulation.
##
## 💡 The simulation never uses floats (plans/00-architecture.md, Rule 3).
## Floats can round differently on different CPUs, which would make two
## players' games drift apart online. Integers are exact everywhere.
##
## Distances are stored in "milli-units": 1000 units = 1 meter.
## Speeds are units per frame (at 60 frames/second).
##
## For clamping/abs/sign use Godot's built-in integer versions:
## clampi(), absi(), signi(), mini(), maxi().
class_name FixedMath

## How many sim units make one meter in the 3D view.
const UNIT := 1000


## Interpolates between a and b by the fraction num/den, using integers only.
static func lerp_int(a: int, b: int, num: int, den: int) -> int:
	return a + ((b - a) * num) / den


## Mixes one integer into a running hash (FNV-1a style, kept to 32 bits).
## Used by checksum() functions to detect desyncs between two games.
static func hash_mix(h: int, value: int) -> int:
	return ((h ^ (value & 0xFFFFFFFF)) * 16777619) & 0xFFFFFFFF


## Starting value for hash_mix() chains.
const HASH_SEED := 2166136261


## Converts sim units to meters. Only VIEW code may call this, because it
## returns a float. The simulation itself must never use the result.
static func to_meters(value: int) -> float:
	return value / float(UNIT)
