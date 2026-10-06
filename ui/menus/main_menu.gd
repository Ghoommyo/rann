## The title screen.
## Buttons work with mouse, touch, keyboard (arrows + Enter) and gamepad.
extends Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(MenuStyle.background())

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 14)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(column)

	var title := MenuStyle.label("RANN", 110, MenuStyle.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var subtitle := MenuStyle.label("रण · the battlefield", 22)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)
	column.add_child(Control.new())  # spacer

	var vs_cpu := MenuStyle.button("Versus CPU", func(): Game.go_to_character_select(Game.Mode.VERSUS_CPU))
	column.add_child(vs_cpu)
	column.add_child(MenuStyle.button("Local Versus", func(): Game.go_to_character_select(Game.Mode.LOCAL_VERSUS)))
	column.add_child(MenuStyle.button("Training", func(): Game.go_to_character_select(Game.Mode.TRAINING)))
	column.add_child(MenuStyle.button("Online", func(): Game.go_to_character_select(Game.Mode.ONLINE)))
	if not OS.has_feature("mobile") and not OS.has_feature("web"):
		column.add_child(MenuStyle.button("Quit", func(): get_tree().quit()))

	MenuStyle.focus_later(vs_cpu)
