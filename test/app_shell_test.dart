import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:whisplayer/app/app.dart';
import 'package:whisplayer/core/providers/repository_providers.dart';
import 'package:whisplayer/domain/entities/album.dart';
import 'package:whisplayer/domain/entities/artist.dart';
import 'package:whisplayer/domain/entities/song.dart';
import 'package:whisplayer/domain/repositories/library_repository.dart';

class _FakeLibraryRepository implements LibraryRepository {
  @override
  Future<List<Song>> getAllSongs() async => [];

  @override
  Future<Song?> getLastPlayedSong() async => null;

  @override
  Future<Song?> getSong(int songId) async => null;

  @override
  Stream<List<Album>> watchAlbums() =>
      Stream.value(const <Album>[]);

  @override
  Stream<List<Artist>> watchArtists() =>
      Stream.value(const <Artist>[]);

  @override
  Stream<List<Song>> watchSongs({
    SongSort sort = SongSort.title,
    bool descending = false,
  }) {
    return Stream.value(const <Song>[]);
  }

  @override
  Stream<List<Song>> watchLocalSongs({
    SongSort sort = SongSort.title,
    bool descending = false,
  }) {
    return watchSongs(sort: sort, descending: descending);
  }

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
  Future<List<Song>> searchSongs(String query) async => [];

  @override
  Future<void> setFavorite(int songId, {required bool favorite}) async {}

  @override
  Future<List<Song>> songsByAlbum(int albumId) async => [];

  @override
  Future<List<Song>> songsByArtist(int artistId) async => [];
}

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryRepositoryProvider.overrideWithValue(
            _FakeLibraryRepository(),
          ),
        ],
        child: const WhisplayerApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('app shell renders library tab by default', (tester) async {
    await pumpApp(tester);
    expect(find.text('本地'), findsOneWidget);
    expect(find.text('云端'), findsOneWidget);
    expect(find.text('播放列表'), findsWidgets);
  });

  testWidgets('library switches between four views', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('专辑'));
    await tester.pump();
    expect(find.text('暂无专辑'), findsOneWidget);

    await tester.tap(find.text('艺术家'));
    await tester.pump();
    expect(find.text('暂无艺术家'), findsOneWidget);

    await tester.tap(find.text('文件夹'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('暂无文件夹'), findsOneWidget);
  });

  testWidgets('theme switcher updates theme mode', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byTooltip('设置'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final context =
        tester.element(find.byType(SegmentedButton<ThemeMode>));
    expect(Theme.of(context).brightness, Brightness.light);

    final darkSegment = find.text('深色');
    await tester.ensureVisible(darkSegment);
    await tester.pump();
    await tester.tap(darkSegment, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    final darkContext = tester.element(
      find.byType(SegmentedButton<ThemeMode>),
    );
    expect(Theme.of(darkContext).brightness, Brightness.dark);
  });
}
