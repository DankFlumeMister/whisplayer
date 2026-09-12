import 'package:whisplayer/data/db/app_database.dart';
import 'package:whisplayer/domain/entities/album.dart';
import 'package:whisplayer/domain/entities/cloud_directory.dart';
import 'package:whisplayer/domain/entities/song.dart';
import 'package:whisplayer/domain/entities/source_type.dart';
import 'package:whisplayer/domain/repositories/cloud_browse_repository.dart';

class DriftCloudBrowseRepository implements CloudBrowseRepository {
  DriftCloudBrowseRepository(this._db);

  final AppDatabase _db;

  static const SourceType _source = SourceType.webdav;

  @override
  Stream<List<Album>> watchAlbums() =>
      _db.albumDao.watchAll(sourceType: _source);

  @override
  Stream<List<CloudDirectory>> watchDirectories(String parentPath) {
    return _db.songDao.watchPaths(sourceType: _source).map(
          (paths) => directoriesUnder(paths, parentPath: parentPath),
        );
  }

  @override
  Stream<List<Song>> watchSongsInDirectory(String directoryPath) =>
      _db.songDao.watchSongsInDirectory(directoryPath: directoryPath);

  @override
  Future<List<Song>> searchSongs(String query) =>
      _db.songDao.search(query, sourceType: _source);
}
