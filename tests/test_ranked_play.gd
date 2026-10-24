## Ranked play decisions that don't need a server.
extends GutTest


func test_guests_play_unranked():
	Account.user = {}
	var ranked := RankedPlay.new(true, "arjun", func(_t, _p): pass)
	assert_false(ranked.enabled)
	assert_string_contains(ranked.status_text, "log in")


func test_opponent_guest_means_unranked():
	Account.user = {"username": "me"}
	var ranked := RankedPlay.new(true, "", func(_t, _p): pass)
	Account.user = {}
	assert_false(ranked.enabled)
	assert_string_contains(ranked.status_text, "opponent")


func test_client_ignores_bad_ranked_messages():
	Account.user = {"username": "me"}
	var ranked := RankedPlay.new(false, "host", func(_t, _p): pass)
	Account.user = {}
	ranked.on_message([NetMessages.Type.RANKED])
	ranked.on_message([NetMessages.Type.RANKED, "x", 5])
	assert_eq(ranked._offers, {})
	ranked.on_message([NetMessages.Type.RANKED, 2, "id-2"])
	assert_eq(ranked._offers, {2: "id-2"}, "kept until match 2 starts")


func test_describe():
	assert_eq(RankedPlay.describe({"status": "confirmed", "rating_change": 12}), "Ranked · rating +12")
	assert_eq(RankedPlay.describe({"status": "confirmed", "rating_change": -9}), "Ranked · rating -9")
	assert_string_contains(RankedPlay.describe({"status": "disputed"}), "unchanged")
