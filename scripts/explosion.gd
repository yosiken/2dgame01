extends Node2D
## 敵破壊エフェクト（衝突時のオプション速度の方向に破片が飛ぶ）。

const LIFE := 0.5

var color := Color(1.0, 0.4, 0.4)
var impact := Vector2.ZERO
var _t := 0.0
var _shards: Array = []


func _ready() -> void:
	var bias := impact.limit_length(900.0) * 0.5
	for k in 14:
		var dir := Vector2.from_angle(randf() * TAU)
		_shards.append({"vel": dir * randf_range(200.0, 520.0) + bias, "pos": Vector2.ZERO})


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	for s in _shards:
		s.pos += s.vel * delta
		s.vel *= exp(-4.0 * delta)
	queue_redraw()


func _draw() -> void:
	var k := _t / LIFE
	draw_arc(Vector2.ZERO, 20.0 + 90.0 * k, 0.0, TAU, 32, Color(1, 0.9, 0.7, 1.0 - k), 6.0 * (1.0 - k) + 1.0, true)
	for s in _shards:
		draw_line(s.pos, s.pos - s.vel * 0.03, Color(color, 1.0 - k), 4.0, true)
