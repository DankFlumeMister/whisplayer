import 'dart:async';

import 'package:audio_service/audio_service.dart';

import 'package:whisplayer/domain/entities/album.dart';
import 'package:whisplayer/domain/entities/artist.dart';
import 'package:whisplayer/domain/entities/play_history_entry.dart';
import 'package:whisplayer/domain/entities/play_stats.dart';
import 'package:whisplayer/domain/entities/playback.dart';
import 'package:whisplayer/domain/entities/song.dart';
import 'package:whisplayer/domain/repositories/audio_engine.dart';
import 'package:whisplayer/domain/repositories/library_repository.dart';
import 'package:whisplayer/domain/repositories/playback_record_repository.dart';
import 'package:whisplayer/domain/repositories/playlist_repository.dart';
import 'package:whisplayer/domain/repositories/settings_repository.dart';
import 'package:whisplayer/features/library/domain/browse_prefs.dart';
import 'package:whisplayer/player/media_session.dart';

/// In-memory [SettingsRepository]; `setString(key, null)` removes the key.
class FakeSettingsRepository implements SettingsRepository {
  FakeSettingsRepository([Map<String, String>? initial])
      : values = initial ?? {};

  final Map<String, String> values;

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> setString(String key, String? value) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<Map<String, String>> getAll() async => Map.of(values);

  @override
  Future<BrowsePrefs> getBrowsePrefs() async => BrowsePrefs.defaults;

  @override
  Future<void> setBrowsePrefs(BrowsePrefs prefs) async {}
}

/// [AudioEngine] with a controllable snapshot stream and recorded calls.
class FakeAudioEngine implements AudioEngine {
  final _snapshots = StreamController<PlaybackSnapshot>.broadcast();

  /// Pushes one snapshot to subscribers.
  void emit(PlaybackSnapshot snap) => _snapshots.add(snap);

  bool openQueueCalled = false;
  bool playCalled = false;
  int openedStartIndex = -1;
  int? openedStartPositionMs;
  int setLoopModeCalls = 0;
  PlaybackLoopMode? lastLoopMode;
  final List<Duration> seeks = <Duration>[];
  final List<int> skippedIndexes = <int>[];

  @override
  Stream<PlaybackSnapshot> get snapshots => _snapshots.stream;

  @override
  PlaybackSnapshot get current => const PlaybackSnapshot();

  @override
  Future<void> openQueue({
    required List<String> uris,
    required int startIndex,
    int? startPositionMs,
  }) async {
    openQueueCalled = true;
    openedStartIndex = startIndex;
    openedStartPositionMs = startPositionMs;
  }

  @override
  Future<void> play() async {
    playCalled = true;
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> seek(Duration position) async {
    seeks.add(position);
  }

  @override
  Future<void> skipToIndex(int index) async {
    skippedIndexes.add(index);
  }

  @override
  void setLoopMode(PlaybackLoopMode mode) {
    setLoopModeCalls++;
    lastLoopMode = mode;
  }

  @override
  Future<void> dispose() async {}
}

/// [LibraryRepository] over an in-memory song list.
///
/// [watchSongs] streams [songs] only when [exposeSongsInWatch] is set
/// (widget tests that render the library list), otherwise it stays empty
/// so search/queue tests see a blank library page.
class FakeLibraryRepository implements LibraryRepository {
  FakeLibraryRepository({
    this.songs = const <Song>[],
    this.search,
    this.exposeSongsInWatch = false,
  });

  final List<Song> songs;
  final List<Song> Function(String query)? search;
  final bool exposeSongsInWatch;

  @override
  Future<List<Song>> getAllSongs() async => songs;

  @override
  Future<Song?> getSong(int songId) async {
    for (final song in songs) {
      if (song.id == songId) {
        return song;
      }
    }
    return null;
  }

  @override
  Stream<List<Song>> watchSongs({
    SongSort sort = SongSort.title,
    bool descending = false,
  }) {
    return Stream.value(exposeSongsInWatch ? songs : const <Song>[]);
  }

  @override
  Stream<List<Song>> watchLocalSongs({
    SongSort sort = SongSort.title,
    bool descending = false,
  }) {
    return Stream.value(exposeSongsInWatch ? songs : const <Song>[]);
  }

  @override
  Future<List<Song>> searchLocalSongs(String query) async {
    final custom = search;
    if (custom != null) {
      return custom(query);
    }
    final normalized = query.toLowerCase();
    return [
      for (final song in songs)
        if (song.title.toLowerCase().contains(normalized)) song,
    ];
  }

  @override
  Stream<List<Album>> watchAlbums() => Stream.value(const <Album>[]);

  @override
  Stream<List<Artist>> watchArtists() => Stream.value(const <Artist>[]);

  @override
  Future<List<Song>> songsByAlbum(int albumId) async => const <Song>[];

  @override
  Future<List<Song>> songsByArtist(int artistId) async => const <Song>[];

  @override
  Future<void> setFavorite(int songId, {required bool favorite}) async {}
}

/// Records `songId:playedMs:completed` strings for assertions.
class FakePlaybackRecordRepository implements PlaybackRecordRepository {
  final List<String> plays = <String>[];

  @override
  Future<void> recordPlayback({
    required int songId,
    required int playedMs,
    required int playedAtMs,
    required bool completed,
  }) async {
    plays.add('$songId:$playedMs:$completed');
  }
}

/// [HistoryRepository] over fixed entries and stats.
class FakeHistoryRepository implements HistoryRepository {
  FakeHistoryRepository({
    this.entries = const <PlayHistoryEntry>[],
    this.stats,
  });

  final List<PlayHistoryEntry> entries;
  final PlayStats? stats;

  @override
  Stream<List<PlayHistoryEntry>> watchRecent({int limit = 100}) {
    return Stream.value(entries);
  }

  @override
  Future<PlayStats> overallStats() async {
    return stats ??
        const PlayStats(
          totalPlays: 0,
          totalPlayedMs: 0,
          completedPlays: 0,
        );
  }
}

/// In-memory [MediaSession]; keeps the last published item, every
/// published queue and the bound delegate for assertions.
class FakeMediaSession implements MediaSession {
  MediaItem? lastNowPlaying;
  final List<List<MediaItem>> publishedQueues = <List<MediaItem>>[];
  SessionDelegate? boundDelegate;

  @override
  void bindSession(SessionDelegate delegate) {
    boundDelegate = delegate;
  }

  @override
  void publishNowPlaying(MediaItem? item) {
    lastNowPlaying = item;
  }

  @override
  void publishQueue(List<MediaItem> items) {
    publishedQueues.add(items);
  }
}
