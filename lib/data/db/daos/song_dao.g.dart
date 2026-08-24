// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'song_dao.dart';

// ignore_for_file: type=lint
mixin _$SongDaoMixin on DatabaseAccessor<AppDatabase> {
  $ArtistsTable get artists => attachedDatabase.artists;
  $AlbumsTable get albums => attachedDatabase.albums;
  $SongsTable get songs => attachedDatabase.songs;
  $PlayHistoryTable get playHistory => attachedDatabase.playHistory;
  SongDaoManager get managers => SongDaoManager(this);
}

class SongDaoManager {
  final _$SongDaoMixin _db;
  SongDaoManager(this._db);
  $$ArtistsTableTableManager get artists =>
      $$ArtistsTableTableManager(_db.attachedDatabase, _db.artists);
  $$AlbumsTableTableManager get albums =>
      $$AlbumsTableTableManager(_db.attachedDatabase, _db.albums);
  $$SongsTableTableManager get songs =>
      $$SongsTableTableManager(_db.attachedDatabase, _db.songs);
  $$PlayHistoryTableTableManager get playHistory =>
      $$PlayHistoryTableTableManager(_db.attachedDatabase, _db.playHistory);
}
