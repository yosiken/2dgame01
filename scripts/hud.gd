extends CanvasLayer
## スコア表示と、実行中にパラメータを調整するデバッグパネル。
## Web 版でも表示できるよう UI 文字列は英語（既定フォントに日本語グリフが無いため）。

const TITLE_SCENE := "res://scenes/title.tscn"

## タブごとのスライダー定義 [key, label, min, max, step]
## オプション追従モード用
const OPTION_TABS := {
	"Spring": [
		["spring_k", "Spring stiffness", 5.0, 300.0, 5.0],
		["damping", "Damping (1=no bounce)", 0.02, 1.5, 0.02],
		["mass", "Mass", 0.3, 5.0, 0.1],
		["mass_step", "Mass step / option", 0.0, 1.5, 0.05],
		["chain", "Chain (0=trail 1=rope)", 0.0, 1.0, 0.05],
		["chain_length", "Chain length", 20.0, 200.0, 5.0],
		["delay_frames", "Delay (frames)", 1, 30, 1],
		["option_count", "Options", 1, 8, 1],
	],
	"Car": [
		["turn_rate", "Turn rate", 0.5, 30.0, 0.5],
		["side_accel", "Side accel (0=car)", 0.0, 1.0, 0.05],
		["grip", "Grip", 0.1, 20.0, 0.1],
		["drag", "Air drag", 0.0, 4.0, 0.05],
		["max_speed", "Max speed", 300.0, 4000.0, 50.0],
	],
	"Curl": [
		["curl_strength", "Curl strength", 0.0, 8000.0, 100.0],
		["curl_scale", "Curl scale", 0.001, 0.015, 0.0005],
		["curl_speed", "Curl time speed", 0.0, 3.0, 0.1],
		["curl_idle", "Curl when idle", 0.0, 1.0, 0.05],
	],
	"Game": [
		["player_speed", "Player speed", 300.0, 1400.0, 20.0],
		["drag_sensitivity", "Drag sensitivity", 0.5, 2.5, 0.05],
		["enemy_max", "Enemy max", 0, 30, 1],
		["enemy_interval", "Enemy interval (s)", 0.1, 3.0, 0.1],
	],
}

## HULA HOOP モード用
const HOOP_TABS := {
	"Hoop": [
		["hoop_push", "Push power", 1.0, 40.0, 0.5],
		["hoop_start_boost", "Start boost x", 1.0, 8.0, 0.1],
		["hoop_reverse_angle", "Reverse zone (deg)", 90.0, 180.0, 5.0],
		["hoop_reverse_brake", "Reverse brake x", 0.0, 5.0, 0.1],
		["hoop_min_omega", "Min spin (break)", 0.0, 8.0, 0.1],
		["hoop_max_omega", "Max spin", 4.0, 40.0, 0.5],
		["hoop_sustain_decay", "Decay while spinning", 0.0, 1.0, 0.01],
		["hoop_drop_decay", "Decay after break", 0.0, 5.0, 0.1],
	],
	"Shape": [
		["hoop_radius", "Radius", 60.0, 320.0, 5.0],
		["hoop_radius_gain", "Radius gain at max", 0.0, 200.0, 5.0],
		["hoop_radial_push", "Radial wobble", 0.0, 3000.0, 50.0],
		["hoop_hip", "Hip sway", 0.0, 100.0, 2.0],
	],
	"Game": [
		["hoop_swipe_ref", "Swipe speed = 1.0", 300.0, 4000.0, 50.0],
		["hoop_enemy_speed", "Enemy speed", 0.0, 300.0, 5.0],
		["enemy_max", "Enemy max", 0, 30, 1],
		["enemy_interval", "Enemy interval (s)", 0.1, 3.0, 0.1],
	],
}

## ゲーム側が add_child 前に設定する
var tabs: Dictionary = OPTION_TABS
var show_presets := true
var mode_labels := ["Mode: STICK", "Mode: DRAG"]

var score := 0

var _score_label: Label
var _status_label: Label
var _gauge_root: Control
var _gauge_fill: ColorRect
var _gauge_label: Label
var _menu_button: Button
var _tune_button: Button
var _panel: PanelContainer
var _toggle_buttons := {}   # key -> [Button, off_text, on_text]
var _preset_button: Button
var _preset_index := 0
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

	_status_label = Label.new()
	_status_label.position = Vector2(24, 72)
	_status_label.add_theme_font_size_override("font_size", 26)
	_status_label.modulate = Color(1, 1, 1, 0.8)
	root.add_child(_status_label)

	_build_gauge(root)

	_menu_button = Button.new()
	_menu_button.text = "MENU"
	_menu_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_menu_button.offset_left = -330
	_menu_button.offset_right = -205
	_menu_button.offset_top = 20
	_menu_button.offset_bottom = 92
	_menu_button.pressed.connect(func(): get_tree().change_scene_to_file.call_deferred(TITLE_SCENE))
	root.add_child(_menu_button)

	_tune_button = Button.new()
	_tune_button.text = "DEBUG"
	_tune_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_tune_button.offset_left = -190
	_tune_button.offset_right = -20
	_tune_button.offset_top = 20
	_tune_button.offset_bottom = 92
	_tune_button.pressed.connect(func(): _panel.visible = not _panel.visible)
	root.add_child(_tune_button)

	_build_panel(root)
	Tuning.changed.connect(_sync_from_tuning)
	_sync_from_tuning()
	add_score(0)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.pressed and not event.echo and event.keycode == KEY_TAB:
		_panel.visible = not _panel.visible


func add_score(n: int) -> void:
	score += n
	_score_label.text = "SCORE %d" % score


func set_status(text: String) -> void:
	_status_label.text = text


