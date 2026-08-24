import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:whisplayer/core/providers/repository_providers.dart';
import 'package:whisplayer/features/player/application/lyrics_controller.dart';
import 'package:whisplayer/features/player/application/player_controller.dart';
import 'package:whisplayer/features/settings/application/theme_font_size.dart';

const _keyEnabled = 'desktop_lyrics.enabled';

class OverlayController extends Notifier<bool> {
  bool _restored = false;
  String? _lastPayload;
  int _pushRetries = 0;
  int? _lastHeightPx;

  @override
  bool build() {
    ref.listen(
      lyricsControllerProvider
          .select((state) => (state.activeIndex, state.status)),
      (_, __) => pushCurrentLine(),
    );
    unawaited(_restore());
    return false;
  }

  /// Current lyric line rendered into the overlay (empty when none).
  String _currentLine() {
    final lyrics = ref.read(lyricsControllerProvider);
    switch (lyrics.status) {
      case LyricsStatus.synced:
        final index = lyrics.activeIndex;
        return index >= 0 && index < lyrics.document.lines.length
            ? lyrics.document.lines[index].text.replaceAll('\n', ' ')
            : '…';
      case LyricsStatus.unsynced:
        return '（纯文本歌词，暂不支持同步滚动）';
      case LyricsStatus.none ||
          LyricsStatus.idle ||
          LyricsStatus.loading:
        return '';
    }
  }

  Future<void> _restore() async {
    if (_restored) {
      return;
    }
    _restored = true;
    final settings = ref.read(settingsRepositoryProvider);
    final saved = await settings.getString(_keyEnabled);
    if (saved != 'true') {
      return;
    }
    if (!await FlutterOverlayWindow.isPermissionGranted()) {
      return;
    }
    await _show();
    state = true;
  }

  /// Returns true when the requested state was applied.
  Future<bool> setEnabled({required bool value}) async {
    if (value == state) {
      return true;
    }
    if (value) {
      if (!await FlutterOverlayWindow.isPermissionGranted()) {
        await FlutterOverlayWindow.requestPermission();
        if (!await FlutterOverlayWindow.isPermissionGranted()) {
          return false;
        }
      }
      try {
        await _show();
      } on Exception {
        return false;
      }
      state = true;
    } else {
      await FlutterOverlayWindow.closeOverlay();
      state = false;
    }
    await ref
        .read(settingsRepositoryProvider)
        .setString(_keyEnabled, value ? 'true' : null);
    return true;
  }

  Future<void> _show() async {
    // The plugin's service mis-handles a second start while a stale
    // instance is alive (remove + stopSelf + re-add kills the fresh view).
    // Close cleanly first so the final action is a single fresh start.
    // NOTE: never call closeOverlay blindly — its native handler never
    // replies when no service is running, which would hang this await.
    try {
      if (await FlutterOverlayWindow.isActive()) {
        await FlutterOverlayWindow.closeOverlay();
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
    } on Exception {
      // Nothing running; ignore.
    }
    await FlutterOverlayWindow.showOverlay(
      // Height must scale with the configurable font size AND the actual
      // line length (long lines wrap to two rows); the plugin takes
      // physical pixels here.
      height: _heightPxFor(
        ref.read(overlayFontSizeProvider),
        _currentLine(),
      ),
      alignment: OverlayAlignment.bottomCenter,
      enableDrag: true,
      positionGravity: PositionGravity.auto,
      overlayTitle: 'Whisplayer 桌面歌词',
      overlayContent: '正在显示桌面歌词',
      // The plugin double-scales the default bottom offset (pixel status-bar
      // height fed through dpToPx), pushing the window fully off-screen on
      // high-density devices. Supply an explicit upward offset in dp so the
      // bar rests ~140px above the bottom edge on any density.
      startPosition: OverlayPosition(0, _bottomLiftDp()),
    );
    // The overlay engine boots asynchronously; resend a few times so the
    // first render picks up the current line even if early sends are lost.
    await pushCurrentLine();
    for (final delay in const [
      Duration(milliseconds: 600),
      Duration(milliseconds: 1500),
      Duration(seconds: 3),
    ]) {
      Timer(delay, () {
        if (state) {
          _lastPayload = null;
          unawaited(pushCurrentLine());
        }
      });
    }
  }

  /// Vertical offset (dp) placing the bar around 2/3 of screen height.
  ///
  /// The native side applies `y` with BOTTOM gravity where positive moves
  /// the window up; we compute from real physical size and pixel ratio so
  /// the bar rests near the upper third boundary on any device.
  static double _bottomLiftDp() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    final dpr = views.isNotEmpty ? views.first.devicePixelRatio : 3.0;
    final physicalHeight =
        views.isNotEmpty ? views.first.physicalSize.height : 0.0;
    const fallbackLiftPx = 140.0;
    final liftPx = physicalHeight > 0
        ? physicalHeight / 3
        : fallbackLiftPx;
    final dp = liftPx / dpr;
    return dp < 8 ? 8 : dp;
  }

