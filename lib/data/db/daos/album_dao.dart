import 'package:drift/drift.dart';

import 'package:whisplayer/data/db/app_database.dart';
import 'package:whisplayer/data/db/mappers.dart';
import 'package:whisplayer/data/db/tables.dart';
import 'package:whisplayer/domain/entities/album.dart';
import 'package:whisplayer/domain/entities/source_type.dart';

part 'album_dao.g.dart';

@DriftAccessor(tables: [Albums, Artists, Songs])
class AlbumDao extends DatabaseAccessor<AppDatabase> with _$AlbumDaoMixin {
  AlbumDao(super.db);

  /// [localOnly] hides albums whose songs are all remote-sourced.
  Stream<List<Album>> watchAll({bool localOnly = false}) {
    final songCount = songs.id.count();
    final q = select(albums).join([
      leftOuterJoin(artists, artists.id.equalsExp(albums.artistId)),
      innerJoin(songs, songs.albumId.equalsExp(albums.id)),
    ])
      ..addColumns([songCount])
      ..groupBy([albums.id])
      ..orderBy([OrderingTerm.asc(albums.title.lower())]);
    if (localOnly) {
      q.where(songs.sourceType.equals(SourceType.local.index));
    }
    return q.watch().map(
      (rows) => rows
          .map(
            (r) => r.readTable(albums).toEntity(
              songCount: r.read(songCount) ?? 0,
              artistName: r.readTableOrNull(artists)?.name,
            ),
          )
          .toList(),
    );
  }

  Future<int> upsert({
    required String groupKey,
    required String title,
    int? artistId,
    int? year,
    String? artworkPath,
  }) async {
    final existing = await (select(albums)
          ..where((t) => t.groupKey.equals(groupKey)))
        .getSingleOrNull();
    if (existing == null) {
      return into(albums).insert(
        AlbumsCompanion.insert(
          title: title,
          groupKey: groupKey,
          artistId: Value(artistId),
          year: Value(year),
          artworkPath: Value(artworkPath),
        ),
      );
    }
    await (update(albums)..where((t) => t.id.equals(existing.id))).write(
      AlbumsCompanion(
        artistId: artistId != null ? Value(artistId) : const Value.absent(),
        year: year != null ? Value(year) : const Value.absent(),
        artworkPath:
            artworkPath != null ? Value(artworkPath) : const Value.absent(),
      ),
    );
    return existing.id;
  }

  Future<void> setArtwork(int albumId, String artworkPath) {
    return (update(albums)..where((t) => t.id.equals(albumId))).write(
      AlbumsCompanion(artworkPath: Value(artworkPath)),
    );
  }
}
