import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:whisplayer/core/providers/repository_providers.dart';
import 'package:whisplayer/domain/repositories/audio_engine.dart';
import 'package:whisplayer/player/just_audio_engine.dart';
import 'package:whisplayer/player/media_session.dart';
import 'package:whisplayer/player/whis_audio_handler.dart';

final audioEngineProvider = FutureProvider<AudioEngine>((ref) async {
  final streams = ref.watch(webDavStreamServiceProvider);
  final engine = JustAudioEngine(headersResolver: streams.headersFor);
  await engine.init();
  ref.onDispose(engine.dispose);
  return engine;
});

final playerHandlerProvider = FutureProvider<MediaSession>((ref) async {
  final engine = await ref.watch(audioEngineProvider.future);
  final handler = await WhisAudioHandler.bootstrap(engine);
  handler.bindEngine();
  return handler;
});

final playerBootstrapProvider = FutureProvider<void>((ref) async {
  await ref.watch(audioEngineProvider.future);
  await ref.watch(playerHandlerProvider.future);
});

/// Latest playback position in milliseconds.
///
/// Updated on every transport tick; the session state
/// (playerControllerProvider) only changes on transitions, so position
/// consumers do not rebuild the whole player UI at tick frequency.
class PlaybackPositionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  int get positionMs => state;

  set positionMs(int value) => state = value;

  void reset() => state = 0;
}

final playbackPositionProvider =
    NotifierProvider<PlaybackPositionNotifier, int>(
  PlaybackPositionNotifier.new,
);
