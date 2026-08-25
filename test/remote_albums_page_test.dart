import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:whisplayer/core/providers/repository_providers.dart';
import 'package:whisplayer/data/remote/remote_library_service.dart';
import 'package:whisplayer/data/subsonic/subsonic_client.dart';
import 'package:whisplayer/data/subsonic/subsonic_models.dart';
import 'package:whisplayer/domain/entities/remote_server.dart';
import 'package:whisplayer/domain/entities/song.dart';
import 'package:whisplayer/domain/repositories/remote_server_repository.dart';
import 'package:whisplayer/domain/repositories/settings_repository.dart';
import 'package:whisplayer/features/library/presentation/remote_albums_page.dart';
import 'package:whisplayer/l10n/app_localizations.dart';

/// Hand-written stub so widget tests never touch HTTP, JSON or the
/// filesystem; wire formats are covered by subsonic_client_test instead.
class _FakeRemoteService implements RemoteLibraryService {
  _FakeRemoteService({
    this.albums = const <SubsonicAlbum>[],
    this.searchAlbums = const <SubsonicAlbum>[],
    this.searchSongs = const <SubsonicSong>[],
  });

  final List<SubsonicAlbum> albums;
  final List<SubsonicAlbum> searchAlbums;
  final List<SubsonicSong> searchSongs;

  @override
  Future<SubsonicClient> clientFor(RemoteServer server) async => SubsonicClient(
        baseUrl: server.baseUrl,
        username: server.username,
        password: 'pw',
      );

  @override
  Future<SubsonicClient> clientForServerId(int serverId) => clientFor(
        const RemoteServer(
          id: 0,
          name: 'stub',
          baseUrl: 'http://stub',
          username: '',
          addedAtMs: 0,
        ),
      );

  @override
  Future<List<SubsonicAlbum>> fetchAlbums(
    int serverId, {
    int size = 100,
    int offset = 0,
  }) async =>
      albums;

  @override
  Future<SubsonicAlbumDetail> fetchAlbum(
    int serverId,
    String albumId,
  ) async {
    final album = albums.isNotEmpty
        ? albums.first
        : const SubsonicAlbum(id: 'stub', name: '');
    return SubsonicAlbumDetail(album: album, songs: const <SubsonicSong>[]);
  }

  @override
  Future<SubsonicSearchResult> search(
    int serverId,
    String query, {
    int songCount = 20,
    int albumCount = 10,
  }) async =>
      SubsonicSearchResult(albums: searchAlbums, songs: searchSongs);

  @override
  Future<String?> fetchLyricsText(Song song) async => null;

  @override
  Future<Song?> ensureSongSynced(
    RemoteServer server,
    SubsonicSong remoteSong,
  ) async =>
      null;

  @override
  Future<int?> syncAlbumToLibrary({
    required RemoteServer server,
    required SubsonicAlbumDetail detail,
  }) async =>
      null;

  @override
  Future<String?> cacheCover({
    required RemoteServer server,
    required String coverArtId,
    int size = 300,
    Directory? baseDir,
  }) async =>
      null;

  @override
  Future<Uri> resolveStreamUri(String logicalPath) async =>
      Uri.parse('https://stub/stream');
}

class _FakeServerRepo implements RemoteServerRepository {
  _FakeServerRepo(this.servers);

  final List<RemoteServer> servers;

  @override
  Stream<List<RemoteServer>> watchServers() => Stream.value(servers);

  @override
  Future<List<RemoteServer>> getServers() async => servers;

  @override
  Future<int> addServer({
    required String name,
    required String baseUrl,
    required String username,
    required String password,
  }) async =>
      0;

  @override
  Future<void> removeServer(int serverId) async {}

  @override
  Future<String?> getPassword(int serverId) async => 'pw';
}

class _FakeSettingsRepo implements SettingsRepository {
  _FakeSettingsRepo({Map<String, String> initial = const {}})

      : values = Map<String, String>.of(initial);

  final Map<String, String> values;

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> setString(String key, String? value) {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
    return Future<void>.value();
  }

