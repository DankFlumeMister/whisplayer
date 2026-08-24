import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:whisplayer/core/providers/repository_providers.dart';

const _keyFontSize = 'desktop_lyrics.font_size';
const double minOverlayFontSize = 14;
const double maxOverlayFontSize = 36;

/// Desktop-lyrics overlay font size in sp, persisted and pushed to the
/// overlay isolate through the shareData payload.
class OverlayFontSizeController extends Notifier<double> {
  bool _restored = false;

  @override
  double build() {
    unawaited(_restore());
    return 22;
  }

  Future<void> _restore() async {
    if (_restored) {
      return;
    }
    _restored = true;
    try {
      final saved = await ref
          .read(settingsRepositoryProvider)
          .getString(_keyFontSize);
      final value = double.tryParse(saved ?? '');
      if (value != null) {
        state = value.clamp(minOverlayFontSize, maxOverlayFontSize);
      }
    } on Exception catch (_) {
      // Settings unavailable; keep the default.
    }
  }

  Future<void> set(double size) async {
    final next = size.clamp(minOverlayFontSize, maxOverlayFontSize);
    if (next == state) {
      return;
    }
    state = next;
    await ref
        .read(settingsRepositoryProvider)
        .setString(_keyFontSize, next.toString());
  }
}

final overlayFontSizeProvider =
    NotifierProvider<OverlayFontSizeController, double>(
  OverlayFontSizeController.new,
);
