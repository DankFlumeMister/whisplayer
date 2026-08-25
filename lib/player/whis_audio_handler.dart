import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';

import 'package:whisplayer/domain/entities/playback.dart';
import 'package:whisplayer/domain/repositories/audio_engine.dart';

abstract class SessionDelegate {
  Future<void> onNext();

  Future<void> onPrevious();
}

class WhisAudioHandler extends BaseAudioHandler {
  WhisAudioHandler._(this._engine);

  final AudioEngine _engine;
  SessionDelegate? delegate;
  bool _engineBound = false;

  static WhisAudioHandler? _active;

  static Future<WhisAudioHandler> bootstrap(AudioEngine engine) async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    session.interruptionEventStream.listen((event) {
      final handler = _active;
      if (handler == null) {
        return;
      }
      if (event.begin) {
        if (event.type != AudioInterruptionType.duck) {
          unawaited(handler._engine.pause());
        }
      } else if (event.type == AudioInterruptionType.pause) {
        unawaited(handler._engine.play());
      }
    });
    session.becomingNoisyEventStream.listen((_) {
      final handler = _active;
      if (handler != null) {
        unawaited(handler._engine.pause());
      }
    });

    return AudioService.init(
      builder: () {
        final handler = WhisAudioHandler._(engine);
        _active = handler;
        return handler;
      },
      config: const AudioServiceConfig(
        androidNotificationChannelId:
            'com.whisplayer.app.playback',
        androidNotificationChannelName: 'Whisplayer',
      ),
    );
  }

  void bindEngine() {
    if (_engineBound) {
      return;
    }
    _engineBound = true;
    _engine.snapshots.listen(_publishSystemState);
  }

  void publishNowPlaying(MediaItem? item) {
    mediaItem.add(item);
  }

  void publishQueue(List<MediaItem> items) {
    queue.add(items);
  }

  @override
  Future<void> play() => _engine.play();

  @override
  Future<void> pause() => _engine.pause();

  @override
  Future<void> seek(Duration position) => _engine.seek(position);

  @override
  Future<void> skipToNext() async {
    await delegate?.onNext();
  }

  @override
  Future<void> skipToPrevious() async {
    await delegate?.onPrevious();
  }

  @override
  Future<void> stop() async {
    await _engine.pause();
    await super.stop();
  }

  void _publishSystemState(PlaybackSnapshot snap) {
    final index = snap.queueIndex;
    final controls = <MediaControl>[
      if (index > 0) MediaControl.skipToPrevious,
      if (snap.playing) MediaControl.pause else MediaControl.play,
      MediaControl.skipToNext,
    ];
    playbackState.add(
      PlaybackState(
        controls: controls,
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        processingState: _mapState(snap.state),
        playing: snap.playing,
        updatePosition: Duration(milliseconds: snap.positionMs),
      ),
    );
  }

  AudioProcessingState _mapState(EngineState state) {
    switch (state) {
      case EngineState.idle:
        return AudioProcessingState.idle;
      case EngineState.loading:
        return AudioProcessingState.loading;
      case EngineState.buffering:
        return AudioProcessingState.buffering;
      case EngineState.ready:
        return AudioProcessingState.ready;
      case EngineState.completed:
        return AudioProcessingState.completed;
    }
  }
}
