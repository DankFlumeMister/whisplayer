import 'package:whisplayer/data/webdav/webdav_client.dart';
import 'package:whisplayer/data/webdav/webdav_metadata_reader.dart';
import 'package:whisplayer/data/webdav/webdav_storage_source.dart';

/// A [WebDavLyricsResolver] backed by the sidecar index that
/// [WebDavStorageSource] builds while walking.
///
/// The index only exists after the walk has run, and the reader's `read`
/// is called during the parse phase — i.e. afterwards — so lookups are
/// cheap: one map hit per audio file, and a single `GET` only when a
/// sibling `.lrc`, `.vtt` or `.srt` actually exists.
class WebDavSidecarLyricsResolver implements WebDavLyricsResolver {
  /// Creates a resolver that downloads sidecar bodies with [client] and
  /// looks paths up in [source]'s most recent walk.
  WebDavSidecarLyricsResolver({
    required this.client,
    required this.source,
  });

  /// The client that downloads the sidecar body.
  final WebDavClient client;

  /// The source whose walk produced the sidecar index.
  final WebDavStorageSource source;

  @override
  Future<String?> lyricsFor(String filePath) async {
    final sidecarPath = source.sidecarPaths[filePath];
    if (sidecarPath == null) {
      return null;
    }
    // The index keys are full `webdav://{serverId}/...` paths; the client
    // wants the bare server-relative path for its request.
    return client.readTextFile(webDavRelativePath(sidecarPath));
  }
}
