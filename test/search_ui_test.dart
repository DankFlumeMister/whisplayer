import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:whisplayer/app/app.dart';
import 'package:whisplayer/core/providers/playback_providers.dart';
import 'package:whisplayer/core/providers/repository_providers.dart';
import 'package:whisplayer/domain/entities/album.dart';
import 'package:whisplayer/domain/entities/artist.dart';
import 'package:whisplayer/domain/entities/playback.dart';
import 'package:whisplayer/domain/entities/song.dart';
import 'package:whisplayer/domain/entities/source_type.dart';
import 'package:whisplayer/domain/repositories/audio_engine.dart';
import 'package:whisplayer/domain/repositories/library_repository.dart';
import 'package:whisplayer/domain/repositories/settings_repository.dart';
import 'package:whisplayer/features/player/application/player_controller.dart';
import 'package:whisplayer/features/player/presentation/player_page.dart';

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

class _FakeLibraryRepository implements LibraryRepository {
  _FakeLibraryRepository(this.searchResults);

  final List<Song> searchResults;

  @override
  Future<List<Song>> getAllSongs() async => [];

  @override
  Future<Song?> getLastPlayedSong() async => null;

  @override
  Future<Song?> getSong(int songId) async => null;

  @override
  Stream<List<Album>> watchAlbums() => Stream.value(const <Album>[]);

  @override
  Stream<List<Artist>> watchArtists() => Stream.value(const <Artist>[]);

  @override
  Stream<List<Song>> watchSongs({
    SongSort sort = SongSort.title,
    bool descending = false,
  }) {
    return Stream.value(const <Song>[]);
  }

  @override
  Stream<List<Song>> watchLocalSongs({
    SongSort sort = SongSort.title,
    bool descending = false,
  }) {
    return Stream.value(const <Song>[]);
  }

  @override
  Future<List<Song>> searchLocalSongs(String query) async =>
      query.trim() == 'love' ? searchResults : const <Song>[];

  @override
  Future<int> removeSongsMissingFrom(Set<String> validPaths) async => 0;

  @override
  Future<void> savePosition({
    required int songId,
    required int positionMs,
  }) async {}

  @override
  Future<void> recordPlayback({
    required int songId,
    required int playedMs,
    required int playedAtMs,
    required bool completed,
  }) async {}

  @override
  Future<List<Song>> searchSongs(String query) async =>
      query.trim() == 'love' ? searchResults : [];

  @override
  Future<void> setFavorite(int songId, {required bool favorite}) async {}

  @override
  Future<List<Song>> songsByAlbum(int albumId) async => [];

  @override
  Future<List<Song>> songsByArtist(int artistId) async => [];
}

class _FakeSettingsRepository implements SettingsRepository {
  final Map<String, String?> values = {};

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> setString(String key, String? value) async {
    values[key] = value;
  }

  @override
  Future<Map<String, String>> getAll() async => {
        for (final entry in values.entries)
          if (entry.value != null) entry.key: entry.value!,
      };
}

class _FakeAudioEngine implements AudioEngine {
  bool openQueueCalled = false;
  bool playCalled = false;
  int openedStartIndex = -1;

  @override
  Stream<PlaybackSnapshot> get snapshots => const Stream.empty();

  @override
  PlaybackSnapshot get current => const PlaybackSnapshot();

  @override
  Future<void> openQueue({
    required List<String> uris,
    required int startIndex,
    int? startPositionMs,
  }) async {
    openQueueCalled = true;
    openedStartIndex = startIndex;
  }

  @override
  Future<void> play() async {
    playCalled = true;
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> skipToIndex(int index) async {}

  @override
  void setLoopMode(PlaybackLoopMode mode) {}

  @override
  Future<void> dispose() async {}
}

void main() {
  late _FakeAudioEngine engine;
  late _FakeSettingsRepository settings;

  Future<void> pumpApp(
    WidgetTester tester,
    List<Song> searchResults,
  ) async {
    engine = _FakeAudioEngine();
    settings = _FakeSettingsRepository();
    tester.platformDispatcher.localesTestValue = const [Locale('zh')];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryRepositoryProvider.overrideWithValue(
            _FakeLibraryRepository(searchResults),
          ),
          settingsRepositoryProvider.overrideWithValue(settings),
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
