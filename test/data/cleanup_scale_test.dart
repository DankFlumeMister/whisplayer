import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:whisplayer/data/db/app_database.dart';
import 'package:whisplayer/domain/entities/source_type.dart';

/// `removeMissingFrom` has to decide which of a scan's paths survived. A real
/// WebDAV library holds tens of thousands of files, and the naive
/// `NOT IN (?, ?, …)` form spends one bound parameter per path — past
/// SQLite's limit the statement fails outright. Because this cleanup is the
/// only thing that ever deletes rows, such a failure is silent and permanent:
/// stale entries pile up and the library never converges.
///
/// 40 000 paths is deliberately above SQLite's 32 766 bound-parameter ceiling,
/// so this test fails against the parameter-list implementation.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seed(int count, {SourceType sourceType = SourceType.webdav}) {
    // The path is UNIQUE across the table, so each source needs its own
    // namespace or the two seed passes collide.
    final prefix = sourceType == SourceType.local ? '/local' : 'webdav://1';
    return db.batch((b) {
      b.insertAll(
        db.songs,
        [
          for (var i = 0; i < count; i++)
            SongsCompanion.insert(
              path: '$prefix/RJ$i/$i.mp3',
              sourceType: sourceType,
              title: 'song $i',
              fileName: '$i.mp3',
              format: 'mp3',
              durationMs: 1000,
              fileSizeBytes: 10,
              addedAtMs: 0,
              modifiedAtMs: 0,
            ),
        ],
      );
    });
  }

  Future<int> countRows() async {
    final rows = await db.customSelect('SELECT COUNT(*) AS c FROM songs').get();
    return rows.first.read<int>('c');
  }

  test('cleans up a library larger than the bound-parameter ceiling',
      () async {
    const total = 40000;
    await seed(total);

    // Keep 3 paths, drop everything else.
    final removed = await db.songDao.removeMissingFrom(
      {'webdav://1/RJ0/0.mp3', 'webdav://1/RJ1/1.mp3', 'webdav://1/RJ2/2.mp3'},
      sourceType: SourceType.webdav,
    );

    expect(removed, total - 3);
    expect(await countRows(), 3);
  });

  test('the staging table does not leak between runs', () async {
    await seed(10);
    await db.songDao.removeMissingFrom(
      {'webdav://1/RJ0/0.mp3'},
      sourceType: SourceType.webdav,
    );

    // A second pass must see a clean staging table, not the previous one.
    await seed(10, sourceType: SourceType.local);
    final removed = await db.songDao.removeMissingFrom(
      {'/kept.mp3'},
      sourceType: SourceType.local,
    );

    expect(removed, 10);
    expect(await countRows(), 1);
  });

  test('an empty valid set still respects the source boundary', () async {
    await seed(5);
    await db.songDao.upsertByPath(
      SongsCompanion.insert(
        path: '/local/a.mp3',
        sourceType: SourceType.local,
        title: 'local',
        fileName: 'a.mp3',
        format: 'mp3',
        durationMs: 1,
        fileSizeBytes: 1,
        addedAtMs: 0,
        modifiedAtMs: 0,
      ),
    );

    final removed = await db.songDao.removeMissingFrom(
      const <String>{},
      sourceType: SourceType.webdav,
    );

    expect(removed, 5);
    expect(await countRows(), 1, reason: 'the local row must survive');
  });

  group('deleteBySource', () {
    test('wipes one source and leaves the others alone', () async {
      await seed(7);
      await seed(3, sourceType: SourceType.local);

      final removed = await db.songDao.deleteBySource(SourceType.webdav);

      expect(removed, 7);
      final remaining = await db.customSelect('SELECT COUNT(*) AS c FROM songs')
          .get();
      expect(remaining.first.read<int>('c'), 3);
    });

    test('drops albums and artists left with no songs', () async {
      final artistId = await db.artistDao.insertIfMissing('Artist');
      final albumId = await db.albumDao.upsert(
        groupKey: 'work|artist',
        title: 'Work',
        artistId: artistId,
      );
      await db.songDao.upsertByPath(
        SongsCompanion.insert(
          path: 'webdav://1/Work/01.mp3',
          sourceType: SourceType.webdav,
          title: 'a',
          fileName: '01.mp3',
          format: 'mp3',
          durationMs: 1,
          fileSizeBytes: 1,
          addedAtMs: 0,
          modifiedAtMs: 0,
          albumId: Value(albumId),
          artistId: Value(artistId),
        ),
      );

      await db.songDao.deleteBySource(SourceType.webdav);

      final albums =
          await db.customSelect('SELECT COUNT(*) AS c FROM albums').get();
      final artists =
          await db.customSelect('SELECT COUNT(*) AS c FROM artists').get();
      expect(albums.first.read<int>('c'), 0);
      expect(artists.first.read<int>('c'), 0);
    });

    test('is a no-op when the source holds nothing', () async {
      expect(await db.songDao.deleteBySource(SourceType.webdav), 0);
    });
  });
}
