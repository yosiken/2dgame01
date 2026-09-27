# Option Lab (Godot 4)

2D シューティングのオプション挙動モック集。タイトルメニューでモードを切り替える。

| モード | 内容 | 仕様書 |
|---|---|---|
| OPTION FOLLOW | オプションが質量・車のような慣性・カールノイズで軌跡からずれながら付いてきて、敵に当たると破壊する | [docs/SPEC.md](docs/SPEC.md) |
| HULA HOOP | 入力でオプション（輪）に力を加える。回転に合わせて入力を回すとパワーが溜まり、逆に入れると落ちる | [docs/SPEC_HOOP.md](docs/SPEC_HOOP.md) |

公開版: https://yosiken.github.io/2dgame01/

## 遊び方

### OPTION FOLLOW
- 画面をタッチしてドラッグ → 自機が全方向に移動（フローティングスティック）
- オプションを敵にぶつけて破壊
- 右上 `DEBUG` でバネの硬さ・減衰・質量・チェーン・グリップ・カールノイズなどを実行中に調整（プリセット切替、スロー、線表示あり。値は自動保存）

### HULA HOOP
- スティックを輪の少し先へ向けたまま、輪と一緒にぐるぐる回す → パワーが溜まる（矢印が緑）
- 手を離してもパワーは維持。逆向きに入れる（矢印が赤）と減速し、遅くなりすぎると輪が落ちる
- 回っている輪で、寄ってくる敵を倒す

## 実行

### PC で確認
1. [Godot 4.3 以降](https://godotengine.org/download) をインストール
2. Godot で `project.godot` を開いて F5（マウスドラッグ = タッチ、矢印キー/WASD でも移動可）

### スマホで遊ぶ
- **ブラウザ（おすすめ）**: `.github/workflows/web.yml` が Web 版をビルドします。
  リポジトリの Settings → Pages → Source を **GitHub Actions** にすると、`main` への push
  （または Actions 画面から手動実行）で GitHub Pages に公開され、スマホのブラウザでそのまま遊べます。
  ビルド結果は各実行の Artifacts からもダウンロード可能。
  ローカルなら Godot の「プロジェクト → エクスポート → Web」で `build/web/` に出力し、
  `python3 -m http.server` などで配信して同じ LAN のスマホから開く。
- **Android**: Godot のエディタ設定で Android SDK / デバッグキーストアを設定し、
  エクスポートの `Android` プリセットで APK を作成、またはワンクリックデプロイ（USB 接続）。
- **iOS**: macOS + Xcode で iOS プリセットを追加してエクスポート。
