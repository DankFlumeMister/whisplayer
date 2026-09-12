import 'dart:async';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:whisplayer/core/providers/playback_providers.dart';
import 'package:whisplayer/core/providers/repository_providers.dart';
import 'package:whisplayer/core/providers/scanner_providers.dart';
import 'package:whisplayer/domain/entities/playback.dart';
import 'package:whisplayer/domain/entities/song.dart';
import 'package:whisplayer/domain/entities/source_type.dart';
import 'package:whisplayer/domain/repositories/audio_engine.dart';
import 'package:whisplayer/features/player/application/playback_recorder.dart';
import 'package:whisplayer/features/player/application/playback_session_store.dart';
import 'package:whisplayer/player/media_session.dart';

class PlayerUiState {
  const PlayerUiState({
    this.queue = const [],
    this.currentIndex = -1,
    this.snapshot = const PlaybackSnapshot(),
    this.loopMode = PlaybackLoopMode.off,
    this.shuffleEnabled = false,
  });

  final List<Song> queue;
  final int currentIndex;
  final PlaybackSnapshot snapshot;
  final PlaybackLoopMode loopMode;
  final bool shuffleEnabled;

  bool get hasCurrent =>
      currentIndex >= 0 && currentIndex < queue.length;

  Song? get currentSong => hasCurrent ? queue[currentIndex] : null;

  bool get isPlaying => snapshot.playing;

  PlayerUiState copyWith({
    List<Song>? queue,
    int? currentIndex,
    PlaybackSnapshot? snapshot,
    PlaybackLoopMode? loopMode,
    bool? shuffleEnabled,
  }) {
    return PlayerUiState(
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      snapshot: snapshot ?? this.snapshot,
      loopMode: loopMode ?? this.loopMode,
      shuffleEnabled: shuffleEnabled ?? this.shuffleEnabled,
    );
  }
}

