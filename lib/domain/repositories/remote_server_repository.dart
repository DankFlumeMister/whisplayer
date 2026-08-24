import 'package:whisplayer/domain/entities/remote_server.dart';

/// Stores secrets (server passwords) outside the database, backed by the
/// platform keystore via flutter_secure_storage.
abstract interface class CredentialStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

abstract interface class RemoteServerRepository {
  Stream<List<RemoteServer>> watchServers();

  Future<List<RemoteServer>> getServers();

  /// Inserts a server row and stores its password in the credential store.
  /// Returns the new server id.
  Future<int> addServer({
    required String name,
    required String baseUrl,
    required String username,
    required String password,
  });

  /// Deletes the server row and its stored password.
  Future<void> removeServer(int serverId);

  Future<String?> getPassword(int serverId);
}
