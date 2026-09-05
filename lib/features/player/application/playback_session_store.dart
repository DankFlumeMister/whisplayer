import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:whisplayer/core/providers/repository_providers.dart';
import 'package:whisplayer/domain/entities/playback.dart';
import 'package:whisplayer/domain/repositories/settings_repository.dart';

/// Owns the playback-session persistence keys and their string encoding.
///
/// This is the typed-store pattern (see BrowsePrefs) applied to the
/// playback session: callers no longer know key names, JSON shapes, enum
/// names or clamp rules — the store is the single place where the
/// settings seam and the session value meet.
class PlaybackSessionStore {
  PlaybackSessionStore(this._settings);

  final SettingsRepository _settings;

  static const _keyQueue = 'playback.queue_json';
  static const _keyIndex = 'playback.index';
  static const _keyPosition = 'playback.position_ms';
  static const _keyLoop = 'playback.loop_mode';
  static const _keyShuffle = 'playback.shuffle';

  /// Reads the whole stored session, tolerating missing or malformed
  /// values (empty queue, index -1, position 0, loop off, shuffle off).
  Future<StoredPlaybackSession> read() async {
    final queueIds = _decodeIds(await _settings.getString(_keyQueue));
    final index =
        int.tryParse(await _settings.getString(_keyIndex) ?? '') ?? -1;
    final positionMs =
        int.tryParse(await _settings.getString(_keyPosition) ?? '') ?? 0;
    final loopMode = _parseLoopMode(await _settings.getString(_keyLoop));
    final shuffleEnabled =
        await _settings.getString(_keyShuffle) == 'true';
    return StoredPlaybackSession(
      queueIds: queueIds,
      index: index,
      positionMs: positionMs,
      loopMode: loopMode,
      shuffleEnabled: shuffleEnabled,
    );
  }

  /// Persists the queue as song-id JSON plus the current index; the
  /// position is written only when given (the stored position is consumed
  /// once on first play, see PlayerController).
  Future<void> saveQueue(
    List<int> songIds,
    int currentIndex, {
    int? positionMs,
  }) async {
    await _settings.setString(_keyQueue, jsonEncode(songIds));
    await _settings.setString(_keyIndex, '$currentIndex');
    if (positionMs != null) {
      await _settings.setString(_keyPosition, '$positionMs');
    }
  }

  Future<void> saveLoopMode(PlaybackLoopMode mode) =>
      _settings.setString(_keyLoop, mode.name);

  Future<void> saveShuffle({required bool enabled}) =>
      _settings.setString(_keyShuffle, enabled ? 'true' : 'false');

  static List<int> _decodeIds(String? json) {
    if (json == null || json.isEmpty) {
      return const <int>[];
    }
    try {
      final raw = jsonDecode(json) as List<dynamic>;
      return raw.whereType<int>().toList();
    } on FormatException {
      return const <int>[];
    }
  }

  static PlaybackLoopMode _parseLoopMode(String? name) {
    for (final mode in PlaybackLoopMode.values) {
      if (mode.name == name) {
        return mode;
      }
    }
    return PlaybackLoopMode.off;
  }
}

/// Decoded playback session as persisted by [PlaybackSessionStore].
class StoredPlaybackSession {
  const StoredPlaybackSession({
    required this.queueIds,
    required this.index,
    required this.positionMs,
    required this.loopMode,
    required this.shuffleEnabled,
  });

  final List<int> queueIds;
  final int index;
  final int positionMs;
  final PlaybackLoopMode loopMode;
  final bool shuffleEnabled;

  /// Clamps the saved index into [queueLength]: an out-of-range index
  /// restarts at 0, an empty queue yields -1.
  int resolveIndex(int queueLength) {
    if (index < queueLength) {
      return index;
    }
    return queueLength == 0 ? -1 : 0;
  }
}

final playbackSessionStoreProvider = Provider<PlaybackSessionStore>(
  (ref) => PlaybackSessionStore(ref.watch(settingsRepositoryProvider)),
);
