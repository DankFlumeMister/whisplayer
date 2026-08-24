import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:whisplayer/data/db/app_database.dart';
import 'package:whisplayer/data/repositories/drift_remote_server_repository.dart';
import 'package:whisplayer/domain/entities/remote_server.dart';
import 'package:whisplayer/domain/repositories/remote_server_repository.dart';

class _InMemoryCredentialStore implements CredentialStore {
  final Map<String, String> values = {};

  String? operator [](String key) => values[key];

  bool containsKey(String key) => values.containsKey(key);

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
  late DriftRemoteServerRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    credentials = _InMemoryCredentialStore();
    repository = DriftRemoteServerRepository(db, credentials);
  });

  tearDown(() async {
    await db.close();
  });

  test('addServer stores row and password under convention key', () async {
    final id = await repository.addServer(
      name: 'Home NAS',
      baseUrl: 'http://192.168.1.10:4533',
      username: 'alice',
      password: 'secret',
    );

    expect(id, greaterThan(0));
    expect(credentials['subsonic.password.$id'], 'secret');

    final servers = await repository.getServers();
    expect(servers, hasLength(1));
    expect(
      servers.single,
      isA<RemoteServer>()
          .having((s) => s.id, 'id', id)
          .having((s) => s.name, 'name', 'Home NAS')
          .having((s) => s.baseUrl, 'baseUrl', 'http://192.168.1.10:4533')
          .having((s) => s.username, 'username', 'alice'),
    );
  });

  test('watchServers emits updates after add and remove', () async {
    final emitted = <List<RemoteServer>>[];
    final subscription = repository.watchServers().listen(emitted.add);
    await Future<void>.delayed(Duration.zero);

    final first = await repository.addServer(
      name: 'A',
      baseUrl: 'http://a',
      username: 'u',
      password: 'p',
    );
    await Future<void>.delayed(Duration.zero);

    await repository.removeServer(first);
    await Future<void>.delayed(Duration.zero);
    await subscription.cancel();

    expect(emitted.last, isEmpty);
    expect(credentials.containsKey('subsonic.password.$first'), isFalse,
        reason: 'removing a server must delete its stored password');
  });

  test('getPassword returns stored value or null when absent', () async {
    expect(await repository.getPassword(123), isNull);

    final id = await repository.addServer(
      name: 'B',
      baseUrl: 'http://b',
      username: 'u',
      password: 'pw',
    );
    expect(await repository.getPassword(id), 'pw');
  });
}
