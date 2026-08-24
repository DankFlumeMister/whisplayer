import 'package:whisplayer/data/db/app_database.dart';
import 'package:whisplayer/domain/entities/play_history_entry.dart';
import 'package:whisplayer/domain/entities/play_stats.dart';
import 'package:whisplayer/domain/entities/playlist.dart';
import 'package:whisplayer/domain/repositories/playlist_repository.dart';

class DriftPlaylistRepository implements PlaylistRepository {
  DriftPlaylistRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<Playlist>> watchPlaylists() => _db.playlistDao.watchAll();

  @override
  Future<Playlist> createPlaylist(String name) =>
      _db.playlistDao.create(name);

  @override
  Future<void> renamePlaylist(int playlistId, String newName) =>
      _db.playlistDao.rename(playlistId, newName);

  @override
  Future<void> deletePlaylist(int playlistId) =>
      _db.playlistDao.remove(playlistId);

  @override
  Future<int> addSong(int playlistId, int songId) =>
      _db.playlistDao.addSong(playlistId, songId);

  @override
  Future<void> removeEntry(int entryId) =>
      _db.playlistDao.removeEntry(entryId);

  @override
  Future<void> removeEntries(List<int> entryIds) =>
      _db.playlistDao.removeEntries(entryIds);

  @override
  Future<void> reorderEntries(List<int> orderedEntryIds) =>
      _db.playlistDao.reorder(orderedEntryIds);

  @override
  Future<void> clearSongs(int playlistId) =>
      _db.playlistDao.clearSongs(playlistId);

  @override
  Stream<List<PlaylistEntry>> watchEntries(int playlistId) =>
      _db.playlistDao.watchEntries(playlistId);
}

class DriftHistoryRepository implements HistoryRepository {
  DriftHistoryRepository(this._db);

  final AppDatabase _db;

  @override
  Future<void> addPlayRecord({
    required int songId,
    required int playedAtMs,
    required int playedMs,
    required bool completed,
  }) {
    return _db.historyDao.add(
      songId: songId,
      playedAtMs: playedAtMs,
      playedMs: playedMs,
      completed: completed,
    );
  }

  @override
  Stream<List<PlayHistoryEntry>> watchRecent({int limit = 100}) {
    return _db.historyDao.watchRecent(limit: limit);
  }

  @override
  Future<PlayStats> overallStats() async {
    final row = await _db.historyDao.overallStats();
    return PlayStats(
      totalPlays: row['totalPlays'] as int? ?? 0,
      totalPlayedMs: row['totalPlayedMs'] as int? ?? 0,
      completedPlays: row['completedPlays'] as int? ?? 0,
    );
  }
}
