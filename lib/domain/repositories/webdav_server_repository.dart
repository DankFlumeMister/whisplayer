import 'package:whisplayer/domain/entities/webdav_server.dart';

/// Stores WebDAV connections and their tokens.
abstract interface class WebDavServerRepository {
  /// Emits the saved connections, oldest first, on every change.
  Stream<List<WebDavServer>> watchServers();

  /// One-shot read of the saved connections.
  Future<List<WebDavServer>> getServers();

  /// Persists a connection and its [token]; returns the new id.
  Future<int> addServer({
    required String name,
    required String baseUrl,
    required String username,
    required String token,
    String rootPath = '/',
  });

  /// Deletes a connection and its token.
  Future<void> removeServer(int serverId);

  /// Reads the shared token for [serverId] from the keystore.
  Future<String?> getToken(int serverId);
}
