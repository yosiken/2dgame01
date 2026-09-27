extends Area2D
## HULA HOOP モードのオプション（1 個）。自機のまわりを円運動する。
##  - 入力ベクトルのうち「いま回っている向き（接線）」の成分だけが回転パワーになる
##  - 同じ向きに入力 → 加速、逆向きに入力 → 減速（hoop_reverse_brake 倍で効く）
##  - 円運動が続いている間（|ω| >= hoop_min_omega）はパワーを維持する
##  - 途切れると輪が落ちる（半径が縮み、hoop_drop_decay で止まっていく）
## 回っている間だけ敵を破壊できる。

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


func _physics_process(delta: float) -> void:
	if player == null:
		return
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

	_trail.push_front(position)
	if _trail.size() > TRAIL_LEN:
		_trail.pop_back()
	_pulse = maxf(_pulse - delta * 3.0, 0.0)
	queue_redraw()


func _on_area_entered(area: Area2D) -> void:
	if spinning and area.has_method("hit"):
		area.hit(tangent() * omega * radius)
		_pulse = 1.0


func _draw() -> void:
	var p := power()
	var col := Color(1.0, 0.66, 0.2).lerp(Color(1.0, 0.25, 0.6), p) if spinning else Color(0.5, 0.5, 0.6)
	# 軌跡（速いほど長く太く）
	for k in range(1, _trail.size()):
		var a := 1.0 - float(k) / TRAIL_LEN
		draw_line(to_local(_trail[k - 1]), to_local(_trail[k]), Color(col, a * (0.2 + 0.6 * p)), RADIUS * a * 1.4, true)
	var r := RADIUS * (1.0 + _pulse * 0.5)
	draw_circle(Vector2.ZERO, r + 10.0, Color(col, 0.25))
	draw_circle(Vector2.ZERO, r, col)
	draw_circle(Vector2.ZERO, r * 0.5, Color(1, 1, 1, 0.9 if spinning else 0.3))
