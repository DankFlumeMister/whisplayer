import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:whisplayer/domain/repositories/audio_engine.dart';
import 'package:whisplayer/player/just_audio_engine.dart';
import 'package:whisplayer/player/whis_audio_handler.dart';

final audioEngineProvider = FutureProvider<AudioEngine>((ref) async {
  final engine = JustAudioEngine();
  await engine.init();
  ref.onDispose(engine.dispose);
  return engine;
});

final playerHandlerProvider = FutureProvider<WhisAudioHandler>((ref) async {
  final engine = await ref.watch(audioEngineProvider.future);
  final handler = await WhisAudioHandler.bootstrap(engine);
  handler.bindEngine();
  return handler;
});

final playerBootstrapProvider = FutureProvider<void>((ref) async {
  await ref.watch(audioEngineProvider.future);
  await ref.watch(playerHandlerProvider.future);
});
