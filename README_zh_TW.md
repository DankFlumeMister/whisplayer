# whisplayer

[![CI](https://github.com/DankFlumeMister/whisplayer/actions/workflows/ci.yml/badge.svg)](https://github.com/DankFlumeMister/whisplayer/actions/workflows/ci.yml)

[English](README_en.md) · [简体中文](README.md) · **繁體中文** · [日本語](README_ja.md) · [한국어](README_ko.md)

一款本地 & 自建伺服器音樂播放器。

## ✨ 功能特性

**自建伺服器串流（Subsonic 協定）**
- 在區網下手機播放你的 PC / NAS 音樂
- 相容 Navidrome 等 Subsonic / OpenSubsonic 伺服器
- 專輯網格瀏覽（封面快取 + 觸底分頁）、伺服器模糊搜尋
- 線上串流：播放頁背景 / 鎖屏通知封面、自動載入伺服器端同步歌詞
- 多伺服器管理與快速切換；憑證存於系統金鑰庫，絕不入庫
- 播放清單同時容納本機與雲端歌曲

**本機播放**
- 無損 / 有損格式支援（FLAC、WAV、ALAC、MP3、M4A 等）
- 按歌曲 / 專輯 / 藝人 / 資料夾瀏覽，全文搜尋與多維度排序
- 佇列管理：插播下一首、加入、移除、清空、批次編輯
- 三種循環模式（單曲 / 清單 / 關閉）
- 播放進度、佇列與循環模式持久化——殺進程後精確續播
- 最近播放紀錄與播放統計

**歌詞**
- 自動載入同目錄 `.lrc` / `.vtt` / `.srt` 側車檔、內嵌歌詞與資料庫文字
- 同步捲動、字體 / 對齊 / 時間偏移調節（持久化）、手動匯入
- 三種顯示模式：封面隱藏式 / 停靠面板 / 沉浸全螢幕（長按解鎖防誤觸）
- 桌面歌詞懸浮視窗（可拖曳、字體可調，任意介面顯示當前行）

**個人化**
- 24 種主題色即時切換，自動適配深淺模式
- 深淺色主題 + 跟隨系統
- 介面語言：简体中文 / 繁體中文 / 日本語 / 한국어 / English
- 毛玻璃模糊背景、封面動效等視覺細節

## 📸 截圖

> TODO: 發布前補充截圖

## ⬇️ 下載

前往 [Releases](../../releases) 頁面下載最新 APK。

### 🧩 可選工具

為自建 Navidrome 伺服器準備的配套小工具（Python 腳本，與 App 版本獨立迭代，無須跟著 APK 一起更新）：

| 工具 | 用途 | 下載 |
| --- | --- | --- |
| [navidrome-tray](https://github.com/DankFlumeMister/navidrome-tray) | 將 Navidrome 收進系統匣，不再彈出主控台視窗 | [ZIP](https://github.com/DankFlumeMister/navidrome-tray/archive/refs/heads/main.zip) |
| [navidrome-vtt-support](https://github.com/DankFlumeMister/navidrome-vtt-support) | 批次將 `.vtt` 字幕轉成 `.lrc`，讓 Navidrome 提供同步歌詞 | [ZIP](https://github.com/DankFlumeMister/navidrome-vtt-support/archive/refs/heads/main.zip) |

兩者皆需 Python 3 環境（托盤工具額外需要 `pip install pystray pillow`），詳細用法見各自儲存庫的 README。

## 🔨 從原始碼建置

```bash
git clone https://github.com/DankFlumeMister/whisplayer.git
cd whisplayer
flutter pub get
flutter build apk --release
# 產物位於 build/app/outputs/flutter-apk/app-release.apk
```

環境需求：

- Flutter **3.27+**（開發環境為 master 分支 `3.48.0-0.3.pre`，使用了 `Color.withValues` 等新 API）
- Android SDK（專案配置 compileSdk 37）

中國大陸網路下取包建議先設定映像：

```bash
export PUB_HOSTED_URL=https://pub.flutter-io.cn
```

## 🖥 連接 Navidrome

1. 部署並啟動 [Navidrome](https://www.navidrome.org)（或任意 Subsonic 相容伺服器）
2. 應用內：設定 → 遠端音樂伺服器 → 新增伺服器位址與帳號
3. 「測試連線」通過後儲存；底部「雲端」標籤即可瀏覽與串流

## 🌐 語言

简体中文 · 繁體中文 · 日本語 · 한국어 · English

設定 → 語言 → 跟隨系統或手動選擇。

## 🗺 路線圖

- [ ] WebDAV 音源
- [ ] 歌詞編輯與打軸
- [ ] iOS 支援

## ⚠️ 免責聲明

本專案不提供任何線上音源或內容分發能力，僅作為本機檔案與**自架伺服器**的播放用戶端。使用本專案即表示你已確保所播放內容的合法性。

## 🤝 致謝

本專案由opencode協助開發。

## 📄 授權條款

[MIT](LICENSE) © 2026 DankFlumeMister
