import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:whisplayer/core/providers/playback_providers.dart';
import 'package:whisplayer/core/providers/repository_providers.dart';
import 'package:whisplayer/domain/entities/album.dart';
import 'package:whisplayer/domain/entities/cloud_directory.dart';
import 'package:whisplayer/domain/entities/song.dart';
import 'package:whisplayer/domain/entities/source_type.dart';
import 'package:whisplayer/domain/entities/webdav_server.dart';
import 'package:whisplayer/domain/repositories/cloud_browse_repository.dart';
import 'package:whisplayer/domain/repositories/settings_repository.dart';
import 'package:whisplayer/domain/repositories/webdav_server_repository.dart';
import 'package:whisplayer/features/library/domain/browse_prefs.dart';
import 'package:whisplayer/features/library/presentation/cloud_folder_page.dart';
import 'package:whisplayer/features/library/presentation/cloud_page.dart';
import 'package:whisplayer/l10n/app_localizations.dart';

import 'helpers/fakes.dart';

// --- fakes ----------------------------------------------------------------

class _FakeSettings implements SettingsRepository {
  // Copied into a mutable map: callers routinely pass `const {}`, and the
  // player persists its queue through setString during playback.
  _FakeSettings([Map<String, String>? initial]) : values = {...?initial};

  final Map<String, String> values;

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> setString(String key, String? value) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<Map<String, String>> getAll() async => Map.of(values);

  @override
  Future<BrowsePrefs> getBrowsePrefs() async => BrowsePrefs.fromMap(values);

  @override
  Future<void> setBrowsePrefs(BrowsePrefs prefs) async {
    values.addAll(prefs.toMap());
  }
}

class _FakeServerRepo implements WebDavServerRepository {
  _FakeServerRepo(this.servers);

  final List<WebDavServer> servers;

  @override
  Stream<List<WebDavServer>> watchServers() => Stream.value(servers);

  @override
  Future<List<WebDavServer>> getServers() async => servers;

