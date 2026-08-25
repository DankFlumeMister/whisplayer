# Whisplayer

[![CI](https://github.com/DankFlumeMister/whisplayer/actions/workflows/ci.yml/badge.svg)](https://github.com/DankFlumeMister/whisplayer/actions/workflows/ci.yml)

[English](README_en.md) · [简体中文](README.md) · [繁體中文](README_zh_TW.md) · **日本語** · [한국어](README_ko.md)

ローカル & セルフホスト音楽プレーヤー。

## ✨ 機能

**セルフホストストリーミング（Subsonic プロトコル）**
- LAN 経由でスマホから PC / NAS の音楽を再生
- Navidrome など Subsonic / OpenSubsonic サーバーに対応
- アルバムグリッド表示（アートワークキャッシュ + 無限スクロール）、サーバー側あいまい検索
- ストリーミング再生：プレーヤー背景 / ロック画面アートワーク、サーバー側の同期歌詞を自動読み込み
- マルチサーバー管理とクイック切替；認証情報はシステムキーストアに保存、データベースには記録されません
- プレイリストにはローカル曲もクラウド曲も追加できます

**ローカル再生**
- ロスレス / ロスリー対応（FLAC、WAV、ALAC、MP3、M4A など）
- 曲 / アルバム / アーティスト / フォルダ別ブラウズ、全文検索と多軸ソート
- キュー管理：次に再生、追加、削除、クリア、一括編集
- 3 種類のループモード（1 曲 / 全曲 / オフ）
- 再生位置・キュー・ループモードの永続化——プロセス終了後も正確に再開
- 再生履歴と再生統計

**歌詞**
- 同フォルダの `.lrc` / `.vtt` / `.srt` サイドカー、埋め込み歌詞、データベーステキストを自動読み込み
- 同期スクロール、文字サイズ / 整列 / オフセット調整（永続化）、手動インポート
- 3 種類の表示モード：カバー非表示 / ドックパネル / イマーシブ全画面（長押しでロック解除）
- デスクトップ歌詞オーバーレイ（ドラッグ可能、文字サイズ調整可、他アプリ上に表示）

**パーソナライズ**
- 24 色のアクセントカラーを即時切替、ライト/ダークに自動対応
- ライト / ダークテーマ + システムに従う
- アプリ言語：简体中文 / 繁體中文 / 日本語 / 한국어 / English
- すりガラスぼかし背景、カバー演出などのビジュアル

## 📸 スクリーンショット

> TODO: リリース前に追加予定

## ⬇️ ダウンロード

[Releases](../../releases) ページから最新 APK をダウンロードしてください。

## 🔨 ソースからビルド

```bash
git clone https://github.com/DankFlumeMister/whisplayer.git
cd whisplayer
flutter pub get
flutter build apk --release
# 出力先：build/app/outputs/flutter-apk/app-release.apk
```

要件：

- Flutter **3.27+**（開発環境は master ブランチ `3.48.0-0.2.pre`、`Color.withValues` などの新 API を使用）
- Android SDK（プロジェクトは compileSdk 37）

中国本土のネットワークではミラー設定を推奨：

```bash
export PUB_HOSTED_URL=https://pub.flutter-io.cn
```

## 🖥 Navidrome への接続

1. [Navidrome](https://www.navidrome.org)（または任意の Subsonic 互換サーバー）をデプロイして起動
2. アプリ内：設定 → リモート音楽サーバー → サーバーアドレスと認証情報を追加
3. 「接続テスト」で確認して保存；下部の「クラウド」タブでブラウズ・ストリーミング可能

## 🌐 言語

简体中文 · 繁體中文 · 日本語 · 한국語 · English

設定 → 言語 → システムに従うか手動で選択。

## 🗺 ロードマップ

- [ ] WebDAV ソース
- [ ] 歌詞編集・タイミング打ち
- [ ] iOS サポート

## ⚠️ 免責事項

本プロジェクトはオンライン音楽ソースやコンテンツ配信機能を提供しません。ローカルファイルと**自身でホストするサーバー**の再生クライアントです。本プロジェクトの使用により、再生するコンテンツの合法性を保証したものとみなされます。

## 📄 ライセンス

[MIT](LICENSE) © 2026 DankFlumeMister
