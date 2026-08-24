import 'package:drift/drift.dart';

import 'package:whisplayer/data/db/app_database.dart';
import 'package:whisplayer/data/db/mappers.dart';
import 'package:whisplayer/data/db/tables.dart';
import 'package:whisplayer/domain/entities/artist.dart';
import 'package:whisplayer/domain/entities/source_type.dart';

part 'artist_dao.g.dart';

@DriftAccessor(tables: [Artists, Songs, Albums])
class ArtistDao extends DatabaseAccessor<AppDatabase> with _$ArtistDaoMixin {
  ArtistDao(super.db);

  /// [localOnly] hides artists whose songs are all remote-sourced.
  Stream<List<Artist>> watchAll({bool localOnly = false}) {
    final songCount = songs.id.count();
    final albumCount = songs.albumId.count(distinct: true);
    final q = select(artists).join([
      innerJoin(songs, songs.artistId.equalsExp(artists.id)),
    ])
      ..addColumns([songCount, albumCount])
      ..groupBy([artists.id])
      ..orderBy([OrderingTerm.asc(artists.name.lower())]);
    if (localOnly) {
      q.where(songs.sourceType.equals(SourceType.local.index));
    }
    return q.watch().map(
      (rows) => rows
          .map(
            (r) => r.readTable(artists).toEntity(
              songCount: r.read(songCount) ?? 0,
              albumCount: r.read(albumCount) ?? 0,
            ),
          )
          .toList(),
    );
  }

  Future<int?> findByName(String name) async {
    final row = await (select(artists)
          ..where((t) => t.name.equals(name)))
        .getSingleOrNull();
    return row?.id;
  }

  Future<int> insertIfMissing(String name) async {
    final existing = await findByName(name);
    if (existing != null) {
      return existing;
    }
    return into(artists).insert(ArtistsCompanion.insert(name: name));
  }
}
