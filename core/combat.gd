## Hits, blocks and throws: what happens when an attack touches the opponent.
##
## 💡 Each tick, both fighters' attacks are checked FIRST and applied AFTER.
## So if both hit on the same frame, both take damage (a "trade"), and the
## result doesn't depend on whether P1 or P2 is checked first.
class_name Combat

enum Contact { NONE, HIT, BLOCK, THROW }

const State := FighterState.State


## Checks and applies all contact for this tick.
static func resolve(state: FightState, defs: Array[CharacterDef]) -> void:
	var contacts: Array[int] = []
	for i in 2:
		contacts.append(check_contact(state.fighters[i], defs[i], state.fighters[1 - i], defs[1 - i]))

	# Two throws on the same frame cancel each other out.
	if contacts[0] == Contact.THROW and contacts[1] == Contact.THROW:
		_break_throw(state.fighters[0], state.fighters[1])
		return
	# A strike beats a throw on the same frame.
	for i in 2:
		if contacts[i] == Contact.THROW and contacts[1 - i] != Contact.NONE:
			contacts[i] = Contact.NONE

	for i in 2:
		var attacker := state.fighters[i]
		var defender := state.fighters[1 - i]
		match contacts[i]:
			Contact.HIT:
				_apply_hit(state, i, defs[i], attacker, defender)
			Contact.BLOCK:
				_apply_block(state, i, defs[i], attacker, defender)
			Contact.THROW:
				_start_throw(attacker, defender)


## What `a`'s attack would do to `d` this tick, without changing anything.
static func check_contact(a: FighterState, a_def: CharacterDef, d: FighterState, d_def: CharacterDef) -> Contact:
	if a.state != State.ATTACK or a.move_connected:
		return Contact.NONE
	var move := a_def.moves[a.move_index]
	if not move.is_active_frame(a.state_frame + 1):
		return Contact.NONE
	if not Collision.has_hurtbox(d):
		return Contact.NONE
	if not move.hitbox_of(a).intersects(Collision.hurtbox_of(d, d_def)):
		return Contact.NONE

	var crouching := Collision.is_low_posture(d, d_def)
	if move.hit_level == MoveDef.HitLevel.THROW:
		return Contact.THROW if _is_throwable(d) and not crouching else Contact.NONE
	if move.hit_level == MoveDef.HitLevel.HIGH and crouching:
		return Contact.NONE  # ducked under it

	if _can_guard(d):
		var dir := InputFrame.to_numpad(d.input.latest(), d.facing)
		if dir == 4 and move.hit_level != MoveDef.HitLevel.LOW:
			return Contact.BLOCK  # standing guard: blocks highs and mids
		if dir == 1 and move.hit_level == MoveDef.HitLevel.LOW:
			return Contact.BLOCK  # crouching guard: blocks lows
	return Contact.HIT


## Throw states: the thrown fighter can break free early, otherwise the throw lands.
## Call once per tick, after update_intent().
static func update_throws(state: FightState, defs: Array[CharacterDef]) -> void:
	for i in 2:
		var d := state.fighters[i]
		if d.state != State.THROWN:
			continue
		var a := state.fighters[1 - i]
		var move := defs[1 - i].moves[a.move_index]
		if d.state_frame < Rules.THROW_BREAK_WINDOW:
			if d.input.just_pressed(move.throw_break_mask()):
				_break_throw(a, d)
		else:
			d.health = maxi(0, d.health - move.damage)
			d.set_state(State.KNOCKDOWN)
			d.vel_x = a.facing * move.pushback
			state.hitstop = maxi(state.hitstop, move.hitstop)


static func _apply_hit(state: FightState, attacker_index: int, a_def: CharacterDef,
		a: FighterState, d: FighterState) -> void:
	var move := a_def.moves[a.move_index]
	var scale := maxi(Rules.MIN_DAMAGE_SCALE, 100 - Rules.DAMAGE_SCALE_STEP * d.combo_hits)
	d.health = maxi(0, d.health - maxi(1, move.damage * scale / 100))
	d.combo_hits += 1
	a.move_connected = true
	state.hitstop = maxi(state.hitstop, move.hitstop)

	var advantage := Rules.NO_ADVANTAGE
	if d.is_airborne() or move.on_hit == MoveDef.OnHit.LAUNCH:
		# Launched, or hit while already in the air → juggle.
		d.set_state(State.JUGGLE)
		d.vel_y = move.launch_velocity if move.on_hit == MoveDef.OnHit.LAUNCH else Rules.JUGGLE_POP
		d.vel_x = a.facing * Rules.JUGGLE_DRIFT
	elif move.on_hit == MoveDef.OnHit.KNOCKDOWN or d.health == 0:
		d.set_state(State.KNOCKDOWN)
		d.vel_x = a.facing * move.pushback
	else:
		d.set_state(State.HITSTUN)
		d.stun_frames = move.hitstun
		d.vel_x = a.facing * move.pushback
		advantage = move.hitstun - _frames_left(a, move)
	state.record_contact(attacker_index, a.move_index, false, advantage)


static func _apply_block(state: FightState, attacker_index: int, a_def: CharacterDef,
		a: FighterState, d: FighterState) -> void:
	var move := a_def.moves[a.move_index]
	a.move_connected = true
	d.set_state(State.BLOCKSTUN)
	d.stun_frames = move.blockstun
	d.crouch_guard = move.hit_level == MoveDef.HitLevel.LOW
	d.vel_x = a.facing * move.pushback
	state.hitstop = maxi(state.hitstop, move.hitstop)
	state.record_contact(attacker_index, a.move_index, true, move.blockstun - _frames_left(a, move))


static func _start_throw(a: FighterState, d: FighterState) -> void:
	a.move_connected = true
	a.set_state(State.THROWING)  # keeps move_index, so we know which throw it is
	a.vel_x = 0
	d.set_state(State.THROWN)
	d.vel_x = 0
	d.vel_y = 0


## Both fighters are pushed apart and stunned briefly.
static func _break_throw(a: FighterState, d: FighterState) -> void:
	for f in [a, d]:
		f.set_state(State.BLOCKSTUN)
		f.stun_frames = Rules.THROW_BREAK_STUN
		f.crouch_guard = false
		f.move_connected = true
	a.vel_x = -a.facing * Rules.THROW_BREAK_PUSH
	d.vel_x = a.facing * Rules.THROW_BREAK_PUSH


## Frames the attacker still needs after this one to finish the move.
static func _frames_left(a: FighterState, move: MoveDef) -> int:
	return move.total_frames() - (a.state_frame + 1)


## States in which holding back (4) or down-back (1) blocks.
static func _can_guard(d: FighterState) -> bool:
	match d.state:
		State.IDLE, State.WALK_BACK, State.CROUCH, State.BLOCKSTUN:
			return true
	return false


static func _is_throwable(d: FighterState) -> bool:
	match d.state:
		State.IDLE, State.WALK_FORWARD, State.WALK_BACK, State.JUMP_SQUAT, \
		State.LANDING, State.ATTACK:
			return true
	return false
