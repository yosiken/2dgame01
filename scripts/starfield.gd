extends Node2D
## 縦スクロールする背景の星。

var _stars: Array = []


func _ready() -> void:
	for k in 90:
		_stars.append({
			"pos": Vector2(randf(), randf()),
			"speed": randf_range(0.03, 0.25),
			"size": randf_range(1.0, 3.0),
		})


func _process(delta: float) -> void:
	for s in _stars:
		s.pos.y = fposmod(s.pos.y + s.speed * delta, 1.0)
	queue_redraw()


func _draw() -> void:
	var size := get_viewport_rect().size
	for s in _stars:
		var c := Color(0.7, 0.8, 1.0, 0.25 + s.speed * 2.5)
		draw_rect(Rect2(s.pos * size, Vector2(s.size, s.size * (1.0 + s.speed * 12.0))), c)
