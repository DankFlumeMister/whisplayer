import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:whisplayer/core/providers/playback_providers.dart';
import 'package:whisplayer/core/providers/repository_providers.dart';
import 'package:whisplayer/core/providers/scanner_providers.dart';
import 'package:whisplayer/data/metadata/isolate_metadata_reader.dart';
import 'package:whisplayer/domain/entities/playback.dart';
import 'package:whisplayer/domain/entities/song.dart';
import 'package:whisplayer/domain/entities/source_type.dart';
import 'package:whisplayer/domain/lyrics/lyric_parser.dart';
import 'package:whisplayer/features/player/application/player_controller.dart';

const _keyOffset = 'lyrics.offset_ms';
const _keyFontScale = 'lyrics.font_scale';
const _keyAlign = 'lyrics.alignment';

enum LyricAlign { left, center, right }

enum LyricsStatus { idle, loading, synced, unsynced, none }

class LyricsUiState {
  const LyricsUiState({
    this.status = LyricsStatus.idle,
    this.document = LyricDocument.empty,
    this.activeIndex = -1,
    this.offsetMs = 0,
    this.fontScale = 1.0,
    this.align = LyricAlign.left,
    this.currentLineText = '',
  });

  final LyricsStatus status;
  final LyricDocument document;
  final int activeIndex;
  final int offsetMs;
  final double fontScale;
  final LyricAlign align;
  final String currentLineText;

  bool get hasContent =>
      status == LyricsStatus.synced ||
      status == LyricsStatus.unsynced;

  LyricsUiState copyWith({
    LyricsStatus? status,
    LyricDocument? document,
    int? activeIndex,
    int? offsetMs,
    double? fontScale,
    LyricAlign? align,
    String? currentLineText,
  }) {
    return LyricsUiState(
      status: status ?? this.status,
      document: document ?? this.document,
      activeIndex: activeIndex ?? this.activeIndex,
      offsetMs: offsetMs ?? this.offsetMs,
      fontScale: fontScale ?? this.fontScale,
      align: align ?? this.align,
      currentLineText: currentLineText ?? this.currentLineText,
    );
  }
}

class LyricsController extends Notifier<LyricsUiState> {
  StreamSubscription<PlaybackSnapshot>? _positionSub;
  final _rawCache = <int, String>{};
  int? _loadedSongId;
  int _lastPositionMs = 0;

  static const _sidecarExtensions = ['.lrc', '.vtt', '.srt'];

  @override
  LyricsUiState build() {
    ref.onDispose(() {
      unawaited(_positionSub?.cancel());
    });
    ref.listen(playerControllerProvider, (previous, next) {
      final song = next.currentSong;
      if (song != null && song.id != _loadedSongId) {
        unawaited(_loadFor(song));
      }
    });
    final current = ref.read(playerControllerProvider).currentSong;
    if (current != null && current.id != _loadedSongId) {
      unawaited(_loadFor(current));
    }
    return const LyricsUiState();
  }

  Future<void> _initPositionListener() async {
    if (_positionSub != null) {
      return;
    }
    final engine = await ref.read(audioEngineProvider.future);
    _positionSub = engine.snapshots.listen(_onPosition);
    await _loadSettingsOnce();
  }

  bool _settingsLoaded = false;

  Future<void> _loadSettingsOnce() async {
    if (_settingsLoaded) {
      return;
    }
    _settingsLoaded = true;
    final repo = ref.read(settingsRepositoryProvider);
    final offset =
        int.tryParse(await repo.getString(_keyOffset) ?? '') ?? 0;
    final scale = double.tryParse(
          await repo.getString(_keyFontScale) ?? '',
        ) ??
        1.0;
    final alignName = await repo.getString(_keyAlign);
    var align = LyricAlign.left;
    for (final a in LyricAlign.values) {
      if (a.name == alignName) {
        align = a;
      }
    }
    state = state.copyWith(
      offsetMs: offset.clamp(-10000, 10000),
      fontScale: scale.clamp(0.7, 2.0),
      align: align,
    );
  }

  void _onPosition(PlaybackSnapshot snap) {
    _lastPositionMs = snap.positionMs;
    if (!state.document.synced) {
      return;
    }
    final index = state.document
        .shifted(state.offsetMs)
        .indexAt(_lastPositionMs);
    if (index != state.activeIndex) {
      state = state.copyWith(activeIndex: index);
    }
  }

  Future<void> _loadFor(Song song) async {
    await _initPositionListener();
    _loadedSongId = song.id;
    state = state.copyWith(
      status: LyricsStatus.loading,
      activeIndex: -1,
      document: LyricDocument.empty,
    );

    final raw = _rawCache[song.id] ??
        await _readSidecar(song.lyricsPath) ??
        song.lyricsText ??
        (song.sourceType == SourceType.local
            ? await _probeSidecar(song.path)
            : null) ??
        (song.sourceType == SourceType.local
            ? await readEmbeddedLyrics(song.path)
            : null) ??
        (song.sourceType == SourceType.remote
            ? await ref
                .read(remoteLibraryServiceProvider)
                .fetchLyricsText(song)
            : null);

    if (raw == null || raw.trim().isEmpty) {
      state = state.copyWith(status: LyricsStatus.none);
      return;
    }
    _rawCache[song.id] = raw;
    const parser = LyricParser();
    final doc = parser.parse(raw);
    state = state.copyWith(
      document: doc,
      status: doc.synced
          ? LyricsStatus.synced
          : LyricsStatus.unsynced,
    );
  }

  Future<String?> _probeSidecar(String audioPath) async {
    final dot = audioPath.lastIndexOf('.');
    final base = dot < 0 ? audioPath : audioPath.substring(0, dot);
    for (final ext in _sidecarExtensions) {
      final file = File('$base$ext');
      if (file.existsSync()) {
        try {
          return file.readAsStringSync();
        } on FileSystemException catch (_) {
          return null;
        }
      }
    }
    return null;
  }

  Future<String?> _readSidecar(String? path) async {
    if (path == null || path.contains('://')) {
      return null;
    }
    try {
      final file = File(path);
      if (!file.existsSync()) {
        return null;
      }
      return file.readAsStringSync();
    } on FileSystemException catch (_) {
      return null;
    }
  }

  Future<void> setOffset(int deltaMs) async {
    final next =
        (state.offsetMs + deltaMs).clamp(-10000, 10000);
    state = state.copyWith(offsetMs: next);
    await ref
        .read(settingsRepositoryProvider)
        .setString(_keyOffset, '$next');
  }

  Future<void> setFontScale(double scale) async {
    final next = scale.clamp(0.7, 2.0);
    state = state.copyWith(fontScale: next);
    await ref
        .read(settingsRepositoryProvider)
        .setString(_keyFontScale, '$next');
  }

  Future<void> setAlignment(LyricAlign align) async {
    state = state.copyWith(align: align);
    await ref
        .read(settingsRepositoryProvider)
        .setString(_keyAlign, align.name);
  }

  Future<void> importLyricsFile(String raw) async {
    final song = ref.read(playerControllerProvider).currentSong;
    if (song == null) {
      return;
    }
    final text = raw.trim();
    const parser = LyricParser();
    final doc = parser.parse(text);
    _rawCache[song.id] = text;
    state = state.copyWith(
      document: doc,
      status: doc.synced
          ? LyricsStatus.synced
          : LyricsStatus.unsynced,
    );
    await ref
        .read(libraryWriterRepositoryProvider)
        .saveLyricsText(songId: song.id, text: text);
  }
}

final lyricsControllerProvider =
    NotifierProvider<LyricsController, LyricsUiState>(
  LyricsController.new,
);
