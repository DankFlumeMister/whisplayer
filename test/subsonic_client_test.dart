import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:whisplayer/data/subsonic/subsonic_client.dart';
import 'package:whisplayer/data/subsonic/subsonic_models.dart';

http.Response _ok(Map<String, dynamic> payload) => http.Response(
      jsonEncode({
        'subsonic-response': {'status': 'ok', ...payload},
      }),
      200,
    );

String _md5Hex(String input) =>
    md5.convert(utf8.encode(input)).toString();

void main() {
  group('SubsonicClient auth', () {
    test('ping succeeds on ok status', () async {
      final client = SubsonicClient(
        baseUrl: 'http://192.168.1.10:4533',
        username: 'alice',
        password: 'secret',
        client: MockClient((_) async => _ok(const {})),
      );
      await expectLater(client.ping(), completes);
    });

    test('ping throws SubsonicException on failed status', () async {
      final client = SubsonicClient(
        baseUrl: 'http://192.168.1.10:4533',
        username: 'alice',
        password: 'wrong',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'subsonic-response': {
                'status': 'failed',
                'error': {'code': 40, 'message': 'Wrong username or password'},
              },
            }),
            200,
          ),
        ),
      );
      await expectLater(
        client.ping(),
        throwsA(
          isA<SubsonicException>()
              .having((e) => e.code, 'code', 40)
              .having(
                (e) => e.message,
                'message',
                'Wrong username or password',
              ),
        ),
      );
    });

    test('requests carry token md5(password+salt) and identity params',
        () async {
      Uri? captured;
      final client = SubsonicClient(
        baseUrl: 'http://nas.local',
        username: 'bob',
        password: 'pw123',
        clientName: 'wisp-test',
        client: MockClient((req) async {
          captured = req.url;
          return _ok(const {});
        }),
      );
      await client.ping();

      final q = captured!.queryParameters;
      expect(q['u'], 'bob');
      expect(q['c'], 'wisp-test');
      expect(q['v'], isNotEmpty);
      expect(q['f'], 'json');
      expect(q['s'], matches(RegExp(r'^[0-9a-f]+$')));
      expect(q['t'], hasLength(32));
      // Recompute the expected token from the salt the client actually sent.
      expect(_md5Hex('pw123${q['s']}'), q['t']);
    });
  });

  group('SubsonicClient URL normalization', () {
    SubsonicClient clientFor(String baseUrl) => SubsonicClient(
          baseUrl: baseUrl,
          username: 'u',
          password: 'p',
        );

    test('appends /rest and strips trailing slash', () {
      expect(
        clientFor('http://nas.local/').restRoot,
        'http://nas.local/rest',
      );
      expect(
        clientFor('http://nas.local/prefix').restRoot,
        'http://nas.local/prefix/rest',
      );
      expect(
        clientFor('http://nas.local/rest/').restRoot,
        'http://nas.local/rest',
      );
    });

    test('streamUri points at bare stream endpoint with id and auth params',
        () {
      final uri = clientFor('http://nas.local').streamUri('song-9');
      expect(uri.path.endsWith('/rest/stream'), isTrue);
      expect(uri.queryParameters['id'], 'song-9');
      expect(uri.queryParameters.containsKey('t'), isTrue);
      expect(uri.queryParameters.containsKey('s'), isTrue);
    });

    test('coverArtUri includes optional size', () {
      final uri =
          clientFor('http://nas.local').coverArtUri('al-1', size: 300);
      expect(uri.path.endsWith('/rest/getCoverArt'), isTrue);
      expect(uri.queryParameters['id'], 'al-1');
      expect(uri.queryParameters['size'], '300');
    });
  });

  group('SubsonicClient parsing', () {
    test('getAlbumList2 parses albums', () async {
      final client = SubsonicClient(
        baseUrl: 'http://nas.local',
        username: 'u',
        password: 'p',
        client: MockClient(
          (_) async => _ok({
            'albumList2': {
              'album': [
                {
                  'id': 'al-1',
                  'name': 'Album One',
                  'artist': 'Artist A',
                  'coverArt': 'al-1',
                  'songCount': 10,
                  'duration': 2400,
                  'year': 2020,
                },
                {'id': 'al-2', 'name': 'Album Two'},
              ],
            },
          }),
        ),
      );
      final albums = await client.getAlbumList2();
      expect(albums, hasLength(2));
      expect(albums[0].id, 'al-1');
      expect(albums[0].name, 'Album One');
      expect(albums[0].artist, 'Artist A');
      expect(albums[0].coverArt, 'al-1');
      expect(albums[0].songCount, 10);
      expect(albums[0].year, 2020);
      expect(albums[1].artist, isNull);
    });

    test('getAlbum parses album detail with songs', () async {
      final client = SubsonicClient(
        baseUrl: 'http://nas.local',
        username: 'u',
        password: 'p',
        client: MockClient(
          (_) async => _ok({
            'album': {
              'id': 'al-1',
              'name': 'Album One',
              'song': [
                {
                  'id': 'so-1',
                  'title': 'Track A',
                  'artist': 'Artist A',
                  'albumId': 'al-1',
                  'duration': 180,
                  'track': 1,
                  'suffix': 'flac',
                  'bitRate': 900,
                },
                {
                  'id': 'so-2',
                  'title': 'Track B',
                  'duration': 200,
                },
              ],
            },
          }),
        ),
      );
      final detail = await client.getAlbum('al-1');
      expect(detail.album.id, 'al-1');
      expect(detail.songs, hasLength(2));
      expect(detail.songs[0].id, 'so-1');
      expect(detail.songs[0].durationSec, 180);
      expect(detail.songs[0].track, 1);
      expect(detail.songs[0].suffix, 'flac');
      expect(detail.songs[1].artist, isNull);
    });

    test('search3 parses albums and songs', () async {
      Uri? captured;
      final client = SubsonicClient(
        baseUrl: 'http://nas.local',
        username: 'u',
        password: 'p',
        client: MockClient((req) async {
          captured = req.url;
          return _ok({
            'searchResult3': {
              'album': [
                {'id': 'al-7', 'name': 'Night', 'artist': 'DJ'},
              ],
              'song': [
                {
                  'id': 'so-7',
                  'title': 'Nightlife',
                  'albumId': 'al-7',
                  'duration': 210,
                },
              ],
            },
          });
        }),
      );
      final result = await client.search3('night');
      expect(captured!.path, '/rest/search3');
      expect(captured!.queryParameters['query'], 'night');
      expect(captured!.queryParameters['songCount'], '20');
      expect(result.albums, hasLength(1));
      expect(result.albums.single.id, 'al-7');
      expect(result.songs.single.title, 'Nightlife');
    });

    test('getBytes returns body bytes and throws on non-200', () async {
      var calls = 0;
      final client = SubsonicClient(
        baseUrl: 'http://nas.local',
        username: 'u',
        password: 'p',
        client: MockClient((req) async {
          calls++;
          if (calls == 1) {
            return http.Response('jpegbytes', 200);
          }
          return http.Response('nope', 404);
        }),
      );
      final bytes =
          await client.getBytes(client.coverArtUri('al-1'));
      expect(bytes, 'jpegbytes'.codeUnits);
      await expectLater(
        client.getBytes(client.coverArtUri('bad')),
        throwsA(isA<SubsonicException>()),
      );
    });

    test('getLyricsBySongId parses synced structured lyrics', () async {
      Uri? captured;
      final client = SubsonicClient(
        baseUrl: 'http://nas.local',
        username: 'u',
        password: 'p',
        client: MockClient((req) async {
          captured = req.url;
          return _ok({
            'lyricsList': {
              'structuredLyrics': [
                {
                  'synced': true,
                  'line': [
                    {'start': 61500, 'value': 'first line'},
                    {'start': 92000, 'value': 'second line'},
                  ],
                },
              ],
            },
          });
        }),
      );
      final lyrics = await client.getLyricsBySongId('so-1');
      expect(captured!.path, '/rest/getLyricsBySongId');
      expect(captured!.queryParameters['id'], 'so-1');
      expect(lyrics, isNotNull);
      expect(lyrics!.synced, isTrue);
      expect(lyrics.toLrcText(), '[01:01.50]first line\n[01:32.00]second line');
    });

    test('getLyricsBySongId returns null without usable lines', () async {
      final client = SubsonicClient(
        baseUrl: 'http://nas.local',
        username: 'u',
        password: 'p',
        client: MockClient(
          (_) async => _ok({
            'lyricsList': {
              'structuredLyrics': [
                {
                  'synced': false,
                  'line': [
                    {'value': ' '},
                  ],
                },
              ],
            },
          }),
        ),
      );
      expect(await client.getLyricsBySongId('so-1'), isNull);
    });

    test('getPlainLyrics returns value or null when blank', () async {
      var call = 0;
      final client = SubsonicClient(
        baseUrl: 'http://nas.local',
        username: 'u',
        password: 'p',
        client: MockClient((req) async {
          call++;
          if (call == 1) {
            return _ok({
              'lyrics': {
                'artist': 'A',
                'title': 'T',
                'value': '[00:01.00]plain lrc',
              },
            });
          }
          return _ok({
            'lyrics': {'value': ''},
          });
        }),
      );
      expect(await client.getPlainLyrics(artist: 'A', title: 'T'),
          '[00:01.00]plain lrc');
      expect(await client.getPlainLyrics(artist: 'A', title: 'T'), isNull);
    });

    test('non-200 HTTP raises SubsonicException', () async {
      final client = SubsonicClient(
        baseUrl: 'http://nas.local',
        username: 'u',
        password: 'p',
        client: MockClient((_) async => http.Response('nope', 500)),
      );
      await expectLater(client.ping(), throwsA(isA<SubsonicException>()));
    });
  });
}
