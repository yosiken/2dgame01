extends Node
## 調整パラメータ（オートロード "Tuning"）。
## HUD の調整パネルから実行中に変更できる。値の意味は docs/SPEC.md を参照。

signal changed

const DEFAULTS := {
	# 操作
	"control_mode": 0,        # 0 = フローティングスティック, 1 = 相対ドラッグ
	"player_speed": 720.0,    # px/s（スティック操作時の最高速）
	"player_accel": 5200.0,   # px/s^2
	"drag_sensitivity": 1.25, # 相対ドラッグの倍率
	# オプション
	"option_count": 4,
	"delay_frames": 10.0,     # 1 個あたりの遅延（プレイヤーが動いたフレーム数）
	"mass": 1.4,              # 先頭オプションの質量
	"mass_step": 0.3,         # 後ろのオプションほど重くなる割合
	"follow_gain": 8.0,       # 目標までの距離 → 目標速度 の係数 (1/s)
	"drive": 18.0,            # 目標速度へ寄せる駆動力
	"turn_rate": 9.0,         # 車体の旋回速度 (rad/s, 質量で割る)
	"side_accel": 0.2,        # 横方向へ直接加速できる割合 (0 = 完全に車)
	"grip": 5.0,              # 横滑りの減衰（小さいほどドリフト）
	"drag": 0.6,              # 空気抵抗
	"max_speed": 1800.0,
	"curl_strength": 2800.0,  # カールノイズの力
	"curl_scale": 0.004,      # ノイズの空間周波数 (1/px)
	"curl_speed": 0.5,        # ノイズの時間変化速度
	"curl_idle": 0.25,        # プレイヤー静止時にも残るノイズの割合
	# 敵
	"enemy_max": 10,
	"enemy_interval": 0.8,    # 秒
	# デバッグ
	"debug_draw": 0,
}

var values: Dictionary = {}


func _ready() -> void:
	reset()


func reset() -> void:
	values = DEFAULTS.duplicate()
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
