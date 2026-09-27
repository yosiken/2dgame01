extends Node
## 調整パラメータ（オートロード "Tuning"）。
## HUD の調整パネルから実行中に変更でき、端末に自動保存される。値の意味は docs/SPEC.md を参照。

signal changed

const SAVE_PATH := "user://tuning.json"

const DEFAULTS := {
	# 操作
	"control_mode": 0,        # 0 = フローティングスティック, 1 = 相対ドラッグ
	"player_speed": 720.0,    # px/s（スティック操作時の最高速）
	"player_accel": 5200.0,   # px/s^2
	"drag_sensitivity": 1.25, # 相対ドラッグの倍率
	# オプション: 追従・バネ
	"option_count": 4,
	"delay_frames": 10.0,     # 1 個あたりの遅延（プレイヤーが動いたフレーム数）
	"spring_k": 45.0,         # バネ定数（大きいほど強く引かれる）
	"damping": 0.22,          # 減衰比 ζ（1 = 振動しない / 小さいほどビヨンビヨン）
	"mass": 1.2,              # 先頭オプションの質量
	"mass_step": 0.25,        # 後ろのオプションほど重くなる割合
	"chain": 0.45,            # 0 = 自機の軌跡を追う / 1 = 前のオプションに紐でつながる
	"chain_length": 70.0,     # 紐の自然長 (px)
	# オプション: 車の挙動
	"turn_rate": 9.0,         # 車体の旋回速度 (rad/s, 質量で割る)
	"side_accel": 0.4,        # 横方向へ直接加速できる割合 (0 = 完全に車)
	"grip": 4.0,              # 横滑りの減衰（小さいほどドリフト）
	"drag": 0.3,              # 空気抵抗
	"max_speed": 2200.0,
	# オプション: カールノイズ
	"curl_strength": 2800.0,  # カールノイズの力
	"curl_scale": 0.004,      # ノイズの空間周波数 (1/px)
	"curl_speed": 0.5,        # ノイズの時間変化速度
	"curl_idle": 0.25,        # プレイヤー静止時にも残るノイズの割合
	# HULA HOOP モード
	"hoop_radius": 150.0,       # 静止時の輪の半径 (px)
	"hoop_radius_gain": 70.0,   # パワー最大時に広がる半径 (px)
	"hoop_push": 8.0,           # 回転方向の入力 1 あたりの角加速度 (rad/s^2)
	"hoop_start_boost": 3.5,    # 輪が落ちている間の入力の効き倍率（回し始めを楽にする）
	"hoop_reverse_angle": 120.0, # 進行方向からこの角度以上ずれた入力を逆入力とみなす (度)
	"hoop_reverse_brake": 1.6,  # 逆方向入力の減速倍率（大きいほど逆入力で落ちやすい）
	"hoop_min_omega": 2.5,      # これ未満の角速度で円運動が途切れる (rad/s)
	"hoop_max_omega": 10.0,     # 角速度の上限 (rad/s)
	"hoop_sustain_decay": 0.0,  # 回っている間の自然減衰 (/s)。0 = パワー維持
	"hoop_drop_decay": 1.2,     # 途切れた後の減衰 (/s)
	"hoop_radial_push": 900.0,  # 半径方向の入力で輪が揺れる強さ
	"hoop_hip": 36.0,           # 入力に合わせて自機（腰）が揺れる幅 (px)
	"hoop_swipe_ref": 1400.0,   # SWIPE 入力で入力 1.0 とみなす指の速さ (px/s)
	"hoop_enemy_speed": 70.0,   # 自機へ寄ってくる敵の速さ (px/s)
	"hoop_throw_time": 0.35,        # 投げてからまっすぐ進む時間 (s)
	"hoop_throw_speed_min": 300.0,  # パワー 0% での投げる速さ (px/s)
	"hoop_throw_speed_max": 1700.0, # パワー 100% での投げる速さ (px/s)。距離 = 速さ × 時間
	"hoop_throw_aim": 0.0,          # 投げる方向: 0 = 輪の進行方向（接線）/ 1 = 直前の入力方向
	"hoop_return_turn": 7.0,        # 戻るときの旋回の強さ (rad/s)。小さいほど大きな弧
	"hoop_return_speed": 1300.0,    # 戻るときの速さ (px/s)
	"hoop_throw_cost": 0.2,         # 投げると失うパワーの割合
	# 敵
	"enemy_max": 10,
	"enemy_interval": 0.8,    # 秒
	# デバッグ
	"debug_draw": 0,
	"slow_motion": 0,
}