## 画面下のゲージ。value は 0..1
func set_gauge(value: float, color: Color, text: String) -> void:
	_gauge_root.visible = true
	_gauge_fill.anchor_right = clampf(value, 0.0, 1.0)
	_gauge_fill.color = color
	_gauge_label.text = text


## UI の上に触れているか（ゲーム側のタッチ操作と取り合わないために使う）
func is_point_on_ui(pos: Vector2) -> bool:
	if _tune_button.get_global_rect().has_point(pos) or _menu_button.get_global_rect().has_point(pos):
		return true
	return _panel.visible and _panel.get_global_rect().has_point(pos)


func _make_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = 26
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.06, 0.12, 0.72)
	panel_style.set_corner_radius_all(12)
	panel_style.set_content_margin_all(12)
	th.set_stylebox("panel", "PanelContainer", panel_style)
	return th


func _build_gauge(root: Control) -> void:
	_gauge_root = Control.new()
	_gauge_root.anchor_left = 0.0
	_gauge_root.anchor_right = 1.0
	_gauge_root.anchor_top = 1.0
	_gauge_root.anchor_bottom = 1.0
	_gauge_root.offset_left = 24
	_gauge_root.offset_right = -24
	_gauge_root.offset_top = -64
	_gauge_root.offset_bottom = -40
	_gauge_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gauge_root.visible = false
	root.add_child(_gauge_root)
	var bg := ColorRect.new()
	bg.color = Color(1, 1, 1, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gauge_root.add_child(bg)
	_gauge_fill = ColorRect.new()
	_gauge_fill.anchor_bottom = 1.0
	_gauge_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gauge_root.add_child(_gauge_fill)
	_gauge_label = Label.new()
	_gauge_label.position = Vector2(0, -40)
	_gauge_root.add_child(_gauge_label)


func _build_panel(root: Control) -> void:
	# 画面の上半分だけを使い、下半分で操作しながら動きを確認できるようにする
	_panel = PanelContainer.new()
	_panel.anchor_right = 1.0
	_panel.anchor_bottom = 0.56
	_panel.offset_left = 12
	_panel.offset_right = -12
	_panel.offset_top = 104
	_panel.visible = false
	root.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_panel.add_child(vbox)

	var row1 := HBoxContainer.new()
	vbox.add_child(row1)
	if show_presets:
		_preset_button = _add_button(row1, "", _next_preset)
	_add_toggle(row1, "debug_draw", "Lines: OFF", "Lines: ON")
	_add_toggle(row1, "slow_motion", "Slow: OFF", "Slow: ON")

	var row2 := HBoxContainer.new()
	vbox.add_child(row2)
	_add_toggle(row2, "control_mode", mode_labels[0], mode_labels[1])
	_add_button(row2, "Reset", _reset)
	_add_button(row2, "Copy", _copy_values)

	var tab_box := TabContainer.new()
	tab_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(tab_box)
	for tab_name in tabs:
		var scroll := ScrollContainer.new()
		scroll.name = tab_name
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		tab_box.add_child(scroll)
		var list := VBoxContainer.new()
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_theme_constant_override("separation", 2)
		scroll.add_child(list)
		for def in tabs[tab_name]:
			_add_slider_row(list, def)


func _add_slider_row(parent: Control, def: Array) -> void:
	var key: String = def[0]
	var label := Label.new()
	parent.add_child(label)

	var row := HBoxContainer.new()
	parent.add_child(row)
	var slider := HSlider.new()
	slider.min_value = def[2]
	slider.max_value = def[3]
	slider.step = def[4]
	slider.custom_minimum_size = Vector2(0, 52)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(func(val: float):
		if not _syncing:
			Tuning.set_value(key, val))
	# 細かい調整用の −/＋ ボタン（1 ステップずつ）
	var minus := _add_button(row, "-", func(): slider.value -= slider.step)
	row.add_child(slider)
	var plus := _add_button(row, "+", func(): slider.value += slider.step)
	for b in [minus, plus]:
		b.size_flags_horizontal = Control.SIZE_FILL
		b.custom_minimum_size = Vector2(64, 52)
	_rows[key] = {"slider": slider, "label": label, "text": def[1]}


func _add_button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 60)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _add_toggle(parent: Control, key: String, off_text: String, on_text: String) -> void:
	var b := _add_button(parent, off_text, func(): Tuning.set_value(key, 1 - Tuning.i(key)))
	_toggle_buttons[key] = [b, off_text, on_text]


func _reset() -> void:
	if show_presets:
		_apply_preset(0)
	else:
		Tuning.reset_keys(_rows.keys())


func _next_preset() -> void:
	_apply_preset((_preset_index + 1) % Tuning.PRESETS.size())


func _apply_preset(idx: int) -> void:
	_preset_index = idx
	Tuning.apply_preset(Tuning.PRESETS.keys()[idx])


func _copy_values() -> void:
	var json := Tuning.to_json()
	DisplayServer.clipboard_set(json)
	print("Tuning (diff from defaults):\n", json)


func _sync_from_tuning() -> void:
	_syncing = true
	for key in _rows:
		var row: Dictionary = _rows[key]
		var val := Tuning.v(key)
		row.slider.value = val
		var fmt := "%s: %d" if row.slider.step >= 1.0 else ("%s: %.4f" if row.slider.step < 0.01 else "%s: %.2f")
		row.label.text = fmt % [row.text, val]
	_syncing = false
	for key in _toggle_buttons:
		var t: Array = _toggle_buttons[key]
		t[0].text = t[2] if Tuning.i(key) == 1 else t[1]
	if _preset_button:
		_preset_button.text = "Preset: %s" % Tuning.PRESETS.keys()[_preset_index]
