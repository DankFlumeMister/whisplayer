import 'dart:convert';

import 'package:whisplayer/data/webdav/webdav_client.dart';
import 'package:whisplayer/domain/entities/webdav_server.dart';
import 'package:whisplayer/domain/repositories/webdav_server_repository.dart';

const String webDavScheme = 'webdav';

/// Splits `webdav://{serverId}/{relativePath}` into its parts.
///
/// Hand-parsed rather than via [Uri] (mirroring the Subsonic path decoder),
/// so the server id and any uppercase characters keep their exact form.
({int serverId, String relativePath})? decodeWebDavPath(String path) {
  const prefix = '$webDavScheme://';
  if (!path.startsWith(prefix)) {
    return null;
  }
  final rest = path.substring(prefix.length);
  final slash = rest.indexOf('/');
  if (slash <= 0) {
    return null;
  }
  final serverId = int.tryParse(rest.substring(0, slash));
  if (serverId == null) {
    return null;
  }
  final raw = rest.substring(slash + 1);
  return (serverId: serverId, relativePath: normalizeWebDavPath(raw));
}

/// Turns logical `webdav://` paths into playable URLs and supplies the
/// credentials those URLs need.
///
/// The token cannot ride in the URL: it would end up in logs, crash dumps
/// and the media-session metadata that Android publishes to the lock screen.
/// Instead the URL stays clean and the player sends an `Authorization`
/// header, supplied by `headersFor`.
class WebDavStreamService {
  /// Creates a service backed by the given connection repository.
  WebDavStreamService(this._servers);

  final WebDavServerRepository _servers;

  /// Resolves [logicalPath] into an absolute http(s) URL.
  ///
  /// Throws [FormatException] when the path is not a `webdav://` path and
  /// [StateError] when the referenced connection no longer exists.
  Future<Uri> resolveUri(String logicalPath) async {
    final parsed = decodeWebDavPath(logicalPath);
    if (parsed == null) {
      throw FormatException('not a webdav library path', logicalPath);
    }
    final server = await _findServer(parsed.serverId);
    final encoded = encodeWebDavPath(parsed.relativePath);
    return Uri.parse('${server.baseUrl}$encoded');
  }

  /// Basic-auth headers for [uri], or `null` when it belongs to no saved
  /// connection (a local file, or a Subsonic stream).
  ///
  /// Called once per queue item when the player builds its sources, so the
  /// lookup is a plain list scan over a handful of saved connections.
  Future<Map<String, String>?> headersFor(Uri uri) async {
    final url = uri.toString();
    for (final server in await _servers.getServers()) {
      if (!url.startsWith(server.baseUrl)) {
        continue;
      }
      final token = await _servers.getToken(server.id);
      if (token == null || token.isEmpty) {
        return null;
      }
      return <String, String>{
        'Authorization':
            'Basic ${base64Encode(utf8.encode('${server.username}:$token'))}',
      };
    }
    return null;
  }

  Future<WebDavServer> _findServer(int serverId) async {
    for (final server in await _servers.getServers()) {
      if (server.id == serverId) {
        return server;
      }
    }
    throw StateError('unknown webdav server $serverId');
  }
}