  @override
  Future<int> addServer({
    required String name,
    required String baseUrl,
    required String username,
    required String token,
    String rootPath = '/',
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> removeServer(int serverId) async {}

  @override
  Future<String?> getToken(int serverId) async => 'token';
}

class _FakeCloudBrowse implements CloudBrowseRepository {
  _FakeCloudBrowse({
    this.albums = const <Album>[],
    this.directories = const <String, List<CloudDirectory>>{},
    this.songs = const <String, List<Song>>{},
    this.searchResults = const <Song>[],
  });

  final List<Album> albums;
  final Map<String, List<CloudDirectory>> directories;
  final Map<String, List<Song>> songs;
  final List<Song> searchResults;

  @override
  Stream<List<Album>> watchAlbums() => Stream.value(albums);

  @override
  Stream<List<CloudDirectory>> watchDirectories(String parentPath) =>
      Stream.value(directories[parentPath] ?? const <CloudDirectory>[]);

  @override
  Stream<List<Song>> watchSongsInDirectory(String directoryPath) =>
      Stream.value(songs[directoryPath] ?? const <Song>[]);

  @override
  Future<List<Song>> searchSongs(String query) async => searchResults;
}

// --- fixtures -------------------------------------------------------------

const _server = WebDavServer(
  id: 1,
  name: 'NAS',
  baseUrl: 'http://nas:8765',
  username: 'u',
  rootPath: '/',
  addedAtMs: 0,
);

const _server2 = WebDavServer(
  id: 2,
  name: 'Backup',
  baseUrl: 'http://backup:8765',
  username: 'u',
  rootPath: '/',
  addedAtMs: 1,
);

Album _album(int id, String title, {int songs = 3}) => Album(
      id: id,
      title: title,
      groupKey: title.toLowerCase(),
      songCount: songs,
    );

CloudDirectory _dir(String path, String name, {int songs = 2, int subs = 0}) =>
    CloudDirectory(
      path: path,
      name: name,
      songCount: songs,
      totalSongCount: songs,
      subDirectoryCount: subs,
    );

Song _song(int id, String title, {int durationMs = 0}) => Song(
      id: id,
      path: 'webdav://1/RJ1/$title.mp3',
      sourceType: SourceType.webdav,
      title: title,
      fileName: '$title.mp3',
      format: 'mp3',
      durationMs: durationMs,
      fileSizeBytes: 1024,
      addedAtMs: 0,
      modifiedAtMs: 0,
      playCount: 0,
      skipCount: 0,
      totalPlayMs: 0,
      lastPositionMs: 0,
      isFavorite: false,
    );

// --- harness --------------------------------------------------------------

List<Override> _overrides({
  required List<WebDavServer> servers,
  _FakeCloudBrowse? browse,
  Map<String, String> settings = const {},
}) =>
    [
      webDavServerRepositoryProvider
          .overrideWithValue(_FakeServerRepo(servers)),
      settingsRepositoryProvider.overrideWithValue(_FakeSettings(settings)),
      if (browse != null)
        cloudBrowseRepositoryProvider.overrideWithValue(browse),
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
        home: CloudPage(),
      ),
    ),
  );
  await tester.idle();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('no WebDAV source shows the setup hint', (tester) async {
    await _pump(tester, _overrides(servers: const []));

    expect(find.text('云端音乐'), findsOneWidget);
    expect(find.text('还没有 WebDAV 音源 —— 点右下角按钮添加'), findsOneWidget);
    expect(find.text('去添加'), findsOneWidget);
  });

  testWidgets('single server shows a plain title and the work grid',
      (tester) async {
    await _pump(
      tester,
      _overrides(
        servers: const [_server],
        browse: _FakeCloudBrowse(
          albums: [_album(1, 'RJ01008335'), _album(2, 'RJ01011259')],
        ),
      ),
    );

    expect(find.text('NAS'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_drop_down), findsNothing);
    expect(find.text('RJ01008335'), findsOneWidget);
    expect(find.text('RJ01011259'), findsOneWidget);
  });

  testWidgets('empty library points at the scanner', (tester) async {
    await _pump(
      tester,
      _overrides(
        servers: const [_server],
        browse: _FakeCloudBrowse(),
      ),
    );

    expect(find.text('还没有云端音乐，先到设置里扫描一次'), findsOneWidget);
  });

  testWidgets('two servers get a switcher that persists the pick',
      (tester) async {
    final settings = _FakeSettings();
    await _pump(tester, [
      webDavServerRepositoryProvider
          .overrideWithValue(_FakeServerRepo(const [_server, _server2])),
      settingsRepositoryProvider.overrideWithValue(settings),
      cloudBrowseRepositoryProvider
          .overrideWithValue(_FakeCloudBrowse(albums: [_album(1, 'Work')])),
    ]);

    expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_drop_down));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Backup').last);
    await tester.pumpAndSettle();

    expect(settings.values[BrowsePrefs.kActiveServer], '2');
  });

  testWidgets('folder mode lists directories from the scan', (tester) async {
    await _pump(
      tester,
      _overrides(
        servers: const [_server],
        browse: _FakeCloudBrowse(
          directories: {
            'webdav://1': [
              _dir('webdav://1/RJ1', 'RJ01008335', songs: 12, subs: 3),
              _dir('webdav://1/RJ2', 'RJ01011259', songs: 5),
            ],
          },
        ),
      ),
    );

    await tester.tap(find.text('文件夹'));
    await tester.pumpAndSettle();

    expect(find.text('RJ01008335'), findsOneWidget);
    expect(find.text('12 首 · 3 个子目录'), findsOneWidget);
    expect(find.text('5 首'), findsOneWidget);
  });

  testWidgets('settings is the right-most action on the cloud tab',
      (tester) async {
    // The user asked for this explicitly: the settings icon must sit in the
    // same place on every tab, so its position is pinned by a test.
    await _pump(
      tester,
      _overrides(servers: const [_server], browse: _FakeCloudBrowse()),
    );

    final icons = tester
        .widgetList<IconButton>(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.byType(IconButton),
          ),
        )
        .map((button) => (button.icon as Icon).icon)
        .toList();

    expect(icons.last, Icons.settings_outlined);
  });

  testWidgets('search in album mode finds songs', (tester) async {
    await _pump(
      tester,
      _overrides(
        servers: const [_server],
        browse: _FakeCloudBrowse(
          albums: [_album(1, 'Work')],
          searchResults: [_song(7, 'sakura cloud')],
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.search_rounded));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'sakura');
    await tester.pumpAndSettle();

    // The query text itself lives in the search field, so assert on the
    // result row rather than the substring.
    expect(find.text('sakura cloud'), findsOneWidget);
  });

  group('CloudFolderPage', () {
    Future<void> pumpFolder(
      WidgetTester tester, {
      required _FakeCloudBrowse browse,
      String path = 'webdav://1/RJ1',
    }) async {
      tester.platformDispatcher.localesTestValue = const [Locale('zh')];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ..._overrides(servers: const [_server], browse: browse),
            audioEngineProvider.overrideWith((ref) => FakeAudioEngine()),
            playbackRecordRepositoryProvider
                .overrideWithValue(FakePlaybackRecordRepository()),
            playerHandlerProvider.overrideWith((ref) => FakeMediaSession()),
          ],
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: CloudFolderPage(directoryPath: path),
          ),
        ),
      );
      await tester.idle();
      await tester.pumpAndSettle();
    }

    testWidgets('lists sub-directories and files, directories first',
        (tester) async {
      await pumpFolder(
        tester,
        browse: _FakeCloudBrowse(
          directories: {
            'webdav://1/RJ1': [
              _dir('webdav://1/RJ1/02_mp3', '02_mp3', songs: 4),
            ],
          },
          songs: {
            'webdav://1/RJ1': [
              _song(1, '01_intro', durationMs: 65000),
              _song(2, '02_main'),
            ],
          },
        ),
      );

      expect(find.text('RJ1'), findsOneWidget, reason: 'title is the folder');
      expect(find.text('02_mp3'), findsOneWidget);
      expect(find.text('01_intro'), findsOneWidget);
      // A known duration renders as mm:ss; an unknown one falls back to the
      // format instead of a misleading 0:00.
      expect(find.text('1:05'), findsOneWidget);
      expect(find.text('MP3'), findsOneWidget);
    });

    testWidgets('empty folder shows the dedicated hint', (tester) async {
      await pumpFolder(tester, browse: _FakeCloudBrowse());

      expect(find.text('该文件夹暂无歌曲'), findsOneWidget);
    });

    testWidgets('tapping a file starts playback of the whole folder',
        (tester) async {
      final engine = FakeAudioEngine();
      // The page pushes /player on tap, so the test needs a router rather
      // than a bare MaterialApp.
      final router = GoRouter(
        initialLocation: '/cloud/dir',
        routes: [
          GoRoute(
            path: '/cloud/dir',
            builder: (_, __) =>
                const CloudFolderPage(directoryPath: 'webdav://1/RJ1'),
          ),
          GoRoute(
            path: '/player',
            builder: (_, __) => const Scaffold(body: Text('player')),
          ),
        ],
      );
      addTearDown(router.dispose);

      tester.platformDispatcher.localesTestValue = const [Locale('zh')];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ..._overrides(
              servers: const [_server],
              browse: _FakeCloudBrowse(
                songs: {
                  'webdav://1/RJ1': [
                    _song(1, '01_intro'),
                    _song(2, '02_main'),
                  ],
                },
              ),
            ),
            audioEngineProvider.overrideWith((ref) => engine),
            playbackRecordRepositoryProvider
                .overrideWithValue(FakePlaybackRecordRepository()),
            playerHandlerProvider.overrideWith((ref) => FakeMediaSession()),
          ],
          child: MaterialApp.router(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.idle();
      await tester.pumpAndSettle();

      await tester.tap(find.text('02_main'));
      await tester.pumpAndSettle();

      expect(engine.openQueueCalled, isTrue);
      expect(engine.openedStartIndex, 1);
    });
  });
}
