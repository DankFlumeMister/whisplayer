import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:whisplayer/data/webdav/webdav_client.dart';

/// A trimmed copy of a real 207 body produced by `tools/webdav_server.py`
/// against `N:\音声\RJ01008335\03_omake`.
const String _multiStatus = '''
<?xml version="1.0" encoding="utf-8"?>
<D:multistatus xmlns:D="DAV:">
  <D:response>
    <D:href>/RJ01008335/03_omake/</D:href>
    <D:propstat><D:prop>
      <D:resourcetype><D:collection/></D:resourcetype>
      <D:displayname>03_omake</D:displayname>
      <D:getlastmodified>Wed, 05 Aug 2026 14:20:41 GMT</D:getlastmodified>
    </D:prop><D:status>HTTP/1.1 200 OK</D:status></D:propstat>
  </D:response>
  <D:response>
    <D:href>/RJ01008335/03_omake/%E3%83%91%E3%83%83%E3%82%B1%E3%83%BC%E3%82%B8%EF%BC%88%E7%99%BA%E6%83%85%E3%83%90%E3%83%BC%E3%82%B8%E3%83%A7%E3%83%B3%EF%BC%89.jpg</D:href>
    <D:propstat><D:prop>
      <D:resourcetype></D:resourcetype>
      <D:displayname>パッケージ（発情バージョン）.jpg</D:displayname>
      <D:getlastmodified>Wed, 05 Aug 2026 14:20:41 GMT</D:getlastmodified>
      <D:getcontentlength>2632978</D:getcontentlength>
      <D:getcontenttype>image/jpeg</D:getcontenttype>
    </D:prop><D:status>HTTP/1.1 200 OK</D:status></D:propstat>
  </D:response>
  <D:response>
    <D:href>/RJ01008335/03_omake/01_wav%EF%BC%88%E9%9F%B3%E5%A3%B0%E3%81%AE%E3%81%BF%EF%BC%89/</D:href>
    <D:propstat><D:prop>
      <D:resourcetype><D:collection/></D:resourcetype>
      <D:displayname>01_wav（音声のみ）</D:displayname>
      <D:getlastmodified>Wed, 05 Aug 2026 14:20:38 GMT</D:getlastmodified>
    </D:prop><D:status>HTTP/1.1 200 OK</D:status></D:propstat>
  </D:response>
</D:multistatus>''';

String _basic(String user, String token) =>
    base64Encode(utf8.encode('$user:$token'));

/// `http.Response(String)` encodes the body as latin-1 and throws on CJK,
/// so the fixture is built from raw UTF-8 bytes instead — exactly why the
/// client itself decodes the raw response bytes and never the decoded body.
http.Response _multiStatusResponse() => http.Response.bytes(
      utf8.encode(_multiStatus),
      207,
      headers: const <String, String>{
        'content-type': 'application/xml; charset=utf-8',
      },
    );

