# Option Follow Mock (Godot 4)

2D シューティングの「自機」と「遅れて追従するオプション」の挙動モック。
オプションは質量・車のような慣性・カールノイズで軌跡からずれながら付いてきて、敵に当たると破壊する。

仕様書: [docs/SPEC.md](docs/SPEC.md)

## 遊び方

- 画面をタッチしてドラッグ → 自機が全方向に移動（フローティングスティック）
- オプションを敵にぶつけて破壊
- 右上 `TUNE` で質量・グリップ・カールノイズなどを実行中に調整

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
