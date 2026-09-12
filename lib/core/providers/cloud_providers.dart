import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:whisplayer/core/providers/repository_providers.dart';
import 'package:whisplayer/domain/entities/album.dart';
import 'package:whisplayer/domain/entities/cloud_directory.dart';
import 'package:whisplayer/domain/entities/song.dart';
import 'package:whisplayer/domain/entities/webdav_server.dart';

/// The saved WebDAV shares, re-emitted whenever one is added or removed.
///
/// A `StreamProvider` rather than a bare `watchServers()` call inside `build`:
/// calling the repository from `build` would hand `StreamBuilder` a fresh
/// stream object on every rebuild and resubscribe each time.
final webDavServersProvider = StreamProvider<List<WebDavServer>>((ref) {
  return ref.watch(webDavServerRepositoryProvider).watchServers();
});

/// Albums holding at least one song imported from a WebDAV share.
final cloudAlbumsProvider = StreamProvider<List<Album>>((ref) {
  return ref.watch(cloudBrowseRepositoryProvider).watchAlbums();
});

/// The directories directly inside a parent path, keyed by that path.
///
/// A family, because the folder browser pushes one level at a time and each
/// level is worth caching independently.
final cloudDirectoriesProvider =
    StreamProvider.family<List<CloudDirectory>, String>((ref, parentPath) {
  return ref.watch(cloudBrowseRepositoryProvider).watchDirectories(parentPath);
});

/// Songs sitting directly inside a directory, keyed by that directory path.
final cloudDirectorySongsProvider =
    StreamProvider.family<List<Song>, String>((ref, directoryPath) {
  return ref
      .watch(cloudBrowseRepositoryProvider)
      .watchSongsInDirectory(directoryPath);
});
