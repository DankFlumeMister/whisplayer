import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:whisplayer/data/navidrome/navidrome_client.dart';
import 'package:whisplayer/data/navidrome/navidrome_models.dart';
import 'package:whisplayer/data/remote/remote_library_service.dart';
import 'package:whisplayer/data/subsonic/subsonic_client.dart';
import 'package:whisplayer/data/subsonic/subsonic_models.dart';
import 'package:whisplayer/domain/entities/album.dart';
import 'package:whisplayer/domain/entities/artist.dart';
import 'package:whisplayer/domain/entities/existing_song_info.dart';
import 'package:whisplayer/domain/entities/remote_server.dart';
import 'package:whisplayer/domain/entities/scanned_song.dart';
import 'package:whisplayer/domain/entities/song.dart';
import 'package:whisplayer/domain/entities/source_type.dart';
import 'package:whisplayer/domain/repositories/library_repository.dart';
import 'package:whisplayer/domain/repositories/library_writer_repository.dart';
import 'package:whisplayer/domain/repositories/remote_server_repository.dart';

class _FakeServers implements RemoteServerRepository {
  final List<RemoteServer> servers = <RemoteServer>[];
  final Map<int, String> passwords = <int, String>{};
  int nextId = 1;

  @override
  Future<int> addServer({
    required String name,
    required String baseUrl,
    required String username,
    required String password,
  }) async {
    final id = nextId++;
    servers.add(
      RemoteServer(
        id: id,
        name: name,
        baseUrl: baseUrl,
        username: username,
        addedAtMs: 0,
      ),
    );
    passwords[id] = password;
    return id;
  }

  @override
  Future<void> removeServer(int serverId) async {
    servers.removeWhere((s) => s.id == serverId);
    passwords.remove(serverId);
  }

  @override
  Future<String?> getPassword(int serverId) async => passwords[serverId];

  @override
  Future<List<RemoteServer>> getServers() async => List.of(servers);

  @override
  Stream<List<RemoteServer>> watchServers() => Stream.value(List.of(servers));
}

class _FakeWriter implements LibraryWriterRepository {
  final List<ScannedSong> saved = <ScannedSong>[];
  int nextId = 100;

  @override
  Future<int> upsertScannedSong(ScannedSong song) async {
    saved.add(song);
    return nextId++;
  }

  @override
  Future<List<ExistingSongInfo>> loadExistingSongs() async => [];

  @override
  Future<int> removeSongsMissingFrom(Set<String> validPaths) async => 0;

  @override
  Future<void> saveLyricsText({
    required int songId,
    required String text,
  }) async {}
}

class _FakeLibrary implements LibraryRepository {
  final Map<int, Song> byId = <int, Song>{};
  final Map<int, List<Song>> byAlbum = <int, List<Song>>{};

  @override
  Future<Song?> getSong(int songId) async => byId[songId];

  // region unused interface members
  @override
  Stream<List<Song>> watchSongs({
    SongSort sort = SongSort.title,
    bool descending = false,
  }) =>
      Stream.value(const <Song>[]);

  @override
  Stream<List<Song>> watchLocalSongs({
    SongSort sort = SongSort.title,
    bool descending = false,
  }) =>
      Stream.value(const <Song>[]);

  @override
  Future<List<Song>> searchLocalSongs(String query) async => [];

  @override
  Future<List<Song>> getAllSongs() async => const <Song>[];

  @override
  Future<Song?> getLastPlayedSong() async => null;

  @override
  Future<List<Song>> songsByAlbum(int albumId) async =>
      byAlbum[albumId] ?? const <Song>[];

  @override
  Future<List<Song>> songsByArtist(int artistId) async => [];

  @override
  Future<List<Song>> searchSongs(String query) async => [];

  @override
  Stream<List<Album>> watchAlbums() => Stream.value(const <Album>[]);

  @override
  Stream<List<Artist>> watchArtists() => Stream.value(const <Artist>[]);

