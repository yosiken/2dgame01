extends Node2D
## ゲーム全体の組み立て・入力・敵の出現を担当する。

const Player := preload("res://scripts/player.gd")
const OptionOrb := preload("res://scripts/option.gd")
const Enemy := preload("res://scripts/enemy.gd")
const Explosion := preload("res://scripts/explosion.gd")
const Starfield := preload("res://scripts/starfield.gd")
const VirtualJoystick := preload("res://scripts/virtual_joystick.gd")
const Hud := preload("res://scripts/hud.gd")

const ENEMY_MIN_DIST_FROM_PLAYER := 260.0

var player: Node2D
var joystick: Node2D
var hud: CanvasLayer
var noise := FastNoiseLite.new()

var _options: Array[Area2D] = []
var _option_layer: Node2D
var _enemy_layer: Node2D
var _fx_layer: Node2D
var _spawn_timer := 0.0

# タッチ（マウスはプロジェクト設定でタッチとしてエミュレートされる）
var _touch_index := -1
var _touch_last := Vector2.ZERO


func _ready() -> void:
	randomize()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 1.0
	noise.seed = randi()

	add_child(Starfield.new())

	_option_layer = Node2D.new()
	_enemy_layer = Node2D.new()
	_fx_layer = Node2D.new()
	add_child(_enemy_layer)
	add_child(_option_layer)

	player = Player.new()
	var size := get_viewport_rect().size
	player.position = Vector2(size.x * 0.5, size.y * 0.72)
	add_child(player)
	add_child(_fx_layer)

	joystick = VirtualJoystick.new()
	joystick.z_index = 50
	add_child(joystick)

	hud = Hud.new()
	add_child(hud)

	Tuning.changed.connect(_rebuild_options)
	_rebuild_options()


## オプション数の変更に合わせて増減する
func _rebuild_options() -> void:
	var count := Tuning.i("option_count")
	while _options.size() > count:
		_options.pop_back().queue_free()
	while _options.size() < count:
		var o: Area2D = OptionOrb.new()
		o.setup(player, _options.size(), noise)
		_option_layer.add_child(o)
		_options.append(o)


func _process(delta: float) -> void:
	# キーボード（PC での確認用）
	var kb := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	kb += Vector2(
		float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W)))
	var stick: Vector2 = joystick.get_vector() if Tuning.i("control_mode") == 0 else Vector2.ZERO
	player.input_vector = (stick + kb).limit_length(1.0)

	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = Tuning.v("enemy_interval")
		if _enemy_layer.get_child_count() < Tuning.i("enemy_max"):
			_spawn_enemy()


func _spawn_enemy() -> void:
	var rect := get_viewport_rect().grow(-60.0)
	var pos := Vector2.ZERO
	for attempt in 12:
		pos = Vector2(randf_range(rect.position.x, rect.end.x), randf_range(rect.position.y, rect.position.y + rect.size.y * 0.75))
		if pos.distance_to(player.position) > ENEMY_MIN_DIST_FROM_PLAYER:
			break
	var e: Area2D = Enemy.new()
	e.position = pos
	e.destroyed.connect(_on_enemy_destroyed)
	_enemy_layer.add_child(e)


func _on_enemy_destroyed(enemy: Area2D, impact: Vector2) -> void:
	var fx: Node2D = Explosion.new()
	fx.position = enemy.position
	fx.impact = impact
	fx.color = enemy._color
	_fx_layer.add_child(fx)
	hud.add_score(1)
	Input.vibrate_handheld(20)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if _touch_index == -1 and not hud.is_point_on_ui(event.position):
				_touch_index = event.index
				_touch_last = event.position
				joystick.show_visual = Tuning.i("control_mode") == 0
				joystick.press(event.position)
		elif event.index == _touch_index:
			_touch_index = -1
			joystick.release()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		player.drag_delta += event.position - _touch_last
		_touch_last = event.position
		joystick.move(event.position)
