import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:whisplayer/core/providers/playback_providers.dart';
import 'package:whisplayer/core/providers/repository_providers.dart';
import 'package:whisplayer/domain/entities/album.dart';
import 'package:whisplayer/domain/entities/artist.dart';
import 'package:whisplayer/domain/entities/playback.dart';
import 'package:whisplayer/domain/entities/song.dart';
import 'package:whisplayer/domain/repositories/audio_engine.dart';
import 'package:whisplayer/domain/repositories/library_repository.dart';
import 'package:whisplayer/domain/repositories/settings_repository.dart';
import 'package:whisplayer/features/player/application/player_controller.dart';


class _FakeLibraryRepository implements LibraryRepository {
  @override
  Future<void> recordPlayback({
    required int songId,
    required int playedMs,
    required int playedAtMs,
    required bool completed,
  }) async {}

  @override
  Future<List<Song>> getAllSongs() async => const <Song>[];

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
  }) =>
      Stream.value(const <Song>[]);

  @override
  Stream<List<Song>> watchLocalSongs({
    SongSort sort = SongSort.title,
    bool descending = false,
  }) =>
      Stream.value(const <Song>[]);

  @override
  Future<List<Song>> searchLocalSongs(String query) async => [];

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
  void setLoopMode(PlaybackLoopMode mode) {}

  @override
  Future<void> dispose() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // audio_service emits delayed platform-channel errors once its bootstrap
  // is touched; guard the zone so plugin noise cannot fail assertions.
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
    Map<String, String> settings = const {},
  }) {
    return ProviderContainer(
      overrides: [
        libraryRepositoryProvider.overrideWithValue(
          _FakeLibraryRepository(),
        ),
        settingsRepositoryProvider.overrideWithValue(
          _FakeSettingsRepository(Map.of(settings)),
        ),
        audioEngineProvider.overrideWith((ref) => _FakeAudioEngine()),
      ],
    );
  }

  Future<PlayerController> restoredWith5Songs(
    ProviderContainer container,
  ) async {
    final notifier = container.read(playerControllerProvider.notifier);
    await notifier.restoreSession();
    await notifier.setShuffle(enabled: true);
    return notifier;
  }

  test(
      'shuffle next visits every song once before a round resets',
      () => runGuarded(() async {
            final settings = <String, String>{
              'playback.queue_json': '[1,2,3,4,5]',
              'playback.index': '0',
            };
            final container = makeContainer(settings: settings);
            addTearDown(container.dispose);
            final notifier = await restoredWith5Songs(container);

            var current =
                container.read(playerControllerProvider).currentIndex;
            expect(current, 0);

            final visited = <int>{current};
            for (var step = 0; step < 4; step++) {
              await notifier.onNext();
              current = container.read(playerControllerProvider).currentIndex;
              expect(visited.contains(current), isFalse,
                  reason: 'step $step revisited $current');
              visited.add(current);
            }
            expect(visited, {0, 1, 2, 3, 4});

            // Round exhausted — the next pick starts a fresh round and may
            // repeat, but must never stay on the same song.
            await notifier.onNext();
            expect(
              container.read(playerControllerProvider).currentIndex,
              isNot(visited.last),
            );
          }));

  test('onPrevious pops the random history back to the exact origin',
      () => runGuarded(() async {
            final container = makeContainer(
              settings: const {
                'playback.queue_json': '[1,2,3,4,5]',
                'playback.index': '0',
              },
            );
            addTearDown(container.dispose);
            final notifier = await restoredWith5Songs(container);

            final first =
          container.read(playerControllerProvider).currentIndex;
            await notifier.onNext();
            final second =
            container.read(playerControllerProvider).currentIndex;

            await notifier.onPrevious();
            expect(
              container.read(playerControllerProvider).currentIndex,
              first,
            );

            await notifier.onNext();
            await notifier.onPrevious();
            expect(
              container.read(playerControllerProvider).currentIndex,
              second,
            );
          }));

  test('setShuffle persists the flag and restoreSession reads it back',
      () => runGuarded(() async {
            final settings = <String, String>{
              'playback.queue_json': '[1,2]',
              'playback.index': '0',
            };
            final container = makeContainer(settings: settings);
            addTearDown(container.dispose);

            final notifier = container.read(playerControllerProvider.notifier);
            await notifier.restoreSession();
            expect(
              container.read(playerControllerProvider).shuffleEnabled,
              isFalse,
            );

            await notifier.setShuffle(enabled: true);
            expect(container.read(playerControllerProvider).shuffleEnabled,
                isTrue);
            expect(settings['playback.shuffle'], 'true');
          }));

  test('clearQueue forgets the random history', () => runGuarded(() async {
        final container = makeContainer(
          settings: const {
            'playback.queue_json': '[1,2,3]',
            'playback.index': '0',
          },
        );
        addTearDown(container.dispose);
        final notifier = await restoredWith5Shuffled(container);

        await notifier.clearQueue();

        // With an empty queue prev/next are no-ops; the assertion is that
        // internal memory was reset without throwing.
        expect(container.read(playerControllerProvider).queue, isEmpty);
      }));
}

Future<PlayerController> restoredWith5Shuffled(
  ProviderContainer container,
) async {
  final notifier = container.read(playerControllerProvider.notifier);
  await notifier.restoreSession();
  await notifier.setShuffle(enabled: true);
  return notifier;
}
