extends Control
## タイトルメニュー。遊ぶモードを選ぶ。

const MODES := [
	{
		"title": "OPTION FOLLOW",
		"desc": "Move freely. Options trail behind you\nwith spring, drift and curl noise.\nRam enemies with your options.",
		"scene": "res://scenes/main.tscn",
		"color": Color(1.0, 0.66, 0.2),
	},
	{
		"title": "HULA HOOP",
		"desc": "Your input pushes the hoop, not the ship.\nRotate with the spin to build power.\nPush against it and the hoop drops.",
		"scene": "res://scenes/hoop.tscn",
		"color": Color(1.0, 0.35, 0.65),
	},
]


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var th := Theme.new()
	th.default_font_size = 28
	theme = th

	add_child(preload("res://scripts/starfield.gd").new())

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 48
	box.offset_right = -48
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 28)
	add_child(box)

	var title := Label.new()
	title.text = "OPTION LAB"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 72)
	box.add_child(title)

	var sub := Label.new()
	sub.text = "movement mock"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.modulate = Color(1, 1, 1, 0.6)
	box.add_child(sub)

	box.add_child(Control.new())

	for mode in MODES:
		var b := Button.new()
		b.text = mode.title
		b.custom_minimum_size = Vector2(0, 120)
		b.add_theme_font_size_override("font_size", 44)
		b.add_theme_color_override("font_color", mode.color)
		b.pressed.connect(func(): get_tree().change_scene_to_file.call_deferred(mode.scene))
		box.add_child(b)
		var d := Label.new()
		d.text = mode.desc
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		d.modulate = Color(1, 1, 1, 0.7)
		d.add_theme_font_size_override("font_size", 24)
		box.add_child(d)