  @override
  Future<void> setFavorite(int songId, {required bool favorite}) async {}

  @override
  Future<void> savePosition({
    required int songId,
    required int positionMs,
  }) async {}

  @override
  Future<void> recordPlayback({
    required int songId,
    required int playedMs,
    required int playedAtMs,
    required bool completed,
  }) async {}

  @override
  Future<int> removeSongsMissingFrom(Set<String> validPaths) async => 0;
  // endregion
}

SubsonicAlbumDetail _detail() => const SubsonicAlbumDetail(
      album: SubsonicAlbum(id: 'al-1', name: 'Album One', year: 2020),
      songs: [
        SubsonicSong(
          id: 'so-1',
          title: 'Track A',
          artist: 'Artist A',
          durationSec: 180,
          track: 3,
          suffix: 'flac',
          bitRate: 900,
        ),
        SubsonicSong(id: 'so-2', title: 'Track B', durationSec: 200),
      ],
    );

void main() {
  late _FakeServers servers;
  late _FakeWriter writer;
  late _FakeLibrary library;
  late RemoteLibraryService service;
  late int serverId;

  setUp(() async {
    servers = _FakeServers();
    writer = _FakeWriter();
    library = _FakeLibrary();
    service = RemoteLibraryService(servers, writer, library);
    serverId = await servers.addServer(
      name: 'Home',
      baseUrl: 'http://192.168.1.50:4533',
      username: 'alice',
      password: 'secret',
    );
  });

  group('subsonic path codec', () {
    test('roundtrips server and song id preserving case', () {
      final path = encodeSubsonicPath(7, 'AbC-9');
      expect(path, 'subsonic://7/AbC-9');
      final parsed = decodeSubsonicPath(path);
      expect(parsed, isNotNull);
      expect(parsed!.serverId, 7);
      expect(parsed.songId, 'AbC-9');
    });

    test('rejects malformed paths', () {
      expect(decodeSubsonicPath('file:///tmp/a.flac'), isNull);
      expect(decodeSubsonicPath('subsonic://x/1'), isNull);
      expect(decodeSubsonicPath('subsonic://7'), isNull);
      expect(decodeSubsonicPath('subsonic://7/'), isNull);
    });
  });

  group('syncAlbumToLibrary', () {
    test('upserts every song as remote with encoded paths', () async {
      await service.syncAlbumToLibrary(
        server: servers.servers.first,
        detail: _detail(),
      );

      expect(writer.saved, hasLength(2));
      expect(writer.saved[0].path, 'subsonic://$serverId/so-1');
      expect(writer.saved[0].sourceType, SourceType.remote);
      expect(writer.saved[0].title, 'Track A');
      expect(writer.saved[0].durationMs, 180000);
      expect(writer.saved[0].format, 'flac');
      expect(writer.saved[0].fileName, 'Track A.flac');
      expect(writer.saved[0].trackNumber, 3);
      expect(writer.saved[0].year, 2020);
      expect(writer.saved[0].albumTitle, 'Album One');
      expect(writer.saved[0].artistName, 'Artist A');

      expect(writer.saved[1].format, '');
      expect(writer.saved[1].fileName, 'Track B');
      expect(writer.saved[1].bitrateKbps, isNull);
    });

    test('returns null album id for empty albums', () async {
      final result = await service.syncAlbumToLibrary(
        server: servers.servers.first,
        detail: const SubsonicAlbumDetail(
          album: SubsonicAlbum(id: 'al-2', name: 'Empty'),
          songs: [],
        ),
      );
      expect(result, isNull);
    });
  });

  group('syncAlbumSongs', () {
    test('returns the whole local album queue after syncing', () async {
      library.byId[100] = Song(
        id: 100,
        path: 'subsonic://$serverId/so-1',
        sourceType: SourceType.remote,
        title: 'Track A',
        fileName: 'Track A.flac',
        format: 'flac',
        durationMs: 180000,
        fileSizeBytes: 1,
        addedAtMs: 0,
        modifiedAtMs: 0,
        playCount: 0,
        skipCount: 0,
        totalPlayMs: 0,
        lastPositionMs: 0,
        isFavorite: false,
        albumId: 77,
      );
      library.byAlbum[77] = [library.byId[100]!];

      final svc = RemoteLibraryService(
        servers,
        writer,
        library,
        clientFactory: (baseUrl, username, password) => SubsonicClient(
          baseUrl: baseUrl,
          username: username,
          password: password,
          client: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'subsonic-response': {
                  'status': 'ok',
                  'album': {
                    'id': 'al-1',
                    'name': 'Album One',
                    'song': [
                      {'id': 'so-1', 'title': 'Track A'},
                      {'id': 'so-2', 'title': 'Track B'},
                    ],
                  },
                },
              }),
              200,
            ),
          ),
        ),
      );

      const remote = SubsonicSong(
        id: 'so-1',
        title: 'Track A',
        albumId: 'al-1',
      );
      final songs = await svc.syncAlbumSongs(
        server: servers.servers.first,
        remoteSong: remote,
      );

      expect(songs.map((s) => s.id), [100]);
      expect(writer.saved, hasLength(2));
    });

    test('returns empty when the remote song has no album', () async {
      const remote = SubsonicSong(id: 'so-x', title: 'X');
      final songs = await service.syncAlbumSongs(
        server: servers.servers.first,
        remoteSong: remote,
      );
      expect(songs, isEmpty);
      expect(writer.saved, isEmpty);
    });
  });

  group('resolveStreamUri', () {
    test('builds authenticated stream URL from stored credentials',
        () async {
      final uri =
          await service.resolveStreamUri('subsonic://$serverId/so-9');
      expect(uri.host, '192.168.1.50');
      expect(uri.port, 4533);
      expect(uri.path, '/rest/stream');
      expect(uri.queryParameters['id'], 'so-9');
      expect(uri.queryParameters['u'], 'alice');
      expect(uri.queryParameters.containsKey('t'), isTrue);
      expect(uri.queryParameters.containsKey('s'), isTrue);
    });

    test('throws StateError when server is unknown', () async {
      await expectLater(
        service.resolveStreamUri('subsonic://999/so-1'),
        throwsA(isA<StateError>()),
      );
    });

    test('throws FormatException for non-subsonic paths', () async {
      await expectLater(
        service.resolveStreamUri('/storage/emulated/0/a.flac'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('cacheCover', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('covers_test');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    RemoteLibraryService serviceWith(MockClient client) =>
        RemoteLibraryService(
          servers,
          writer,
          library,
          clientFactory: (baseUrl, username, password) => SubsonicClient(
            baseUrl: baseUrl,
            username: username,
            password: password,
            client: client,
          ),
        );

    test('downloads once, caches to disk and reuses the hit', () async {
      var requests = 0;
      final svc = serviceWith(
        MockClient((req) async {
          requests++;
          expect(req.url.path, '/rest/getCoverArt');
          return http.Response.bytes(
            <int>[1, 2, 3, 4],
            200,
            headers: {'content-type': 'image/jpeg'},
          );
        }),
      );

      final first = await svc.cacheCover(
        server: servers.servers.first,
        coverArtId: 'al-1',
        baseDir: tempDir,
      );
      expect(first, isNotNull);
      expect(File(first!).readAsBytesSync(), <int>[1, 2, 3, 4]);

      final second = await svc.cacheCover(
        server: servers.servers.first,
        coverArtId: 'al-1',
        baseDir: tempDir,
      );
      expect(second, first);
      expect(requests, 1,
          reason: 'second call must be served from the disk cache');
    });

    test('returns null on HTTP failure without writing files', () async {
      final svc = serviceWith(
        MockClient(
          (_) async => http.Response('nope', 404),
        ),
      );
      final result = await svc.cacheCover(
        server: servers.servers.first,
        coverArtId: 'bad-id',
        baseDir: tempDir,
      );
      expect(result, isNull);
      expect(tempDir.listSync(), isEmpty);
    });
  });

  group('fetchLyricsText', () {
    Song lyricSong() => Song(
          id: 500,
          path: 'subsonic://$serverId/so-77',
          sourceType: SourceType.remote,
          title: 'Nightlife',
          fileName: 'nightlife.flac',
          format: 'flac',
          durationMs: 210000,
          fileSizeBytes: 0,
          addedAtMs: 0,
          modifiedAtMs: 0,
          playCount: 0,
          skipCount: 0,
          totalPlayMs: 0,
          lastPositionMs: 0,
          isFavorite: false,
          artistName: 'DJ',
        );

    RemoteLibraryService lyricsServiceWith(MockClient client) =>
        RemoteLibraryService(
          servers,
          writer,
          library,
          clientFactory: (baseUrl, username, password) => SubsonicClient(
            baseUrl: baseUrl,
            username: username,
            password: password,
            client: client,
          ),
        );

    test('converts structured lyrics into LRC text', () async {
      final svc = lyricsServiceWith(
        MockClient(
          (_) async => http.Response(
            jsonEncode({
              'subsonic-response': {
                'status': 'ok',
                'lyricsList': {
                  'structuredLyrics': [
                    {
                      'synced': true,
                      'line': [
                        {'start': 1000, 'value': 'hey'},
                        {'start': 4000, 'value': 'ho'},
                      ],
                    },
                  ],
                },
              },
            }),
            200,
          ),
        ),
      );
      expect(
        await svc.fetchLyricsText(lyricSong()),
        '[00:01.00]hey\n[00:04.00]ho',
      );
    });

    test('falls back to plain lyrics when structured is empty', () async {
      var call = 0;
      final svc = lyricsServiceWith(
        MockClient((req) async {
          call++;
          if (call == 1) {
            return http.Response(
              jsonEncode({
                'subsonic-response': {
                  'status': 'ok',
                  'lyricsList': <String, dynamic>{
                    'structuredLyrics': <Map<String, dynamic>>[],
                  },
                },
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'subsonic-response': {
                'status': 'ok',
                'lyrics': {'value': 'just words'},
              },
            }),
            200,
          );
        }),
      );
      expect(await svc.fetchLyricsText(lyricSong()), 'just words');
    });

    test('returns null on server errors', () async {
      final svc = lyricsServiceWith(
        MockClient((_) async => http.Response('down', 500)),
      );
      expect(await svc.fetchLyricsText(lyricSong()), isNull);
    });

    test('returns null for non-subsonic songs', () async {
      const local = Song(
        id: 1,
        path: '/music/a.flac',
        sourceType: SourceType.local,
        title: 'A',
        fileName: 'a.flac',
        format: 'flac',
        durationMs: 1,
        fileSizeBytes: 1,
        addedAtMs: 0,
        modifiedAtMs: 0,
        playCount: 0,
        skipCount: 0,
        totalPlayMs: 0,
        lastPositionMs: 0,
        isFavorite: false,
      );
      expect(await service.fetchLyricsText(local), isNull);
    });
  });

  group('navidrome folder index', () {
    RemoteLibraryService navServiceWith(MockClient client) =>
        RemoteLibraryService(
          servers,
          writer,
          library,
          navidromeClientFactory: (baseUrl, username, password) =>
              NavidromeClient(
                baseUrl: baseUrl,
                username: username,
                password: password,
                client: client,
              ),
        );

    test('groups by top folder, sorts and caches the sweep', () async {
      var sweeps = 0;
      final svc = navServiceWith(
        MockClient((request) async {
          if (request.method == 'POST') {
            return http.Response(jsonEncode({'token': 'jwt'}), 200);
          }
          sweeps++;
          return http.Response(
            jsonEncode([
              {
                'id': 's1',
                'path': 'RJ00000002/a.flac',
                'title': 'A',
                'suffix': 'flac',
                'duration': 10,
                'size': 1,
                'hasCoverArt': false,
              },
              {
                'id': 's2',
                'path': 'RJ00000001/sub/b.mp3',
                'title': 'B',
                'artist': '[Unknown Artist]',
                'album': '[Unknown Album]',
                'suffix': 'mp3',
                'duration': 20,
                'size': 2,
                'hasCoverArt': true,
              },
              {
                'id': 's3',
                'path': 'RJ00000001/c.flac',
                'title': 'C',
                'suffix': 'flac',
                'duration': 30,
                'size': 3,
                'hasCoverArt': false,
              },
            ]),
            200,
            headers: {'x-total-count': '3'},
          );
        }),
      );

      final folders = await svc.indexFolders(serverId);

      expect(sweeps, 1);
      expect(folders, hasLength(2));
      expect(folders[0].name, 'RJ00000001');
      expect(folders[0].songCount, 2);
      expect(folders[0].coverSongId, 's2');
      expect(folders[1].name, 'RJ00000002');
      expect(folders[1].songCount, 1);

      final cached = await svc.indexFolders(serverId);
      expect(cached.map((f) => f.name), ['RJ00000001', 'RJ00000002']);
      expect(sweeps, 1);
    });

    test('folderSongs flattens sub-directories in path order', () async {
      final svc = navServiceWith(
        MockClient((request) async {
          if (request.method == 'POST') {
            return http.Response(jsonEncode({'token': 'jwt'}), 200);
          }
          return http.Response(
            jsonEncode([
              {
                'id': 's3',
                'path': 'RJ00000009/c.flac',
                'title': 'C',
                'suffix': 'flac',
                'duration': 30,
                'size': 3,
                'hasCoverArt': false,
              },
              {
                'id': 's4',
                'path': 'RJ00000009/sub/d.flac',
                'title': 'D',
                'suffix': 'flac',
                'duration': 40,
                'size': 4,
                'hasCoverArt': false,
              },
            ]),
            200,
            headers: {'x-total-count': '2'},
          );
        }),
      );

      final songs = await svc.folderSongs(serverId, 'RJ00000009');
      expect(songs.map((s) => s.id), ['s3', 's4']);
    });
  });

  group('syncSingleSong', () {
    test('maps fields and strips placeholder tags', () async {
      library.byId[100] = Song(
        id: 100,
        path: 'subsonic://$serverId/sf-9',
        sourceType: SourceType.remote,
        title: 'Track W',
        fileName: 'track.wav',
        format: 'wav',
        durationMs: 61000,
        fileSizeBytes: 12345,
        addedAtMs: 0,
        modifiedAtMs: 0,
        playCount: 0,
        skipCount: 0,
        totalPlayMs: 0,
        lastPositionMs: 0,
        isFavorite: false,
      );

      const remote = NavidromeSong(
        id: 'sf-9',
        path: 'RJ777/本編/track.wav',
        title: 'Track W',
        album: '[Unknown Album]',
        artist: '[Unknown Artist]',
        suffix: 'wav',
        durationSec: 61,
        sizeBytes: 12345,
        hasCoverArt: false,
      );

      final song = await service.syncSingleSong(
        server: servers.servers.first,
        remote: remote,
      );

      expect(song, isNotNull);
      expect(song!.id, 100);
      final saved = writer.saved.single;
      expect(saved.path, 'subsonic://$serverId/sf-9');
      expect(saved.sourceType, SourceType.remote);
      expect(saved.fileName, 'track.wav');
      expect(saved.albumTitle, isNull);
      expect(saved.artistName, isNull);
      expect(saved.durationMs, 61000);
      expect(saved.fileSizeBytes, 12345);
    });
  });
}
