import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:whisplayer/data/db/app_database.dart';
import 'package:whisplayer/data/repositories/drift_cloud_browse_repository.dart';
import 'package:whisplayer/domain/entities/source_type.dart';

void main() {
  late AppDatabase db;
  late DriftCloudBrowseRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftCloudBrowseRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> addSong(
    String path, {
    required String title,
    SourceType sourceType = SourceType.webdav,
    int? albumId,
    int addedAt = 1000,
  }) {
    return db.songDao.upsertByPath(
      SongsCompanion.insert(
        path: path,
        sourceType: sourceType,
        title: title,
        fileName: title,
        format: 'mp3',
        durationMs: 1000,
        fileSizeBytes: 10,
        addedAtMs: addedAt,
        modifiedAtMs: addedAt,
        albumId: albumId == null ? const Value.absent() : Value(albumId),
        searchText: Value(title.toLowerCase()),
      ),
    );
  }

  Future<int> addAlbum(String title) => db.albumDao.upsert(
        groupKey: title.toLowerCase(),
        title: title,
      );

  group('watchAlbums', () {
    test('lists webdav albums and hides local-only ones', () async {
      final cloudAlbum = await addAlbum('RJ01008335');
      final localAlbum = await addAlbum('Local Album');
      await addSong('webdav://1/RJ01008335/01.mp3',
          title: 'cloud', albumId: cloudAlbum);
      await addSong('file:///music/01.mp3',
          title: 'local',
          sourceType: SourceType.local,
          albumId: localAlbum);

      final albums = await repo.watchAlbums().first;

      expect(albums.map((a) => a.title), ['RJ01008335']);
    });

    test('reports the song count per album', () async {
      final album = await addAlbum('Work');
      await addSong('webdav://1/Work/01.mp3', title: 'a', albumId: album);
      await addSong('webdav://1/Work/02.mp3', title: 'b', albumId: album);

      final albums = await repo.watchAlbums().first;

      expect(albums.single.songCount, 2);
    });

    test('is empty when the scan has imported nothing', () async {
      expect(await repo.watchAlbums().first, isEmpty);
    });
  });

  group('watchDirectories', () {
    test('lists the top level of one server only', () async {
      await addSong('webdav://1/RJ1/02_mp3/01.mp3', title: 'a');
      await addSong('webdav://1/RJ2/01.mp3', title: 'b');
      await addSong('webdav://10/RJ9/01.mp3', title: 'c');
      await addSong('file:///music/x.mp3',
          title: 'd', sourceType: SourceType.local);

      final dirs = await repo.watchDirectories('webdav://1').first;

      expect(dirs.map((d) => d.name), ['RJ1', 'RJ2']);
    });

    test('drills into a nested directory', () async {
      await addSong('webdav://1/RJ1/02_mp3/01.mp3', title: 'a');
      await addSong('webdav://1/RJ1/イラスト/cover.jpg', title: 'b');
      await addSong('webdav://1/RJ2/01.mp3', title: 'c');

      final dirs = await repo.watchDirectories('webdav://1/RJ1').first;

      expect(dirs.map((d) => d.name), ['02_mp3', 'イラスト']);
    });

    test('emits again when a later scan adds a directory', () async {
      expect(await repo.watchDirectories('webdav://1').first, isEmpty);

      await addSong('webdav://1/RJ1/01.mp3', title: 'a');

      final after = await repo.watchDirectories('webdav://1').first;
      expect(after.map((d) => d.name), ['RJ1']);
    });
  });

  group('watchSongsInDirectory', () {
    test('returns direct files only, not nested ones', () async {
      await addSong('webdav://1/RJ1/01.mp3', title: 'top');
      await addSong('webdav://1/RJ1/02_mp3/02.mp3', title: 'nested');

      final songs = await repo.watchSongsInDirectory('webdav://1/RJ1').first;

      expect(songs.map((s) => s.title), ['top']);
    });

    test('excludes a sibling server whose id shares the prefix', () async {
      // "webdav://10" must not be swept up by a query rooted at "webdav://1".
      // Both files sit at their own share root, which is the only place the
      // two prefixes can be confused for one another.
      await addSong('webdav://1/01.mp3', title: 'server one');
      await addSong('webdav://10/01.mp3', title: 'server ten');

      final songs = await repo.watchSongsInDirectory('webdav://1').first;

      expect(songs.map((s) => s.title), ['server one']);
    });

    test('treats % and _ in names as literal characters', () async {
      // Under LIKE these are wildcards; the range query must not care.
      await addSong('webdav://1/100%_mix/01.mp3', title: 'odd');
      await addSong('webdav://1/100XYmix/01.mp3', title: 'other');

      final songs =
          await repo.watchSongsInDirectory('webdav://1/100%_mix').first;

      expect(songs.map((s) => s.title), ['odd']);
    });

    test('returns nothing for an unknown directory', () async {
      await addSong('webdav://1/RJ1/01.mp3', title: 'a');

      expect(
        await repo.watchSongsInDirectory('webdav://1/NOPE').first,
        isEmpty,
      );
    });

    test('reacts to songs added by a later scan', () async {
      await addSong('webdav://1/RJ1/01.mp3', title: 'first');
      expect(
        (await repo.watchSongsInDirectory('webdav://1/RJ1').first).length,
        1,
      );

      await addSong('webdav://1/RJ1/02.mp3', title: 'second');

      final after = await repo.watchSongsInDirectory('webdav://1/RJ1').first;
      expect(after.map((s) => s.title), ['first', 'second']);
    });
  });

  group('searchSongs', () {
    test('finds webdav songs and ignores local ones', () async {
      await addSong('webdav://1/RJ1/sakura.mp3', title: 'sakura cloud');
      await addSong('file:///music/sakura.mp3',
          title: 'sakura local', sourceType: SourceType.local);

      final hits = await repo.searchSongs('sakura');

      expect(hits.map((s) => s.title), ['sakura cloud']);
    });
  });
}
