import 'dart:async';

import 'package:just_audio/just_audio.dart';

import 'package:whisplayer/domain/entities/playback.dart';
import 'package:whisplayer/domain/repositories/audio_engine.dart';

/// Supplies per-URI request headers, or `null` when a URI needs none.
///
/// WebDAV is the motivating case: its shared token travels as an
/// `Authorization` header because putting it in the URL would leak it into
/// logs, crash dumps and the lock-screen media metadata.
typedef StreamHeadersResolver = Future<Map<String, String>?> Function(Uri uri);

class JustAudioEngine implements AudioEngine {
  /// Creates an engine.
  ///
  /// [useProxyForRequestHeaders] defaults to `false`, which lets ExoPlayer
  /// (Android) and AVFoundation (iOS/macOS) send headers natively. Leaving it
  /// `true` makes just_audio spin up a cleartext local HTTP proxy instead —
  /// slower, and it meddles with the byte-range requests that seeking relies
  /// on. Flip it back if a device turns out to drop native headers.
  JustAudioEngine({
    AudioPlayer? player,
    this.headersResolver,
    this.useProxyForRequestHeaders = false,
  }) : _player = player ?? AudioPlayer(
            useProxyForRequestHeaders: useProxyForRequestHeaders,
          );

  final AudioPlayer _player;
  final StreamHeadersResolver? headersResolver;
  final bool useProxyForRequestHeaders;
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
  }) async {
    final sources = <AudioSource>[];
    for (final uri in uris) {
      final parsed = Uri.tryParse(uri);
      if (parsed == null) {
        continue;
      }
      final headers = await _headersFor(parsed);
      sources.add(AudioSource.uri(parsed, headers: headers));
    }
    await _player.setAudioSources(
      sources,
      initialIndex: startIndex,
      initialPosition: startPositionMs == null
          ? null
          : Duration(milliseconds: startPositionMs),
    );
  }

  /// A resolver that throws must not cost the user their queue — fall back
  /// to a header-less source and let the server reject it if it must.
  Future<Map<String, String>?> _headersFor(Uri uri) async {
    final resolver = headersResolver;
    if (resolver == null) {
      return null;
    }
    try {
      return await resolver(uri);
    } on Object catch (_) {
      return null;
    }
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
