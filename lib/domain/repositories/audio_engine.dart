import 'package:whisplayer/domain/entities/playback.dart';

abstract interface class AudioEngine {
  Stream<PlaybackSnapshot> get snapshots;

  PlaybackSnapshot get current;

  Future<void> openQueue({
    required List<String> uris,
    required int startIndex,
    int? startPositionMs,
  });

  Future<void> play();

  Future<void> pause();

  Future<void> seek(Duration position);

  Future<void> skipToIndex(int index);

  void setLoopMode(PlaybackLoopMode mode);

  Future<void> dispose();
}
