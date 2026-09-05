import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:whisplayer/app/app.dart';
import 'package:whisplayer/core/locale/language_controller.dart';
import 'package:whisplayer/core/providers/repository_providers.dart';
import 'package:whisplayer/core/providers/startup_tab_provider.dart';

import 'helpers/fakes.dart';

class _CloudStartupTab extends StartupTab {
  @override
  String build() => 'cloud';
}

class _ZhLanguageController extends LanguageController {
  @override
  LocaleState build() => const LocaleState(locale: Locale('zh'));

  @override
  Future<void> setLocale(Locale? locale) async {}
}

void main() {
  Future<void> pumpApp(
    WidgetTester tester, {
    List<Override> extraOverrides = const [],
  }) async {
    // Pin zh so l10n-driven labels match the Chinese assertions below.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryRepositoryProvider.overrideWithValue(
            FakeLibraryRepository(),
          ),
          languageControllerProvider.overrideWith(_ZhLanguageController.new),
          ...extraOverrides,
        ],
        child: const WhisplayerApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('app shell renders library tab by default', (tester) async {
    await pumpApp(tester);
    expect(find.text('本地'), findsOneWidget);
    expect(find.text('云端'), findsOneWidget);
    expect(find.text('播放列表'), findsWidgets);
  });

  testWidgets('library switches between four views', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('专辑'));
    await tester.pump();
    expect(find.text('暂无专辑'), findsOneWidget);

    await tester.tap(find.text('艺术家'));
    await tester.pump();
    expect(find.text('暂无艺术家'), findsOneWidget);

    await tester.tap(find.text('文件夹'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('暂无文件夹'), findsOneWidget);
  });

  testWidgets('theme switcher updates theme mode', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byTooltip('设置'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    await tester.tap(find.text('外观'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final context =
        tester.element(find.byType(SegmentedButton<ThemeMode>));
    expect(Theme.of(context).brightness, Brightness.light);

    final darkSegment = find.text('深色');
    await tester.ensureVisible(darkSegment);
    await tester.pump();
    await tester.tap(darkSegment, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    final darkContext = tester.element(
      find.byType(SegmentedButton<ThemeMode>),
    );
    expect(Theme.of(darkContext).brightness, Brightness.dark);
  });

  testWidgets('startup tab preference lands on the cloud branch',
      (tester) async {
    await pumpApp(
      tester,
      extraOverrides: [
        startupTabProvider.overrideWith(_CloudStartupTab.new),
      ],
    );
    expect(find.text('云端音乐'), findsOneWidget);
  });
}
