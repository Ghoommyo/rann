## The first screen: logs back in with the saved session, then goes to the
## main menu, or to the login screen for a new player.
extends Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(MenuStyle.background())
	var title := MenuStyle.label("RANN", 110, MenuStyle.ACCENT)
	title.set_anchors_preset(Control.PRESET_CENTER)
	title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	title.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(title)

	if Game.started_from_cli():
		return  # Game is already heading to the online lobby
	if Account.has_saved_session():
		var status := MenuStyle.label("Logging in…", 22)
		status.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		status.grow_horizontal = Control.GROW_DIRECTION_BOTH
		status.offset_top = -80
		add_child(status)
		var result: Dictionary = await Account.restore()
		if not result.ok and result.error == "network":
			Game.notice = "Couldn't reach the server, so you're playing offline."
		Game.go_to_main_menu.call_deferred()
	elif Account.guest:
		Game.go_to_main_menu.call_deferred()
	else:
		Game.go_to.call_deferred(Game.LOGIN)