## プリセット（DEFAULTS に上書きする値）
const PRESETS := {
	"Loose": {},
	"Tight": {
		"spring_k": 160.0, "damping": 0.8, "mass": 0.8, "mass_step": 0.1, "chain": 0.0,
		"side_accel": 0.8, "grip": 10.0, "curl_strength": 1200.0,
	},
	"Jelly": {
		"spring_k": 25.0, "damping": 0.12, "mass": 1.5, "mass_step": 0.35, "chain": 0.8,
		"chain_length": 60.0, "side_accel": 0.6, "grip": 2.0, "drag": 0.15, "curl_strength": 2500.0,
	},
	"Drift": {
		"spring_k": 60.0, "damping": 0.35, "chain": 0.2, "turn_rate": 4.0,
		"side_accel": 0.0, "grip": 1.0, "drag": 0.2,
	},
}
## プレイ中に保持する（プリセット・保存の対象外の）キー
const RUNTIME_KEYS := ["control_mode", "debug_draw", "slow_motion"]

var values: Dictionary = {}
var _save_pending := false


func _ready() -> void:
	values = DEFAULTS.duplicate()
	_load()
	changed.connect(_on_changed)
	changed.emit()


func reset() -> void:
	apply_preset("Loose")


## オプション追従モードのプリセット。HULA HOOP の値（hoop_*）は変えない
func apply_preset(preset_name: String) -> void:
	for k in DEFAULTS:
		if k in RUNTIME_KEYS or k.begins_with("hoop_"):
			continue
		values[k] = DEFAULTS[k]
	values.merge(PRESETS.get(preset_name, {}), true)
	changed.emit()


## 指定したキーだけ既定値に戻す
func reset_keys(keys: Array) -> void:
	for k in keys:
		values[k] = DEFAULTS[k]
	changed.emit()


func v(key: String) -> float:
	return float(values.get(key, DEFAULTS.get(key, 0.0)))


func i(key: String) -> int:
	return int(round(v(key)))


func set_value(key: String, value: float) -> void:
	if is_equal_approx(v(key), value):
		return
	values[key] = value
	changed.emit()


## 既定値と異なる値だけを JSON にする（調整結果の共有用）
func to_json() -> String:
	var diff := {}
	for k in values:
		if k in RUNTIME_KEYS:
			continue
		if not is_equal_approx(float(values[k]), float(DEFAULTS[k])):
			diff[k] = values[k]
	return JSON.stringify(diff, "  ", true)


func _on_changed() -> void:
	Engine.time_scale = 0.3 if i("slow_motion") == 1 else 1.0
	# スライダー操作中の連続書き込みを避けるため、少し遅らせて保存
	if not _save_pending:
		_save_pending = true
		get_tree().create_timer(0.5, true, false, true).timeout.connect(_save)


## 既定値から変えた値だけを保存する（既定値を更新したときに古い値が残らないように）
func _save() -> void:
	_save_pending = false
	var diff := {}
	for k in values:
		if k != "slow_motion" and not is_equal_approx(float(values[k]), float(DEFAULTS[k])):
			diff[k] = values[k]
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(diff))


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if data is Dictionary:
		for k in data:
			if DEFAULTS.has(k) and k != "slow_motion":
				values[k] = data[k]