  @override
  Future<Map<String, String>> getAll() async => Map.of(values);
}

const _srv5 = RemoteServer(
  id: 5,
  name: 'NAS',
  baseUrl: 'http://nas:4533',
  username: 'u',
  addedAtMs: 0,
);

const _srv9 = RemoteServer(
  id: 9,
  name: 'CloudBox',
  baseUrl: 'http://cloud:4533',
  username: 'u',
  addedAtMs: 1,
);

SubsonicAlbum _album(String id, String name, String artist) => SubsonicAlbum(
      id: id,
      name: name,
      artist: artist,
    );

List<Override> _overrides({
  required List<RemoteServer> servers,
  _FakeRemoteService? service,
  Map<String, String> settings = const {},
}) =>
    [
      remoteServerRepositoryProvider
          .overrideWithValue(_FakeServerRepo(servers)),
      settingsRepositoryProvider
          .overrideWithValue(_FakeSettingsRepo(initial: settings)),
      if (service != null)
        remoteLibraryServiceProvider.overrideWithValue(service),
    ];

Future<void> _pump(WidgetTester tester, List<Override> overrides) async {
  tester.platformDispatcher.localesTestValue = const [Locale('zh')];
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: const MaterialApp(
        locale: Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RemoteAlbumsPage(),
      ),
    ),
  );
  await tester.idle();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('no server shows error state with add action', (tester) async {
    await _pump(tester, _overrides(servers: const []));

    expect(find.text('云端音乐'), findsOneWidget);
    expect(find.text('尚未添加服务器'), findsOneWidget);
    expect(find.text('去添加'), findsOneWidget);
  });

  testWidgets('renders album grid under a plain single-server title',
      (tester) async {
    await _pump(
      tester,
      _overrides(
        servers: [_srv5],
        service: _FakeRemoteService(albums: [
          _album('a1', 'Album A', 'Artist X'),
          _album('a2', 'Album B', 'Artist Y'),
        ]),
      ),
    );

    expect(find.text('NAS'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_drop_down), findsNothing);
    expect(find.text('Album A'), findsOneWidget);
    expect(find.text('Artist X'), findsOneWidget);
    expect(find.text('Album B'), findsOneWidget);
  });

  testWidgets('empty server shows dedicated hint', (tester) async {
    await _pump(
      tester,
      _overrides(servers: [_srv5], service: _FakeRemoteService()),
    );

    expect(find.text('服务器上没有专辑'), findsOneWidget);
  });

  testWidgets('multi-server header restores saved pick and switches',
      (tester) async {
    final settings = _FakeSettingsRepo(
      initial: {'remote.active_server_id': '9'},
    );
    await _pump(tester, [
      remoteServerRepositoryProvider.overrideWithValue(
        _FakeServerRepo([_srv5, _srv9]),
      ),
      settingsRepositoryProvider.overrideWithValue(settings),
      remoteLibraryServiceProvider.overrideWithValue(
        _FakeRemoteService(albums: [_album('a1', 'Album A', 'X')]),
      ),
    ]);

    expect(find.text('CloudBox'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);

    await tester.tap(find.byType(PopupMenuButton<RemoteServer>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('NAS'));
    await tester.pumpAndSettle();

    expect(settings.values['remote.active_server_id'], '5');
    expect(find.text('NAS'), findsOneWidget);
  });

  testWidgets('search suggestions group albums and songs', (tester) async {
    await _pump(
      tester,
      _overrides(
        servers: [_srv5],
        service: _FakeRemoteService(
          searchAlbums: [_album('al1', 'Love Album', 'Love Artist')],
          searchSongs: [
            const SubsonicSong(id: 's1', title: 'Love Song', artist: 'LS'),
          ],
        ),
      ),
    );

    await tester.tap(find.byTooltip('搜索'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'love');
    await tester.pump();
    await tester.idle();
    await tester.pumpAndSettle();

    expect(find.text('专辑'), findsOneWidget);
    expect(find.text('歌曲'), findsOneWidget);
    expect(find.text('Love Album'), findsOneWidget);
    expect(find.text('Love Song'), findsOneWidget);
  });
}
