import 'package:drift/drift.dart';

import 'package:whisplayer/data/db/app_database.dart';
import 'package:whisplayer/data/db/mappers.dart';
import 'package:whisplayer/data/db/tables.dart';
import 'package:whisplayer/domain/entities/existing_song_info.dart';
import 'package:whisplayer/domain/entities/song.dart';
import 'package:whisplayer/domain/entities/source_type.dart';

part 'song_dao.g.dart';

@DriftAccessor(tables: [Songs, Artists, Albums, PlayHistory])
class SongDao extends DatabaseAccessor<AppDatabase> with _$SongDaoMixin {
  SongDao(super.db);

  JoinedSelectStatement<HasResultSet, dynamic> _query({
    bool localOnly = false,
  }) {
    final q = select(songs).join([
      leftOuterJoin(artists, artists.id.equalsExp(songs.artistId)),
      leftOuterJoin(albums, albums.id.equalsExp(songs.albumId)),
    ]);
    if (localOnly) {
      q.where(songs.sourceType.equals(SourceType.local.index));
    }
    return q;
  }

  Song _map(TypedResult row) {
    final s = row.readTable(songs);
    final artist = row.readTableOrNull(artists);
    final album = row.readTableOrNull(albums);
    return s.toEntity(
      artistName: artist?.name,
      albumTitle: album?.title,
    );
  }

  OrderingTerm _order(SongSort sort, bool descending) {
    final mode =
        descending ? OrderingMode.desc : OrderingMode.asc;
    switch (sort) {
      case SongSort.title:
        return OrderingTerm(
          expression: songs.title.lower(),
          mode: mode,
        );
      case SongSort.artist:
        return OrderingTerm(
          expression: artists.name.lower(),
          mode: mode,
        );
      case SongSort.album:
        return OrderingTerm(
          expression: albums.title.lower(),
          mode: mode,
        );
      case SongSort.addedAt:
        return OrderingTerm(expression: songs.addedAtMs, mode: mode);
      case SongSort.playCount:
        return OrderingTerm(expression: songs.playCount, mode: mode);
      case SongSort.duration:
        return OrderingTerm(
          expression: songs.durationMs,
          mode: mode,
        );
    }
  }

  Stream<List<Song>> watchSongs({
    SongSort sort = SongSort.title,
    bool descending = false,
    bool localOnly = false,
  }) {
    final q = _query(localOnly: localOnly)
      ..orderBy([_order(sort, descending)]);
    return q.watch().map((rows) => rows.map(_map).toList());
  }

  Future<List<Song>> getAllSongs({
    SongSort sort = SongSort.title,
    bool descending = false,
  }) async {
    final q = _query()..orderBy([_order(sort, descending)]);
    final rows = await q.get();
    return rows.map(_map).toList();
  }

  Future<Song?> getSong(int songId) async {
    final q = _query()..where(songs.id.equals(songId));
    final rows = await q.get();
    return rows.isEmpty ? null : _map(rows.first);
  }

  Future<List<Song>> getSongsByAlbum(int albumId) async {
    final q = _query()
      ..where(songs.albumId.equals(albumId))
      ..orderBy([
        OrderingTerm.asc(songs.discNumber),
        OrderingTerm.asc(songs.trackNumber),
        OrderingTerm.asc(songs.title.lower()),
      ]);
    final rows = await q.get();
    return rows.map(_map).toList();
  }

  Future<List<Song>> getSongsByArtist(int artistId) async {
    final q = _query()
      ..where(songs.artistId.equals(artistId))
      ..orderBy([OrderingTerm.asc(songs.title.lower())]);
    final rows = await q.get();
    return rows.map(_map).toList();
  }

  Future<Song?> getLastPlayedSong() async {
    final q = _query()
      ..where(songs.lastPlayedAtMs.isNotNull())
      ..orderBy([
        OrderingTerm.asc(songs.lastPlayedAtMs.isNull()),
        OrderingTerm.desc(songs.lastPlayedAtMs),
      ])
      ..limit(1);
    final rows = await q.get();
    return rows.isEmpty ? null : _map(rows.first);
  }

