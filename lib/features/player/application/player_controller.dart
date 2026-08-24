import 'dart:async';
import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:whisplayer/core/providers/playback_providers.dart';
import 'package:whisplayer/core/providers/repository_providers.dart';
import 'package:whisplayer/domain/entities/playback.dart';
import 'package:whisplayer/domain/entities/song.dart';
import 'package:whisplayer/domain/entities/source_type.dart';
import 'package:whisplayer/domain/repositories/audio_engine.dart';
import 'package:whisplayer/player/whis_audio_handler.dart';

const _keyQueue = 'playback.queue_json';
const _keyIndex = 'playback.index';
const _keyPosition = 'playback.position_ms';
const _keyLoop = 'playback.loop_mode';
const _restartThresholdMs = 3000;
const _wrapDetectMs = 2000;

class PlayerUiState {
  const PlayerUiState({
    this.queue = const [],
    this.currentIndex = -1,
    this.snapshot = const PlaybackSnapshot(),
    this.loopMode = PlaybackLoopMode.off,
  });

  final List<Song> queue;
  final int currentIndex;
  final PlaybackSnapshot snapshot;
  final PlaybackLoopMode loopMode;

  bool get hasCurrent =>
      currentIndex >= 0 && currentIndex < queue.length;

  Song? get currentSong => hasCurrent ? queue[currentIndex] : null;

  bool get isPlaying => snapshot.playing;

  PlayerUiState copyWith({
    List<Song>? queue,
    int? currentIndex,
    PlaybackSnapshot? snapshot,
    PlaybackLoopMode? loopMode,
  }) {
    return PlayerUiState(
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      snapshot: snapshot ?? this.snapshot,
      loopMode: loopMode ?? this.loopMode,
    );
  }
}

