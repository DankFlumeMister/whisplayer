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

class _RecordingLibraryRepository implements LibraryRepository {
  _RecordingLibraryRepository(this.songs);

  final List<Song> songs;
  final plays = <String>[];

  @override
  Future<void> recordPlayback({
    required int songId,
    required int playedMs,
    required int playedAtMs,
    required bool completed,
  }) async {
    plays.add('$songId:$playedMs:$completed');
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
    return Stream.value(songs);
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

class _ControllableEngine implements AudioEngine {
  final _snapshots = StreamController<PlaybackSnapshot>.broadcast();

  void emit(PlaybackSnapshot snap) => _snapshots.add(snap);

  @override
  Stream<PlaybackSnapshot> get snapshots => _snapshots.stream;

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
  void setLoopMode(PlaybackLoopMode mode) {}

  @override
  Future<void> dispose() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Same zone guard as player_restore_test.dart: touching the media
  // session bootstrap in tests emits delayed platform-channel errors
  // that would otherwise fail green assertions after teardown.
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

  Future<void> settle() async {
    await pumpEventQueue();
    await pumpEventQueue();
  }

  test('natural completion records exactly one full listen',
      () => runGuarded(() async {
            final engine = _ControllableEngine();
            final library =
                _RecordingLibraryRepository([_song(1)]);
            final container = ProviderContainer(
              overrides: [
                libraryRepositoryProvider.overrideWithValue(library),
                settingsRepositoryProvider.overrideWithValue(
                  _FakeSettingsRepository(),
                ),
                audioEngineProvider.overrideWith((ref) => engine),
              ],
            );
            addTearDown(container.dispose);

            final notifier =
                container.read(playerControllerProvider.notifier);
            await notifier.restoreSession();
            await notifier.playSongs([_song(1)]);

            engine.emit(
              const PlaybackSnapshot(
                state: EngineState.ready,
                playing: true,
                positionMs: 5000,
                queueIndex: 0,
              ),
            );
            await settle();
            expect(library.plays, isEmpty);

            engine.emit(
              const PlaybackSnapshot(
                state: EngineState.completed,
                positionMs: 180000,
                queueIndex: 0,
              ),
            );
            await settle();
            expect(library.plays, ['1:180000:true']);
          }));

  test('skipping away mid-song records an incomplete listen',
      () => runGuarded(() async {
            final engine = _ControllableEngine();
            final library =
                _RecordingLibraryRepository([_song(1), _song(2)]);
            final container = ProviderContainer(
              overrides: [
                libraryRepositoryProvider.overrideWithValue(library),
                settingsRepositoryProvider.overrideWithValue(
                  _FakeSettingsRepository(),
                ),
                audioEngineProvider.overrideWith((ref) => engine),
              ],
            );
            addTearDown(container.dispose);

            final notifier =
                container.read(playerControllerProvider.notifier);
            await notifier.restoreSession();
            await notifier.playSongs([_song(1), _song(2)]);

            engine.emit(
              const PlaybackSnapshot(
                state: EngineState.ready,
                playing: true,
                positionMs: 30000,
                queueIndex: 0,
              ),
            );
            await settle();
            engine.emit(
              const PlaybackSnapshot(
                state: EngineState.ready,
                playing: true,
                queueIndex: 1,
              ),
            );
            await settle();

            expect(library.plays, ['1:30000:false']);
          }));

  test('completion followed by auto-advance is not double recorded',
      () => runGuarded(() async {
            final engine = _ControllableEngine();
            final library =
                _RecordingLibraryRepository([_song(1), _song(2)]);
            final container = ProviderContainer(
              overrides: [
                libraryRepositoryProvider.overrideWithValue(library),
                settingsRepositoryProvider.overrideWithValue(
                  _FakeSettingsRepository(),
                ),
                audioEngineProvider.overrideWith((ref) => engine),
              ],
            );
            addTearDown(container.dispose);

            final notifier =
                container.read(playerControllerProvider.notifier);
            await notifier.restoreSession();
            await notifier.playSongs([_song(1), _song(2)]);

            engine.emit(
              const PlaybackSnapshot(
                state: EngineState.ready,
                playing: true,
                positionMs: 179000,
                queueIndex: 0,
              ),
            );
            await settle();
            engine.emit(
              const PlaybackSnapshot(
                state: EngineState.completed,
                positionMs: 180000,
                queueIndex: 0,
              ),
            );
            await settle();
            engine.emit(
              const PlaybackSnapshot(
                state: EngineState.ready,
                playing: true,
                queueIndex: 1,
              ),
            );
            await settle();

            expect(library.plays, ['1:180000:true']);
          }));

  test('native loop-one wrap records every finished playthrough',
      () => runGuarded(() async {
            final engine = _ControllableEngine();
            final library = _RecordingLibraryRepository([_song(1)]);
            final container = ProviderContainer(
              overrides: [
                libraryRepositoryProvider.overrideWithValue(library),
                settingsRepositoryProvider.overrideWithValue(
                  _FakeSettingsRepository(),
                ),
                audioEngineProvider.overrideWith((ref) => engine),
              ],
            );
            addTearDown(container.dispose);

            final notifier =
                container.read(playerControllerProvider.notifier);
            await notifier.restoreSession();
            await notifier.playSongs([_song(1)]);

            const playing = EngineState.ready;
            engine.emit(
              const PlaybackSnapshot(
                state: playing,
                playing: true,
                positionMs: 100000,
                queueIndex: 0,
              ),
            );
            await settle();
            engine.emit(
              const PlaybackSnapshot(
                state: playing,
                playing: true,
                positionMs: 1000,
                queueIndex: 0,
              ),
            );
            await settle();
            engine.emit(
              const PlaybackSnapshot(
                state: playing,
                playing: true,
                positionMs: 150000,
                queueIndex: 0,
              ),
            );
            await settle();
            engine.emit(
              const PlaybackSnapshot(
                state: playing,
                playing: true,
                positionMs: 800,
                queueIndex: 0,
              ),
            );
            await settle();

            expect(
              library.plays,
              ['1:180000:true', '1:180000:true'],
            );
          }));
}
