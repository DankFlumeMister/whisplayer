import 'package:drift/drift.dart';

import 'package:whisplayer/data/db/app_database.dart';
import 'package:whisplayer/data/db/tables.dart';

part 'remote_server_dao.g.dart';

@DriftAccessor(tables: [RemoteServers])
class RemoteServerDao extends DatabaseAccessor<AppDatabase>
    with _$RemoteServerDaoMixin {
  RemoteServerDao(super.db);

  Stream<List<RemoteServerRow>> watchAll() {
    return (select(remoteServers)
          ..orderBy([(t) => OrderingTerm.asc(t.addedAtMs)]))
        .watch();
  }

  Future<List<RemoteServerRow>> getAll() {
    return (select(remoteServers)
          ..orderBy([(t) => OrderingTerm.asc(t.addedAtMs)]))
        .get();
  }

  Future<int> insert({
    required String name,
    required String baseUrl,
    required String username,
    required int addedAtMs,
  }) {
    return into(remoteServers).insert(
      RemoteServersCompanion.insert(
        name: name,
        baseUrl: baseUrl,
        username: username,
        addedAtMs: addedAtMs,
      ),
    );
  }

  Future<void> remove(int serverId) {
    return (delete(remoteServers)
          ..where((t) => t.id.equals(serverId)))
        .go();
  }
}