void main() {
  group('normalizeBaseUrl', () {
    test('defaults to http and strips a trailing slash', () {
      expect(
        WebDavClient.normalizeBaseUrl('192.168.1.10:8765/'),
        'http://192.168.1.10:8765',
      );
    });

    test('keeps https and tolerates a single-slash scheme', () {
      expect(
        WebDavClient.normalizeBaseUrl('https:/nas.local:8443'),
        'https://nas.local:8443',
      );
    });

    test('rejects an empty address', () {
      expect(
        () => WebDavClient.normalizeBaseUrl('   '),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects an address without a host', () {
      expect(
        () => WebDavClient.normalizeBaseUrl('http://'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('list', () {
    test('parses collections and files, dropping the collection itself',
        () async {
      final client = WebDavClient(
        baseUrl: 'http://192.168.1.10:8765',
        token: 'tok',
        client: MockClient((_) async => _multiStatusResponse()),
      );

      final entries = await client.list('/RJ01008335/03_omake');

      expect(entries, hasLength(2));
      final file = entries.firstWhere((e) => !e.isDirectory);
      expect(file.name, 'パッケージ（発情バージョン）.jpg');
      expect(file.path, '/RJ01008335/03_omake/パッケージ（発情バージョン）.jpg');
      expect(file.sizeBytes, 2632978);
      expect(file.contentType, 'image/jpeg');
      expect(file.modifiedAt, DateTime.utc(2026, 8, 5, 14, 20, 41));

      final dir = entries.firstWhere((e) => e.isDirectory);
      expect(dir.name, '01_wav（音声のみ）');
      expect(dir.isDirectory, isTrue);
      expect(dir.sizeBytes, isNull);
    });

    test('sends Depth: 1 and an allprop body', () async {
      http.Request? captured;
      final client = WebDavClient(
        baseUrl: 'http://nas.local:8765',
        token: 'tok',
        client: MockClient((request) async {
          captured = request;
          return _multiStatusResponse();
        }),
      );

      await client.list('/RJ01008335');

      expect(captured!.method, 'PROPFIND');
      expect(captured!.headers['Depth'], '1');
      expect(captured!.body, contains('propfind'));
    });

    test('encodes CJK path segments without escaping the separators',
        () async {
      Uri? captured;
      final client = WebDavClient(
        baseUrl: 'http://nas.local:8765',
        token: 'tok',
        client: MockClient((request) async {
          captured = request.url;
          return _multiStatusResponse();
        }),
      );

      await client.list('/RJ01003442/イラスト');

      expect(captured!.path, isNot(contains('イラスト')));
      expect(Uri.decodeComponent(captured!.path), contains('イラスト'));
    });

    test('sends the shared token as the basic-auth password', () async {
      http.Request? captured;
      final client = WebDavClient(
        baseUrl: 'http://nas.local:8765',
        token: 's3cret',
        client: MockClient((request) async {
          captured = request;
          return _multiStatusResponse();
        }),
      );

      await client.list('/');

      expect(
        captured!.headers['authorization'],
        'Basic ${_basic('whisplayer', 's3cret')}',
      );
    });

    test('depth 0 keeps the collection itself (used by ping)', () async {
      final client = WebDavClient(
        baseUrl: 'http://nas.local:8765',
        token: 'tok',
        client: MockClient((_) async => _multiStatusResponse()),
      );

      final entries = await client.list('/RJ01008335/03_omake', depth: 0);
      expect(entries, hasLength(3));
      await expectLater(client.ping(), completes);
    });

    test('401 becomes WebDavAuthException', () async {
      final client = WebDavClient(
        baseUrl: 'http://nas.local:8765',
        token: 'wrong',
        client: MockClient((_) async => http.Response('nope', 401)),
      );

      await expectLater(
        client.list('/'),
        throwsA(
          isA<WebDavAuthException>().having(
            (e) => e.statusCode,
            'statusCode',
            401,
          ),
        ),
      );
    });

    test('404 becomes WebDavNotFoundException', () async {
      final client = WebDavClient(
        baseUrl: 'http://nas.local:8765',
        token: 'tok',
        client: MockClient((_) async => http.Response('missing', 404)),
      );

      await expectLater(
        client.list('/nope'),
        throwsA(isA<WebDavNotFoundException>()),
      );
    });

    test('an unexpected status becomes WebDavException', () async {
      final client = WebDavClient(
        baseUrl: 'http://nas.local:8765',
        token: 'tok',
        client: MockClient((_) async => http.Response('boom', 500)),
      );

      await expectLater(
        client.list('/'),
        throwsA(
          isA<WebDavException>().having(
            (e) => e.statusCode,
            'statusCode',
            500,
          ),
        ),
      );
    });
  });

  group('getBytes', () {
    test('downloads the whole body when no range is given', () async {
      final client = WebDavClient(
        baseUrl: 'http://nas.local:8765',
        token: 'tok',
        client: MockClient(
          (_) async => http.Response.bytes(<int>[0xFF, 0xD8, 0xFF, 0xE1], 200),
        ),
      );

      final bytes = await client.getBytes('/a/cover.jpg');

      expect(bytes, <int>[0xFF, 0xD8, 0xFF, 0xE1]);
    });

    test('sends an inclusive Range header and accepts 206', () async {
      http.Request? captured;
      final client = WebDavClient(
        baseUrl: 'http://nas.local:8765',
        token: 'tok',
        client: MockClient((request) async {
          captured = request;
          return http.Response.bytes(<int>[1, 2, 3], 206);
        }),
      );

      final bytes = await client.getBytes(
        '/a/track.mp3',
        start: 0,
        end: 99,
      );

      expect(captured!.headers['Range'], 'bytes=0-99');
      expect(bytes, hasLength(3));
    });

    test('an open-ended range omits the end offset', () async {
      http.Request? captured;
      final client = WebDavClient(
        baseUrl: 'http://nas.local:8765',
        token: 'tok',
        client: MockClient((request) async {
          captured = request;
          return http.Response.bytes(<int>[1], 206);
        }),
      );

      await client.getBytes('/a/track.mp3', start: 1024);

      expect(captured!.headers['Range'], 'bytes=1024-');
    });

    test('416 becomes WebDavException with the status preserved', () async {
      final client = WebDavClient(
        baseUrl: 'http://nas.local:8765',
        token: 'tok',
        client: MockClient(
          (_) async => http.Response('bad range', 416),
        ),
      );

      await expectLater(
        client.getBytes('/a/track.mp3', start: 1 << 40),
        throwsA(
          isA<WebDavException>().having(
            (e) => e.statusCode,
            'statusCode',
            416,
          ),
        ),
      );
    });
  });

  group('readTextFile', () {
    test('reads UTF-8 text from raw bytes without a charset header',
        () async {
      const text = '  [00:01.00] こんにちは\n[00:02.00] 終わり  \n';
      final client = WebDavClient(
        baseUrl: 'http://nas.local:8765',
        token: 'tok',
        client: MockClient(
          (_) async => http.Response.bytes(utf8.encode(text), 200,
              headers: const <String, String>{
                'content-type': 'text/plain',
              }),
        ),
      );

      final lyrics = await client.readTextFile('/a/track.lrc');

      expect(lyrics, '[00:01.00] こんにちは\n[00:02.00] 終わり');
    });

    test('sends a plain GET carrying the basic-auth token', () async {
      http.Request? captured;
      final client = WebDavClient(
        baseUrl: 'http://nas.local:8765',
        token: 's3cret',
        client: MockClient((request) async {
          captured = request;
          return http.Response('lyrics', 200);
        }),
      );

      await client.readTextFile('/a/track.lrc');

      expect(captured!.method, 'GET');
      expect(
        captured!.headers['authorization'],
        'Basic ${_basic('whisplayer', 's3cret')}',
      );
    });

    test('returns null when the file does not exist', () async {
      final client = WebDavClient(
        baseUrl: 'http://nas.local:8765',
        token: 'tok',
        client: MockClient((_) async => http.Response('missing', 404)),
      );

      expect(await client.readTextFile('/a/nope.lrc'), isNull);
    });

    test('returns null on a server error', () async {
      final client = WebDavClient(
        baseUrl: 'http://nas.local:8765',
        token: 'tok',
        client: MockClient((_) async => http.Response('boom', 500)),
      );

      expect(await client.readTextFile('/a/track.lrc'), isNull);
    });

    test('returns null for a blank body', () async {
      final client = WebDavClient(
        baseUrl: 'http://nas.local:8765',
        token: 'tok',
        client: MockClient((_) async => http.Response('   \n', 200)),
      );

      expect(await client.readTextFile('/a/empty.lrc'), isNull);
    });

    test('propagates connection failures as WebDavException', () async {
      final client = WebDavClient(
        baseUrl: 'http://nas.local:8765',
        token: 'tok',
        client: MockClient(
          (_) async => throw http.ClientException('host down'),
        ),
      );

      await expectLater(
        client.readTextFile('/a/track.lrc'),
        throwsA(isA<WebDavException>()),
      );
    });
  });
}
