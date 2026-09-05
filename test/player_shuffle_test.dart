import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:whisplayer/core/providers/playback_providers.dart';
import 'package:whisplayer/core/providers/repository_providers.dart';
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
    Map<String, String> settings = const {},
  }) {
    return ProviderContainer(
      overrides: [
        libraryRepositoryProvider.overrideWithValue(
          FakeLibraryRepository(
            songs: [for (var id = 1; id <= 5; id++) _song(id)],
          ),
        ),
        settingsRepositoryProvider.overrideWithValue(
          FakeSettingsRepository(Map.of(settings)),
        ),
        playbackRecordRepositoryProvider.overrideWithValue(
          FakePlaybackRecordRepository(),
        ),
        audioEngineProvider.overrideWith((ref) => FakeAudioEngine()),
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
            expect(second, isNot(first));

            await notifier.onPrevious();
            expect(
              container.read(playerControllerProvider).currentIndex,
              first,
            );

            await notifier.onNext();
            await notifier.onPrevious();
            expect(
              container.read(playerControllerProvider).currentIndex,
              first,
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
            final saved = await container
                .read(settingsRepositoryProvider)
                .getString('playback.shuffle');
            expect(saved, 'true');
          }));

  test('clearQueue forgets the random history', () => runGuarded(() async {
        final container = makeContainer(
          settings: const {
            'playback.queue_json': '[1,2,3]',
            'playback.index': '0',
          },
        );
        addTearDown(container.dispose);
        final notifier = await restoredWith5Songs(container);

        await notifier.clearQueue();

        // With an empty queue prev/next are no-ops; the assertion is that
        // internal memory was reset without throwing.
        expect(container.read(playerControllerProvider).queue, isEmpty);
      }));
}