class PlayerController extends Notifier<PlayerUiState>
    implements SessionDelegate {
  StreamSubscription<PlaybackSnapshot>? _sub;
  Timer? _saver;
  bool _restored = false;
  bool _rebuilding = false;
  int _pendingPositionMs = 0;
  int? _recordedIndex;
  int _lastPositionMs = 0;
  bool _wasPlaying = false;

  @override
  PlayerUiState build() {
    ref.onDispose(_teardown);
    return const PlayerUiState();
  }

  void _teardown() {
    unawaited(_sub?.cancel());
    _saver?.cancel();
  }

  Future<AudioEngine> get _engine => ref.read(audioEngineProvider.future);

  static const _handlerInitTimeout = Duration(seconds: 5);

  Future<WhisAudioHandler?> get _handler async {
    try {
      return await ref
          .read(playerHandlerProvider.future)
          .timeout(_handlerInitTimeout);
    } on Exception {
      return null;
    }
    // audio_service surfaces bootstrap problems as assertion Errors in
    // some environments; swallowing them here keeps playback alive, so
    // catching Error is intentional despite avoid_catching_errors.
    // ignore: avoid_catching_errors
    on Error {
      return null;
    }
  }

  Future<void> restoreSession() async {
    if (_restored) {
      return;
    }
    _restored = true;
    await _ensureSubscribed();

    final settings = ref.read(settingsRepositoryProvider);
    final idsJson = await settings.getString(_keyQueue);
    final savedIndex =
        int.tryParse(await settings.getString(_keyIndex) ?? '') ?? -1;
    _pendingPositionMs =
        int.tryParse(await settings.getString(_keyPosition) ?? '') ?? 0;
    final loopName = await settings.getString(_keyLoop);

    var mode = PlaybackLoopMode.off;
    for (final m in PlaybackLoopMode.values) {
      if (m.name == loopName) {
        mode = m;
      }
    }

    final library = ref.read(libraryRepositoryProvider);
    final byId = {
      for (final song in await library.getAllSongs()) song.id: song,
    };
    final queue = [
      for (final id in _decodeIds(idsJson))
        if (byId[id] != null) byId[id]!,
    ];

    var index = savedIndex;
    if (index >= queue.length) {
      index = queue.isEmpty ? -1 : 0;
    }

    state = state.copyWith(
      queue: queue,
      currentIndex: index,
      loopMode: mode,
    );
    (await _engine).setLoopMode(mode);
    await _publishCurrentMediaItem();
  }

  List<int> _decodeIds(String? json) {
    if (json == null || json.isEmpty) {
      return const [];
    }
    try {
      final raw = jsonDecode(json) as List<dynamic>;
      return raw.whereType<int>().toList();
    } on FormatException catch (_) {
      return const [];
    }
  }

  Future<void> _ensureSubscribed() async {
    if (_sub != null) {
      return;
    }
    final engine = await _engine;
    _sub = engine.snapshots.listen(_onSnapshot);
  }

  void _onSnapshot(PlaybackSnapshot snap) {
    var index = state.currentIndex;
    final q = snap.queueIndex;
    final advanced =
        !_rebuilding && q >= 0 && q != index && q < state.queue.length;
    if (advanced) {
      unawaited(_recordDeparture(index));
      index = q;
      _recordedIndex = null;
    } else {
      _detectLoopWrap(snap);
    }

    state = state.copyWith(
      snapshot: snap,
      currentIndex: advanced ? q : null,
    );

    if (!advanced &&
        snap.state == EngineState.completed &&
        state.hasCurrent) {
      unawaited(_recordFullListen(rearm: false));
    }

    if (advanced) {
      unawaited(_publishCurrentMediaItem());
      unawaited(_saveNow());
    }
    if (snap.playing && _saver == null) {
      _saver = Timer.periodic(
        const Duration(seconds: 5),
        (_) => unawaited(_saveNow()),
      );
    } else if (!snap.playing && _saver != null) {
      _saver?.cancel();
      _saver = null;
      unawaited(_saveNow());
    }
    _wasPlaying = snap.playing;
    _lastPositionMs = snap.positionMs;
  }

  // Native LoopMode.one replays seamlessly without ever emitting
  // EngineState.completed, so a finished listen can only be spotted by the
  // playback position jumping backwards on the same track.
  void _detectLoopWrap(PlaybackSnapshot snap) {
    if (_rebuilding || !state.hasCurrent || !snap.playing) {
      return;
    }
    if (_lastPositionMs - snap.positionMs <= _wrapDetectMs) {
      return;
    }
    unawaited(_recordFullListen(rearm: true));
  }

  Future<void> _recordDeparture(int index) async {
    if (index < 0 || index >= state.queue.length || _recordedIndex == index) {
      return;
    }
    final listened = _wasPlaying || _lastPositionMs > 0;
    if (!listened) {
      return;
    }
    final song = state.queue[index];
    final completed =
        _lastPositionMs >= song.durationMs - _restartThresholdMs;
    await ref.read(libraryRepositoryProvider).recordPlayback(
          songId: song.id,
          playedMs: _lastPositionMs,
          playedAtMs: DateTime.now().millisecondsSinceEpoch,
          completed: completed,
        );
    _recordedIndex = index;
  }

  Future<void> _recordFullListen({required bool rearm}) async {
    final song = state.currentSong;
    if (song == null || _recordedIndex == state.currentIndex) {
      return;
    }
    await ref.read(libraryRepositoryProvider).recordPlayback(
          songId: song.id,
          playedMs: song.durationMs,
          playedAtMs: DateTime.now().millisecondsSinceEpoch,
          completed: true,
        );
    _recordedIndex = rearm ? null : state.currentIndex;
  }

  Future<void> playSongs(List<Song> songs, {int startIndex = 0}) async {
    if (songs.isEmpty) {
      return;
    }
    await _ensureSubscribed();
    await _applyQueue(songs, startIndex.clamp(0, songs.length - 1));
    await (await _engine).play();
    await _saveNow();
  }

  Future<void> togglePlayPause() async {
    if (!state.hasCurrent) {
      return;
    }
    await _ensureSubscribed();
    final engine = await _engine;
    final snap = state.snapshot;

    if (snap.state == EngineState.idle) {
      await _applyQueue(
        state.queue,
        state.currentIndex,
        startPositionMs:
            _pendingPositionMs > 0 ? _pendingPositionMs : null,
      );
      _pendingPositionMs = 0;
      await engine.play();
      return;
    }
    if (snap.state == EngineState.completed) {
      _recordedIndex = null;
      await engine.seek(Duration.zero);
      await engine.skipToIndex(state.currentIndex);
      await engine.play();
      return;
    }
    if (snap.playing) {
      await engine.pause();
    } else {
      await engine.play();
    }
  }

  @override
  Future<void> onNext() async {
    if (!state.hasCurrent) {
      return;
    }
    var next = state.currentIndex + 1;
    if (next >= state.queue.length) {
      if (state.loopMode != PlaybackLoopMode.all) {
        return;
      }
      next = 0;
    }
    await skipTo(next);
  }

  @override
  Future<void> onPrevious() async {
    if (!state.hasCurrent) {
      return;
    }
    if (state.snapshot.positionMs > _restartThresholdMs) {
      await (await _engine).seek(Duration.zero);
      return;
    }
    var prev = state.currentIndex - 1;
    if (prev < 0) {
      prev = state.loopMode == PlaybackLoopMode.all
          ? state.queue.length - 1
          : 0;
    }
    await skipTo(prev);
  }

  Future<void> seekTo(int positionMs) async {
    await (await _engine).seek(Duration(milliseconds: positionMs));
  }

  Future<void> skipTo(int index) async {
    if (index < 0 || index >= state.queue.length) {
      return;
    }
    // state.currentIndex is updated synchronously below, so the engine's
    // follow-up snapshot no longer reports an index advance; record the
    // departure of the current song here instead.
    await _recordDeparture(state.currentIndex);
    _recordedIndex = null;
    state = state.copyWith(currentIndex: index);
    await (await _engine).skipToIndex(index);
    await _publishCurrentMediaItem();
    await _saveNow();
  }

  Future<void> cycleLoopMode() async {
    const order = PlaybackLoopMode.values;
    final next =
        order[(order.indexOf(state.loopMode) + 1) % order.length];
    state = state.copyWith(loopMode: next);
    (await _engine).setLoopMode(next);
    await ref
        .read(settingsRepositoryProvider)
        .setString(_keyLoop, next.name);
  }

  Future<void> setNextFromLibrary(Song song) async {
    if (!state.hasCurrent) {
      await playSongs([song]);
      return;
    }
    final queue = [...state.queue]
      ..insert(state.currentIndex + 1, song);
    await _rebuildPreserving(queue);
  }

  Future<void> appendToQueue(List<Song> songs) async {
    if (songs.isEmpty || !state.hasCurrent) {
      return;
    }
    await _rebuildPreserving([...state.queue, ...songs]);
  }

  Future<void> removeFromQueue(int index) async {
    if (index < 0 || index >= state.queue.length) {
      return;
    }
    if (state.queue.length == 1) {
      await clearQueue();
      return;
    }
    final queue = [...state.queue]..removeAt(index);
    var newIndex = state.currentIndex;
    if (index < newIndex) {
      newIndex--;
    } else if (index == newIndex) {
      newIndex = index.clamp(0, queue.length - 1);
    }
    if (index == state.currentIndex) {
      await _recordDeparture(index);
      final wasPlaying = state.snapshot.playing;
      await _applyQueue(queue, newIndex);
      if (wasPlaying) {
        await (await _engine).play();
      }
    } else {
      await _rebuildPreserving(queue, forcedIndex: newIndex);
    }
  }

  Future<void> clearQueue() async {
    await _ensureSubscribed();
    await (await _engine).pause();
    await _recordDeparture(state.currentIndex);
    _rebuilding = true;
    try {
      state = PlayerUiState(loopMode: state.loopMode);
      _pendingPositionMs = 0;
      _recordedIndex = null;
      _lastPositionMs = 0;
      _wasPlaying = false;
      final handler = await _handler;
      handler
        ?..publishNowPlaying(null)
        ..publishQueue(const []);
      await _persist(const []);
    } finally {
      _rebuilding = false;
    }
  }

  Future<void> _rebuildPreserving(
    List<Song> queue, {
    int? forcedIndex,
  }) async {
    final wasPlaying = state.snapshot.playing;
    final position = state.snapshot.positionMs;
    final index = forcedIndex ?? state.currentIndex;
    await _applyQueue(queue, index, startPositionMs: position);
    if (wasPlaying) {
      await (await _engine).play();
    }
  }

  Future<void> _applyQueue(
    List<Song> songs,
    int index, {
    int? startPositionMs,
  }) async {
    _rebuilding = true;
    _recordedIndex = null;
    _lastPositionMs = startPositionMs ?? 0;
    _wasPlaying = false;
    try {
      state = state.copyWith(queue: songs, currentIndex: index);
      final handler = await _handler;
      if (songs.isEmpty || index < 0) {
        state = state.copyWith(snapshot: const PlaybackSnapshot());
        handler?.publishNowPlaying(null);
        handler?.publishQueue(const []);
        await _persist(songs);
        return;
      }
      handler?.publishQueue([
        for (final song in songs) _mediaItem(song),
      ]);
      final uris = <String>[];
      for (final song in songs) {
        uris.add(await _playbackUriFor(song));
      }
      await (await _engine).openQueue(
        uris: uris,
        startIndex: index,
        startPositionMs: startPositionMs,
      );
      await _publishCurrentMediaItem();
      await _persist(songs);
    } finally {
      _rebuilding = false;
    }
  }

  /// Remote songs carry a logical `subsonic://` path that must become a
  /// real stream URL before reaching the engine. On resolution failure
  /// (server deleted/offline config) we fall back to the raw path so the
  /// engine reports a playback error instead of this call crashing.
  Future<String> _playbackUriFor(Song song) async {
    if (song.sourceType != SourceType.remote) {
      return Uri.file(song.path).toString();
    }
    try {
      return await ref
          .read(remoteLibraryServiceProvider)
          .resolveStreamUri(song.path)
          .then((uri) => uri.toString());
    } on Exception catch (_) {
      return Uri.file(song.path).toString();
    }
  }

  Future<void> _publishCurrentMediaItem() async {
    final handler = await _handler;
    final song = state.currentSong;
    handler?.publishNowPlaying(song == null ? null : _mediaItem(song));
  }

  MediaItem _mediaItem(Song song) {
    return MediaItem(
      id: song.id.toString(),
      title: song.title,
      artist: song.artistName,
      album: song.albumTitle,
      duration: Duration(milliseconds: song.durationMs),
      artUri:
          song.artworkPath == null ? null : Uri.file(song.artworkPath!),
    );
  }

  Future<void> _saveNow() async {
    if (!state.hasCurrent) {
      return;
    }
    await _persist(
      state.queue,
      positionMs: state.snapshot.positionMs,
    );
  }

  Future<void> _persist(List<Song> queue, {int? positionMs}) async {
    final settings = ref.read(settingsRepositoryProvider);
    await settings.setString(
      _keyQueue,
      jsonEncode([for (final song in queue) song.id]),
    );
    await settings.setString(_keyIndex, '${state.currentIndex}');
    if (positionMs != null) {
      await settings.setString(_keyPosition, '$positionMs');
    }
  }
}

final playerControllerProvider =
    NotifierProvider<PlayerController, PlayerUiState>(
  PlayerController.new,
);
