import 'package:flutter_test/flutter_test.dart';

import 'package:whisplayer/domain/entities/playback.dart';
import 'package:whisplayer/domain/entities/song.dart';
import 'package:whisplayer/domain/entities/source_type.dart';
import 'package:whisplayer/features/player/application/playback_recorder.dart';

import 'helpers/fakes.dart';

Song _song(int id, {int durationMs = 180000}) => Song(
      id: id,
      path: '/tmp/$id.flac',
      sourceType: SourceType.local,
      title: 'Song $id',
      fileName: '$id.flac',
      format: 'flac',
      durationMs: durationMs,
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
  group('recordDeparture', () {
    test('records an incomplete listen when leaving mid-song', () async {
      final records = FakePlaybackRecordRepository();
      final recorder = PlaybackRecorder(records);
      // ignore: cascade_invocations - the snapshot must be noted first.
      recorder.noteSnapshot(
        const PlaybackSnapshot(playing: true, positionMs: 30000),
      );

      await recorder.recordDeparture(
        queue: [_song(1), _song(2)],
        index: 0,
      );

      expect(records.plays, ['1:30000:false']);
    });

    test('records a completed listen within the restart threshold',
        () async {
      final records = FakePlaybackRecordRepository();
      final recorder = PlaybackRecorder(records);
      // ignore: cascade_invocations - the snapshot must be noted first.
      recorder.noteSnapshot(
        const PlaybackSnapshot(playing: true, positionMs: 179000),
      );

      await recorder.recordDeparture(
        queue: [_song(1)],
        index: 0,
      );

      expect(records.plays, ['1:179000:true']);
    });

    test('records nothing when the song was never actually listened',
        () async {
      final records = FakePlaybackRecordRepository();
      final recorder = PlaybackRecorder(records);

      await recorder.recordDeparture(
        queue: [_song(1)],
        index: 0,
      );

      expect(records.plays, isEmpty);
    });

    test('deduplicates repeated departures of the same index', () async {
      final records = FakePlaybackRecordRepository();
      final recorder = PlaybackRecorder(records);
      // ignore: cascade_invocations - the snapshot must be noted first.
      recorder.noteSnapshot(
        const PlaybackSnapshot(playing: true, positionMs: 30000),
      );

      await recorder.recordDeparture(queue: [_song(1)], index: 0);
      // ignore: cascade_invocations - a second call is the dedupe probe.
      await recorder.recordDeparture(queue: [_song(1)], index: 0);

      expect(records.plays, ['1:30000:false']);
    });

    test('reset releases the recorded-index lock', () async {
      final records = FakePlaybackRecordRepository();
      final recorder = PlaybackRecorder(records);
      // ignore: cascade_invocations - the snapshot must be noted first.
      recorder.noteSnapshot(
        const PlaybackSnapshot(playing: true, positionMs: 30000),
      );

      await recorder.recordDeparture(queue: [_song(1)], index: 0);
      recorder.reset();
      // ignore: cascade_invocations - snapshot must be noted first.
      recorder.noteSnapshot(
        const PlaybackSnapshot(playing: true, positionMs: 45000),
      );
      // ignore: cascade_invocations - the second call proves reset
      // released the recorded-index lock.
      await recorder.recordDeparture(queue: [_song(1)], index: 0);

      expect(records.plays, ['1:30000:false', '1:45000:false']);
    });
  });

  group('recordFullListen', () {
    test('records duration with completed true and locks the index',
        () async {
      final records = FakePlaybackRecordRepository();
      final recorder = PlaybackRecorder(records);

      await recorder.recordFullListen(
        song: _song(1),
        currentIndex: 0,
        rearm: false,
      );
      await recorder.recordFullListen(
        song: _song(1),
        currentIndex: 0,
        rearm: false,
      );

      expect(records.plays, ['1:180000:true']);
    });

    test('rearm releases the lock so the next wrap records again',
        () async {
      final records = FakePlaybackRecordRepository();
      final recorder = PlaybackRecorder(records);

      await recorder.recordFullListen(
        song: _song(1),
        currentIndex: 0,
        rearm: true,
      );
      await recorder.recordFullListen(
        song: _song(1),
        currentIndex: 0,
        rearm: true,
      );

      expect(records.plays, ['1:180000:true', '1:180000:true']);
    });

    test('records nothing without a current song', () async {
      final records = FakePlaybackRecordRepository();
      final recorder = PlaybackRecorder(records);

      await recorder.recordFullListen(
        song: null,
        currentIndex: 0,
        rearm: false,
      );

      expect(records.plays, isEmpty);
    });
  });

  group('isLoopWrap', () {
    test('detects a backwards jump beyond the wrap threshold', () {
      final recorder = PlaybackRecorder(FakePlaybackRecordRepository());
      // ignore: cascade_invocations - previous tick must be noted first.
      recorder.noteSnapshot(
        const PlaybackSnapshot(playing: true, positionMs: 100000),
      );

      // ignore: cascade_invocations - the wrap check needs the noted tick.
      final wrap = recorder.isLoopWrap(
        const PlaybackSnapshot(
          playing: true,
          positionMs: 1000,
        ),
        rebuilding: false,
        hasCurrent: true,
      );
      expect(wrap, isTrue);
    });

    test('ignores small jumps, pauses and rebuild windows', () {
      final recorder = PlaybackRecorder(FakePlaybackRecordRepository());
      // ignore: cascade_invocations - previous tick must be noted first.
      recorder.noteSnapshot(
        const PlaybackSnapshot(playing: true, positionMs: 5000),
      );

      // ignore: cascade_invocations - each case needs the noted tick.
      final smallJump = recorder.isLoopWrap(
        const PlaybackSnapshot(playing: true, positionMs: 4000),
        rebuilding: false,
        hasCurrent: true,
      );
      expect(smallJump, isFalse);

      // ignore: cascade_invocations - each case needs the noted tick.
      final paused = recorder.isLoopWrap(
        const PlaybackSnapshot(positionMs: 1000),
        rebuilding: false,
        hasCurrent: true,
      );
      expect(paused, isFalse);

      // ignore: cascade_invocations - each case needs the noted tick.
      final rebuilding = recorder.isLoopWrap(
        const PlaybackSnapshot(playing: true, positionMs: 1000),
        rebuilding: true,
        hasCurrent: true,
      );
      expect(rebuilding, isFalse);

      // ignore: cascade_invocations - each case needs the noted tick.
      final noCurrent = recorder.isLoopWrap(
        const PlaybackSnapshot(playing: true, positionMs: 1000),
        rebuilding: false,
        hasCurrent: false,
      );
      expect(noCurrent, isFalse);
    });
  });
}
