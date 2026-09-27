extends Node2D
## 自機。全方向移動し、移動した軌跡を履歴バッファに記録する（オプションの追従目標）。

const RADIUS := 26.0
const HISTORY_SIZE := 1024
const MIN_RECORD_DIST := 0.5   # これ未満しか動かなかったフレームは履歴に積まない

var input_vector := Vector2.ZERO   # スティック / キーボード入力 (長さ 0..1)
var drag_delta := Vector2.ZERO     # 相対ドラッグの今フレームの移動量 (px)
var velocity := Vector2.ZERO       # 実際の移動速度 (px/s)
var movement_energy := 0.0         # 直近の移動量 0..~1.5（オプションのノイズ強度に使う）
var external_control := false      # true: 位置はゲーム側が直接動かす（HULA HOOP モード）

var _history := PackedVector2Array()
var _head := 0
var _bank := 0.0
var _last_pos := Vector2.ZERO


func _ready() -> void:
	_last_pos = position
	reset_history()


## 自機の下方向に一直線の履歴を作り、開始時からオプションが隊列を組むようにする。
func reset_history() -> void:
	_history.resize(HISTORY_SIZE)
	_head = 0
	for age in HISTORY_SIZE:
		_history[posmod(_head - age, HISTORY_SIZE)] = position + Vector2(0, minf(age * 6.0, 900.0))


## frames フレーム前（移動したフレームのみカウント）の位置。小数は線形補間。
func get_past_position(frames: float) -> Vector2:
	frames = clampf(frames, 0.0, HISTORY_SIZE - 2)
	var f0 := int(floor(frames))
	var t := frames - f0
	var a := _history[posmod(_head - f0, HISTORY_SIZE)]
	var b := _history[posmod(_head - f0 - 1, HISTORY_SIZE)]
	return a.lerp(b, t)


func _physics_process(delta: float) -> void:
	var prev := position
	if external_control:
		prev = _last_pos
	elif Tuning.i("control_mode") == 1:
		position += drag_delta * Tuning.v("drag_sensitivity")
	else:
		var target_vel := input_vector.limit_length(1.0) * Tuning.v("player_speed")
		var vel := velocity.move_toward(target_vel, Tuning.v("player_accel") * delta)
		position += vel * delta
	drag_delta = Vector2.ZERO

	var rect := get_viewport_rect()
	position = position.clamp(rect.position + Vector2.ONE * RADIUS, rect.end - Vector2.ONE * RADIUS)
	_last_pos = position

	var moved := position - prev
	velocity = moved / delta
	var ratio := clampf(velocity.length() / maxf(Tuning.v("player_speed"), 1.0), 0.0, 1.5)
	movement_energy = lerpf(movement_energy, ratio, 1.0 - exp(-6.0 * delta))

	if moved.length() >= MIN_RECORD_DIST:
		_head = (_head + 1) % HISTORY_SIZE
		_history[_head] = position

	_bank = lerpf(_bank, clampf(velocity.x / 900.0, -1.0, 1.0), 1.0 - exp(-10.0 * delta))
	queue_redraw()


func _draw() -> void:
	var w := 22.0 * (1.0 - absf(_bank) * 0.35)
	var hull := PackedVector2Array([
		Vector2(0, -34), Vector2(w, 20), Vector2(0, 10), Vector2(-w, 20),
	])
	# 噴射炎
	var flame := 10.0 + 8.0 * movement_energy + randf() * 5.0
	draw_colored_polygon(PackedVector2Array([Vector2(-7, 14), Vector2(7, 14), Vector2(0, 14 + flame)]), Color(1.0, 0.6, 0.2, 0.9))
	draw_colored_polygon(hull, Color(0.37, 0.9, 1.0))
	draw_polyline(hull + PackedVector2Array([hull[0]]), Color(0.85, 1.0, 1.0), 2.0, true)
	draw_circle(Vector2(0, -6), 5.0, Color(0.1, 0.2, 0.4))
