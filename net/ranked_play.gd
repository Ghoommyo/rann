## Ranked online play: registers each online match with the server and
## reports who won, so both players' ratings change (see server/).
##
##  - A match is ranked only when both players are logged in.
##  - The host opens it on the server and sends its id to the other player
##    (RANKED message), who joins it. Rematches are new ranked matches.
##  - Both report the winner once the result can no longer be rolled back.
##    If the opponent leaves early, the player who stayed reports a win
##    (leaving a ranked match counts as a loss).
class_name RankedPlay
extends RefCounted

## Reports still being sent, kept alive here so leaving the fight screen
## (which drops the RankedPlay) doesn't cut them off.
static var _sending: Array[RankedPlay] = []

## Shown on the fight HUD, e.g. "Ranked" or "Ranked · rating +12".
var status_text := ""
var enabled := false

var _is_host := false
var _match_number := -1
var _match_id := ""
var _reported := false
var _offers := {}  # match number → server match id, from the host
var _send: Callable


## `send` sends a message to the other player: send.call(type, payload).
func _init(is_host: bool, opponent_name: String, send: Callable) -> void:
	_is_host = is_host
	_send = send
	enabled = Account.is_logged_in() and opponent_name != ""
	if not Account.is_logged_in():
		status_text = "Unranked (log in to play ranked)"
	elif opponent_name == "":
		status_text = "Unranked (your opponent isn't logged in)"


## A new match (first one or rematch) starts.
func begin(match_number: int, p1_character: String, p2_character: String, opponent_name: String) -> void:
	if not enabled:
		return
	_match_number = match_number
	_match_id = ""
	_reported = false
	status_text = "Ranked"
	if _is_host:
		var result: Dictionary = await Account.call_api(HTTPClient.METHOD_POST, "/matches",
			{"opponent": opponent_name, "my_character": p1_character, "opponent_character": p2_character})
		if match_number != _match_number:
			return  # a rematch started meanwhile
		if result.ok:
			_match_id = str(result.data.get("match_id", ""))
			_send.call(NetMessages.Type.RANKED, [match_number, _match_id])
		else:
			status_text = "Unranked (%s)" % result.message
	elif _offers.has(match_number):
		_join(_offers[match_number])


## The host's RANKED message: [match number, server match id].
func on_message(msg: Array) -> void:
	if not enabled or _is_host or msg.size() < 3 or not msg[1] is int or not msg[2] is String:
		return
	_offers[msg[1]] = msg[2]
	if msg[1] == _match_number and _match_id == "":
		_join(msg[2])


func _join(id: String) -> void:
	var number := _match_number
	var result: Dictionary = await Account.call_api(HTTPClient.METHOD_POST, "/matches/%s/join" % id.uri_encode())
	if number != _match_number:
		return
	if result.ok:
		_match_id = id
	else:
		status_text = "Unranked (%s)" % result.message


## The final result: `winner` is 0 (P1), 1 (P2) or -1 (draw).
func report(winner: int) -> void:
	if not enabled or _reported or _match_id == "":
		return
	_reported = true
	_sending.append(self)
	await _send_report(winner)
	_sending.erase(self)


func _send_report(winner: int) -> void:
	var id := _match_id
	var number := _match_number
	var result: Dictionary = await Account.call_api(HTTPClient.METHOD_POST, "/matches/%s/result" % id.uri_encode(),
		{"result": ["p1", "p2"][winner] if winner >= 0 else "draw"})
	if not result.ok:
		if number == _match_number:
			status_text = "Couldn't send the result (%s)" % result.message
		return
	# The result counts once both players have reported, so the first
	# reporter waits a little for the other.
	for _attempt in 6:
		if number != _match_number:
			return
		if result.data.get("status") != "pending":
			break
		await Engine.get_main_loop().create_timer(2.0).timeout
		var update: Dictionary = await Account.call_api(HTTPClient.METHOD_GET, "/matches/%s" % id.uri_encode())
		if update.ok:
			result = update
	if number == _match_number:
		status_text = describe(result.data)
	if result.data.get("status") == "confirmed":
		Account.refresh_profile()


## What to show for a match the server answered about.
static func describe(match_data: Dictionary) -> String:
	match str(match_data.get("status", "")):
		"confirmed":
			var change := int(match_data.get("rating_change", 0))
			return "Ranked · rating %s%d" % ["+" if change >= 0 else "", change]
		"disputed":
			return "Ranked · the results didn't match, so ratings are unchanged"
		"pending":
			return "Ranked · result sent; your rating updates when your opponent's result arrives"
	return "Ranked"
