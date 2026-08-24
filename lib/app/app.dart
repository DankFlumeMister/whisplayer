import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:whisplayer/app/router/app_router.dart';
import 'package:whisplayer/core/locale/language_controller.dart';
import 'package:whisplayer/core/theme/app_theme.dart';
import 'package:whisplayer/core/theme/theme_controller.dart';
import 'package:whisplayer/l10n/app_localizations.dart';

class WhisplayerApp extends ConsumerWidget {
  const WhisplayerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeControllerProvider);
    final localeState = ref.watch(languageControllerProvider);
    return MaterialApp.router(
      title: 'Whisplayer',
      debugShowCheckedModeBanner: false,
      locale: localeState.locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light(seed: theme.seed),
      darkTheme: AppTheme.dark(seed: theme.seed),
      themeMode: theme.mode,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
