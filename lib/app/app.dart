import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:whisplayer/app/router/app_router.dart';
import 'package:whisplayer/core/theme/app_theme.dart';
import 'package:whisplayer/core/theme/theme_controller.dart';

class WhisplayerApp extends ConsumerWidget {
  const WhisplayerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeControllerProvider);
    return MaterialApp.router(
      title: 'Whisplayer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(seed: theme.seed),
      darkTheme: AppTheme.dark(seed: theme.seed),
      themeMode: theme.mode,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
