## The last SIZE frames of one player's input.
##
## 💡 Fighting games remember recent inputs so that:
##  - motion inputs such as 236 (↓ ↘ →) can be read across several frames (Phase 2)
##  - a button pressed a few frames early still triggers the move ("buffering")
##
## The buffer is part of FighterState, so rollback (Phase 4) saves and restores it too.
class_name InputBuffer
extends RefCounted

const SIZE := 30  # half a second at 60 fps

var _frames := PackedInt32Array()
var _head := 0  # index of the most recent frame in _frames
## How many frames have been pushed in total. Used as a timestamp for presses.
var frame_count := 0


func _init() -> void:
	_frames.resize(SIZE)  # filled with 0 = no input


## Adds this frame's input. The oldest frame falls off the end.
func push(bits: int) -> void:
	_head = (_head + 1) % SIZE
	_frames[_head] = bits
	frame_count += 1


## Input from `frames_ago` frames back. 0 = this frame.
func get_ago(frames_ago: int) -> int:
	assert(frames_ago >= 0 and frames_ago < SIZE, "InputBuffer only remembers %d frames" % SIZE)
	return _frames[(_head - frames_ago + SIZE) % SIZE]


func latest() -> int:
	return get_ago(0)


## True only on the frame the button went down (not while it is held).
func just_pressed(flag: int) -> bool:
	return InputFrame.has(get_ago(0), flag) and not InputFrame.has(get_ago(1), flag)


func copy() -> InputBuffer:
	var c := InputBuffer.new()
	c._frames = _frames.duplicate()
	c._head = _head
	c.frame_count = frame_count
	return c


func mix_checksum(h: int) -> int:
	h = FixedMath.hash_mix(h, frame_count)
	# Hash in time order (oldest → newest) so the ring-buffer position doesn't matter.
	for i in range(SIZE - 1, -1, -1):
		h = FixedMath.hash_mix(h, get_ago(i))
	return h
