import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:whisplayer/core/providers/repository_providers.dart';
import 'package:whisplayer/domain/entities/album.dart';
import 'package:whisplayer/domain/entities/artist.dart';
import 'package:whisplayer/domain/entities/playlist.dart';
import 'package:whisplayer/domain/entities/remote_server.dart';
import 'package:whisplayer/domain/entities/song.dart';
import 'package:whisplayer/domain/entities/source_type.dart';
import 'package:whisplayer/domain/repositories/library_repository.dart';
import 'package:whisplayer/domain/repositories/playlist_repository.dart';
import 'package:whisplayer/domain/repositories/remote_server_repository.dart';
import 'package:whisplayer/features/playlists/presentation/playlist_detail_page.dart';
import 'package:whisplayer/l10n/app_localizations.dart';

class _FakePlaylistRepository implements PlaylistRepository {
  _FakePlaylistRepository({this.entries = const <PlaylistEntry>[]});

  List<PlaylistEntry> entries;
  final List<List<int>> removedBatches = <List<int>>[];
  final List<int> deletedIds = <int>[];
  final List<(int, int)> added = <(int, int)>[];

  @override
  Stream<List<Playlist>> watchPlaylists() =>
      Stream.value(const <Playlist>[]);

  @override
  Future<Playlist> createPlaylist(String name) async => Playlist(
        id: 1,
        name: name,
        createdAtMs: 0,
        updatedAtMs: 0,
        songCount: 0,
      );

  @override
  Future<void> renamePlaylist(int playlistId, String newName) async {}

  @override
  Future<void> deletePlaylist(int playlistId) {
    deletedIds.add(playlistId);
    return Future<void>.value();
  }

  @override
  Future<int> addSong(int playlistId, int songId) {
    added.add((playlistId, songId));
    return Future<int>.value(0);
  }

  @override
  Future<void> removeEntry(int entryId) async {}

  @override
  Future<void> removeEntries(List<int> entryIds) {
    removedBatches.add(List<int>.of(entryIds));
    return Future<void>.value();
  }

  @override
  Future<void> reorderEntries(List<int> orderedEntryIds) async {}

  @override
  Future<void> clearSongs(int playlistId) async {}

  @override
  Stream<List<PlaylistEntry>> watchEntries(int playlistId) =>
      Stream.value(entries);
}

class _FakeLibraryRepository implements LibraryRepository {
  _FakeLibraryRepository({this.songs = const <Song>[]});

  final List<Song> songs;

  @override
  Future<List<Song>> getAllSongs() async => songs;

  @override
  Future<Song?> getLastPlayedSong() async => null;

  @override
  Future<Song?> getSong(int songId) async => null;

  @override
  Stream<List<Album>> watchAlbums() => Stream.value(const <Album>[]);

  @override
  Stream<List<Artist>> watchArtists() => Stream.value(const <Artist>[]);

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
      watchSongs(sort: sort, descending: descending);

  @override
  Future<List<Song>> searchLocalSongs(String query) => searchSongs(query);

  @override
  Future<int> removeSongsMissingFrom(Set<String> validPaths) async => 0;

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
  Future<List<Song>> searchSongs(String query) async =>
      songs.where((s) => s.title.contains(query)).toList();

  @override
  Future<void> setFavorite(int songId, {required bool favorite}) async {}

  @override
  Future<List<Song>> songsByAlbum(int albumId) async => const [];

  @override
  Future<List<Song>> songsByArtist(int artistId) async => const [];
}

class _FakeRemoteServerRepository implements RemoteServerRepository {
  @override
  Stream<List<RemoteServer>> watchServers() =>
      Stream.value(const <RemoteServer>[]);

  @override
  Future<List<RemoteServer>> getServers() async => const <RemoteServer>[];

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
  Future<String?> getPassword(int serverId) async => null;
}

Song _song(int id, {SourceType type = SourceType.local}) => Song(
      id: id,
      path: type == SourceType.local ? '/tmp/$id.flac' : 'subsonic://7/r$id',
      sourceType: type,
      title: 'Song $id',
      fileName: '$id.flac',
      format: 'flac',
      durationMs: 180000,
      fileSizeBytes: 1024,
      addedAtMs: 0,
      modifiedAtMs: 0,
      playCount: 0,
      skipCount: 0,
      totalPlayMs: 0,
      lastPositionMs: 0,
      isFavorite: false,
    );

List<PlaylistEntry> _entries() => [
      PlaylistEntry(entryId: 101, position: 0, song: _song(1)),
      PlaylistEntry(
        entryId: 102,
        position: 1,
        song: _song(9, type: SourceType.remote),
      ),
    ];

/// Root route keeps a two-level stack so `context.pop()` after deleting the
/// playlist has somewhere to go.
GoRouter _router() => GoRouter(
      initialLocation: '/detail',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: Text('root')),
          routes: [
            GoRoute(
              path: 'detail',
              builder: (_, __) => const PlaylistDetailPage(
                playlistId: 7,
                name: '我的歌单',
              ),
            ),
            GoRoute(
              path: 'settings/remote-servers',
              builder: (_, __) =>
                  const Scaffold(body: Text('servers-page')),
            ),
          ],
        ),
      ],
    );

