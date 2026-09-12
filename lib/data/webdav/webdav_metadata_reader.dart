import 'package:whisplayer/data/webdav/webdav_client.dart';
import 'package:whisplayer/domain/entities/scanned_song.dart';
import 'package:whisplayer/domain/entities/source_type.dart';
import 'package:whisplayer/domain/repositories/metadata_reader.dart';

/// Supplies a locally cached cover file for one remote audio path.
///
/// Kept as an interface so the reader stays testable and so the cover
/// strategy (which image to pick for a work) can evolve on its own.
// ignore: one_member_abstracts
abstract interface class WebDavCoverResolver {
  /// Returns a local path to a cached cover for [relativePath], or `null`
  /// when the work has no image.
  Future<String?> coverFor(String relativePath);
}

/// Fetches sidecar lyrics text for one remote audio path.
///
/// Kept as an interface so the reader stays testable and so the sidecar
/// strategy (which files to ingest) can evolve on its own.
// ignore: one_member_abstracts
abstract interface class WebDavLyricsResolver {
  /// Returns the lyrics text found next to the audio file for [filePath],
  /// or `null` when there is none.
  Future<String?> lyricsFor(String filePath);
}

/// Builds [ScannedSong] rows for files discovered over WebDAV.
///
/// Per decision D2 the reader does **not** download audio to sniff tags: the
/// library carries no embedded metadata anyway, so parsing would cost two
/// range requests per file and buy nothing. What it can derive cheaply, it
/// derives from the path:
///
/// * **title** — the file name without its extension (identical to what
///   Navidrome already shows for these untagged files today).
/// * **albumTitle** — the top-level work directory, which is exactly the
///   "work" the user browses by, so the local library groups by work for free.
/// * **trackNumber** — a numeric prefix such as `01_` in `01_xxx.mp3`.
/// * **durationMs** — `0` until the player learns the real value and writes
///   it back (see the playback-time backfill in W5).
///
/// Cover art is delegated to the optional resolver passed to the
/// constructor; a failing resolver never fails the scan.
class WebDavMetadataReader implements MetadataReader {
  /// Creates a reader, optionally attaching [coverResolver] and
  /// [lyricsResolver].
  const WebDavMetadataReader({
    WebDavCoverResolver? coverResolver,
    WebDavLyricsResolver? lyricsResolver,
  })  : // Named parameters cannot be private, so an initializing formal is
        // unavailable here (same constraint as SubsonicClient's password).
        // ignore: prefer_initializing_formals
        _coverResolver = coverResolver,
        // The same constraint applies to the second field.
        // ignore: prefer_initializing_formals
        _lyricsResolver = lyricsResolver;

  final WebDavCoverResolver? _coverResolver;
  final WebDavLyricsResolver? _lyricsResolver;

  @override
  Future<ScannedSong> read({
    required String filePath,
    required int sizeBytes,
    required int modifiedAtMs,
  }) async {
    final relative = _relativeOf(filePath);
    final fileName = _nameOf(relative);
    final format = _formatOf(fileName);
    final title = format.isEmpty
        ? fileName
        : fileName.substring(0, fileName.length - format.length - 1);

    return ScannedSong(
      path: filePath,
      sourceType: SourceType.webdav,
      title: title,
      fileName: fileName,
      format: format,
      durationMs: 0,
      fileSizeBytes: sizeBytes,
      modifiedAtMs: modifiedAtMs,
      albumTitle: _workOf(relative),
      trackNumber: _trackOf(fileName),
      artworkPath: await _resolveCover(relative),
      // The fetched sidecar text lands in `lyricsText`; `lyricsPath` stays
      // null because the player can only open local files from it. Playback
      // then falls through to `lyricsText` unchanged.
      lyricsText: await _resolveLyrics(filePath),
    );
  }

  Future<String?> _resolveCover(String relative) async {
    final resolver = _coverResolver;
    if (resolver == null) {
      return null;
    }
    try {
      return await resolver.coverFor(relative);
    } on Object catch (_) {
      // A missing or broken cover must never fail the scan.
      return null;
    }
  }

  Future<String?> _resolveLyrics(String filePath) async {
    final resolver = _lyricsResolver;
    if (resolver == null) {
      return null;
    }
    try {
      return await resolver.lyricsFor(filePath);
    } on Object catch (_) {
      // A missing or unreadable sidecar must never fail the scan.
      return null;
    }
  }
}

/// Strips the `webdav://{serverId}` prefix, leaving the server-relative path.
String _relativeOf(String path) => webDavRelativePath(path);

/// The top-level work directory, e.g. `/RJ01008335/02_mp3/a.mp3` -> `RJ01008335`.
///
/// Returns `null` for a file sitting directly at the share root, which has no
/// work to belong to.
String? _workOf(String relative) {
  final segments = relative
      .split('/')
      .where((String segment) => segment.isNotEmpty)
      .toList(growable: false);
  return segments.length > 1 ? segments.first : null;
}

String _nameOf(String relative) {
  final slash = relative.lastIndexOf('/');
  return slash < 0 ? relative : relative.substring(slash + 1);
}

String _formatOf(String fileName) {
  final dot = fileName.lastIndexOf('.');
  return dot <= 0 ? '' : fileName.substring(dot + 1);
}

/// Reads a leading track number: `01_xxx.mp3` -> 1, `track 7.flac` -> null.
int? _trackOf(String fileName) {
  var end = 0;
  while (end < fileName.length && _isDigit(fileName.codeUnitAt(end))) {
    end++;
  }
  if (end == 0) {
    return null;
  }
  return int.tryParse(fileName.substring(0, end));
}

bool _isDigit(int codeUnit) => codeUnit >= 0x30 && codeUnit <= 0x39;
