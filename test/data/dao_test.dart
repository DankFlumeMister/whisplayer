import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:whisplayer/data/db/app_database.dart';
import 'package:whisplayer/domain/entities/source_type.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  SongsCompanion song(
    String path,
    String title, {
    String searchText = '',
    int? artistId,
    int? albumId,
    int addedAt = 1000,
  }) {
    return SongsCompanion.insert(
      path: path,
      sourceType: SourceType.local,
      title: title,
      fileName: title,
      format: 'flac',
      durationMs: 200000,
      fileSizeBytes: 4096,
      addedAtMs: addedAt,
      modifiedAtMs: addedAt,
      artistId: artistId == null ? const Value.absent() : Value(artistId),
      albumId: albumId == null ? const Value.absent() : Value(albumId),
      searchText: Value(searchText),
    );
  }

  Future<int> seedAlbum({
    String artistName = 'Artist A',
    String albumTitle = 'Album X',
  }) async {
    final artistId = await db.artistDao.insertIfMissing(artistName);
    return db.albumDao.upsert(
      groupKey: '$albumTitle|$artistName'.toLowerCase(),
      title: albumTitle,
      artistId: artistId,
      year: 2020,
    );
  }

  test('artist and album upserts are idempotent', () async {
    final a1 = await db.artistDao.insertIfMissing('A');
    final a2 = await db.artistDao.insertIfMissing('A');
    expect(a1, a2);

    const key = 'x|a';
    final al1 = await db.albumDao.upsert(groupKey: key, title: 'X');
    final al2 = await db.albumDao.upsert(groupKey: key, title: 'X');
    expect(al1, al2);
  });

  test('watchSongs joins artist and album names', () async {
    final albumId = await seedAlbum();
    final artistId = await db.artistDao.findByName('Artist A');
    await db.songDao.upsertAll([
      song('/b.flac', 'Beta', artistId: artistId, albumId: albumId),
      song('/a.flac', 'Alpha', artistId: artistId, albumId: albumId),
    ]);

    final list = await db.songDao.getAllSongs();
    expect(list.map((s) => s.title).toList(), ['Alpha', 'Beta']);
    expect(list.first.artistName, 'Artist A');
    expect(list.first.albumTitle, 'Album X');
  });

  test('FTS search matches tokens and ranks results', () async {
    await db.songDao.upsertAll([
      song('/1.flac', 'Nocturne', searchText: 'nocturne jay 2004'),
      song('/2.flac', 'Blue', searchText: 'blue other 1999'),
    ]);

    final hits = await db.songDao.search('jay');
    expect(hits, hasLength(1));
    expect(hits.first.title, 'Nocturne');

    final none = await db.songDao.search('zzz');
    expect(none, isEmpty);

    final empty = await db.songDao.search('   ');
    expect(empty.length, 2);
  });

  test('recordPlayback updates stats and writes history', () async {
    await db.songDao.upsertAll([song('/p.flac', 'PlayMe')]);
    final id = (await db.songDao.getAllSongs()).first.id;

    await db.songDao.recordPlayback(
      songId: id,
      playedMs: 5000,
      playedAtMs: 777,
      completed: false,
    );

    final s = await db.songDao.getSong(id);
    expect(s!.playCount, 1);
    expect(s.skipCount, 1);
    expect(s.totalPlayMs, 5000);
    expect(s.lastPlayedAtMs, 777);

    final stats = await db.historyDao.overallStats();
    expect(stats['totalPlays'], 1);
    expect(stats['totalPlayedMs'], 5000);
  });

  test('getLastPlayedSong returns most recent', () async {
    await db.songDao.upsertAll([
      song('/old.flac', 'Old'),
      song('/new.flac', 'New'),
    ]);
    final all = await db.songDao.getAllSongs();
    final oldId = all.firstWhere((s) => s.title == 'Old').id;
    final newId = all.firstWhere((s) => s.title == 'New').id;

    await db.songDao.recordPlayback(
      songId: oldId,
      playedMs: 10,
      playedAtMs: 100,
      completed: true,
    );
    await db.songDao.recordPlayback(
      songId: newId,
      playedMs: 10,
      playedAtMs: 200,
      completed: true,
    );

    final last = await db.songDao.getLastPlayedSong();
    expect(last!.title, 'New');
  });

  test('removeMissingFrom deletes stale rows and orphans', () async {
    final keepAlbum = await seedAlbum(albumTitle: 'Keep');
    final dropAlbum =
        await seedAlbum(artistName: 'B', albumTitle: 'Drop');

    await db.songDao.upsertAll([
      song('/keep.flac', 'K', albumId: keepAlbum),
      song('/drop.flac', 'D', albumId: dropAlbum),
    ]);

    final removed = await db.songDao.removeMissingFrom({'/keep.flac'});
    expect(removed, 1);

    final albums = await db.select(db.albums).get();
    expect(albums.map((a) => a.title), ['Keep']);
    final artists = await db.select(db.artists).get();
    expect(artists.map((a) => a.name), ['Artist A']);
  });

  test('playlist add, rename, reorder, remove, clear', () async {
    await db.songDao.upsertAll([
      song('/s1.flac', 'S1'),
      song('/s2.flac', 'S2'),
      song('/s3.flac', 'S3'),
    ]);
    final songs = await db.songDao.getAllSongs();

    final pl = await db.playlistDao.create('Fav');
    final e1 = await db.playlistDao.addSong(pl.id, songs[0].id);
    await db.playlistDao.addSong(pl.id, songs[1].id);
    final e3 = await db.playlistDao.addSong(pl.id, songs[2].id);

    var entries = await db.playlistDao.watchEntries(pl.id).first;
    expect(entries.map((e) => e.song.title).toList(),
        ['S1', 'S2', 'S3']);

    await db.playlistDao.rename(pl.id, 'Best');
    final lists = await db.playlistDao.watchAll().first;
    expect(lists.single.name, 'Best');
    expect(lists.single.songCount, 3);

    await db.playlistDao.reorder([e3, e1]);
    entries = await db.playlistDao.watchEntries(pl.id).first;
    expect(entries[0].song.title, 'S3');
    expect(entries[1].song.title, 'S1');

    await db.playlistDao.removeEntry(e1);
    entries = await db.playlistDao.watchEntries(pl.id).first;
    expect(
      entries.map((e) => e.position).toList(),
      [0, 1],
    );

    await db.playlistDao.clearSongs(pl.id);
    entries = await db.playlistDao.watchEntries(pl.id).first;
    expect(entries, isEmpty);
  });

  test('deleting playlist cascades entries', () async {
    await db.songDao.upsertAll([song('/x.flac', 'X')]);
    final pl = await db.playlistDao.create('Temp');
    final sid = (await db.songDao.getAllSongs()).single.id;
    await db.playlistDao.addSong(pl.id, sid);

    await db.playlistDao.remove(pl.id);
    final left = await db.select(db.playlistEntries).get();
    expect(left, isEmpty);
  });

  test('favorite and position persist', () async {
    await db.songDao.upsertAll([song('/f.flac', 'F')]);
    final s = (await db.songDao.getAllSongs()).single;

    await db.songDao.setFavorite(s.id, favorite: true);
    await db.songDao.savePosition(songId: s.id, positionMs: 12345);

    final reloaded = await db.songDao.getSong(s.id);
    expect(reloaded!.isFavorite, isTrue);
    expect(reloaded.lastPositionMs, 12345);
  });

  test('settings roundtrip', () async {
    await db.settingsDao.setValue('k', 'v1');
    expect(await db.settingsDao.getValue('k'), 'v1');
    await db.settingsDao.setValue('k', null);
    expect(await db.settingsDao.getValue('k'), isNull);
  });

  test('local view filters out remote songs, albums and artists',
      () async {
    final localId = await db.songDao.upsertByPath(
      SongsCompanion.insert(
        path: '/music/local.flac',
        sourceType: SourceType.local,
        title: 'Local Song',
        fileName: 'local.flac',
        format: 'flac',
        durationMs: 100000,
        fileSizeBytes: 1,
        addedAtMs: 1,
        modifiedAtMs: 1,
        searchText: const Value('local song'),
      ),
    );
    final remoteId = await db.songDao.upsertByPath(
      SongsCompanion.insert(
        path: 'subsonic://1/so-9',
        sourceType: SourceType.remote,
        title: 'Cloud Song',
        fileName: 'cloud.flac',
        format: 'flac',
        durationMs: 100000,
        fileSizeBytes: 0,
        addedAtMs: 2,
        modifiedAtMs: 2,
        searchText: const Value('cloud song'),
      ),
    );
    // Attach both to one shared album/artist so the remote-only entry is
    // not what hides it — the shared album must survive via the local song.
    final artistId = await db.artistDao.insertIfMissing('Shared Artist');
    final albumId = await db.albumDao.upsert(
      groupKey: 'shared|shared artist',
      title: 'Shared Album',
      artistId: artistId,
    );
    for (final id in [localId, remoteId]) {
      await (db.update(db.songs)..where((t) => t.id.equals(id))).write(
        SongsCompanion(artistId: Value(artistId), albumId: Value(albumId)),
      );
    }
    final cloudOnlyArtist =
        await db.artistDao.insertIfMissing('Cloud Artist');
    final cloudOnlyAlbum = await db.albumDao.upsert(
      groupKey: 'cloudy|cloud artist',
      title: 'Cloudy Album',
      artistId: cloudOnlyArtist,
    );
    await (db.update(db.songs)..where((t) => t.id.equals(remoteId))).write(
      SongsCompanion(
        artistId: Value(cloudOnlyArtist),
        albumId: Value(cloudOnlyAlbum),
      ),
    );

    final localSongs = await db.songDao
        .watchSongs(localOnly: true)
        .map((list) => list.map((s) => s.title).toList())
        .first;
    expect(localSongs, ['Local Song']);

    final localSearch =
        await db.songDao.search('song', localOnly: true);
    expect(localSearch.map((s) => s.title), ['Local Song']);

    final albums = await db.albumDao.watchAll(localOnly: true).first;
    expect(albums.map((a) => a.title), ['Shared Album']);

    final artists = await db.artistDao.watchAll(localOnly: true).first;
    expect(artists.map((a) => a.name), ['Shared Artist']);
  });
}
