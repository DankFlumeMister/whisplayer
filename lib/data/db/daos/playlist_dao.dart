import 'package:drift/drift.dart';

import 'package:whisplayer/data/db/app_database.dart';
import 'package:whisplayer/data/db/mappers.dart';
import 'package:whisplayer/data/db/tables.dart';
import 'package:whisplayer/domain/entities/playlist.dart';

part 'playlist_dao.g.dart';

@DriftAccessor(tables: [Playlists, PlaylistEntries, Songs, Artists, Albums])
class PlaylistDao extends DatabaseAccessor<AppDatabase>
    with _$PlaylistDaoMixin {
  PlaylistDao(super.db);

  Stream<List<Playlist>> watchAll() {
    final songCount = playlistEntries.id.count();
    final q = select(playlists).join([
      leftOuterJoin(
        playlistEntries,
        playlistEntries.playlistId.equalsExp(playlists.id),
      ),
    ])
      ..addColumns([songCount])
      ..groupBy([playlists.id])
      ..orderBy([OrderingTerm.asc(playlists.name.lower())]);
    return q.watch().map(
      (rows) => rows
          .map(
            (r) => r.readTable(playlists).toEntity(
              songCount: r.read(songCount) ?? 0,
            ),
          )
          .toList(),
    );
  }

  Future<Playlist> create(String name) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = await into(playlists).insert(
      PlaylistsCompanion.insert(name: name, createdAtMs: now,
          updatedAtMs: now),
    );
    return Playlist(
      id: id,
      name: name,
      createdAtMs: now,
      updatedAtMs: now,
      songCount: 0,
    );
  }

  Future<void> rename(int playlistId, String newName) {
    return (update(playlists)..where((t) => t.id.equals(playlistId)))
        .write(
      PlaylistsCompanion(
        name: Value(newName),
        updatedAtMs: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> remove(int playlistId) {
    return (delete(playlists)..where((t) => t.id.equals(playlistId)))
        .go();
  }

  Future<int> addSong(int playlistId, int songId) {
    return transaction(() async {
      final maxRow = await customSelect(
        'SELECT COALESCE(MAX(position), -1) AS max_pos '
        'FROM playlist_entries WHERE playlist_id = ?',
        variables: [Variable<int>(playlistId)],
        readsFrom: {playlistEntries},
      ).getSingle();
      final nextPos = maxRow.read<int>('max_pos') + 1;
      return into(playlistEntries).insert(
        PlaylistEntriesCompanion.insert(
          playlistId: playlistId,
          songId: songId,
          position: nextPos,
          addedAtMs: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    });
  }

  Future<void> removeEntry(int entryId) {
    return transaction(() async {
      await (delete(playlistEntries)
            ..where((t) => t.id.equals(entryId)))
          .go();
      await _compactPositions();
    });
  }

  Future<void> removeEntries(List<int> entryIds) {
    return transaction(() async {
      if (entryIds.isEmpty) {
        return;
      }
      await (delete(playlistEntries)
            ..where((t) => t.id.isIn(entryIds)))
          .go();
      await _compactPositions();
    });
  }

  Future<void> clearSongs(int playlistId) {
    return (delete(playlistEntries)..where(
      (t) => t.playlistId.equals(playlistId),
    )).go();
  }

  Future<void> reorder(List<int> orderedEntryIds) {
    return transaction(() async {
      for (var i = 0; i < orderedEntryIds.length; i++) {
        await (update(playlistEntries)
              ..where((t) => t.id.equals(orderedEntryIds[i])))
            .write(PlaylistEntriesCompanion(position: Value(i)));
      }
    });
  }

  Future<void> _compactPositions() async {
    await customStatement(
      'UPDATE playlist_entries SET position = '
      '(SELECT COUNT(*) FROM playlist_entries AS other '
      'WHERE other.playlist_id = playlist_entries.playlist_id '
      'AND other.position < playlist_entries.position)',
    );
  }

  Stream<List<PlaylistEntry>> watchEntries(int playlistId) {
    final q = select(playlistEntries).join([
      innerJoin(songs, songs.id.equalsExp(playlistEntries.songId)),
      leftOuterJoin(artists, artists.id.equalsExp(songs.artistId)),
      leftOuterJoin(albums, albums.id.equalsExp(songs.albumId)),
    ])
      ..where(playlistEntries.playlistId.equals(playlistId))
      ..orderBy([OrderingTerm.asc(playlistEntries.position)]);
    return q.watch().map(
      (rows) => rows
          .map(
            (r) => PlaylistEntry(
              entryId: r.readTable(playlistEntries).id,
              position: r.readTable(playlistEntries).position,
              song: r.readTable(songs).toEntity(
                artistName: r.readTableOrNull(artists)?.name,
                albumTitle: r.readTableOrNull(albums)?.title,
              ),
            ),
          )
          .toList(),
    );
  }
}
