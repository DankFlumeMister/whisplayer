import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:whisplayer/core/providers/repository_providers.dart';
import 'package:whisplayer/domain/entities/playback.dart';
import 'package:whisplayer/domain/entities/song.dart';
import 'package:whisplayer/domain/repositories/playback_record_repository.dart';

/// Playback-recording policy: when a listen is recorded and whether it
/// counts as completed or skipped.
///
/// Semantics are frozen from the historic PlayerController implementation
/// (see PROJECT_HANDOFF.md decision 7): one record per departure or full
/// listen, `completed` when the departure position is within
/// [restartThresholdMs] of the duration, and native LoopMode.one wraps
/// detected by a position jump of more than [wrapDetectMs] on the same
/// track while playing.
class PlaybackRecorder {
  PlaybackRecorder(this._record);

  final PlaybackRecordRepository _record;

  static const restartThresholdMs = 3000;
  static const wrapDetectMs = 2000;

  int? _recordedIndex;
  int _lastPositionMs = 0;
  bool _wasPlaying = false;

  /// Tracks the latest transport position/playing state; call once per
  /// engine snapshot so later policy decisions see the previous tick.
  void noteSnapshot(PlaybackSnapshot snap) {
    _lastPositionMs = snap.positionMs;
    _wasPlaying = snap.playing;
  }

  /// Native LoopMode.one replays seamlessly without emitting
  /// EngineState.completed, so a finished listen can only be spotted by
  /// the playback position jumping backwards on the same track.
  bool isLoopWrap(
    PlaybackSnapshot snap, {
    required bool rebuilding,
    required bool hasCurrent,
  }) {
    return !rebuilding &&
        hasCurrent &&
        snap.playing &&
        _lastPositionMs - snap.positionMs > wrapDetectMs;
  }

  /// Records the departure of the song at [index] when it was actually
  /// listened to: completed when the last position is within
  /// [restartThresholdMs] of the duration, skipped otherwise.
  Future<void> recordDeparture({
    required List<Song> queue,
    required int index,
  }) async {
    if (index < 0 || index >= queue.length || _recordedIndex == index) {
      return;
    }
    final listened = _wasPlaying || _lastPositionMs > 0;
    if (!listened) {
      return;
    }
    final song = queue[index];
    final completed =
        _lastPositionMs >= song.durationMs - restartThresholdMs;
    await _record.recordPlayback(
      songId: song.id,
      playedMs: _lastPositionMs,
      playedAtMs: DateTime.now().millisecondsSinceEpoch,
      completed: completed,
    );
    _recordedIndex = index;
  }

  /// Records a full listen of [song]; deduplicated by [_recordedIndex].
  /// With [rearm] the index lock is released so the next wrap can record
  /// again (loop-one), otherwise the current index stays locked.
  Future<void> recordFullListen({
    required Song? song,
    required int currentIndex,
    required bool rearm,
  }) async {
    if (song == null || _recordedIndex == currentIndex) {
      return;
    }
    await _record.recordPlayback(
      songId: song.id,
      playedMs: song.durationMs,
      playedAtMs: DateTime.now().millisecondsSinceEpoch,
      completed: true,
    );
    _recordedIndex = rearm ? null : currentIndex;
  }

  /// Releases the recorded-index lock (manual replay, skip, departures
  /// recorded outside the snapshot flow).
  void clear() {
    _recordedIndex = null;
  }

  /// Resets all tracking state for a queue rebuild.
  void reset({int positionMs = 0}) {
    _recordedIndex = null;
    _lastPositionMs = positionMs;
    _wasPlaying = false;
  }
}

final playbackRecorderProvider = Provider<PlaybackRecorder>(
  (ref) => PlaybackRecorder(ref.watch(playbackRecordRepositoryProvider)),
);
