import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:whisplayer/core/providers/playback_providers.dart';
import 'package:whisplayer/core/providers/repository_providers.dart';
import 'package:whisplayer/domain/entities/playback.dart';
import 'package:whisplayer/domain/entities/song.dart';
import 'package:whisplayer/domain/entities/source_type.dart';
import 'package:whisplayer/features/player/application/player_controller.dart';

import 'helpers/fakes.dart';
import 'helpers/run_guarded.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer makeContainer({
    required List<Song> songs,
    required FakeAudioEngine engine,
    Map<String, String> settings = const {},
  }) {
    return ProviderContainer(
      overrides: [
        libraryRepositoryProvider.overrideWithValue(
          FakeLibraryRepository(songs: songs),
        ),
        settingsRepositoryProvider.overrideWithValue(
          FakeSettingsRepository(Map.of(settings)),
        ),
        playbackRecordRepositoryProvider.overrideWithValue(
          FakePlaybackRecordRepository(),
        ),
        audioEngineProvider.overrideWith((ref) => engine),
      ],
    );
  }

  test('restoreSession rebuilds queue, clamps index and restores loop',
      () => runGuarded(() async {
            final engine = FakeAudioEngine();
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
            final engine = FakeAudioEngine();
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
            final engine = FakeAudioEngine();
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
