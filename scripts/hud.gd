extends CanvasLayer
## スコア表示と、実行中にパラメータを調整するパネル。
## Web 版でも表示できるよう UI 文字列は英語（既定フォントに日本語グリフが無いため）。

const SLIDERS := [
	# [key, label, min, max, step]
	["option_count", "Options", 1, 8, 1],
	["delay_frames", "Delay (frames)", 2, 30, 1],
	["mass", "Mass", 0.5, 6.0, 0.1],
	["mass_step", "Mass step / option", 0.0, 1.5, 0.05],
	["follow_gain", "Follow gain", 1.0, 15.0, 0.5],
	["drive", "Drive", 4.0, 40.0, 1.0],
	["turn_rate", "Turn rate", 1.0, 30.0, 0.5],
	["side_accel", "Side accel (0=car)", 0.0, 1.0, 0.05],
	["grip", "Grip", 0.2, 20.0, 0.2],
	["drag", "Drag", 0.0, 4.0, 0.1],
	["curl_strength", "Curl strength", 0.0, 8000.0, 100.0],
	["curl_scale", "Curl scale", 0.001, 0.015, 0.0005],
	["curl_speed", "Curl time speed", 0.0, 3.0, 0.1],
	["curl_idle", "Curl when idle", 0.0, 1.0, 0.05],
	["player_speed", "Player speed", 300.0, 1400.0, 20.0],
	["drag_sensitivity", "Drag sensitivity", 0.5, 2.5, 0.05],
	["enemy_max", "Enemy max", 1, 30, 1],
	["enemy_interval", "Enemy interval (s)", 0.1, 3.0, 0.1],
]

var score := 0

var _score_label: Label
var _tune_button: Button
var _panel: PanelContainer
var _mode_button: Button
var _debug_button: Button
var _rows := {}   # key -> {"slider": HSlider, "label": Label, "text": String}
var _syncing := false


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _make_theme()
	add_child(root)

	_score_label = Label.new()
	_score_label.position = Vector2(24, 20)
	_score_label.add_theme_font_size_override("font_size", 40)
	root.add_child(_score_label)

	_tune_button = Button.new()
	_tune_button.text = "TUNE"
	_tune_button.custom_minimum_size = Vector2(150, 72)
	_tune_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_tune_button.offset_left = -170
	_tune_button.offset_right = -20
	_tune_button.offset_top = 20
	_tune_button.offset_bottom = 92
	_tune_button.pressed.connect(func(): _panel.visible = not _panel.visible)
	root.add_child(_tune_button)

	_build_panel(root)
	Tuning.changed.connect(_sync_from_tuning)
	_sync_from_tuning()
	add_score(0)


func add_score(n: int) -> void:
	score += n
	_score_label.text = "SCORE %d" % score


## UI の上に触れているか（ゲーム側のタッチ操作と取り合わないために使う）
func is_point_on_ui(pos: Vector2) -> bool:
	if _tune_button.get_global_rect().has_point(pos):
		return true
	return _panel.visible and _panel.get_global_rect().has_point(pos)


func _make_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = 26
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.06, 0.12, 0.88)
	panel_style.set_corner_radius_all(12)
	panel_style.set_content_margin_all(16)
	th.set_stylebox("panel", "PanelContainer", panel_style)
	return th


func _build_panel(root: Control) -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.offset_left = 20
	_panel.offset_right = -20
	_panel.offset_top = 110
	_panel.offset_bottom = -300   # 下部は操作用に空けておく
	_panel.visible = false
	root.add_child(_panel)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(vbox)

	var buttons := HBoxContainer.new()
	vbox.add_child(buttons)
	_mode_button = _add_button(buttons, "", func():
		Tuning.set_value("control_mode", 1 - Tuning.i("control_mode")))
	_debug_button = _add_button(buttons, "", func():
		Tuning.set_value("debug_draw", 1 - Tuning.i("debug_draw")))
	_add_button(buttons, "Reset", func(): Tuning.reset())

	for def in SLIDERS:
		var label := Label.new()
		vbox.add_child(label)
		var slider := HSlider.new()
		slider.min_value = def[2]
		slider.max_value = def[3]
		slider.step = def[4]
		slider.custom_minimum_size = Vector2(0, 44)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var key: String = def[0]
		slider.value_changed.connect(func(val: float):
			if not _syncing:
				Tuning.set_value(key, val))
		vbox.add_child(slider)
		_rows[key] = {"slider": slider, "label": label, "text": def[1]}


func _add_button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 64)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _sync_from_tuning() -> void:
	_syncing = true
	for key in _rows:
		var row: Dictionary = _rows[key]
		var val := Tuning.v(key)
		row.slider.value = val
		var fmt := "%s: %d" if row.slider.step >= 1.0 else ("%s: %.4f" if row.slider.step < 0.01 else "%s: %.2f")
		row.label.text = fmt % [row.text, val]
	_syncing = false
	_mode_button.text = "Mode: DRAG" if Tuning.i("control_mode") == 1 else "Mode: STICK"
	_debug_button.text = "Debug: ON" if Tuning.i("debug_draw") == 1 else "Debug: OFF"
