import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:whisplayer/data/db/app_database.dart';
import 'package:whisplayer/data/repositories/drift_remote_server_repository.dart';
import 'package:whisplayer/data/repositories/drift_webdav_server_repository.dart';
import 'package:whisplayer/domain/entities/webdav_server.dart';
import 'package:whisplayer/domain/repositories/remote_server_repository.dart';

class _InMemoryCredentialStore implements CredentialStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

void main() {
  late AppDatabase db;
  late _InMemoryCredentialStore credentials;
  late DriftWebDavServerRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    credentials = _InMemoryCredentialStore();
    repository = DriftWebDavServerRepository(db, credentials);
  });

  tearDown(() async {
    await db.close();
  });

  test('a fresh database is at schema version 4', () async {
    // Guards the migration counter: adding the WebDAV table must have
    // bumped it, otherwise the upgrade branch never runs for existing users.
    final version = await db
        .customSelect('PRAGMA user_version')
        .getSingle()
        .then((row) => row.read<int>('user_version'));
    expect(version, 4);
    expect(db.schemaVersion, 4);
  });

  test('the WebDAV table coexists with the Subsonic one', () async {
    // Both tables must survive `createAll` — a typo in table registration
    // would silently drop one of them.
    final tables = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' "
          'ORDER BY name',
        )
        .get()
        .then(
          (rows) => rows.map((row) => row.read<String>('name')).toSet(),
        );

    expect(tables, contains('web_dav_servers'));
    expect(tables, contains('remote_servers'));

    // The pre-existing Subsonic path still works.
    final subsonic = DriftRemoteServerRepository(db, credentials);
    await subsonic.addServer(
      name: 'navidrome',
      baseUrl: 'http://nas:4533',
      username: 'u',
      password: 'p',
    );
    expect(await subsonic.getServers(), hasLength(1));
  });

  test('addServer persists the row and the token separately', () async {
    final id = await repository.addServer(
      name: 'music-pc',
      baseUrl: 'http://192.168.1.10:8765',
      username: 'whisplayer',
      token: 's3cret',
    );

    final servers = await repository.getServers();
    expect(servers, hasLength(1));
    expect(servers.single.id, id);
    expect(servers.single.name, 'music-pc');
    expect(servers.single.baseUrl, 'http://192.168.1.10:8765');
    expect(servers.single.rootPath, '/');

    // The token must never be readable from the database.
    final rows = await db.select(db.webDavServers).get();
    expect(rows.single.toString(), isNot(contains('s3cret')));
    expect(credentials.values['webdav.token.$id'], 's3cret');
    await expectLater(repository.getToken(id), completion('s3cret'));
  });

  test('rootPath is stored when given', () async {
    await repository.addServer(
      name: 'sub',
      baseUrl: 'http://nas:8765',
      username: 'whisplayer',
      token: 't',
      rootPath: '/音声',
    );

    final servers = await repository.getServers();
    expect(servers.single.rootPath, '/音声');
  });

  test('pathPrefix is derived from the row id', () async {
    final id = await repository.addServer(
      name: 'n',
      baseUrl: 'http://nas:8765',
      username: 'u',
      token: 't',
    );

    final server = (await repository.getServers()).single;
    expect(server.pathPrefix, 'webdav://$id');
  });

  test('watchServers emits on change', () async {
    // Drift may coalesce two writes landing in the same event-loop turn, so
    // this asserts on the observed sequence rather than requiring every
    // intermediate emission to arrive.
    final seen = <int>[];
    final subscription = repository.watchServers().listen(
          (List<WebDavServer> list) => seen.add(list.length),
        );
    addTearDown(subscription.cancel);

    Future<void> settle() =>
        Future<void>.delayed(const Duration(milliseconds: 20));

    await settle();
    final id = await repository.addServer(
      name: 'n',
      baseUrl: 'http://nas:8765',
      username: 'u',
      token: 't',
    );
    await settle();
    await repository.removeServer(id);
    await settle();

    expect(seen, isNotEmpty);
    expect(seen.first, 0, reason: 'the stream primes with the current value');
    expect(seen, contains(1), reason: 'the insertion must be observable');
    expect(seen.last, 0);
  });

  test('removeServer deletes the row and the token', () async {
    final id = await repository.addServer(
      name: 'n',
      baseUrl: 'http://nas:8765',
      username: 'u',
      token: 't',
    );

    await repository.removeServer(id);

    expect(await repository.getServers(), isEmpty);
    expect(credentials.values.containsKey('webdav.token.$id'), isFalse);
  });
}
