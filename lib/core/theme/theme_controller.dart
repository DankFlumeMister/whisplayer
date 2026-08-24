import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:whisplayer/core/providers/repository_providers.dart';
import 'package:whisplayer/core/theme/app_theme.dart';

const _keyMode = 'theme.mode';
const _keySeed = 'theme.seed';

/// Immutable appearance state: light/dark/system mode plus the Material 3
/// seed color every surface derives from.
class ThemeState {
  const ThemeState({
    this.mode = ThemeMode.system,
    this.seed = AppTheme.defaultSeed,
  });

  final ThemeMode mode;
  final Color seed;

  ThemeState copyWith({ThemeMode? mode, Color? seed}) {
    return ThemeState(
      mode: mode ?? this.mode,
      seed: seed ?? this.seed,
    );
  }
}

class ThemeController extends Notifier<ThemeState> {
  bool _restored = false;

  @override
  ThemeState build() {
    // Restored asynchronously right after the first frame; until then the
    // defaults below are shown (same pattern as lyrics settings).
    unawaited(_restore());
    return const ThemeState();
  }

  Future<void> _restore() async {
    if (_restored) {
      return;
    }
    _restored = true;
    try {
      final repo = ref.read(settingsRepositoryProvider);
      final modeName = await repo.getString(_keyMode);
      var mode = ThemeMode.system;
      for (final candidate in ThemeMode.values) {
        if (candidate.name == modeName) {
          mode = candidate;
        }
      }
      final argb = int.tryParse(await repo.getString(_keySeed) ?? '');
      var seed = AppTheme.defaultSeed;
      if (argb != null) {
        for (final palette in AppTheme.palettes) {
          if (palette.seed.toARGB32() == argb) {
            seed = palette.seed;
          }
        }
      }
      if (mode != state.mode || seed != state.seed) {
        state = state.copyWith(mode: mode, seed: seed);
      }
    } on Exception catch (_) {
      // Settings unavailable (e.g. widget tests without overrides);
      // defaults are fine.
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    if (mode == state.mode) {
      return;
    }
    state = state.copyWith(mode: mode);
    await ref.read(settingsRepositoryProvider).setString(_keyMode, mode.name);
  }

  Future<void> setSeed(Color seed) async {
    if (seed == state.seed) {
      return;
    }
    state = state.copyWith(seed: seed);
    await ref
        .read(settingsRepositoryProvider)
        .setString(_keySeed, seed.toARGB32().toString());
  }
}

final themeControllerProvider =
    NotifierProvider<ThemeController, ThemeState>(ThemeController.new);
