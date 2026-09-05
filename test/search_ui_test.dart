import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:whisplayer/app/app.dart';
import 'package:whisplayer/core/providers/playback_providers.dart';
import 'package:whisplayer/core/providers/repository_providers.dart';
import 'package:whisplayer/domain/entities/song.dart';
import 'package:whisplayer/domain/entities/source_type.dart';
import 'package:whisplayer/features/player/application/player_controller.dart';
import 'package:whisplayer/features/player/presentation/player_page.dart';

import 'helpers/fakes.dart';

Song _song(int id, String title) => Song(
      id: id,
      path: '/tmp/$id.flac',
      sourceType: SourceType.local,
      title: title,
      fileName: '$id.flac',
      format: 'flac',
      durationMs: 180000,
      fileSizeBytes: 1024,
      addedAtMs: 0,
      modifiedAtMs: 0,
      playCount: 0,
      skipCount: 0,
      totalPlayMs: 0,
      lastPositionMs: 0,
      isFavorite: false,
    );

void main() {
  late FakeAudioEngine engine;
  late FakeSettingsRepository settings;

  Future<void> pumpApp(
    WidgetTester tester,
    List<Song> searchResults,
  ) async {
    engine = FakeAudioEngine();
    settings = FakeSettingsRepository();
    tester.platformDispatcher.localesTestValue = const [Locale('zh')];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryRepositoryProvider.overrideWithValue(
            FakeLibraryRepository(
              search: (query) =>
                  query.trim() == 'love' ? searchResults : const <Song>[],
            ),
          ),
          settingsRepositoryProvider.overrideWithValue(settings),
          playbackRecordRepositoryProvider.overrideWithValue(
            FakePlaybackRecordRepository(),
          ),
          audioEngineProvider.overrideWith((ref) => engine),
        ],
        child: const WhisplayerApp(),
      ),
    );
    await tester.pump();
    await tester.idle();
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('search results appear and tapping one starts playback',
      (tester) async {
    final results = [
      _song(1, 'Love Story'),
      _song(2, 'You Belong with Me'),
    ];
    await pumpApp(tester, results);

    await tester.tap(find.byIcon(Icons.search_rounded));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'love');
    await tester.pumpAndSettle();

    expect(find.text('Love Story'), findsOneWidget);
    expect(find.text('You Belong with Me'), findsOneWidget);

    await tester.tap(find.text('You Belong with Me'));
    await tester.pump(const Duration(seconds: 12));
    await tester.pumpAndSettle();

    expect(engine.openQueueCalled, isTrue);
    expect(engine.openedStartIndex, 1);
    expect(engine.playCalled, isTrue);
    expect(settings.values['playback.queue_json'], isNotNull);

    final container =
        ProviderScope.containerOf(tester.element(find.byType(WhisplayerApp)));
    final uiState = container.read(playerControllerProvider);
    expect(uiState.queue.length, 2);
    expect(uiState.currentIndex, 1);
    expect(uiState.currentSong?.title, 'You Belong with Me');
    expect(find.byType(PlayerPage), findsOneWidget);
  });

  testWidgets('search shows hint when no matches', (tester) async {
    await pumpApp(tester, []);

    await tester.tap(find.byIcon(Icons.search_rounded));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'nothing');
    await tester.pumpAndSettle();

    expect(find.text('未找到匹配的歌曲'), findsOneWidget);
  });
}
