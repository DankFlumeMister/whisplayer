import 'dart:async';

import 'package:just_audio/just_audio.dart';

import 'package:whisplayer/domain/entities/playback.dart';
import 'package:whisplayer/domain/repositories/audio_engine.dart';

class JustAudioEngine implements AudioEngine {
  JustAudioEngine({AudioPlayer? player})
      : _player = player ?? AudioPlayer();

  final AudioPlayer _player;
  final _snapshots = StreamController<PlaybackSnapshot>.broadcast();
  final _subs = <StreamSubscription<dynamic>>[];

  EngineState _state = EngineState.idle;
  bool _playing = false;
  int _positionMs = 0;
  int _durationMs = 0;
  int _queueIndex = -1;

  @override
  PlaybackSnapshot get current => PlaybackSnapshot(
        state: _state,
        playing: _playing,
        positionMs: _positionMs,
        durationMs: _durationMs,
        queueIndex: _queueIndex,
      );

  @override
  Stream<PlaybackSnapshot> get snapshots => _snapshots.stream;

  Future<void> init() async {
    void emit() {
      if (_snapshots.isClosed) {
        return;
      }
      _snapshots.add(current);
    }

    _subs
      ..add(
        _player.playerStateStream.listen((ps) {
          _playing = ps.playing;
          _state = _mapState(ps.processingState);
          emit();
        }),
      )
      ..add(
        _player.positionStream.listen((p) {
          _positionMs = p.inMilliseconds;
          emit();
        }),
      )
      ..add(
        _player.durationStream.listen((d) {
          _durationMs = d?.inMilliseconds ?? 0;
          emit();
        }),
      )
      ..add(
        _player.currentIndexStream.listen((i) {
          _queueIndex = i ?? -1;
          emit();
        }),
      );
  }

  @override
  Future<void> openQueue({
    required List<String> uris,
    required int startIndex,
    int? startPositionMs,
  }) {
    final sources = [
      for (final uri in uris) AudioSource.uri(Uri.parse(uri)),
    ];
    return _player.setAudioSources(
      sources,
      initialIndex: startIndex,
      initialPosition: startPositionMs == null
          ? null
          : Duration(milliseconds: startPositionMs),
    );
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToIndex(int index) =>
      _player.seek(Duration.zero, index: index);

  @override
  void setLoopMode(PlaybackLoopMode mode) {
    switch (mode) {
      case PlaybackLoopMode.off:
        _player.setLoopMode(LoopMode.off);
      case PlaybackLoopMode.one:
        _player.setLoopMode(LoopMode.one);
      case PlaybackLoopMode.all:
        _player.setLoopMode(LoopMode.all);
    }
  }

  EngineState _mapState(ProcessingState s) {
    switch (s) {
      case ProcessingState.idle:
        return EngineState.idle;
      case ProcessingState.loading:
        return EngineState.loading;
      case ProcessingState.buffering:
        return EngineState.buffering;
      case ProcessingState.ready:
        return EngineState.ready;
      case ProcessingState.completed:
        return EngineState.completed;
    }
  }

  @override
  Future<void> dispose() async {
    for (final sub in _subs) {
      await sub.cancel();
    }
    await _player.dispose();
    await _snapshots.close();
  }
}
