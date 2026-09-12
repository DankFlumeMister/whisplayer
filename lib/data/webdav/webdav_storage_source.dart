import 'package:whisplayer/data/webdav/webdav_client.dart';
import 'package:whisplayer/domain/entities/audio_formats.dart';
import 'package:whisplayer/domain/entities/storage_entry.dart';
import 'package:whisplayer/domain/repositories/storage_source.dart';

/// A [StorageSource] backed by WebDAV PROPFIND instead of the local disk.
///
/// It walks the remote tree level by level, keeping [concurrency] listings
/// in flight so a full-library scan (roughly a thousand work folders) does
/// not degrade into a sequential round trip per directory. A directory that
/// fails to list is skipped and reported through [onError] — one unreadable
/// folder must not abort the whole scan.
///
/// Emitted paths are prefixed with [pathPrefix] (for example `webdav://1`)
/// so that a remote file is identifiable the same way a local path is, and
/// so two servers never collide in the `songs` table.
class WebDavStorageSource implements StorageSource {
  /// Creates a source that walks the tree exposed by [lister].
  WebDavStorageSource({
    required WebDavLister lister,
    required this.pathPrefix,
    this.concurrency = 6,
    this.maxDepth = 64,
    this.onError,
    // Named parameters cannot be private, so an initializing formal is
    // unavailable here (same constraint as SubsonicClient's password).
    // ignore: prefer_initializing_formals
  }) : _lister = lister;

  final WebDavLister _lister;

  /// Prepended to every emitted path, e.g. `webdav://1`.
  final String pathPrefix;

  /// How many directories are listed in parallel per level.
  final int concurrency;

  /// Depth guard: a server that reports a cycle would otherwise loop forever.
  final int maxDepth;

  /// Called with a directory that could not be listed; the walk continues.
  final void Function(String path, Object error)? onError;

  /// Sidecar lyrics index from the most recent [listAudioFiles] walk:
  /// audio logical path -> sidecar logical path.
  ///
  /// Built for free during the walk — the same PROPFIND listings that find
  /// the audio files also name their sibling `.lrc`, `.vtt` and `.srt`
  /// files, so indexing costs no extra requests. A sidecar names its audio
  /// neighbour either as `X.ext` next to `X.mp3` (local-style) or as
  /// `X.mp3.vtt` next to `X.mp3` (video-rip-style); both forms are matched.
  /// When one audio file has several sidecars, `.lrc` wins over `.vtt`
  /// over `.srt`, the same priority the player uses for local sidecars.
  Map<String, String> sidecarPaths = const <String, String>{};

