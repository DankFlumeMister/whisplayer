import 'package:whisplayer/domain/entities/album.dart';
import 'package:whisplayer/domain/entities/cloud_directory.dart';
import 'package:whisplayer/domain/entities/song.dart';

/// Read-only browsing over the songs a WebDAV scan has already imported.
///
/// Deliberately separate from `LibraryRepository`: that one answers "what is
/// on this device", while this one answers "what came from the cloud share".
/// Both read the same tables, but every method here is pinned to
/// `SourceType.webdav`, so no caller can accidentally widen the scope.
abstract interface class CloudBrowseRepository {
  /// Albums holding at least one WebDAV song.
  ///
  /// A work directory becomes an album because the scan sets `albumTitle` to
  /// the top-level directory name.
  Stream<List<Album>> watchAlbums();

  /// The directories immediately inside [parentPath].
  ///
  /// [parentPath] is an absolute logical prefix — `webdav://1` for the share
  /// root, or `webdav://1/RJ01008335` deeper in.
  Stream<List<CloudDirectory>> watchDirectories(String parentPath);

  /// Songs sitting directly inside [directoryPath], re-emitted on change.
  Stream<List<Song>> watchSongsInDirectory(String directoryPath);

  /// Full-text search across every WebDAV song.
  Future<List<Song>> searchSongs(String query);
}
