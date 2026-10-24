## The logged-in player's profile: rating, rank and games played/won/lost
## (from ranked online matches), and an editable bio.
extends FormScreen

const BIO_MAX := 300
## Like chess.com and lichess: a rating whose deviation is still this high is
## shown as provisional ("1500?"). It settles after a handful of games.
const PROVISIONAL_DEVIATION := 110

var _title: Label
var _since: Label
var _stats: HBoxContainer
var _rank_hint: Label
var _bio_count: Label
var _save_bio: Button


func _ready() -> void:
	if not Account.is_logged_in():
		Game.go_to.call_deferred(Game.LOGIN)
		return
	build("PROFILE")
	_title = column.get_child(0)
	_since = add_text("", 18, Color(MenuStyle.TEXT, 0.7))

	section(12)
	_stats = HBoxContainer.new()
	_stats.add_theme_constant_override("separation", 10)
	into.add_child(_stats)
	_rank_hint = add_text("Play an online match against another logged-in player to get your first rating.", 17)

	section()
	var bio := add_text_area("bio", "Bio", "Tell other fighters about yourself")
	bio.text_changed.connect(_count_bio)
	_bio_count = add_text("", 16, Color(MenuStyle.TEXT, 0.7))
	_bio_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_save_bio = add_submit("Save bio", _save)

	section()
	add_button("Account settings", func(): Game.go_to(Game.ACCOUNT_SETTINGS))
	var back := add_link("Back", go_back)

	Account.changed.connect(_show)
	_show()
	set_value("bio", str(Account.user.get("bio", "")))
	_count_bio()
	MenuStyle.focus_later(back)
	Account.refresh_profile()  # newest rating; _show runs again when it arrives


func _show() -> void:
	if not Account.is_logged_in():
		return
	var u := Account.user
	_title.text = Account.username()
	_since.text = "Member since %s" % str(u.get("member_since", "")).left(10)
	var played := int(u.get("games_played", 0))
	var rating := "%d" % int(u.get("rating", 1500))
	if int(u.get("rating_deviation", 350)) > PROVISIONAL_DEVIATION:
		rating += "?"
	var rank: Variant = u.get("rank")
	for child in _stats.get_children():
		child.queue_free()
	_stats.add_child(_stat("RATING", rating))
	_stats.add_child(_stat("RANK", "#%d" % int(rank) if rank != null else "—"))
	_stats.add_child(_stat("PLAYED", str(played)))
	_stats.add_child(_stat("WON", str(int(u.get("wins", 0)))))
	_stats.add_child(_stat("LOST", str(int(u.get("losses", 0)))))
	_rank_hint.visible = played == 0


func _stat(caption: String, number: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0.45)
	box.set_corner_radius_all(6)
	box.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", box)
	var inner := VBoxContainer.new()
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(inner)
	for part in [MenuStyle.label(number, 32), MenuStyle.label(caption, 15, MenuStyle.ACCENT)]:
		part.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inner.add_child(part)
	return panel


func _count_bio() -> void:
	var n := value("bio").length()
	_bio_count.text = "%d / %d" % [n, BIO_MAX]
	_bio_count.add_theme_color_override("font_color", MenuStyle.ERROR if n > BIO_MAX else Color(MenuStyle.TEXT, 0.7))


func _save() -> void:
	clear_errors()
	if value("bio").length() > BIO_MAX:
		field_error("bio", "Bio can be at most %d characters." % BIO_MAX)
		return
	set_busy(true, _save_bio)
	var result: Dictionary = await Account.update_bio(value("bio"))
	if not is_inside_tree():
		return
	set_busy(false, _save_bio)
	if result.ok:
		show_status("Bio saved.", MenuStyle.SUCCESS, _save_bio)
	else:
		show_error(result, _save_bio)
