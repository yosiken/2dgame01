extends Node2D
## HULA HOOP モード。入力はオプション（輪）に力を加えるために使い、自機は画面中央で腰を振るだけ。
## 輪の回転方向に合わせて入力をぐるぐる回し続けるとパワーが溜まる。逆向きに入れると落ちる。
## 回っている間に指（左クリック）を離すと輪を投げる。溜めたパワーが大きいほど遠くまで飛んで戻ってくる。

const Player := preload("res://scripts/player.gd")
const HoopOption := preload("res://scripts/hoop_option.gd")
const Enemy := preload("res://scripts/enemy.gd")
const Explosion := preload("res://scripts/explosion.gd")
const Starfield := preload("res://scripts/starfield.gd")
const VirtualJoystick := preload("res://scripts/virtual_joystick.gd")
const Hud := preload("res://scripts/hud.gd")

var player: Node2D
var hoop: Area2D
var joystick: Node2D
var hud: CanvasLayer

var _home := Vector2.ZERO
var _enemy_layer: Node2D
var _fx_layer: Node2D
var _spawn_timer := 1.5
var _misses := 0
var _keep_time := 0.0
var _best_keep := 0.0

var _touch_index := -1
var _touch_last := Vector2.ZERO
var _swipe_accum := Vector2.ZERO
var _swipe_vec := Vector2.ZERO
var _input := Vector2.ZERO


func _ready() -> void:
	randomize()
	add_child(Starfield.new())
	_enemy_layer = Node2D.new()
	add_child(_enemy_layer)

	var size := get_viewport_rect().size
	_home = Vector2(size.x * 0.5, size.y * 0.7)

	player = Player.new()
	player.external_control = true
	player.position = _home
	add_child(player)

	hoop = HoopOption.new()
	hoop.player = player
	add_child(hoop)

	_fx_layer = Node2D.new()
	add_child(_fx_layer)

	joystick = VirtualJoystick.new()
	joystick.z_index = 50
	add_child(joystick)

	hud = Hud.new()
	hud.tabs = Hud.HOOP_TABS
	hud.show_presets = false
	hud.mode_labels = ["Input: STICK", "Input: SWIPE"]
	add_child(hud)


func _physics_process(delta: float) -> void:
	# 入力: キーボード + スティック or スワイプ（指の速度ベクトル）
	var kb := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	kb += Vector2(
		float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W)))
	var touch_vec := Vector2.ZERO
	if Tuning.i("control_mode") == 1:
		var raw := _swipe_accum / delta / maxf(Tuning.v("hoop_swipe_ref"), 1.0)
		_swipe_accum = Vector2.ZERO
		_swipe_vec = _swipe_vec.lerp(raw.limit_length(1.0), 1.0 - exp(-18.0 * delta))
		touch_vec = _swipe_vec if _touch_index != -1 else Vector2.ZERO
	else:
		touch_vec = joystick.get_vector()
	_input = (touch_vec + kb).limit_length(1.0)
	hoop.input_vector = _input

	# 自機は入力方向に腰を振る
	var hip_target := _home + _input * Tuning.v("hoop_hip")
	player.position = player.position.lerp(hip_target, 1.0 - exp(-12.0 * delta))

	# 敵の出現
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = Tuning.v("enemy_interval")
		if _enemy_layer.get_child_count() < Tuning.i("enemy_max"):
			_spawn_enemy()

	# 回し続けた時間
	if hoop.spinning:
		_keep_time += delta
		_best_keep = maxf(_best_keep, _keep_time)
	else:
		_keep_time = 0.0

	_update_hud()
	queue_redraw()


func _update_hud() -> void:
	var p: float = hoop.power()
	var col := Color(0.5, 0.5, 0.6)
	if hoop.spinning:
		col = Color(1.0, 0.66, 0.2).lerp(Color(1.0, 0.25, 0.6), p)
	# 画面は y 下向きなので角度増加（omega > 0）= 時計回り
	var state := "DROPPED"
	if hoop.is_flying():
		state = "THROWN"
	elif hoop.spinning:
		state = "SPIN CW" if hoop.omega > 0.0 else "SPIN CCW"
	hud.set_gauge(p, col, "POWER %3d%%   %s   %.1f rad/s" % [int(p * 100.0), state, absf(hoop.omega)])
	hud.set_status("KEEP %.1fs  BEST %.1fs  MISS %d" % [_keep_time, _best_keep, _misses])


