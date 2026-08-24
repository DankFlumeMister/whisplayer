import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:whisplayer/core/providers/repository_providers.dart';
import 'package:whisplayer/features/player/application/lyrics_controller.dart';
import 'package:whisplayer/features/player/application/player_controller.dart';

const _keyEnabled = 'desktop_lyrics.enabled';

class OverlayController extends Notifier<bool> {
  bool _restored = false;
  String? _lastPayload;
  int _pushRetries = 0;

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
      height: 150,
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

  Future<void> pushCurrentLine() async {
    if (!state) {
      return;
    }
    final lyrics = ref.read(lyricsControllerProvider);
    final player = ref.read(playerControllerProvider);
    final song = player.currentSong;

    String line;
    switch (lyrics.status) {
      case LyricsStatus.synced:
        final index = lyrics.activeIndex;
        line = index >= 0 && index < lyrics.document.lines.length
            ? lyrics.document.lines[index].text.replaceAll('\n', ' ')
            : '…';
      case LyricsStatus.unsynced:
        line = '（纯文本歌词，暂不支持同步滚动）';
      case LyricsStatus.none ||
          LyricsStatus.idle ||
          LyricsStatus.loading:
        line = '';
    }

    final payload = jsonEncode({
      'title': song?.title ?? '',
      'line': line,
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
