import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:whisplayer/core/providers/repository_providers.dart';
import 'package:whisplayer/core/theme/app_theme.dart';
import 'package:whisplayer/core/theme/theme_controller.dart';
import 'package:whisplayer/domain/repositories/settings_repository.dart';

class _InMemorySettings implements SettingsRepository {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> setString(String key, String? value) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<Map<String, String>> getAll() async => Map.of(values);
}

ProviderContainer _container(_InMemorySettings settings) {
  final container = ProviderContainer(
    overrides: [
      settingsRepositoryProvider.overrideWithValue(settings),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _settle() async {
  await pumpEventQueue();
}

void main() {
  test('setMode and setSeed update state and persist', () async {
    final settings = _InMemorySettings();
    final container = _container(settings);
    final controller = container.read(themeControllerProvider.notifier);
    await _settle();

    await controller.setMode(ThemeMode.dark);
    final seed = AppTheme.palettes
        .firstWhere((p) => p.seed != AppTheme.defaultSeed)
        .seed;
    await controller.setSeed(seed);
    await _settle();

    final state = container.read(themeControllerProvider);
    expect(state.mode, ThemeMode.dark);
    expect(state.seed, seed);
    expect(settings.values['theme.mode'], 'dark');
    expect(settings.values['theme.seed'], '${seed.toARGB32()}');
  });

  test('restores persisted mode and seed on startup', () async {
    final seed = AppTheme.palettes
        .firstWhere((p) => p.seed != AppTheme.defaultSeed)
        .seed;
    final settings = _InMemorySettings()
      ..values['theme.mode'] = 'light'
      ..values['theme.seed'] = '${seed.toARGB32()}';

    final container = _container(settings)
      ..read(themeControllerProvider);
    await _settle();

    final state = container.read(themeControllerProvider);
    expect(state.mode, ThemeMode.light);
    expect(state.seed, seed);
  });

  test('unknown persisted seed falls back to default', () async {
    final settings = _InMemorySettings()
      ..values['theme.mode'] = 'bogus'
      ..values['theme.seed'] = '12345';

    final container = _container(settings)
      ..read(themeControllerProvider);
    await _settle();

    final state = container.read(themeControllerProvider);
    expect(state.mode, ThemeMode.system);
    expect(state.seed, AppTheme.defaultSeed);
  });

  test('palette list contains the default seed', () {
    expect(
      AppTheme.palettes.any((p) => p.seed == AppTheme.defaultSeed),
      isTrue,
    );
  });
}
