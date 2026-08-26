import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:whisplayer/data/navidrome/navidrome_client.dart';
import 'package:whisplayer/data/navidrome/navidrome_models.dart';

http.Response _json(Object payload, {int status = 200}) => http.Response(
      jsonEncode(payload),
      status,
      headers: {'content-type': 'application/json'},
    );

Future<http.Response> Function(http.Request) _pagingHandler({
  required int total,
  int pageSize = 2,
}) {
  return (http.Request request) async {
    final start = int.parse(request.url.queryParameters['_start']!);
    final take = pageSize.clamp(0, total - start);
    final rows = <Map<String, dynamic>>[
      for (var i = start; i < start + take; i++)
        <String, dynamic>{
          'id': 's$i',
          'path': 'RJ00000001/track$i.flac',
          'title': 'T$i',
          'suffix': 'flac',
          'duration': 9,
          'size': 1,
          'hasCoverArt': i == 0,
        },
    ];
    return http.Response(
      jsonEncode(rows),
      200,
      headers: {'x-total-count': '$total'},
    );
  };
}

void main() {
  group('NavidromeClient', () {
    test('login stores the token and authorizes later requests', () async {
      Uri? authorizedUri;
      var authHeader = '';
      final client = NavidromeClient(
        baseUrl: 'http://x:4533/',
        username: 'u',
        password: 'p',
        client: MockClient((request) async {
          if (request.method == 'POST' && request.url.path == '/auth/login') {
            return _json({'token': 'jwt-1'});
          }
          if (request.url.path == '/api/song') {
            authorizedUri = request.url;
            authHeader = request.headers['x-nd-authorization'] ?? '';
            return _json(<Object>[]);
          }
          return http.Response('not found', 404);
        }),
      );

      await client.login();
      final songs = await client.fetchAllSongs();

      expect(songs, isEmpty);
      expect(authHeader, 'Bearer jwt-1');
      expect(authorizedUri!.queryParameters['_start'], '0');
    });

    test('login failure surfaces a typed exception', () async {
      final client = NavidromeClient(
        baseUrl: 'http://x:4533',
        username: 'u',
        password: 'bad',
        client: MockClient(
          (request) async => http.Response('{"error":"invalid"}', 401),
        ),
      );
      await expectLater(client.login(), throwsA(isA<NavidromeException>()));
    });

    test('fetchAllSongs pages until the reported total is reached',
        () async {
      final starts = <String>[];
      final client = NavidromeClient(
        baseUrl: 'http://x:4533',
        username: 'u',
        password: 'p',
        pageSize: 2,
        client: MockClient((request) async {
          if (request.method == 'POST') {
            return _json({'token': 'jwt'});
          }
          starts.add(request.url.queryParameters['_start']!);
          return _pagingHandler(total: 3)(request);
        }),
      );

      final songs = await client.fetchAllSongs();

      expect(songs, hasLength(3));
      expect(songs[0].path, startsWith('RJ'));
      expect(songs[0].hasCoverArt, isTrue);
      expect(songs[2].title, 'T2');
      expect(starts, ['0', '2']);
    });

    test('expired token triggers one silent re-login and retry', () async {
      var logins = 0;
      var songGets = 0;
      final client = NavidromeClient(
        baseUrl: 'http://x:4533',
        username: 'u',
        password: 'p',
        client: MockClient((request) async {
          if (request.method == 'POST') {
            logins++;
            return _json({'token': 'jwt-$logins'});
          }
          songGets++;
          final auth = request.headers['x-nd-authorization'];
          if (auth == 'Bearer jwt-1') {
            return http.Response('expired', 401);
          }
          if (auth == 'Bearer jwt-2') {
            return _json(<Object>[]);
          }
          return http.Response('nope', 403);
        }),
      );

      await client.login();
      await expectLater(client.fetchAllSongs(), completion(isEmpty));

      expect(logins, 2);
      expect(songGets, 2);
    });

    test('server address is normalized like the Subsonic client',
        () async {
      final seen = <Uri>[];
      Future<http.Response> handler(http.Request request) async {
        if (request.method == 'POST') {
          seen.add(request.url);
          return _json({'token': 'jwt'});
        }
        return _json(<Object>[]);
      }

      for (final raw in <String>[
        '192.168.28.31:4533',
        '192.168.28.31:4533/',
        'http://192.168.28.31:4533/rest/',
      ]) {
        seen.clear();
        final client = NavidromeClient(
          baseUrl: raw,
          username: 'u',
          password: 'p',
          client: MockClient(handler),
        );
        await client.login();
        expect(seen, hasLength(1));
        expect(seen.single.scheme, 'http');
        expect(seen.single.host, '192.168.28.31');
        expect(seen.single.port, 4533);
        expect(seen.single.path, '/auth/login');
      }
    });
  });
}
