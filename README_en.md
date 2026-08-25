# Whisplayer

[![CI](https://github.com/DankFlumeMister/whisplayer/actions/workflows/ci.yml/badge.svg)](https://github.com/DankFlumeMister/whisplayer/actions/workflows/ci.yml)

**English** · [简体中文](README.md) · [繁體中文](README_zh_TW.md) · [日本語](README_ja.md) · [한국어](README_ko.md)

A local & self-hosted music player.

一款本地 & 自建服务器音乐播放器。（简体中文版见 [README.md](README.md)）

## ✨ Features

**Self-hosted streaming (Subsonic protocol)**
- Play music from your PC / NAS over LAN
- Compatible with Navidrome and other Subsonic / OpenSubsonic servers
- Album grid browsing (artwork caching + infinite scroll), server-side fuzzy search
- Streaming: player background / lock screen artwork, automatic synced lyrics from server
- Multi-server management with quick switching; credentials stored in system keystore, never in plain text
- Playlists that hold both local and cloud songs

**Local playback**
- Lossless / lossy format support (FLAC, WAV, ALAC, MP3, M4A, etc.)
- Browse by songs / albums / artists / folders, full-text search & multi-key sorting
- Queue management: play next, append, remove, clear, batch edit
- Three loop modes (one / all / off)
- Playback position, queue & loop mode persistence — precise resume after process kill
- Recently played history & playback statistics

**Lyrics**
- Auto-load `.lrc` / `.vtt` / `.srt` sidecar files, embedded lyrics, and database text
- Synced scrolling, font size / alignment / offset adjustment (persisted), manual import
- Three display modes: cover-hidden / docked panel / immersive fullscreen (long-press to unlock)
- Desktop lyrics overlay (draggable, adjustable font size, visible over any app)

**Personalization**
- 24 accent colors with instant preview, auto-adapting to light & dark
- Light / dark theme + follow system
- App language: 简体中文 / 繁體中文 / 日本語 / 한국어 / English
- Frosted glass blur background, cover animation, and other visual polish

## 📸 Screenshots

> TODO: add screenshots before release

## ⬇️ Download

Get the latest APK from the [Releases](../../releases) page.

## 🔨 Build from source

```bash
git clone https://github.com/DankFlumeMister/whisplayer.git
cd whisplayer
flutter pub get
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

Requirements:

- Flutter **3.27+** (dev environment uses master branch `3.48.0-0.2.pre`, uses newer APIs like `Color.withValues`)
- Android SDK (project targets compileSdk 37)

If you're behind a firewall in mainland China:

```bash
export PUB_HOSTED_URL=https://pub.flutter-io.cn
```

## 🖥 Connect to Navidrome

1. Deploy and start [Navidrome](https://www.navidrome.org) (or any Subsonic-compatible server)
2. In-app: Settings → Remote music servers → Add server address & credentials
3. Tap "Test connection" to verify, then save; the "Cloud" tab is ready for browsing & streaming

## 🌐 Language

简体中文 · 繁體中文 · 日本語 · 한국어 · English

Settings → Language → Follow system or pick manually.

## 🗺 Roadmap

- [ ] WebDAV source
- [ ] Lyrics editor & timing
- [ ] iOS support

## ⚠️ Disclaimer

This project does not provide any online music sources or content distribution. It is a client for local files and **your own self-hosted server** only. By using this project you confirm that all content you play is legal.

## 📄 License

[MIT](LICENSE) © 2026 DankFlumeMister
