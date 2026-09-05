import 'package:flutter_test/flutter_test.dart';

import 'package:whisplayer/domain/entities/playback.dart';
import 'package:whisplayer/features/player/application/playback_session_store.dart';

import 'helpers/fakes.dart';

void main() {
  test('read decodes queue, index, position, loop and shuffle', () async {
    final settings = FakeSettingsRepository(const {
      'playback.queue_json': '[7,8,9]',
      'playback.index': '1',
      'playback.position_ms': '42000',
      'playback.loop_mode': 'all',
      'playback.shuffle': 'true',
    });
    final store = PlaybackSessionStore(settings);

    final session = await store.read();

    expect(session.queueIds, [7, 8, 9]);
    expect(session.index, 1);
    expect(session.positionMs, 42000);
    expect(session.loopMode, PlaybackLoopMode.all);
    expect(session.shuffleEnabled, isTrue);
  });

  test('read yields defaults for missing or empty values', () async {
    final store = PlaybackSessionStore(FakeSettingsRepository());

    final session = await store.read();

    expect(session.queueIds, isEmpty);
    expect(session.index, -1);
    expect(session.positionMs, 0);
    expect(session.loopMode, PlaybackLoopMode.off);
    expect(session.shuffleEnabled, isFalse);
  });

  test('read tolerates malformed queue json and drops non-int ids',
      () async {
    final settings = FakeSettingsRepository(<String, String>{
      'playback.queue_json': 'not-json',
    });
    final store = PlaybackSessionStore(settings);

    expect((await store.read()).queueIds, isEmpty);

    settings.values['playback.queue_json'] = '[1,"x",2]';
    expect((await store.read()).queueIds, [1, 2]);
  });

  test('read falls back to off for an unknown loop mode name', () async {
    final settings = FakeSettingsRepository(const {
      'playback.loop_mode': 'turbo',
    });
    final store = PlaybackSessionStore(settings);

    expect((await store.read()).loopMode, PlaybackLoopMode.off);
  });

  test('saveQueue writes ids json, index and optional position', () async {
    final settings = FakeSettingsRepository();
    final store = PlaybackSessionStore(settings);

    await store.saveQueue([1, 2], 1);
    expect(settings.values['playback.queue_json'], '[1,2]');
    expect(settings.values['playback.index'], '1');
    expect(settings.values.containsKey('playback.position_ms'), isFalse);

    await store.saveQueue([1, 2], 1, positionMs: 5000);
    expect(settings.values['playback.position_ms'], '5000');
  });

  test('saveLoopMode and saveShuffle write the canonical strings', () async {
    final settings = FakeSettingsRepository();
    final store = PlaybackSessionStore(settings);

    await store.saveLoopMode(PlaybackLoopMode.one);
    expect(settings.values['playback.loop_mode'], 'one');

    await store.saveShuffle(enabled: true);
    expect(settings.values['playback.shuffle'], 'true');
    await store.saveShuffle(enabled: false);
    expect(settings.values['playback.shuffle'], 'false');
  });

  group('resolveIndex', () {
    const session = StoredPlaybackSession(
      queueIds: [1, 2, 3],
      index: 1,
      positionMs: 0,
      loopMode: PlaybackLoopMode.off,
      shuffleEnabled: false,
    );

    test('keeps an in-range index', () {
      expect(session.resolveIndex(3), 1);
    });

    test('clamps an out-of-range index to the first song', () {
      expect(session.resolveIndex(1), 0);
    });

    test('yields -1 for an empty queue', () {
      expect(session.resolveIndex(0), -1);
    });
  });
}
