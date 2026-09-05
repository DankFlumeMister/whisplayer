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

  Future<void> settle() async {
    await pumpEventQueue();
    await pumpEventQueue();
  }

  Future<ProviderContainer> makeContainer({
    required List<Song> songs,
    required FakeAudioEngine engine,
    required FakePlaybackRecordRepository records,
  }) async {
    final container = ProviderContainer(
      overrides: [
        libraryRepositoryProvider.overrideWithValue(
          FakeLibraryRepository(songs: songs),
        ),
        settingsRepositoryProvider.overrideWithValue(
          FakeSettingsRepository(),
        ),
        playbackRecordRepositoryProvider.overrideWithValue(records),
        audioEngineProvider.overrideWith((ref) => engine),
      ],
    );
    addTearDown(container.dispose);
    await container.read(playerControllerProvider.notifier).restoreSession();
    return container;
  }

  test('natural completion records exactly one full listen',
      () => runGuarded(() async {
            final engine = FakeAudioEngine();
            final records = FakePlaybackRecordRepository();
            final container = await makeContainer(
              songs: [_song(1)],
              engine: engine,
              records: records,
            );

            await container
                .read(playerControllerProvider.notifier)
                .playSongs([_song(1)]);

            engine.emit(
              const PlaybackSnapshot(
                state: EngineState.ready,
                playing: true,
                positionMs: 5000,
                queueIndex: 0,
              ),
            );
            await settle();
            expect(records.plays, isEmpty);

            engine.emit(
              const PlaybackSnapshot(
                state: EngineState.completed,
                positionMs: 180000,
                queueIndex: 0,
              ),
            );
            await settle();
            expect(records.plays, ['1:180000:true']);
          }));

  test('skipping away mid-song records an incomplete listen',
      () => runGuarded(() async {
            final engine = FakeAudioEngine();
            final records = FakePlaybackRecordRepository();
            final container = await makeContainer(
              songs: [_song(1), _song(2)],
              engine: engine,
              records: records,
            );

            await container
                .read(playerControllerProvider.notifier)
                .playSongs([_song(1), _song(2)]);

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

            expect(records.plays, ['1:30000:false']);
          }));

  test('completion followed by auto-advance is not double recorded',
      () => runGuarded(() async {
            final engine = FakeAudioEngine();
            final records = FakePlaybackRecordRepository();
            final container = await makeContainer(
              songs: [_song(1), _song(2)],
              engine: engine,
              records: records,
            );

            await container
                .read(playerControllerProvider.notifier)
                .playSongs([_song(1), _song(2)]);

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

            expect(records.plays, ['1:180000:true']);
          }));

  test('native loop-one wrap records every finished playthrough',
      () => runGuarded(() async {
            final engine = FakeAudioEngine();
            final records = FakePlaybackRecordRepository();
            final container = await makeContainer(
              songs: [_song(1)],
              engine: engine,
              records: records,
            );

            await container
                .read(playerControllerProvider.notifier)
                .playSongs([_song(1)]);

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
              records.plays,
              ['1:180000:true', '1:180000:true'],
            );
          }));
}
