import 'package:drift/drift.dart';

import 'package:whisplayer/data/db/app_database.dart';
import 'package:whisplayer/data/db/mappers.dart';
import 'package:whisplayer/data/db/tables.dart';
import 'package:whisplayer/domain/entities/existing_song_info.dart';
import 'package:whisplayer/domain/entities/song.dart';
import 'package:whisplayer/domain/entities/source_type.dart';

part 'song_dao.g.dart';

/// Rows staged per `INSERT` when cleaning up after a scan. Small enough to stay
/// well inside SQLite's bound-parameter limit on every platform.
const int _pathChunk = 400;

@DriftAccessor(tables: [Songs, Artists, Albums, PlayHistory])
class SongDao extends DatabaseAccessor<AppDatabase> with _$SongDaoMixin {
  SongDao(super.db);

  JoinedSelectStatement<HasResultSet, dynamic> _query({
    SourceType? sourceType,
  }) {
    final q = select(songs).join([
      leftOuterJoin(artists, artists.id.equalsExp(songs.artistId)),
      leftOuterJoin(albums, albums.id.equalsExp(songs.albumId)),
    ]);
    if (sourceType != null) {
      q.where(songs.sourceType.equals(sourceType.index));
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
    SourceType? sourceType,
  }) {
    final q = _query(sourceType: sourceType)
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

  Future<List<Song>> search(
    String query, {
    int limit = 200,
    SourceType? sourceType,
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
    final q = _query(sourceType: sourceType)..where(songs.id.isIn(ids));
    final rows = await q.get();
    final byId = {for (final s in rows.map(_map)) s.id: s};
    return [
      for (final id in ids)
        if (byId[id] != null) byId[id]!,
    ];
  }

  /// Every song path of [sourceType], for rebuilding a directory tree.
  ///
  /// Reads one column instead of whole rows: the cloud browser only needs the
  /// *shape* of the paths, and a music share can hold tens of thousands of
  /// files.
  Stream<List<String>> watchPaths({required SourceType sourceType}) {
    final q = selectOnly(songs)
      ..addColumns([songs.path])
      ..where(songs.sourceType.equalsValue(sourceType));
    return q.watch().map(
      (rows) => [for (final row in rows) row.read(songs.path)!],
    );
  }

  /// Songs sitting directly inside [directoryPath] — never deeper.
  ///
  /// [directoryPath] is an absolute logical prefix — `webdav://1/RJ01008335`,
  /// or just `webdav://1` for the share root.
  ///
  /// Two stages, each doing what it is good at. SQL narrows to the whole
  /// *subtree* with a half-open range, standing in for `LIKE 'prefix/%'` on
  /// purpose: file names may legally contain `%` or `_`, which are wildcards
  /// to `LIKE` and would have to be escaped to stay literal. The range also
  /// keeps sibling servers apart, since `webdav://10/...` falls outside the
  /// bounds built from `webdav://1`. Dart then drops the deeper rows, because
  /// "exactly one more path segment" is not expressible as a range.
  Stream<List<Song>> watchSongsInDirectory({required String directoryPath}) {
    final prefix = '$directoryPath/';
    final q = _query()
      ..where(
        songs.path.isBiggerOrEqualValue(prefix) &
            songs.path.isSmallerThanValue('${directoryPath}0'),
      )
      ..orderBy([OrderingTerm.asc(songs.path)]);
    return q.watch().map(
          (rows) => [
            for (final row in rows)
              if (!row
                  .readTable(songs)
                  .path
                  .substring(prefix.length)
                  .contains('/'))
                _map(row),
          ],
        );
  }

  /// One-shot read of [watchSongsInDirectory].
  Future<List<Song>> songsInDirectory({required String directoryPath}) =>
      watchSongsInDirectory(directoryPath: directoryPath).first;

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

  /// Stores a duration the player learned while streaming.
  ///
  /// Callers only pass positive values, and only for songs whose duration is
  /// still unknown, so this can never replace a good number with a zero.
  Future<void> setDuration(int songId, {required int durationMs}) {
    return (update(songs)..where((t) => t.id.equals(songId))).write(
      SongsCompanion(durationMs: Value(durationMs)),
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

  /// Deletes songs of [sourceType] whose path is absent from [validPaths].
  ///
  /// Scoped to a single source on purpose. Deleting every path outside
  /// [validPaths] regardless of origin means a WebDAV scan would wipe the
  /// whole local library, and a local scan would wipe every synced remote
  /// row — an empty [validPaths] (a share that went offline, say) would empty
  /// the table outright. Each source only ever cleans up after itself.
  ///
  /// The surviving paths are staged in a temporary table rather than inlined
  /// as `NOT IN (?, ?, …)`. That form spends one bound parameter per path and
  /// a real library runs to tens of thousands of files; past SQLite's limit
  /// the statement fails outright, and since this is the only thing that ever
  /// deletes rows, the failure would be silent and permanent.
  Future<int> removeMissingFrom(
    Set<String> validPaths, {
    required SourceType sourceType,
  }) {
    return transaction(() async {
      if (validPaths.isEmpty) {
        return _deleteAllOfSource(sourceType);
      }
      await customStatement(
        'CREATE TEMP TABLE IF NOT EXISTS _scan_paths '
        '(path TEXT PRIMARY KEY)',
      );
      try {
        await customStatement('DELETE FROM _scan_paths');
        final paths = validPaths.toList(growable: false);
        for (var start = 0; start < paths.length; start += _pathChunk) {
          final end = start + _pathChunk < paths.length
              ? start + _pathChunk
              : paths.length;
          final slice = paths.sublist(start, end);
          final values = List<String>.filled(slice.length, '(?)').join(',');
          await customUpdate(
            'INSERT OR IGNORE INTO _scan_paths (path) VALUES $values',
            variables: [for (final path in slice) Variable<String>(path)],
            updates: {songs},
          );
        }
        final removed = await customUpdate(
          'DELETE FROM songs WHERE source_type = ? '
          'AND path NOT IN (SELECT path FROM _scan_paths)',
          variables: [Variable<int>(sourceType.index)],
          updates: {songs},
        );
        await _pruneOrphans();
        return removed;
      } finally {
        await customStatement('DROP TABLE IF EXISTS _scan_paths');
      }
    });
  }

  /// Deletes every song of [sourceType], for a deliberate clear-and-rescan.
  ///
  /// Returns how many rows were removed. Other sources are untouched.
  Future<int> deleteBySource(SourceType sourceType) {
    return transaction(() => _deleteAllOfSource(sourceType));
  }

  Future<int> _deleteAllOfSource(SourceType sourceType) async {
    final removed = await (delete(songs)
          ..where((t) => t.sourceType.equalsValue(sourceType)))
        .go();
    await _pruneOrphans();
    return removed;
  }

  /// Drops albums and artists left with nothing pointing at them.
  Future<void> _pruneOrphans() async {
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
  }
}