class PlayerController extends Notifier<PlayerUiState>
    implements SessionDelegate {
  StreamSubscription<PlaybackSnapshot>? _sub;
  Timer? _saver;
  bool _restored = false;
  bool _rebuilding = false;
  bool _sessionBound = false;
  int _pendingPositionMs = 0;
  final Random _random = Random();
  final List<int> _shuffleHistory = <int>[];
  final Set<int> _shuffledPlayed = <int>{};

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

  PlaybackPositionNotifier get _position =>
      ref.read(playbackPositionProvider.notifier);

  int get _positionMs => ref.read(playbackPositionProvider);

  PlaybackSessionStore get _sessionStore =>
      ref.read(playbackSessionStoreProvider);

  PlaybackRecorder get _recorder => ref.read(playbackRecorderProvider);

  static const _handlerInitTimeout = Duration(seconds: 5);

  Future<MediaSession?> get _handler async {
    try {
      final handler = await ref
          .read(playerHandlerProvider.future)
          .timeout(_handlerInitTimeout);
      if (!_sessionBound) {
        _sessionBound = true;
        handler.bindSession(this);
      }
      return handler;
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

    final session = await _sessionStore.read();
    _pendingPositionMs = session.positionMs;

    final library = ref.read(libraryRepositoryProvider);
    final byId = {
      for (final song in await library.getAllSongs()) song.id: song,
    };
    final queue = [
      for (final id in session.queueIds)
        if (byId[id] != null) byId[id]!,
    ];
    final index = session.resolveIndex(queue.length);

    state = state.copyWith(
      queue: queue,
      currentIndex: index,
      loopMode: session.loopMode,
      shuffleEnabled: session.shuffleEnabled,
    );
    (await _engine).setLoopMode(session.loopMode);
    await _publishCurrentMediaItem();
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
      unawaited(_recorder.recordDeparture(
        queue: state.queue,
        index: index,
      ));
      index = q;
      _recorder.clear();
    } else {
      if (_recorder.isLoopWrap(
        snap,
        rebuilding: _rebuilding,
        hasCurrent: state.hasCurrent,
      )) {
        unawaited(_recorder.recordFullListen(
          song: state.currentSong,
          currentIndex: state.currentIndex,
          rearm: true,
        ));
      }
    }

    final previous = state.snapshot;
    final transition = advanced ||
        snap.state != previous.state ||
        snap.playing != previous.playing ||
        snap.durationMs != previous.durationMs ||
        snap.queueIndex != previous.queueIndex;
    if (transition) {
      state = state.copyWith(
        snapshot: snap,
        currentIndex: advanced ? q : null,
      );
      _position.positionMs = snap.positionMs;

      if (!advanced &&
          snap.state == EngineState.completed &&
          state.hasCurrent) {
        unawaited(_recorder.recordFullListen(
          song: state.currentSong,
          currentIndex: state.currentIndex,
          rearm: false,
        ));
      }

      if (advanced) {
        unawaited(_publishCurrentMediaItem());
        unawaited(_saveNow());
      }
      unawaited(_backfillDurationIfNeeded(snap));
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
    } else {
      _position.positionMs = snap.positionMs;
    }
    _recorder.noteSnapshot(snap);
  }

  /// Songs already probed this session, so the write happens at most once
  /// each even though the engine re-reports its duration on every tick.
  final Set<int> _durationBackfilled = <int>{};

  /// Persists the duration the engine probed from a WebDAV stream.
  ///
  /// Such files carry no embedded tags, so the row starts at 0 and the
  /// progress bar would stay dead forever. The first real value the engine
  /// reports is written back — but never over an existing duration, and never
  /// for a local or Subsonic song (their durations are already known).
  Future<void> _backfillDurationIfNeeded(PlaybackSnapshot snap) async {
    final song = state.currentSong;
    if (song == null ||
        snap.durationMs <= 0 ||
        song.durationMs > 0 ||
        song.sourceType != SourceType.webdav ||
        !_durationBackfilled.add(song.id)) {
      return;
    }
    try {
      await ref.read(libraryWriterRepositoryProvider).setSongDuration(
            songId: song.id,
            durationMs: snap.durationMs,
          );
      await _publishCurrentMediaItem();
    } on Object catch (_) {
      // A failed write must not disturb playback; drop the guard so a later
      // tick can retry.
      _durationBackfilled.remove(song.id);
    }
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
      _recorder.clear();
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
    final randomNext = _pickRandomNext();
    if (randomNext != null) {
      _shuffleHistory.add(state.currentIndex);
      _shuffledPlayed.add(state.currentIndex);
      await skipTo(randomNext);
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
    if (_positionMs > PlaybackRecorder.restartThresholdMs) {
      await (await _engine).seek(Duration.zero);
      return;
    }
    if (state.shuffleEnabled && _shuffleHistory.isNotEmpty) {
      await skipTo(_shuffleHistory.removeLast());
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
    await _recorder.recordDeparture(
      queue: state.queue,
      index: state.currentIndex,
    );
    _recorder.clear();
    state = state.copyWith(currentIndex: index);
    await (await _engine).skipToIndex(index);
    await _publishCurrentMediaItem();
    await _saveNow();
  }

  /// Toggles random playback over the current queue. Shuffle keeps its
  /// own visited set so every song plays once before a new round.
  Future<void> setShuffle({required bool enabled}) async {
    if (state.shuffleEnabled == enabled) {
      return;
    }
    state = state.copyWith(shuffleEnabled: enabled);
    _resetShuffleMemory();
    await _sessionStore.saveShuffle(enabled: enabled);
  }

  /// Random next index when shuffle is on; null otherwise. When every
  /// other song has been played the visited set resets (round-based).
  int? _pickRandomNext() {
    if (!state.shuffleEnabled || state.queue.length < 2) {
      return null;
    }
    var candidates = <int>[
      for (var i = 0; i < state.queue.length; i++)
        if (i != state.currentIndex && !_shuffledPlayed.contains(i)) i,
    ];
    if (candidates.isEmpty) {
      _shuffledPlayed.clear();
      candidates = <int>[
        for (var i = 0; i < state.queue.length; i++)
          if (i != state.currentIndex) i,
      ];
    }
    if (candidates.isEmpty) {
      return null;
    }
    return candidates[_random.nextInt(candidates.length)];
  }

  void _resetShuffleMemory() {
    _shuffleHistory.clear();
    _shuffledPlayed.clear();
  }

  Future<void> cycleLoopMode() async {
    const order = PlaybackLoopMode.values;
    final next =
        order[(order.indexOf(state.loopMode) + 1) % order.length];
    state = state.copyWith(loopMode: next);
    (await _engine).setLoopMode(next);
    await _sessionStore.saveLoopMode(next);
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
      await _recorder.recordDeparture(queue: state.queue, index: index);
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
    await _recorder.recordDeparture(
      queue: state.queue,
      index: state.currentIndex,
    );
    _rebuilding = true;
    try {
      state = PlayerUiState(loopMode: state.loopMode);
      _pendingPositionMs = 0;
      _position.reset();
      _recorder.reset();
      _resetShuffleMemory();
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
    final position = _positionMs;
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
    _recorder.reset(positionMs: startPositionMs ?? 0);
    _position.reset();
    _resetShuffleMemory();
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
    // `on Object` rather than `on Exception`: the resolvers signal a missing
    // server with StateError, which is an Error and would otherwise escape
    // and kill the play call.
    switch (song.sourceType) {
      case SourceType.remote:
        try {
          return await ref
              .read(remoteLibraryServiceProvider)
              .resolveStreamUri(song.path)
              .then((uri) => uri.toString());
        } on Object catch (_) {
          return _fileUri(song.path);
        }
      case SourceType.webdav:
        // The URL stays credential-free; the engine attaches the
        // Authorization header (see WebDavStreamService.headersFor).
        try {
          return await ref
              .read(webDavStreamServiceProvider)
              .resolveUri(song.path)
              .then((uri) => uri.toString());
        } on Object catch (_) {
          return _fileUri(song.path);
        }
      case SourceType.local:
        return _fileUri(song.path);
    }
  }

  /// Last-resort URI for an unresolvable path.
  ///
  /// A logical `webdav://` or `subsonic://` path is not a legal file path, so
  /// [Uri.file] can itself throw; the raw string is returned in that case and
  /// the engine reports a playback error rather than this call crashing.
  String _fileUri(String path) {
    try {
      return Uri.file(path).toString();
    } on Object catch (_) {
      return path;
    }
  }

  Future<void> _publishCurrentMediaItem() async {
    final handler = await _handler;
    final song = state.currentSong;
    handler?.publishNowPlaying(song == null ? null : _mediaItem(song));
  }

  MediaItem _mediaItem(Song song) {
    // A known duration always wins. Only when the row has none (a freshly
    // synced WebDAV song) does the probed value stand in, so a mid-transition
    // snapshot can never overwrite a real number.
    final probed = state.snapshot.durationMs;
    final durationMs = song.durationMs > 0 ? song.durationMs : probed;
    return MediaItem(
      id: song.id.toString(),
      title: song.title,
      artist: song.artistName,
      album: song.albumTitle,
      duration: Duration(milliseconds: durationMs),
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
      positionMs: _positionMs,
    );
  }

  Future<void> _persist(List<Song> queue, {int? positionMs}) async {
    await _sessionStore.saveQueue(
      [for (final song in queue) song.id],
      state.currentIndex,
      positionMs: positionMs,
    );
  }
}

final playerControllerProvider =
    NotifierProvider<PlayerController, PlayerUiState>(
  PlayerController.new,
);
