import 'package:drift/drift.dart';

import 'package:whisplayer/data/db/app_database.dart';
import 'package:whisplayer/data/db/tables.dart';

part 'webdav_server_dao.g.dart';

@DriftAccessor(tables: [WebDavServers])
class WebDavServerDao extends DatabaseAccessor<AppDatabase>
    with _$WebDavServerDaoMixin {
  WebDavServerDao(super.db);

  Stream<List<WebDavServerRow>> watchAll() {
    return (select(webDavServers)
          ..orderBy([(t) => OrderingTerm.asc(t.addedAtMs)]))
        .watch();
  }

  Future<List<WebDavServerRow>> getAll() {
    return (select(webDavServers)
          ..orderBy([(t) => OrderingTerm.asc(t.addedAtMs)]))
        .get();
  }

  Future<int> insert({
    required String name,
    required String baseUrl,
    required String username,
    required String rootPath,
    required int addedAtMs,
  }) {
    return into(webDavServers).insert(
      WebDavServersCompanion.insert(
        name: name,
        baseUrl: baseUrl,
        username: username,
        rootPath: Value(rootPath),
        addedAtMs: addedAtMs,
      ),
    );
  }

  Future<void> remove(int serverId) {
    return (delete(webDavServers)..where((t) => t.id.equals(serverId))).go();
  }
}
