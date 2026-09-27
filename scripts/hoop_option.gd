extends Area2D
## HULA HOOP モードのオプション（1 個）。自機のまわりを円運動する。
##  - 入力ベクトルのうち「いま回っている向き（接線）」の成分だけが回転パワーになる
##  - 同じ向きに入力 → 加速、逆向きに入力 → 減速（hoop_reverse_brake 倍で効く）
##  - 円運動が続いている間（|ω| >= hoop_min_omega）はパワーを維持する
##  - 途切れると輪が落ちる（半径が縮み、hoop_drop_decay で止まっていく）
## 回っている間に手を離すと（throw）、軌道を外れて飛んでいき、弧を描いて戻ってくる（ブーメラン）。
##  - OUT: 投げた方向へ hoop_throw_time 秒まっすぐ進む。速さ（= 飛距離）は溜めたパワーで決まる
##  - RETURN: 自機の方へ少しずつ曲がりながら戻り、輪の軌道に触れたらキャッチして円運動に戻る
## 回っている間と飛んでいる間は敵を破壊できる。

const RADIUS := 22.0
const TRAIL_LEN := 18

var player: Node2D
var input_vector := Vector2.ZERO   # 0..1

var angle := PI * 0.5              # 自機から見た角度 (rad)
var omega := 0.0                   # 角速度 (rad/s)。符号 = 回転方向
var radius := 90.0                 # 現在の半径 (px)
var radius_vel := 0.0
var spinning := false              # 円運動が続いているか
var push_amount := 0.0             # 今フレームの接線方向入力（+ 加速 / - 減速）。表示用

enum State { ORBIT, OUT, RETURN }
var state := State.ORBIT
var fly_vel := Vector2.ZERO        # 飛行中の速度 (px/s)
var _fly_t := 0.0
var _saved_omega := 0.0            # 投げたときの角速度（キャッチ時に戻す）
var _last_input_dir := Vector2.ZERO

var _trail: Array[Vector2] = []
var _pulse := 0.0


func _ready() -> void:
	var shape := CircleShape2D.new()
	shape.radius = RADIUS
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)
	collision_layer = 1 << 1   # layer 2: options
	collision_mask = 1 << 2    # layer 3: enemies
	monitoring = true
	monitorable = false
	area_entered.connect(_on_area_entered)
	radius = Tuning.v("hoop_radius") * 0.55


## 0..1 のパワー
func power() -> float:
	return clampf(absf(omega) / maxf(Tuning.v("hoop_max_omega"), 0.01), 0.0, 1.0)


## 角度が増える向きの接線（omega > 0 なら進行方向）。
## 注意: Vector2.orthogonal() は -90° 回転なので使わない
func tangent() -> Vector2:
	return Vector2.from_angle(angle + PI * 0.5)


func speed() -> float:
	return absf(omega) * radius


func is_flying() -> bool:
	return state != State.ORBIT


## 投げる方向（進行方向の接線と、直前の入力方向を hoop_throw_aim でブレンド）
func throw_direction() -> Vector2:
	var along := tangent() * signf(omega)
	if _last_input_dir == Vector2.ZERO:
		return along
	return along.slerp(_last_input_dir, Tuning.v("hoop_throw_aim")).normalized()


func throw_speed() -> float:
	return lerpf(Tuning.v("hoop_throw_speed_min"), Tuning.v("hoop_throw_speed_max"), power())


## まっすぐ進む距離（プレビュー用）
func throw_distance() -> float:
	return throw_speed() * Tuning.v("hoop_throw_time")


## 手を離したときに呼ぶ。回っていなければ投げられない
func throw() -> bool:
	if state != State.ORBIT or not spinning:
		return false
	fly_vel = throw_direction() * throw_speed()
	_saved_omega = omega * (1.0 - Tuning.v("hoop_throw_cost"))
	state = State.OUT
	_fly_t = 0.0
	_pulse = 1.0
	return true


func _physics_process(delta: float) -> void:
	if player == null:
		return
	if input_vector.length() > 0.3:
		_last_input_dir = input_vector.normalized()
	if state == State.ORBIT:
		_orbit_process(delta)
	else:
		_flight_process(delta)
	_trail.push_front(position)
	if _trail.size() > TRAIL_LEN:
		_trail.pop_back()
	_pulse = maxf(_pulse - delta * 3.0, 0.0)
	queue_redraw()


func _flight_process(delta: float) -> void:
	_fly_t += delta
	if state == State.OUT:
		position += fly_vel * delta
		_bounce_on_screen_edges()
		if _fly_t >= Tuning.v("hoop_throw_time"):
			state = State.RETURN
			_fly_t = 0.0
		return

	# RETURN: 自機の方向へ有限の旋回速度で曲がる（時間とともに旋回を強めて必ず戻る）
	var to_player := player.position - position
	var turn := Tuning.v("hoop_return_turn") * (1.0 + _fly_t * 2.0) * delta
	var diff := wrapf(to_player.angle() - fly_vel.angle(), -PI, PI)
	fly_vel = fly_vel.rotated(clampf(diff, -turn, turn))
	# 折り返し地点で減速してから戻る（ブーメランらしさ・行き過ぎ防止）
	var spd := move_toward(fly_vel.length(), Tuning.v("hoop_return_speed"), 4500.0 * delta)
	fly_vel = fly_vel.normalized() * spd
	position += fly_vel * delta
	_bounce_on_screen_edges()

	var catch_r := Tuning.v("hoop_radius") + Tuning.v("hoop_radius_gain") * power() + 12.0
	if to_player.length() <= catch_r or _fly_t > 4.0:
		_catch()


