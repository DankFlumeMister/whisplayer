import 'package:whisplayer/data/db/app_database.dart';
import 'package:whisplayer/domain/entities/remote_server.dart';
import 'package:whisplayer/domain/repositories/remote_server_repository.dart';

/// Passwords are never stored in the database; they live in the
/// platform keystore under a convention-based key.
const String _credentialKeyPrefix = 'subsonic.password.';

String credentialKeyFor(int serverId) => '$_credentialKeyPrefix$serverId';

class DriftRemoteServerRepository implements RemoteServerRepository {
  DriftRemoteServerRepository(this._db, this._credentials);

  final AppDatabase _db;
  final CredentialStore _credentials;

  @override
  Stream<List<RemoteServer>> watchServers() =>
      _db.remoteServerDao.watchAll().map(
            (rows) => rows.map(_toEntity).toList(),
          );

  @override
  Future<List<RemoteServer>> getServers() async {
    final rows = await _db.remoteServerDao.getAll();
    return rows.map(_toEntity).toList();
  }

  @override
  Future<int> addServer({
    required String name,
    required String baseUrl,
    required String username,
    required String password,
  }) async {
    final id = await _db.remoteServerDao.insert(
      name: name,
      baseUrl: baseUrl,
      username: username,
      addedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _credentials.write(credentialKeyFor(id), password);
    return id;
  }

  @override
  Future<void> removeServer(int serverId) async {
    await _db.remoteServerDao.remove(serverId);
    await _credentials.delete(credentialKeyFor(serverId));
  }

  @override
  Future<String?> getPassword(int serverId) =>
      _credentials.read(credentialKeyFor(serverId));

  RemoteServer _toEntity(RemoteServerRow row) {
    return RemoteServer(
      id: row.id,
      name: row.name,
      baseUrl: row.baseUrl,
      username: row.username,
      addedAtMs: row.addedAtMs,
    );
  }
}
