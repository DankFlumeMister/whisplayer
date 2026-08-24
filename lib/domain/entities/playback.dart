enum EngineState {
  idle,
  loading,
  buffering,
  ready,
  completed,
}

enum PlaybackLoopMode {
  off,
  one,
  all,
}

class PlaybackSnapshot {
  const PlaybackSnapshot({
    this.state = EngineState.idle,
    this.playing = false,
    this.positionMs = 0,
    this.durationMs = 0,
    this.queueIndex = -1,
  });

  final EngineState state;
  final bool playing;
  final int positionMs;
  final int durationMs;
  final int queueIndex;

  bool get isEnded => state == EngineState.completed;

  PlaybackSnapshot copyWith({
    EngineState? state,
    bool? playing,
    int? positionMs,
    int? durationMs,
    int? queueIndex,
  }) {
    return PlaybackSnapshot(
      state: state ?? this.state,
      playing: playing ?? this.playing,
      positionMs: positionMs ?? this.positionMs,
      durationMs: durationMs ?? this.durationMs,
      queueIndex: queueIndex ?? this.queueIndex,
    );
  }
}