  Future<List<Song>> search(
    String query, {
    int limit = 200,
    bool localOnly = false,
  }) async {
    final tokens = query
        .toLowerCase()
        .trim()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .map((t) => '"${t.replaceAll('"', '""')}"*')
        .toList();
    if (tokens.isEmpty) {
      return getAllSongs();
    }
    final match = tokens.join(' ');
    final idRows = await customSelect(
      'SELECT rowid FROM songs_fts WHERE songs_fts MATCH ? '
      'ORDER BY bm25(songs_fts) LIMIT ?',
      variables: [Variable<String>(match), Variable<int>(limit)],
      readsFrom: {songs},
    ).get();
    if (idRows.isEmpty) {
      return const [];
    }
    final ids = idRows.map((r) => r.read<int>('rowid')).toList();
    final q = _query(localOnly: localOnly)..where(songs.id.isIn(ids));
    final rows = await q.get();
    final byId = {for (final s in rows.map(_map)) s.id: s};
    return [
      for (final id in ids)
        if (byId[id] != null) byId[id]!,
    ];
  }

  Future<List<ExistingSongInfo>> loadExistingLight() async {
    final rows = await select(songs).get();
    return [
      for (final r in rows)
        ExistingSongInfo(
          songId: r.id,
          path: r.path,
          sizeBytes: r.fileSizeBytes,
          modifiedAtMs: r.modifiedAtMs,
        ),
    ];
  }

  Future<int> upsertByPath(SongsCompanion entry) async {
    final existing =
        await (select(songs)..where((t) => t.path.equals(entry.path.value)))
            .getSingleOrNull();
    if (existing == null) {
      return into(songs).insert(entry);
    }
    final updateValues = entry.copyWith(
      id: const Value.absent(),
      addedAtMs: const Value.absent(),
    );
    await (update(songs)..where((t) => t.id.equals(existing.id)))
        .write(updateValues);
    return existing.id;
  }
  Future<void> upsertAll(List<SongsCompanion> entries) {
    return batch((b) => b.insertAllOnConflictUpdate(songs, entries));
  }

  Future<void> setFavorite(int songId, {required bool favorite}) {
    return (update(songs)..where((t) => t.id.equals(songId))).write(
      SongsCompanion(isFavorite: Value(favorite)),
    );
  }

  Future<void> savePosition({
    required int songId,
    required int positionMs,
  }) {
    return (update(songs)..where((t) => t.id.equals(songId))).write(
      SongsCompanion(lastPositionMs: Value(positionMs)),
    );
  }

  Future<void> recordPlayback({
    required int songId,
    required int playedMs,
    required int playedAtMs,
    required bool completed,
  }) {
    return transaction(() async {

      final skipDelta = completed ? 0 : 1;
      await customStatement(
        'UPDATE songs SET play_count = play_count + 1, '
        'total_play_ms = total_play_ms + ?, '
        'skip_count = skip_count + ?, '
        'last_played_at_ms = ? '
        'WHERE id = ?',
        [playedMs, skipDelta, playedAtMs,
          songId,
        ],
      );
      await into(playHistory).insert(
        PlayHistoryCompanion.insert(
          songId: songId,
          playedAtMs: playedAtMs,
          playedMs: playedMs,
          completed: Value(completed),
        ),
      );
    });
  }

  Future<int> removeMissingFrom(Set<String> validPaths) {
    return transaction(() async {
      var removed = 0;
      if (validPaths.isEmpty) {
        removed = await delete(songs).go();
      } else {
        removed = await (delete(songs)..where(
          (t) => t.path.isNotIn(validPaths),
        )).go();
      }
      await customStatement(
        'DELETE FROM albums WHERE id NOT IN '
        '(SELECT DISTINCT album_id FROM songs WHERE album_id IS NOT NULL)',
      );
      await customStatement(
        'DELETE FROM artists WHERE id NOT IN ( '
        'SELECT artist_id FROM songs '
        'WHERE artist_id IS NOT NULL '
        'UNION '
        'SELECT artist_id FROM albums '
        'WHERE artist_id IS NOT NULL)',
      );
      return removed;
    });
  }
}
