extends Node2D
## フローティング仮想スティックの表示と入力ベクトル計算。
## 触れた位置が中心になり、半径より遠くへ指を動かすと中心が指に引っ張られて付いてくる。

const RADIUS := 110.0
const DEADZONE := 0.12

var active := false
var base := Vector2.ZERO
var knob := Vector2.ZERO
var show_visual := true


func press(pos: Vector2) -> void:
	active = true
	base = pos
	knob = pos
	queue_redraw()


func move(pos: Vector2) -> void:
	knob = pos
	var d := knob - base
	if d.length() > RADIUS:
		base = knob - d.normalized() * RADIUS
	queue_redraw()


func release() -> void:
	active = false
	queue_redraw()


func get_vector() -> Vector2:
	if not active:
		return Vector2.ZERO
	var v := (knob - base) / RADIUS
	if v.length() < DEADZONE:
		return Vector2.ZERO
	return v.limit_length(1.0)


func _draw() -> void:
	if not active or not show_visual:
		return
	draw_circle(base, RADIUS, Color(1, 1, 1, 0.08))
	draw_arc(base, RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 3.0, true)
	draw_circle(knob, 42.0, Color(1, 1, 1, 0.3))
