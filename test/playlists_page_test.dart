import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:whisplayer/core/providers/repository_providers.dart';
import 'package:whisplayer/domain/entities/playlist.dart';
import 'package:whisplayer/domain/repositories/playlist_repository.dart';
import 'package:whisplayer/features/playlists/presentation/playlists_page.dart';
import 'package:whisplayer/l10n/app_localizations.dart';

class _FakePlaylistRepository implements PlaylistRepository {
  _FakePlaylistRepository({this.playlists = const <Playlist>[]});

  List<Playlist> playlists;
  final List<String> createdNames = <String>[];

  @override
  Stream<List<Playlist>> watchPlaylists() => Stream.value(playlists);

  @override
  Future<Playlist> createPlaylist(String name) {
    createdNames.add(name);
    return Future.value(
      Playlist(
        id: playlists.length + 1,
        name: name,
        createdAtMs: 0,
        updatedAtMs: 0,
        songCount: 0,
      ),
    );
  }

  @override
  Future<void> renamePlaylist(int playlistId, String newName) async {}

  @override
  Future<void> deletePlaylist(int playlistId) async {}

  @override
  Future<int> addSong(int playlistId, int songId) async => 0;

  @override
  Future<void> removeEntry(int entryId) async {}

  @override
  Future<void> removeEntries(List<int> entryIds) async {}

  @override
  Future<void> reorderEntries(List<int> orderedEntryIds) async {}

  @override
  Future<void> clearSongs(int playlistId) async {}

  @override
  Stream<List<PlaylistEntry>> watchEntries(int playlistId) =>
      Stream.value(const <PlaylistEntry>[]);
}

Playlist _playlist(int id, String name, int songCount) => Playlist(
      id: id,
      name: name,
      createdAtMs: 0,
      updatedAtMs: 0,
      songCount: songCount,
    );

GoRouter _router() => GoRouter(
      initialLocation: '/playlists',
      routes: [
        GoRoute(
          path: '/playlists',
          builder: (_, __) => const PlaylistsPage(),
          routes: [
            GoRoute(
              path: ':id',
              builder: (_, state) => Scaffold(
                body: Text('detail-${state.pathParameters['id']}'),
              ),
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

void main() {
  testWidgets('renders playlists with names and song counts', (tester) async {
    final repo = _FakePlaylistRepository(
      playlists: [_playlist(1, '我最爱', 3), _playlist(2, '通勤', 12)],
    );
    await _pump(tester, [playlistRepositoryProvider.overrideWithValue(repo)]);

    expect(find.text('我最爱'), findsOneWidget);
    expect(find.textContaining('3 首'), findsOneWidget);
    expect(find.text('通勤'), findsOneWidget);
    expect(find.textContaining('12 首'), findsOneWidget);
  });

  testWidgets('shows hint when no playlists exist', (tester) async {
    await _pump(tester, [
      playlistRepositoryProvider.overrideWithValue(_FakePlaylistRepository()),
    ]);

    expect(find.text('还没有播放列表'), findsOneWidget);
    expect(find.text('本地歌曲和云端歌曲都可以加入'), findsOneWidget);
  });

  testWidgets('create dialog submits trimmed name to repository',
      (tester) async {
    final repo = _FakePlaylistRepository();
    await _pump(tester, [playlistRepositoryProvider.overrideWithValue(repo)]);

    await tester.tap(find.byTooltip('新建播放列表'));
    await tester.pumpAndSettle();

    expect(find.text('新建播放列表'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '  夜跑  ');
    await tester.tap(find.widgetWithText(FilledButton, '创建'));
    await tester.pumpAndSettle();

    expect(repo.createdNames, ['夜跑']);
    expect(find.text('新建播放列表'), findsNothing);
  });

  testWidgets('tapping a playlist opens its detail route', (tester) async {
    final repo = _FakePlaylistRepository(playlists: [_playlist(7, '我最爱', 3)]);
    await _pump(tester, [playlistRepositoryProvider.overrideWithValue(repo)]);

    await tester.tap(find.text('我最爱'));
    await tester.pumpAndSettle();

    expect(find.text('detail-7'), findsOneWidget);
  });
}
