import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'package:whisplayer/data/db/daos/album_dao.dart';
import 'package:whisplayer/data/db/daos/artist_dao.dart';
import 'package:whisplayer/data/db/daos/history_dao.dart';
import 'package:whisplayer/data/db/daos/playlist_dao.dart';
import 'package:whisplayer/data/db/daos/remote_server_dao.dart';
import 'package:whisplayer/data/db/daos/settings_dao.dart';
import 'package:whisplayer/data/db/daos/song_dao.dart';
import 'package:whisplayer/data/db/tables.dart';
import 'package:whisplayer/domain/entities/source_type.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Artists,
    Albums,
    Songs,
    Playlists,
    PlaylistEntries,
    PlayHistory,
    SettingsKv,
    RemoteServers,
  ],
  daos: [
    SongDao,
    AlbumDao,
    ArtistDao,
    PlaylistDao,
    HistoryDao,
    SettingsDao,
    RemoteServerDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  AppDatabase.open() : super(_openConnection());

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'whisplayer');
  }

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _createFts();
        },
        onUpgrade: (m, fromVersion, toVersion) async {
          if (fromVersion < 2) {
            await m.addColumn(songs, songs.lyricsText);
          }
          if (fromVersion < 3) {
            await m.createTable(remoteServers);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  Future<void> _createFts() async {
    await customStatement(
      'CREATE VIRTUAL TABLE IF NOT EXISTS songs_fts '
      "USING fts5(search_text, content='songs', content_rowid='id')",
    );
    await customStatement(
      'CREATE TRIGGER IF NOT EXISTS songs_fts_ai '
      'AFTER INSERT ON songs BEGIN '
      'INSERT INTO songs_fts(rowid, search_text) '
      'VALUES (new.id, new.search_text); END',
    );
    await customStatement(
      'CREATE TRIGGER IF NOT EXISTS songs_fts_ad '
      'AFTER DELETE ON songs BEGIN '
      'INSERT INTO songs_fts(songs_fts, rowid, search_text) '
      "VALUES ('delete', old.id, old.search_text); END",
    );
    await customStatement(
      'CREATE TRIGGER IF NOT EXISTS songs_fts_au '
      'AFTER UPDATE OF search_text ON songs BEGIN '
      'INSERT INTO songs_fts(songs_fts, rowid, search_text) '
      "VALUES ('delete', old.id, old.search_text); "
      'INSERT INTO songs_fts(rowid, search_text) '
      'VALUES (new.id, new.search_text); END',
    );
  }
}
