import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:whisplayer/app/app.dart';
import 'package:whisplayer/core/providers/playback_providers.dart';
import 'package:whisplayer/core/providers/startup_tab_provider.dart';
import 'package:whisplayer/features/player/application/player_controller.dart';
import 'package:whisplayer/features/settings/application/overlay_controller.dart';
import 'package:whisplayer/overlay/desktop_lyrics_overlay.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer();
  await container.read(playerBootstrapProvider.future);
  await container
      .read(playerControllerProvider.notifier)
      .restoreSession();
  await container.read(startupTabProvider.notifier).restore();
  container.read(overlayControllerProvider);
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const WhisplayerApp(),
    ),
  );
}

@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DesktopLyricsOverlayApp());
}
