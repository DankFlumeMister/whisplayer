import 'package:whisplayer/data/db/app_database.dart';
import 'package:whisplayer/domain/entities/webdav_server.dart';
import 'package:whisplayer/domain/repositories/remote_server_repository.dart';
import 'package:whisplayer/domain/repositories/webdav_server_repository.dart';

/// Tokens never touch the database; they live in the platform keystore
/// under a convention-based key.
const String webDavCredentialKeyPrefix = 'webdav.token.';

/// Keystore key holding the token of connection [serverId].
String webDavCredentialKeyFor(int serverId) =>
    '$webDavCredentialKeyPrefix$serverId';

class DriftWebDavServerRepository implements WebDavServerRepository {
  DriftWebDavServerRepository(this._db, this._credentials);

  final AppDatabase _db;
  final CredentialStore _credentials;

  @override
  Stream<List<WebDavServer>> watchServers() =>
      _db.webDavServerDao.watchAll().map(
            (rows) => rows.map(_toEntity).toList(),
          );

  @override
  Future<List<WebDavServer>> getServers() async {
    final rows = await _db.webDavServerDao.getAll();
    return rows.map(_toEntity).toList();
  }

  @override
  Future<int> addServer({
    required String name,
    required String baseUrl,
    required String username,
    required String token,
    String rootPath = '/',
  }) async {
    final id = await _db.webDavServerDao.insert(
      name: name,
      baseUrl: baseUrl,
      username: username,
      rootPath: rootPath,
      addedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _credentials.write(webDavCredentialKeyFor(id), token);
    return id;
  }

  @override
  Future<void> removeServer(int serverId) async {
    await _db.webDavServerDao.remove(serverId);
    await _credentials.delete(webDavCredentialKeyFor(serverId));
  }

  @override
  Future<String?> getToken(int serverId) =>
      _credentials.read(webDavCredentialKeyFor(serverId));

  WebDavServer _toEntity(WebDavServerRow row) {
    return WebDavServer(
      id: row.id,
      name: row.name,
      baseUrl: row.baseUrl,
      username: row.username,
      rootPath: row.rootPath,
      addedAtMs: row.addedAtMs,
    );
  }
}
