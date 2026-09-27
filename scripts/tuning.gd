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


func apply_preset(preset_name: String) -> void:
	var keep := {}
	for k in RUNTIME_KEYS:
		keep[k] = values.get(k, DEFAULTS[k])
	values = DEFAULTS.duplicate()
	values.merge(PRESETS.get(preset_name, {}), true)
	values.merge(keep, true)
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


func _save() -> void:
	_save_pending = false
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(values))


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if data is Dictionary:
		for k in data:
			if DEFAULTS.has(k) and k != "slow_motion":
				values[k] = data[k]
