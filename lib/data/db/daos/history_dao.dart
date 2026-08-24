import 'package:drift/drift.dart';

import 'package:whisplayer/data/db/app_database.dart';
import 'package:whisplayer/data/db/mappers.dart';
import 'package:whisplayer/data/db/tables.dart';
import 'package:whisplayer/domain/entities/play_history_entry.dart';

part 'history_dao.g.dart';

@DriftAccessor(tables: [PlayHistory, Songs, Artists, Albums])
class HistoryDao extends DatabaseAccessor<AppDatabase>
    with _$HistoryDaoMixin {
  HistoryDao(super.db);

  Future<void> add({
    required int songId,
    required int playedAtMs,
    required int playedMs,
    required bool completed,
  }) {
    return into(playHistory).insert(
      PlayHistoryCompanion.insert(
        songId: songId,
        playedAtMs: playedAtMs,
        playedMs: playedMs,
        completed: Value(completed),
      ),
    );
  }

  Stream<List<PlayHistoryEntry>> watchRecent({int limit = 100}) {
    final q = _query()..limit(limit);
    return q.watch().map(_toEntries);
  }

  JoinedSelectStatement<HasResultSet, dynamic> _query() {
    return select(playHistory).join([
      innerJoin(songs, songs.id.equalsExp(playHistory.songId)),
      leftOuterJoin(artists, artists.id.equalsExp(songs.artistId)),
      leftOuterJoin(albums, albums.id.equalsExp(songs.albumId)),
    ])
      ..orderBy([OrderingTerm.desc(playHistory.playedAtMs)]);
  }

  List<PlayHistoryEntry> _toEntries(List<TypedResult> rows) {
    return rows
        .map((r) {
          final h = r.readTable(playHistory);
          final s = r.readTable(songs);
          final artist = r.readTableOrNull(artists);
          final album = r.readTableOrNull(albums);
          return h.toEntity(
            s.toEntity(
              artistName: artist?.name,
              albumTitle: album?.title,
            ),
          );
        })
        .toList();
  }

  Future<Map<String, Object?>> overallStats() async {
    final row = await customSelect(
      'SELECT COUNT(*) AS total_plays, '
      'COALESCE(SUM(played_ms), 0) AS total_ms, '
      'COALESCE(SUM(completed), 0) AS completed_plays '
      'FROM play_history',
      readsFrom: {playHistory},
    ).getSingle();
    return {
      'totalPlays': row.read<int>('total_plays'),
      'totalPlayedMs': row.read<int>('total_ms'),
      'completedPlays': row.read<int>('completed_plays'),
    };
  }
}