Future<void> _pump(WidgetTester tester, List<Override> overrides) async {
  tester.platformDispatcher.localesTestValue = const [Locale('zh')];
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(
        routerConfig: _router(),
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.idle();
  await tester.pumpAndSettle();
}

Future<void> _openAddSheet(WidgetTester tester) async {
  await tester.tap(find.byTooltip('添加歌曲'));
  await tester.pumpAndSettle();
  await tester.idle();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders entries with source icons and cloud tag',
      (tester) async {
    final repo = _FakePlaylistRepository(entries: _entries());
    await _pump(tester, [playlistRepositoryProvider.overrideWithValue(repo)]);

    expect(find.text('我的歌单'), findsOneWidget);
    expect(find.text('Song 1'), findsOneWidget);
    expect(find.text('Song 9'), findsOneWidget);
    expect(find.byIcon(Icons.music_note_outlined), findsOneWidget);
    expect(find.byIcon(Icons.cloud_outlined), findsOneWidget);
    expect(find.text('云端'), findsOneWidget);
  });

  testWidgets('shows empty hint when playlist has no entries',
      (tester) async {
    await _pump(tester, [
      playlistRepositoryProvider.overrideWithValue(_FakePlaylistRepository()),
    ]);

    expect(find.text('列表为空，点右上角添加歌曲'), findsOneWidget);
  });

  testWidgets('edit mode toggles checkboxes and selected count',
      (tester) async {
    final repo = _FakePlaylistRepository(entries: _entries());
    await _pump(tester, [playlistRepositoryProvider.overrideWithValue(repo)]);

    await tester.tap(find.byTooltip('编辑歌曲'));
    await tester.pumpAndSettle();

    expect(find.byType(Checkbox), findsNWidgets(2));
    expect(find.textContaining('已选 0 首'), findsOneWidget);
    expect(find.textContaining('删除所选 (0)'), findsOneWidget);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('已选 1 首'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.select_all_rounded));
    await tester.pumpAndSettle();
    expect(find.textContaining('已选 2 首'), findsOneWidget);
  });

  testWidgets('delete-selected removes one batch then exits editing',
      (tester) async {
    final repo = _FakePlaylistRepository(entries: _entries());
    await _pump(tester, [playlistRepositoryProvider.overrideWithValue(repo)]);

    await tester.tap(find.byTooltip('编辑歌曲'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.select_all_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(repo.removedBatches, [
      [101, 102],
    ]);
    expect(find.textContaining('已移除 2 首'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    expect(find.byType(Checkbox), findsNothing);
    expect(find.textContaining('已选'), findsNothing);
  });

  testWidgets('delete playlist confirms then pops back to root',
      (tester) async {
    final repo = _FakePlaylistRepository(entries: _entries());
    await _pump(tester, [playlistRepositoryProvider.overrideWithValue(repo)]);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.text('删除播放列表？'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();

    expect(repo.deletedIds, [7]);
    expect(find.byType(PlaylistDetailPage), findsNothing);
    expect(find.text('root'), findsOneWidget);
  });

  testWidgets('add sheet filters local songs and adds via repository',
      (tester) async {
    final repo = _FakePlaylistRepository();
    final library = _FakeLibraryRepository(songs: [
      _song(1),
      _song(2),
      _song(3),
      _song(9, type: SourceType.remote),
    ]);
    await _pump(tester, [
      playlistRepositoryProvider.overrideWithValue(repo),
      libraryRepositoryProvider.overrideWithValue(library),
    ]);
    await _openAddSheet(tester);

    expect(find.text('本地歌曲'), findsOneWidget);
    expect(find.text('Song 1'), findsOneWidget);
    expect(find.text('Song 3'), findsOneWidget);
    expect(find.text('Song 9'), findsNothing);

    await tester.enterText(find.byType(TextField), '2');
    await tester.pumpAndSettle();
    expect(find.text('Song 2'), findsOneWidget);
    expect(find.text('Song 1'), findsNothing);

    await tester.tap(find.text('Song 2'));
    await tester.pump();

    expect(repo.added, [(7, 2)]);
    expect(find.textContaining('已加入「Song 2」'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('cloud picker without server prompts to connect',
      (tester) async {
    await _pump(tester, [
      playlistRepositoryProvider.overrideWithValue(_FakePlaylistRepository()),
      libraryRepositoryProvider.overrideWithValue(_FakeLibraryRepository()),
      remoteServerRepositoryProvider.overrideWithValue(
        _FakeRemoteServerRepository(),
      ),
    ]);
    await _openAddSheet(tester);

    await tester.tap(find.text('云端歌曲'));
    await tester.idle();
    await tester.pumpAndSettle();

    expect(find.text('未连接到服务器'), findsOneWidget);
    expect(find.text('去连接'), findsOneWidget);

    await tester.tap(find.text('去连接'));
    await tester.pumpAndSettle();

    expect(find.text('servers-page'), findsOneWidget);
  });
}