func _spawn_enemy() -> void:
	# 画面の外周から出現して自機へ歩いてくる
	var rect := get_viewport_rect().grow(-40.0)
	var pos := Vector2.ZERO
	match randi() % 3:
		0: pos = Vector2(randf_range(rect.position.x, rect.end.x), rect.position.y + 120.0)
		1: pos = Vector2(rect.position.x, randf_range(rect.position.y + 120.0, rect.end.y))
		2: pos = Vector2(rect.end.x, randf_range(rect.position.y + 120.0, rect.end.y))
	var e: Area2D = Enemy.new()
	e.position = pos
	e.approach_target = player
	e.approach_speed = Tuning.v("hoop_enemy_speed") * randf_range(0.7, 1.3)
	e.destroyed.connect(_on_enemy_destroyed)
	e.reached.connect(_on_enemy_reached)
	_enemy_layer.add_child(e)


func _on_enemy_destroyed(enemy: Area2D, impact: Vector2) -> void:
	var fx: Node2D = Explosion.new()
	fx.position = enemy.position
	fx.impact = impact
	fx.color = enemy._color
	_fx_layer.add_child(fx)
	hud.add_score(1)
	Input.vibrate_handheld(20)


func _on_enemy_reached(enemy: Area2D) -> void:
	_misses += 1
	var fx: Node2D = Explosion.new()
	fx.position = enemy.position
	fx.color = Color(0.6, 0.6, 0.7)
	_fx_layer.add_child(fx)


func _unhandled_input(event: InputEvent) -> void:
	# PC 確認用: Space を離すと投げる
	if event is InputEventKey and event.keycode == KEY_SPACE and not event.pressed:
		hoop.throw()
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if _touch_index == -1 and not hud.is_point_on_ui(event.position):
				_touch_index = event.index
				_touch_last = event.position
				_swipe_vec = Vector2.ZERO
				joystick.show_visual = Tuning.i("control_mode") == 0
				joystick.press(event.position)
		elif event.index == _touch_index:
			_touch_index = -1
			joystick.release()
			hoop.throw()   # 指を離す = 投げる
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_swipe_accum += event.position - _touch_last
		_touch_last = event.position
		joystick.move(event.position)


func _draw() -> void:
	# 輪の通り道
	var r: float = hoop.radius
	var col := Color(1, 1, 1, 0.10 + 0.25 * hoop.power()) if hoop.spinning else Color(1, 1, 1, 0.06)
	if hoop.is_flying():
		col = Color(0.4, 0.9, 1.0, 0.15)
	draw_arc(player.position, r, 0.0, TAU, 96, col, 2.0, true)

	# 投げたときにまっすぐ進む距離のプレビュー（回っている間、点線）
	if not hoop.is_flying() and hoop.spinning:
		var from: Vector2 = hoop.position
		var d: Vector2 = hoop.throw_direction() * hoop.throw_distance()
		var dashes := int(d.length() / 24.0)
		for k in dashes:
			if k % 2 == 0:
				draw_line(from + d * (float(k) / dashes), from + d * (float(k + 1) / dashes), Color(0.4, 0.9, 1.0, 0.35), 3.0)

	# 入力ベクトル（緑 = 回転方向へ押している / 赤 = 逆向きで減速中）
	if _input.length() > 0.05:
		var push: float = hoop.push_amount
		var icol := Color(0.4, 1.0, 0.5) if push >= 0.0 else Color(1.0, 0.3, 0.3)
		var from := player.position
		var to := from + _input * 110.0
		draw_line(from, to, icol, 6.0, true)
		var n := _input.normalized()
		draw_colored_polygon(PackedVector2Array([to + n * 18.0, to + n.orthogonal() * 12.0, to - n.orthogonal() * 12.0]), icol)

	if Tuning.i("debug_draw") == 1:
		# 輪の位置での接線（進行方向）と、入力の接線成分
		var t: Vector2 = hoop.tangent() * signf(hoop.omega if absf(hoop.omega) > 0.01 else 1.0)
		draw_line(hoop.position, hoop.position + t * 80.0, Color(0.5, 0.7, 1.0), 3.0, true)
		draw_line(hoop.position, hoop.position + t * hoop.push_amount * 120.0, Color(1, 1, 0.3), 5.0, true)