## 画面の端で跳ね返る（輪を見失わないように）
func _bounce_on_screen_edges() -> void:
	var rect := get_viewport_rect().grow(-RADIUS)
	if position.x < rect.position.x or position.x > rect.end.x:
		fly_vel.x = -fly_vel.x
		_pulse = 0.6
	if position.y < rect.position.y or position.y > rect.end.y:
		fly_vel.y = -fly_vel.y
		_pulse = 0.6
	position = position.clamp(rect.position, rect.end)


## 軌道に戻る。回転方向は投げる前と同じにし（入力を回す向きを変えずに続けられる）、
## 投げたときのパワー（hoop_throw_cost 分を引いたもの）を引き継ぐ
func _catch() -> void:
	var rel := position - player.position
	angle = rel.angle()
	radius = maxf(rel.length(), RADIUS * 2.0)
	radius_vel = 0.0
	omega = _saved_omega
	spinning = absf(omega) >= Tuning.v("hoop_min_omega")
	state = State.ORBIT
	_pulse = 1.0


func _orbit_process(delta: float) -> void:
	var t := tangent()
	var outward := Vector2.from_angle(angle)

	# 1) 接線方向の入力で角速度を変える
	#    along = 入力の「進行方向」成分。進行方向から hoop_reverse_angle 度以上ずれた入力だけが逆入力（減速）
	var u_t := input_vector.dot(t)
	var dir := signf(omega) if absf(omega) > 0.01 else 0.0
	var along := u_t * dir
	# 逆入力のしきい値: cos(reverse_angle) × 入力の強さ（120° なら -0.5）
	var reverse_threshold := cos(deg_to_rad(Tuning.v("hoop_reverse_angle"))) * input_vector.length()
	var d_omega := 0.0
	if not spinning:
		# 落ちている輪は軽く回し始められる（向きは自由）
		d_omega = u_t * Tuning.v("hoop_push") * Tuning.v("hoop_start_boost")
	elif along > 0.0:
		d_omega = along * dir * Tuning.v("hoop_push")
	elif along < reverse_threshold:
		d_omega = along * dir * Tuning.v("hoop_push") * Tuning.v("hoop_reverse_brake")
	push_amount = along if spinning else absf(u_t)
	if spinning and along <= 0.0 and along >= reverse_threshold:
		push_amount = 0.0   # 横向きの入力は影響なし
	omega += d_omega * delta
	omega = clampf(omega, -Tuning.v("hoop_max_omega"), Tuning.v("hoop_max_omega"))

	# 2) 円運動が途切れていないか
	var was_spinning := spinning
	spinning = absf(omega) >= Tuning.v("hoop_min_omega")
	if spinning != was_spinning:
		_pulse = 1.0
	var decay := Tuning.v("hoop_sustain_decay")
	if not spinning and input_vector.length() < 0.2:
		decay = Tuning.v("hoop_drop_decay")   # 入力していない間だけ止まっていく
	omega *= exp(-decay * delta)
	angle = wrapf(angle + omega * delta, -PI, PI)

	# 3) 半径: 回っている間はパワーに応じて広がり、途切れると縮む（輪が落ちる）
	var r_target := Tuning.v("hoop_radius") + Tuning.v("hoop_radius_gain") * power()
	if not spinning:
		r_target = Tuning.v("hoop_radius") * 0.55
	var u_r := input_vector.dot(outward)
	radius_vel += (60.0 * (r_target - radius) - 9.0 * radius_vel + u_r * Tuning.v("hoop_radial_push")) * delta
	radius = maxf(radius + radius_vel * delta, RADIUS * 2.0)

	position = player.position + Vector2.from_angle(angle) * radius


func _on_area_entered(area: Area2D) -> void:
	if not area.has_method("hit"):
		return
	if is_flying():
		area.hit(fly_vel)
		_pulse = 1.0
	elif spinning:
		area.hit(tangent() * omega * radius)
		_pulse = 1.0


func _draw() -> void:
	var p := power()
	var col := Color(1.0, 0.66, 0.2).lerp(Color(1.0, 0.25, 0.6), p) if spinning else Color(0.5, 0.5, 0.6)
	if is_flying():
		col = Color(0.4, 0.9, 1.0)
		p = 1.0
	# 軌跡（速いほど長く太く）
	for k in range(1, _trail.size()):
		var a := 1.0 - float(k) / TRAIL_LEN
		draw_line(to_local(_trail[k - 1]), to_local(_trail[k]), Color(col, a * (0.2 + 0.6 * p)), RADIUS * a * 1.4, true)
	var r := RADIUS * (1.0 + _pulse * 0.5)
	draw_circle(Vector2.ZERO, r + 10.0, Color(col, 0.25))
	draw_circle(Vector2.ZERO, r, col)
	draw_circle(Vector2.ZERO, r * 0.5, Color(1, 1, 1, 0.9 if spinning else 0.3))