  @override
  Future<List<StorageEntry>> listAudioFiles(
    String rootPath,
    Set<String> excludedPaths,
  ) async {
    final excluded = _normalizePrefixes(excludedPaths);
    final prefix = _trimTrailing(pathPrefix);
    final files = <StorageEntry>[];
    final audioPathsByBase = <String, Set<String>>{};
    final audioFullPaths = <String>{};
    final sidecars = <_SidecarEntry>[];
    sidecarPaths = const <String, String>{};

    var level = <String>[_normalizePath(rootPath)];
    var depth = 0;
    while (level.isNotEmpty && depth < maxDepth) {
      final next = <String>[];
      for (var start = 0; start < level.length; start += concurrency) {
        final chunk = level.skip(start).take(concurrency).toList();
        final listings = await Future.wait(chunk.map(_safeList));
        for (var i = 0; i < chunk.length; i++) {
          for (final entry in listings[i]) {
            if (entry.isDirectory) {
              if (!_isExcluded(entry.path, excluded)) {
                next.add(entry.path);
              }
              continue;
            }
            final relative = _normalizePath(entry.path);
            if (AudioFormats.isSupported(entry.path)) {
              final dot = relative.lastIndexOf('.');
              final base = dot > 0 ? relative.substring(0, dot) : relative;
              audioPathsByBase
                  .putIfAbsent(base, () => <String>{})
                  .add(relative);
              audioFullPaths.add(relative);
              files.add(
                StorageEntry(
                  path: '$prefix$relative',
                  sizeBytes: entry.sizeBytes ?? 0,
                  modifiedAtMs:
                      entry.modifiedAt?.millisecondsSinceEpoch ?? 0,
                ),
              );
              continue;
            }
            final rank = _sidecarRank(relative);
            if (rank < 0) {
              continue;
            }
            final dot = relative.lastIndexOf('.');
            if (dot <= 0) {
              continue;
            }
            sidecars.add(_SidecarEntry(relative, rank));
          }
        }
      }
      level = next;
      depth++;
    }

    // A sidecar only matters next to an audio file that the walk also saw;
    // orphans are dropped. It may name its neighbour two ways:
    //   a.lrc      next to a.mp3 / a.flac  (base matches the audio base)
    //   a.mp3.vtt  next to a.mp3           (base is the audio file itself)
    // Several sidecars may target one audio (a.mp3 with both a.lrc and
    // a.mp3.vtt); the lower rank wins, so .lrc still beats .vtt.
    final index = <String, String>{};
    final indexRank = <String, int>{};
    void offer(String audioPath, String sidecarPath, int rank) {
      final key = '$prefix$audioPath';
      final previous = indexRank[key];
      if (previous == null || rank < previous) {
        indexRank[key] = rank;
        index[key] = '$prefix$sidecarPath';
      }
    }
    for (final sidecar in sidecars) {
      final dot = sidecar.path.lastIndexOf('.');
      final base = dot > 0 ? sidecar.path.substring(0, dot) : sidecar.path;
      final audiosByBase = audioPathsByBase[base];
      if (audiosByBase != null) {
        for (final audioPath in audiosByBase) {
          offer(audioPath, sidecar.path, sidecar.rank);
        }
      }
      if (audioFullPaths.contains(base)) {
        offer(base, sidecar.path, sidecar.rank);
      }
    }
    sidecarPaths = index;
    return files;
  }

  /// Rank of a sidecar extension: `.lrc` wins, then `.vtt`, then `.srt`;
  /// anything else is not a sidecar.
  static int _sidecarRank(String relativePath) {
    final lowered = relativePath.toLowerCase();
    if (lowered.endsWith('.lrc')) {
      return 0;
    }
    if (lowered.endsWith('.vtt')) {
      return 1;
    }
    if (lowered.endsWith('.srt')) {
      return 2;
    }
    return -1;
  }

  /// A directory that fails (permissions, vanished mid-walk, 401 on a
  /// sub-tree) yields no children instead of failing the scan.
  Future<List<WebDavEntry>> _safeList(String path) async {
    try {
      return await _lister.list(path);
    } on Object catch (error) {
      onError?.call(path, error);
      return const <WebDavEntry>[];
    }
  }
}

/// A sidecar file found during the walk: its normalized relative path and
/// its extension rank (0 = .lrc, 1 = .vtt, 2 = .srt).
class _SidecarEntry {
  const _SidecarEntry(this.path, this.rank);

  final String path;
  final int rank;
}

/// WebDAV paths always use `/`, unlike the local source which has to match
/// the platform separator.
Set<String> _normalizePrefixes(Set<String> paths) => paths
    .map((path) => path.replaceAll(r'\', '/'))
    .map(_trimTrailing)
    .where((path) => path.isNotEmpty)
    .toSet();

bool _isExcluded(String path, Set<String> prefixes) {
  final normalized = _normalizePath(path);
  for (final prefix in prefixes) {
    if (normalized == prefix || normalized.startsWith('$prefix/')) {
      return true;
    }
  }
  return false;
}

String _normalizePath(String path) {
  var value = path.replaceAll(r'\', '/').trim();
  if (!value.startsWith('/')) {
    value = '/$value';
  }
  return _trimTrailing(value);
}

String _trimTrailing(String value) {
  var result = value;
  while (result.length > 1 && result.endsWith('/')) {
    result = result.substring(0, result.length - 1);
  }
  return result;
}