  /// Overlay window height in physical pixels for [fontSize] rendering
  /// [line]: estimates wrapped line count (the overlay Text allows 2 lines)
  /// so long lyrics grow the window instead of clipping at the bottom.
  static int _heightPxFor(double fontSize, String line) {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    final dpr = views.isNotEmpty ? views.first.devicePixelRatio : 3.0;
    final screenWidthDp = views.isNotEmpty
        ? views.first.physicalSize.width / dpr
        : 360.0;
    // Horizontal chrome: 16 margin ×2 + 20 padding ×2.
    final maxTextWidthDp =
        (screenWidthDp - 72).clamp(120.0, screenWidthDp);
    // Weighted length: CJK/full-width ≈ 1 em, ASCII ≈ 0.55 em.
    var em = line.isEmpty ? 1.0 : 0.0;
    for (final rune in line.runes) {
      em += rune > 0x2e7f ? 1.0 : 0.55;
    }
    final charsPerLine = (maxTextWidthDp / fontSize).clamp(1.0, 1000.0);
    final textLines = (em / charsPerLine).ceil().clamp(1, 2);
    // 1.25× line height × wrapped lines + 10 vertical padding ×2 + buffer.
    final logical = textLines * fontSize * 1.25 + 34;
    return (logical * dpr).round().clamp(120, 800);
  }

  static int _screenWidthPx() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    return views.isNotEmpty
        ? views.first.physicalSize.width.round()
        : 0;
  }

  /// Resizes the overlay window when the required height for [line]
  /// changes (long lines wrap to two rows and need more room).
  Future<void> _syncHeight(double fontSize, String line) async {
    final height = _heightPxFor(fontSize, line);
    if (height == _lastHeightPx) {
      return;
    }
    final width = _screenWidthPx();
    if (width <= 0) {
      return;
    }
    try {
      await FlutterOverlayWindow.resizeOverlay(width, height, true);
      _lastHeightPx = height;
    } on Exception {
      // Window not up yet; the next push retries.
    }
  }

  /// Re-fits the overlay window after a font-size change so larger sizes
  /// are not clipped at the bottom. No-op while the overlay is hidden.
  Future<void> applyFontSize(double fontSize) async {
    if (!state) {
      return;
    }
    final line = _currentLine();
    await _syncHeight(fontSize, line);
    await pushCurrentLine();
  }

  Future<void> pushCurrentLine() async {
    if (!state) {
      return;
    }
    final fontSize = ref.read(overlayFontSizeProvider);
    final line = _currentLine();
    final song = ref.read(playerControllerProvider).currentSong;

    await _syncHeight(fontSize, line);

    final payload = jsonEncode({
      'title': song?.title ?? '',
      'line': line,
      'fontSize': fontSize,
    });
    if (payload == _lastPayload) {
      return;
    }
    _lastPayload = payload;
    try {
      await FlutterOverlayWindow.shareData(payload);
      _pushRetries = 0;
    } on Exception {
      // Overlay channel not ready yet; retry a few times so an early
      // send is not lost until the next lyric-line change. Capped to
      // avoid looping forever when the service never comes up.
      _lastPayload = null;
      if (_pushRetries < 5) {
        _pushRetries++;
        Timer(const Duration(milliseconds: 300), () {
          if (state) {
            unawaited(pushCurrentLine());
          }
        });
      }
    }
  }
}

final overlayControllerProvider =
    NotifierProvider<OverlayController, bool>(OverlayController.new);
