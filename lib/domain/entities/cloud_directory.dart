import 'package:whisplayer/core/util/natural_compare.dart';

/// One directory inside a WebDAV share, rebuilt from the song paths already
/// stored in the local database.
///
/// The share is never re-listed to browse it: a scan has already recorded
/// every file path, and the directory structure is derivable from them. That
/// makes browsing instant and works with the server offline.
class CloudDirectory {
  const CloudDirectory({
    required this.path,
    required this.name,
    required this.songCount,
    required this.totalSongCount,
    required this.subDirectoryCount,
  });

  /// Absolute logical path, e.g. `webdav://1/RJ01008335/02_mp3`.
  final String path;

  /// Last path segment, for display.
  final String name;

  /// Songs sitting *directly* in this directory.
  final int songCount;

  /// Songs anywhere beneath this directory, including nested ones.
  ///
  /// Shown in listings because a work directory often holds no audio of its
  /// own — the files sit one level down in `02_mp3/` — so the direct count
  /// would read as a misleading zero.
  final int totalSongCount;

  /// Immediate sub-directories.
  final int subDirectoryCount;

  /// Whether this directory leads anywhere at all.
  bool get isEmpty => totalSongCount == 0 && subDirectoryCount == 0;
}

/// The immediate sub-directories of [parentPath], derived from [songPaths].
///
/// Pure and synchronous, so the tree can be rebuilt on each emission of the
/// path stream without going back to the database.
///
/// [parentPath] is an absolute logical prefix — `webdav://1/RJ01008335`, or
/// just `webdav://1` for the share root. Files sitting directly in
/// [parentPath] belong to no child directory and are ignored here; read them
/// with a directory query instead.
List<CloudDirectory> directoriesUnder(
  Iterable<String> songPaths, {
  required String parentPath,
}) {
  final prefix = '$parentPath/';
  final directSongs = <String, int>{};
  final totals = <String, int>{};
  final childDirs = <String, Set<String>>{};

  for (final path in songPaths) {
    if (!path.startsWith(prefix)) {
      continue;
    }
    final rest = path.substring(prefix.length);
    if (rest.isEmpty) {
      continue;
    }
    final segments = rest.split('/');
    if (segments.length < 2 || segments.last.isEmpty) {
      // A file directly in parentPath, or a bare directory reference.
      continue;
    }
    final dir = segments.first;
    totals[dir] = (totals[dir] ?? 0) + 1;
    if (segments.length == 2) {
      directSongs[dir] = (directSongs[dir] ?? 0) + 1;
    } else {
      (childDirs[dir] ??= <String>{}).add(segments[1]);
    }
  }

  final names = <String>{...directSongs.keys, ...childDirs.keys}.toList()
    ..sort(naturalCompare);

  return [
    for (final name in names)
      CloudDirectory(
        path: '$parentPath/$name',
        name: name,
        songCount: directSongs[name] ?? 0,
        totalSongCount: totals[name] ?? 0,
        subDirectoryCount: childDirs[name]?.length ?? 0,
      ),
  ];
}

/// The final path segment of [path], for use as a display name.
///
/// Returns the whole string when it holds no separator, and `/` for the
/// empty or root case.
String directoryNameOf(String path) {
  final trimmed = path.endsWith('/') && path.length > 1
      ? path.substring(0, path.length - 1)
      : path;
  if (trimmed.isEmpty) {
    return '/';
  }
  final slash = trimmed.lastIndexOf('/');
  final name = slash < 0 ? trimmed : trimmed.substring(slash + 1);
  return name.isEmpty ? '/' : name;
}
