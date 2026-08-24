// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'album_dao.dart';

// ignore_for_file: type=lint
mixin _$AlbumDaoMixin on DatabaseAccessor<AppDatabase> {
  $ArtistsTable get artists => attachedDatabase.artists;
  $AlbumsTable get albums => attachedDatabase.albums;
  $SongsTable get songs => attachedDatabase.songs;
  AlbumDaoManager get managers => AlbumDaoManager(this);
}

class AlbumDaoManager {
  final _$AlbumDaoMixin _db;
  AlbumDaoManager(this._db);
  $$ArtistsTableTableManager get artists =>
      $$ArtistsTableTableManager(_db.attachedDatabase, _db.artists);
  $$AlbumsTableTableManager get albums =>
      $$AlbumsTableTableManager(_db.attachedDatabase, _db.albums);
  $$SongsTableTableManager get songs =>
      $$SongsTableTableManager(_db.attachedDatabase, _db.songs);
}
