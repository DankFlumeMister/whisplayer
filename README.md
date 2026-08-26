# Whisplayer

[![CI](https://github.com/DankFlumeMister/whisplayer/actions/workflows/ci.yml/badge.svg)](https://github.com/DankFlumeMister/whisplayer/actions/workflows/ci.yml)

**简体中文** · [English](README_en.md) · [繁體中文](README_zh_TW.md) · [日本語](README_ja.md) · [한국어](README_ko.md)

一款本地 & 自建服务器音乐播放器。

A polished local & self-hosted music player for Android, built with Flutter.

## ✨ 功能特性

**自建服务器串流（Subsonic 协议）**
- 在局域网下使用手机播放你的PC / NAS 音乐
- 兼容 Navidrome 等 Subsonic / OpenSubsonic 服务端
- 专辑网格浏览（封面缓存 + 触底分页）、服务端模糊搜索
- 在线流播：播放页背景 / 锁屏通知封面、自动加载服务器端同步歌词
- 多服务器管理与快速切换；凭据存于系统密钥库，绝不入库
- 播放列表同时容纳本地与云端歌曲

**本地播放**
- 无损 / 有损格式支持（FLAC、WAV、ALAC、MP3、M4A 等）
- 按歌曲 / 专辑 / 艺术家 / 文件夹浏览，全文搜索与多维度排序
- 队列管理：插播下一首、追加、移除、清空、批量编辑
- 三种循环模式（单曲 / 列表 / 关闭）
- 播放进度、队列与循环模式持久化——杀进程后精确续播
- 最近播放记录与播放统计

**歌词**
- 自动加载同目录 `.lrc` / `.vtt` / `.srt` 旁注、内嵌歌词与库内文本
- 同步滚动、字号 / 对齐 / 时间偏移调节（持久化）、手动导入
- 三种展示模式：封面隐藏式 / 停靠面板 / 沉浸全屏（长按解锁防误触）
- 桌面歌词悬浮窗（可拖动、字号可调，任意界面显示当前行）

**个性化**
- 24 种主题色即时切换，自动适配深浅模式
- 深浅色主题 + 跟随系统
- 界面语言：简体中文 / 繁體中文 / 日本語 / 한국어 / English
- 毛玻璃模糊背景、封面动效等视觉细节


## 📸 截图

> TODO: 发布前补充截图

## ⬇️ 下载

前往 [Releases](../../releases) 页面下载最新 APK。

## 🔨 从源码构建

```bash
git clone https://github.com/DankFlumeMister/whisplayer.git
cd whisplayer
flutter pub get
flutter build apk --release
# 产物位于 build/app/outputs/flutter-apk/app-release.apk
```

环境要求：

- Flutter **3.27+**（开发环境为 master 分支 `3.48.0-0.2.pre`，使用了 `Color.withValues` 等新 API）
- Android SDK（项目配置 compileSdk 37）

中国大陆网络下取包建议先设置镜像：

```bash
export PUB_HOSTED_URL=https://pub.flutter-io.cn
```

## 🖥 连接 Navidrome

1. 部署并启动 [Navidrome](https://www.navidrome.org)（或任意 Subsonic 兼容服务端）
2. 应用内：设置 → 远程音乐服务器 → 添加服务器地址与账号
3. 「测试连接」通过后保存；底部「云端」标签即可浏览与流播

## 🌐 语言

简体中文 · 繁體中文 · 日本語 · 한국어 · English

设置 → 语言 → 跟随系统或手动选择。

## 🗺 路线图

- [ ] WebDAV 音源
- [ ] 歌词编辑与打轴
- [ ] iOS 支持

## ⚠️ 免责声明

本项目不提供任何在线音源或内容分发能力，仅作为本地文件与**自建服务器**的播放客户端。使用本项目即表示你已确保所播放内容的合法性。

## 🤝 致谢

本项目由opencode协助开发。

## 📄 License

[MIT](LICENSE) © 2026 DankFlumeMister
