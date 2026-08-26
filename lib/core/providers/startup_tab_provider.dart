import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:whisplayer/core/providers/repository_providers.dart';

/// Which bottom tab the app lands on at launch ('local' | 'cloud').
///
/// Restored synchronously-ish from settings in main() before runApp so
/// the router can pick its initial location without a visible jump.
/// Changing it in Settings takes effect on the next launch by design.
class StartupTab extends Notifier<String> {
  @override
  String build() => 'local';

  /// Loads the persisted choice; storage errors keep the default.
  Future<void> restore() async {
    try {
      final saved = await ref
          .read(settingsRepositoryProvider)
          .getString(keyStartupTab);
      if (saved == 'cloud') {
        state = 'cloud';
      }
    } on Exception {
      // Settings storage unavailable - default to the local tab.
    }
  }
}

final startupTabProvider =
    NotifierProvider<StartupTab, String>(StartupTab.new);

const String keyStartupTab = 'app.startup_tab';
