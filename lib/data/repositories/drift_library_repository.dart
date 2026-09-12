import 'package:whisplayer/data/db/app_database.dart';
import 'package:whisplayer/domain/entities/album.dart';
import 'package:whisplayer/domain/entities/artist.dart';
import 'package:whisplayer/domain/entities/song.dart';
import 'package:whisplayer/domain/entities/source_type.dart';
import 'package:whisplayer/domain/repositories/library_repository.dart';

class DriftLibraryRepository implements LibraryRepository {
  DriftLibraryRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<Song>> watchSongs({
    SongSort sort = SongSort.title,
    bool descending = false,
  }) {
    return _db.songDao.watchSongs(sort: sort, descending: descending);
  }

  @override
  Stream<List<Song>> watchLocalSongs({
    SongSort sort = SongSort.title,
    bool descending = false,
  }) {
    return _db.songDao.watchSongs(
      sort: sort,
      descending: descending,
      sourceType: SourceType.local,
    );
  }

  @override
  Future<List<Song>> getAllSongs() => _db.songDao.getAllSongs();

  @override
  Future<Song?> getSong(int songId) => _db.songDao.getSong(songId);

  @override
  Future<List<Song>> songsByAlbum(int albumId) =>
      _db.songDao.getSongsByAlbum(albumId);

  @override
  Future<List<Song>> songsByArtist(int artistId) =>
      _db.songDao.getSongsByArtist(artistId);

  @override
  Future<List<Song>> searchLocalSongs(String query) =>
      _db.songDao.search(query, sourceType: SourceType.local);

  @override
  Stream<List<Album>> watchAlbums({SourceType? sourceType}) =>
      _db.albumDao.watchAll(sourceType: sourceType);

  @override
  Stream<List<Artist>> watchArtists() =>
      _db.artistDao.watchAll(sourceType: SourceType.local);

  @override
  Future<void> setFavorite(int songId, {required bool favorite}) =>
      _db.songDao.setFavorite(songId, favorite: favorite);
}
