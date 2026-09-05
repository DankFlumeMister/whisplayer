import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:whisplayer/core/providers/playback_providers.dart';
import 'package:whisplayer/core/providers/repository_providers.dart';
import 'package:whisplayer/domain/entities/playback.dart';
import 'package:whisplayer/domain/entities/song.dart';
import 'package:whisplayer/domain/entities/source_type.dart';
import 'package:whisplayer/features/player/application/player_controller.dart';

import 'helpers/fakes.dart';

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

ProviderContainer _makeContainer(
  FakeAudioEngine engine,
  FakeSettingsRepository settings,
) {
  return ProviderContainer(
    overrides: [
      libraryRepositoryProvider.overrideWithValue(
        FakeLibraryRepository(songs: [_song(1)]),
      ),
      settingsRepositoryProvider.overrideWithValue(settings),
      playbackRecordRepositoryProvider.overrideWithValue(
        FakePlaybackRecordRepository(),
      ),
      playerHandlerProvider.overrideWith((ref) => FakeMediaSession()),
      audioEngineProvider.overrideWith((ref) => engine),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('position-only ticks update the position channel, not session state',
      () async {
        final engine = FakeAudioEngine();
        final settings = FakeSettingsRepository();
        final container = _makeContainer(engine, settings);
        addTearDown(container.dispose);
        final notifier = container.read(playerControllerProvider.notifier);
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
        await pumpEventQueue();
        final before = container.read(playerControllerProvider);
        expect(container.read(playbackPositionProvider), 5000);

        engine.emit(
          const PlaybackSnapshot(
            state: EngineState.ready,
            playing: true,
            positionMs: 6000,
            queueIndex: 0,
          ),
        );
        await pumpEventQueue();

        expect(container.read(playbackPositionProvider), 6000);
        final after = container.read(playerControllerProvider);
        expect(identical(after, before), isTrue,
            reason: 'a pure position tick must not rebuild session state');
        expect(after.snapshot.positionMs, 5000);
      });

  test('a transition updates session state and persists the latest position',
      () async {
        final engine = FakeAudioEngine();
        final settings = FakeSettingsRepository();
        final container = _makeContainer(engine, settings);
        addTearDown(container.dispose);
        final notifier = container.read(playerControllerProvider.notifier);
        await notifier.restoreSession();
        await notifier.playSongs([_song(1)]);

        engine.emit(
          const PlaybackSnapshot(
            state: EngineState.ready,
            playing: true,
            positionMs: 10000,
            queueIndex: 0,
          ),
        );
        await pumpEventQueue();
        engine.emit(
          const PlaybackSnapshot(
            state: EngineState.ready,
            positionMs: 12000,
            queueIndex: 0,
          ),
        );
        await pumpEventQueue();

        final state = container.read(playerControllerProvider);
        expect(state.snapshot.playing, isFalse);
        expect(state.snapshot.positionMs, 12000);
        expect(container.read(playbackPositionProvider), 12000);
        expect(settings.values['playback.position_ms'], '12000');
      });

  testWidgets('playing keeps the 5s persistence cadence for kill-resume',
      (tester) async {
    final engine = FakeAudioEngine();
    final settings = FakeSettingsRepository();
    final container = _makeContainer(engine, settings);
    addTearDown(container.dispose);
    final notifier = container.read(playerControllerProvider.notifier);
    await notifier.restoreSession();
    await notifier.playSongs([_song(1)]);
    // playSongs persists the session with the starting position.
    expect(settings.values['playback.position_ms'], '0');

    engine.emit(
      const PlaybackSnapshot(
        state: EngineState.ready,
        playing: true,
        positionMs: 10000,
        queueIndex: 0,
      ),
    );
    await tester.pump();
    // A pure transition does not write; the periodic saver owns position.
    expect(settings.values['playback.position_ms'], '0');

    await tester.pump(const Duration(seconds: 5));
    expect(settings.values['playback.position_ms'], '10000');

    engine.emit(
      const PlaybackSnapshot(
        state: EngineState.ready,
        playing: true,
        positionMs: 15000,
        queueIndex: 0,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    expect(settings.values['playback.position_ms'], '15000');

    // Stop playback so the periodic saver timer is cancelled before the
    // test's pending-timer check.
    engine.emit(
      const PlaybackSnapshot(
        state: EngineState.ready,
        positionMs: 15000,
        queueIndex: 0,
      ),
    );
    await tester.pump();
  });

  test('clearQueue resets the position channel', () async {
    final engine = FakeAudioEngine();
    final settings = FakeSettingsRepository();
    final container = _makeContainer(engine, settings);
    addTearDown(container.dispose);
    final notifier = container.read(playerControllerProvider.notifier);
    await notifier.restoreSession();
    await notifier.playSongs([_song(1)]);

    engine.emit(
      const PlaybackSnapshot(
        state: EngineState.ready,
        playing: true,
        positionMs: 30000,
        queueIndex: 0,
      ),
    );
    await pumpEventQueue();
    expect(container.read(playbackPositionProvider), 30000);

    await notifier.clearQueue();
    expect(container.read(playbackPositionProvider), 0);
    expect(container.read(playerControllerProvider).queue, isEmpty);
  });
}
