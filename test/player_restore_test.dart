import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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

Song _song(int id) => Song(
      id: id,
      path: '/tmp/$id.flac',
      sourceType: SourceType.local,
      title: 'Song $id',
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
  _FakeLibraryRepository(this.songs);

  final List<Song> songs;
  final recordedPlays = <String>[];

  @override
  Future<void> recordPlayback({
    required int songId,
    required int playedMs,
    required int playedAtMs,
    required bool completed,
  }) async {
    recordedPlays.add('$songId:$playedMs:$completed');
  }

  @override
  Future<List<Song>> getAllSongs() async => songs;

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
    return watchSongs(sort: sort, descending: descending);
  }

  @override
  Future<List<Song>> searchLocalSongs(String query) => searchSongs(query);
  @override
  Future<int> removeSongsMissingFrom(Set<String> validPaths) async => 0;

  @override
  Future<void> savePosition({
    required int songId,
    required int positionMs,
  }) async {}

  @override
  Future<List<Song>> searchSongs(String query) async => [];

  @override
  Future<void> setFavorite(int songId, {required bool favorite}) async {}

  @override
  Future<List<Song>> songsByAlbum(int albumId) async => [];

  @override
  Future<List<Song>> songsByArtist(int artistId) async => [];
}

class _FakeSettingsRepository implements SettingsRepository {
  _FakeSettingsRepository([Map<String, String>? initial])
      : values = initial ?? {};

  final Map<String, String> values;

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

class _FakeAudioEngine implements AudioEngine {
  int setLoopModeCalls = 0;
  PlaybackLoopMode? lastLoopMode;

  @override
  Stream<PlaybackSnapshot> get snapshots => const Stream.empty();

  @override
  PlaybackSnapshot get current => const PlaybackSnapshot();

  @override
  Future<void> openQueue({
    required List<String> uris,
    required int startIndex,
    int? startPositionMs,
  }) async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> skipToIndex(int index) async {}

  @override
  void setLoopMode(PlaybackLoopMode mode) {
    setLoopModeCalls++;
    lastLoopMode = mode;
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // audio_service emits delayed platform-channel errors once its bootstrap
  // is touched; they escape after the test body finishes. Guard the zone
  // so plugin noise cannot fail otherwise-green restore assertions.
  Future<void> runGuarded(Future<void> Function() body) {
    final done = Completer<void>();
    runZonedGuarded(
      () async {
        await body();
        if (!done.isCompleted) done.complete();
      },
      (_, __) {
        if (!done.isCompleted) done.complete();
      },
    );
    return done.future;
  }

  ProviderContainer makeContainer({
    required List<Song> songs,
    required _FakeAudioEngine engine,
    Map<String, String> settings = const {},
  }) {
    final container = ProviderContainer(
      overrides: [
        libraryRepositoryProvider.overrideWithValue(
          _FakeLibraryRepository(songs),
        ),
        settingsRepositoryProvider.overrideWithValue(
          _FakeSettingsRepository(Map.of(settings)),
        ),
        audioEngineProvider.overrideWith((ref) => engine),
      ],
    );
    return container;
  }

  test('restoreSession rebuilds queue, clamps index and restores loop',
      () => runGuarded(() async {
            final engine = _FakeAudioEngine();
            final container = makeContainer(
              songs: [_song(1), _song(2), _song(3)],
              settings: const {
                'playback.queue_json': '[1,999,2]',
                'playback.index': '5',
                'playback.position_ms': '42000',
                'playback.loop_mode': 'one',
              },
              engine: engine,
            );
            addTearDown(container.dispose);

            await container
                .read(playerControllerProvider.notifier)
                .restoreSession();

            final state = container.read(playerControllerProvider);
            expect(state.queue.map((s) => s.id).toList(), [1, 2]);
            expect(state.currentIndex, 0);
            expect(state.loopMode, PlaybackLoopMode.one);
            expect(engine.lastLoopMode, PlaybackLoopMode.one);
          }));

  test('restoreSession without saved data yields empty idle state',
      () => runGuarded(() async {
            final engine = _FakeAudioEngine();
            final container = makeContainer(
              songs: [_song(1)],
              engine: engine,
            );
            addTearDown(container.dispose);

            await container
                .read(playerControllerProvider.notifier)
                .restoreSession();

            final state = container.read(playerControllerProvider);
            expect(state.queue, isEmpty);
            expect(state.currentIndex, -1);
            expect(state.loopMode, PlaybackLoopMode.off);
          }));

  test('restoreSession is idempotent',
      () => runGuarded(() async {
            final engine = _FakeAudioEngine();
            final container = makeContainer(
              songs: [_song(1), _song(2)],
              settings: const {
                'playback.queue_json': '[2,1]',
                'playback.index': '1',
                'playback.loop_mode': 'all',
              },
              engine: engine,
            );
            addTearDown(container.dispose);

            final notifier =
                container.read(playerControllerProvider.notifier);
            await notifier.restoreSession();
            await notifier.restoreSession();
            await notifier.restoreSession();

            expect(engine.setLoopModeCalls, 1);
            final state = container.read(playerControllerProvider);
            expect(state.queue.map((s) => s.id).toList(), [2, 1]);
            expect(state.currentIndex, 1);
          }));
}
