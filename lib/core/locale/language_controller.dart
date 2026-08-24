import 'dart:async';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:whisplayer/core/providers/repository_providers.dart';

const _keyLocale = 'app.locale';

/// App display locale; `locale == null` means follow the system.
class LocaleState {
  const LocaleState({this.locale});

  final Locale? locale;
}

class LanguageController extends Notifier<LocaleState> {
  bool _restored = false;

  @override
  LocaleState build() {
    unawaited(_restore());
    return const LocaleState();
  }

  Future<void> _restore() async {
    if (_restored) {
      return;
    }
    _restored = true;
    try {
      final saved =
          await ref.read(settingsRepositoryProvider).getString(_keyLocale);
      if (saved == null || saved == 'system') {
        return;
      }
      final locale = _parse(saved);
      if (locale != null && locale != state.locale) {
        state = LocaleState(locale: locale);
      }
    } on Exception catch (_) {
      // Settings unavailable; follow the system.
    }
  }

  Future<void> setLocale(Locale? locale) async {
    if (locale == state.locale) {
      return;
    }
    state = LocaleState(locale: locale);
    await ref
        .read(settingsRepositoryProvider)
        .setString(_keyLocale, locale?.toString() ?? 'system');
  }

  static Locale? _parse(String tag) {
    final parts = tag.split('_');
    if (parts.isEmpty || parts.first.isEmpty) {
      return null;
    }
    return parts.length > 1
        ? Locale(parts.first, parts.sublist(1).join('_'))
        : Locale(parts.first);
  }
}

final languageControllerProvider =
    NotifierProvider<LanguageController, LocaleState>(
  LanguageController.new,
);
