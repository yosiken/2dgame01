extends Area2D
## 敵。画面内をゆっくり漂う。オプションに触れると破壊される（HP 1）。
## approach_target を設定すると、その位置へ向かって歩いてくる（HULA HOOP モード）。

signal destroyed(enemy: Area2D, impact: Vector2)
signal reached(enemy: Area2D)

const REACH_DIST := 44.0

const RADIUS := 30.0

var velocity := Vector2.ZERO
var approach_target: Node2D
var approach_speed := 80.0
var _spin := 0.0
var _angle := 0.0
var _age := 0.0
var _dead := false
var _color := Color(1.0, 0.3, 0.4)


func _ready() -> void:
	var shape := CircleShape2D.new()
	shape.radius = RADIUS
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)
	collision_layer = 1 << 2   # layer 3: enemies
	collision_mask = 0
	monitoring = false
	monitorable = true
	velocity = Vector2.from_angle(randf() * TAU) * randf_range(40.0, 120.0)
	_spin = randf_range(-2.0, 2.0)
	_color = Color.from_hsv(randf_range(0.93, 1.05), 0.7, 1.0)
	scale = Vector2.ZERO


func _physics_process(delta: float) -> void:
	_age += delta
	scale = Vector2.ONE * minf(_age / 0.25, 1.0)
	_angle += _spin * delta
	if approach_target != null:
		velocity = velocity.lerp((approach_target.position - position).normalized() * approach_speed, 1.0 - exp(-2.0 * delta))
		position += velocity * delta
		if not _dead and position.distance_to(approach_target.position) < REACH_DIST:
			_dead = true
			reached.emit(self)
			queue_free()
		queue_redraw()
		return
	position += velocity * delta
	var rect := get_viewport_rect().grow(-RADIUS)
	if position.x < rect.position.x or position.x > rect.end.x:
		velocity.x = -velocity.x
	if position.y < rect.position.y or position.y > rect.end.y:
		velocity.y = -velocity.y
	position = position.clamp(rect.position, rect.end)
	queue_redraw()


func hit(impact: Vector2) -> void:
	if _dead:
		return
	_dead = true
	destroyed.emit(self, impact)
	queue_free()


func _draw() -> void:
	var pts := PackedVector2Array()
	for k in 6:
		var a := _angle + k * TAU / 6.0
		pts.append(Vector2.from_angle(a) * (RADIUS if k % 2 == 0 else RADIUS * 0.72))
	draw_colored_polygon(pts, _color.darkened(0.35))
	pts.append(pts[0])
	draw_polyline(pts, _color, 3.0, true)
	draw_circle(Vector2.ZERO, 7.0 + sin(_age * 8.0) * 2.0, Color(1, 0.9, 0.9))
