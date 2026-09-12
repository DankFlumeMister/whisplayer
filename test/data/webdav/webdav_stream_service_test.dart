import 'package:flutter_test/flutter_test.dart';

import 'package:whisplayer/data/webdav/webdav_stream_service.dart';
import 'package:whisplayer/domain/entities/webdav_server.dart';
import 'package:whisplayer/domain/repositories/webdav_server_repository.dart';

class _FakeServers implements WebDavServerRepository {
  _FakeServers(this.servers, {this.tokens = const <int, String>{}});

  final List<WebDavServer> servers;
  final Map<int, String> tokens;

  @override
  Future<List<WebDavServer>> getServers() async => servers;

  @override
  Future<String?> getToken(int serverId) async => tokens[serverId];

  @override
  Stream<List<WebDavServer>> watchServers() =>
      Stream<List<WebDavServer>>.value(servers);

  @override
  Future<int> addServer({
    required String name,
    required String baseUrl,
    required String username,
    required String token,
    String rootPath = '/',
  }) async => 0;

  @override
  Future<void> removeServer(int serverId) async {}
}

WebDavServer _server({
  required int id,
  String baseUrl = 'http://192.168.1.10:8765',
  String username = 'whisplayer',
}) =>
    WebDavServer(
      id: id,
      name: 'pc',
      baseUrl: baseUrl,
      username: username,
      rootPath: '/',
      addedAtMs: 0,
    );

void main() {
  group('decodeWebDavPath', () {
    test('splits server id and relative path', () {
      final parsed = decodeWebDavPath('webdav://1/RJ01008335/02_mp3/a.mp3');
      expect(parsed, isNotNull);
      expect(parsed!.serverId, 1);
      expect(parsed.relativePath, '/RJ01008335/02_mp3/a.mp3');
    });

    test('rejects other schemes and malformed ids', () {
      expect(decodeWebDavPath('subsonic://1/x'), isNull);
      expect(decodeWebDavPath('webdav://abc/x'), isNull);
      expect(decodeWebDavPath('webdav://1'), isNull);
      expect(decodeWebDavPath('/RJ/a.mp3'), isNull);
    });
  });

  group('WebDavStreamService', () {
    test('resolveUri builds an encoded URL without credentials', () async {
      final service = WebDavStreamService(
        _FakeServers(<WebDavServer>[_server(id: 1)]),
      );

      final uri = await service.resolveUri(
        'webdav://1/RJ01003442/イラスト/a.mp3',
      );

      expect(uri.toString(), startsWith('http://192.168.1.10:8765/'));
      expect(uri.path, contains('RJ01003442'));
      // The token must never appear in the URL.
      expect(uri.toString(), isNot(contains('token')));
    });

    test('headersFor carries basic auth for our own URLs', () async {
      final service = WebDavStreamService(
        _FakeServers(
          <WebDavServer>[_server(id: 7)],
          tokens: <int, String>{7: 's3cret'},
        ),
      );

      final headers = await service.headersFor(
        Uri.parse('http://192.168.1.10:8765/RJ/a.mp3'),
      );

      expect(headers, isNotNull);
      // base64('whisplayer:s3cret')
      expect(
        headers!['Authorization'],
        'Basic d2hpc3BsYXllcjpzM2NyZXQ=',
      );
    });

    test('headersFor returns null for foreign URLs', () async {
      final service = WebDavStreamService(
        _FakeServers(
          <WebDavServer>[_server(id: 7)],
          tokens: <int, String>{7: 's3cret'},
        ),
      );

      expect(
        await service.headersFor(Uri.parse('http://nas:4533/rest/stream')),
        isNull,
      );
      expect(
        await service.headersFor(Uri.file('/storage/music/a.mp3')),
        isNull,
      );
    });

    test('headersFor returns null when the token was never stored', () async {
      final service = WebDavStreamService(
        _FakeServers(<WebDavServer>[_server(id: 7)]),
      );

      expect(
        await service.headersFor(
          Uri.parse('http://192.168.1.10:8765/RJ/a.mp3'),
        ),
        isNull,
      );
    });

    test('resolveUri throws for an unknown connection', () async {
      final service = WebDavStreamService(_FakeServers(<WebDavServer>[]));

      await expectLater(
        service.resolveUri('webdav://99/RJ/a.mp3'),
        throwsA(isA<StateError>()),
      );
    });

    test('resolveUri rejects a non-webdav path', () async {
      final service = WebDavStreamService(_FakeServers(<WebDavServer>[]));

      await expectLater(
        service.resolveUri('/RJ/a.mp3'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
