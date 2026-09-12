/// A saved WebDAV share used as a music source.
///
/// The shared token is *not* a field: it lives in the platform keystore
/// (see `DriftWebDavServerRepository`), so it never lands in a database
/// file or a backup.
class WebDavServer {
  const WebDavServer({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.username,
    required this.rootPath,
    required this.addedAtMs,
  });

  /// Row id; also the `{serverId}` inside `webdav://{serverId}/{path}`.
  final int id;

  /// User-facing label.
  final String name;

  /// Normalized root URL, e.g. `http://192.168.1.10:8765`.
  final String baseUrl;

  /// Basic-auth username; the bundled sidecar ignores it but real servers
  /// may require one.
  final String username;

  /// Server-relative directory the scan starts from; `/` for the whole share.
  final String rootPath;

  final int addedAtMs;

  /// Prefix used when turning a relative path into a library path.
  String get pathPrefix => 'webdav://$id';
}
