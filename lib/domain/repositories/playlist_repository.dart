import 'package:whisplayer/domain/entities/play_history_entry.dart';
import 'package:whisplayer/domain/entities/play_stats.dart';
import 'package:whisplayer/domain/entities/playlist.dart';

abstract interface class PlaylistRepository {
  Stream<List<Playlist>> watchPlaylists();

  Future<Playlist> createPlaylist(String name);

  Future<void> renamePlaylist(int playlistId, String newName);

  Future<void> deletePlaylist(int playlistId);

  Future<int> addSong(int playlistId, int songId);

  Future<void> removeEntry(int entryId);

  /// Removes several entries in one transaction, then compacts positions.
  Future<void> removeEntries(List<int> entryIds);

  Future<void> reorderEntries(List<int> orderedEntryIds);

  Future<void> clearSongs(int playlistId);

  Stream<List<PlaylistEntry>> watchEntries(int playlistId);
}

abstract interface class HistoryRepository {
  Future<void> addPlayRecord({
    required int songId,
    required int playedAtMs,
    required int playedMs,
    required bool completed,
  });

  Stream<List<PlayHistoryEntry>> watchRecent({int limit});

  Future<PlayStats> overallStats();
}
