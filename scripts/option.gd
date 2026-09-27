extends Area2D
## オプション。自機の軌跡を遅れて追いかけるが、
##  - 質量付きのバネ・ダンパ（重いほど遅れてオーバーシュートする）
##  - 車のような挙動（車体の向きへしか強く加速できず、横滑りはグリップで減衰）
##  - カールノイズによる流れ場（自機の移動量が大きいほど強い）
## によって、軌跡上の目標位置から自然にずれる。
## 敵 (collision layer 3) に触れると敵を破壊する。

const RADIUS := 20.0
const TRAIL_LEN := 14

var index := 0
var player: Node2D
var noise: FastNoiseLite

var velocity := Vector2.ZERO
var heading := -PI / 2.0
var _time := 0.0
var _target := Vector2.ZERO
var _trail: Array[Vector2] = []
var _pulse := 0.0


func setup(p_player: Node2D, p_index: int, p_noise: FastNoiseLite) -> void:
	player = p_player
	index = p_index
	noise = p_noise
	position = player.get_past_position(_delay_frames())
	_time = index * 13.7


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


func _delay_frames() -> float:
	return Tuning.v("delay_frames") * (index + 1)


func mass() -> float:
	return maxf(Tuning.v("mass") * (1.0 + index * Tuning.v("mass_step")), 0.05)


func _physics_process(delta: float) -> void:
	if player == null:
		return
	var m := mass()

	# 1) 追従目標: 自機の過去位置
	_target = player.get_past_position(_delay_frames())

	# 2) 目標速度へ寄せる加速度（バネ・ダンパ。質量が大きいほど弱い）
	var desired_vel: Vector2 = (_target - position) * Tuning.v("follow_gain")
	var accel: Vector2 = (desired_vel - velocity) * Tuning.v("drive") / m

	# 3) 車の挙動: 車体の向きは目標速度の方向へ有限の速さでしか回らない
	if desired_vel.length() > 30.0:
		heading = rotate_toward(heading, desired_vel.angle(), Tuning.v("turn_rate") / m * delta)
	var fwd := Vector2.from_angle(heading)
	var side := fwd.orthogonal()
	# 前後方向（アクセル/ブレーキ）は満額、横方向は side_accel 分だけ
	velocity += (fwd * accel.dot(fwd) + side * accel.dot(side) * Tuning.v("side_accel")) * delta
	# 横滑りはグリップで減衰（重いほど滑る）
	var v_fwd := velocity.dot(fwd)
	var v_side := velocity.dot(side) * exp(-Tuning.v("grip") / m * delta)
	velocity = fwd * v_fwd + side * v_side

	# 4) カールノイズの流れ場。自機の移動量に比例して強くなる
	var energy: float = Tuning.v("curl_idle") + player.movement_energy
	velocity += curl(position * Tuning.v("curl_scale"), _time) * Tuning.v("curl_strength") * energy / m * delta

	# 5) 抵抗・速度制限・積分
	velocity *= exp(-Tuning.v("drag") * delta)
	velocity = velocity.limit_length(Tuning.v("max_speed"))
	position += velocity * delta
	_time += Tuning.v("curl_speed") * delta

	# 画面外に飛び出しすぎないよう柔らかく押し戻す
	var rect := get_viewport_rect().grow(-RADIUS)
	var clamped := position.clamp(rect.position, rect.end)
	if clamped != position:
		velocity += (clamped - position) * 40.0 * delta
		position = position.lerp(clamped, 0.5)

	_trail.push_front(position)
	if _trail.size() > TRAIL_LEN:
		_trail.pop_back()
	_pulse = maxf(_pulse - delta * 4.0, 0.0)
	queue_redraw()


## 2D カールノイズ: スカラーノイズ N の回転 (dN/dy, -dN/dx)。発散ゼロの流れ場になる。
func curl(p: Vector2, t: float) -> Vector2:
	const EPS := 0.01
	var z := t + index * 37.0
	var dx := noise.get_noise_3d(p.x + EPS, p.y, z) - noise.get_noise_3d(p.x - EPS, p.y, z)
	var dy := noise.get_noise_3d(p.x, p.y + EPS, z) - noise.get_noise_3d(p.x, p.y - EPS, z)
	return Vector2(dy, -dx) / (2.0 * EPS)


func _on_area_entered(area: Area2D) -> void:
	if area.has_method("hit"):
		area.hit(velocity)
		_pulse = 1.0


func _draw() -> void:
	# 軌跡
	for k in range(1, _trail.size()):
		var a := 1.0 - float(k) / TRAIL_LEN
		draw_line(to_local(_trail[k - 1]), to_local(_trail[k]), Color(1.0, 0.6, 0.15, a * 0.6), RADIUS * a, true)
	# 本体
	var r := RADIUS * (1.0 + _pulse * 0.4)
	draw_circle(Vector2.ZERO, r + 8.0, Color(1.0, 0.55, 0.1, 0.25))
	draw_circle(Vector2.ZERO, r, Color(1.0, 0.66, 0.2))
	draw_circle(Vector2.ZERO, r * 0.55, Color(1.0, 0.93, 0.7))
	# 車体の向き（ドリフトが見える）
	draw_line(Vector2.ZERO, Vector2.from_angle(heading) * (r + 10.0), Color(1, 1, 1, 0.8), 3.0, true)

	if Tuning.i("debug_draw") == 1:
		var tl := to_local(_target)
		draw_line(Vector2.ZERO, tl, Color(0.4, 1.0, 0.5, 0.6), 2.0)
		draw_line(tl + Vector2(-8, 0), tl + Vector2(8, 0), Color(0.4, 1.0, 0.5), 2.0)
		draw_line(tl + Vector2(0, -8), tl + Vector2(0, 8), Color(0.4, 1.0, 0.5), 2.0)
		draw_line(Vector2.ZERO, velocity * 0.08, Color(0.5, 0.7, 1.0, 0.8), 2.0)
