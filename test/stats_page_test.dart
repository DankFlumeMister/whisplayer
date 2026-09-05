import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:whisplayer/core/providers/repository_providers.dart';
import 'package:whisplayer/domain/entities/song.dart';
import 'package:whisplayer/domain/entities/source_type.dart';
import 'package:whisplayer/features/library/presentation/stats_page.dart';
import 'package:whisplayer/l10n/app_localizations.dart';

import 'helpers/fakes.dart';

Song _song(int id, {required int playCount, int totalPlayMs = 0}) => Song(
      id: id,
      path: '/tmp/$id.flac',
      sourceType: SourceType.local,
      title: 'Song $id',
      fileName: '$id.flac',
      format: 'flac',
      durationMs: 180000,
      fileSizeBytes: 1024,
      addedAtMs: 0,
      modifiedAtMs: 0,
      playCount: playCount,
      skipCount: 0,
      totalPlayMs: totalPlayMs,
      lastPositionMs: 0,
      isFavorite: false,
    );

void main() {
  group('topPlayedSongs', () {
    test('filters out never-played songs', () {
      final top = topPlayedSongs(
        [
          _song(1, playCount: 3),
          _song(2, playCount: 0),
        ],
        limit: 10,
      );
      expect(top.map((s) => s.id), [1]);
    });

    test('orders by play count descending', () {
      final top = topPlayedSongs(
        [
          _song(1, playCount: 2),
          _song(2, playCount: 9),
          _song(3, playCount: 5),
        ],
        limit: 10,
      );
      expect(top.map((s) => s.id), [2, 3, 1]);
    });

    test('breaks ties by total listened time', () {
      final top = topPlayedSongs(
        [
          _song(1, playCount: 3, totalPlayMs: 100000),
          _song(2, playCount: 3, totalPlayMs: 300000),
        ],
        limit: 10,
      );
      expect(top.map((s) => s.id), [2, 1]);
    });

    test('limits the number of entries', () {
      final top = topPlayedSongs(
        [
          for (var i = 1; i <= 15; i++) _song(i, playCount: i),
        ],
        limit: 10,
      );
      expect(top.length, 10);
      expect(top.first.id, 15);
      expect(top.last.id, 6);
    });
  });

  group('formatTotalDuration', () {
    final zh = lookupAppLocalizations(const Locale('zh'));

    test('under an hour reads minutes', () {
      expect(formatTotalDuration(zh, 45 * 60 * 1000), '约 45 分钟');
    });

    test('whole hours read without remainder', () {
      expect(formatTotalDuration(zh, 2 * 3600 * 1000), '约 2 小时');
    });

    test('mixed reads hours and minutes', () {
      expect(
        formatTotalDuration(zh, 90 * 60 * 1000),
        '1 小时 30 分钟',
      );
    });
  });

  testWidgets('renders top played rows with cumulative listen time',
      (tester) async {
    final library = FakeLibraryRepository(
      songs: [
        _song(1, playCount: 2),
        _song(2, playCount: 5, totalPlayMs: 600000),
        _song(3, playCount: 0),
      ],
      exposeSongsInWatch: true,
    );

    tester.platformDispatcher.localesTestValue = const [Locale('zh')];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryRepositoryProvider.overrideWithValue(library),
        ],
        child: const MaterialApp(
            locale: Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: StatsPage()),
      ),
    );
    await tester.idle();
    await tester.pumpAndSettle();

    expect(find.text('最常播放'), findsOneWidget);
    expect(find.textContaining('播放 5 次'), findsOneWidget);
    expect(find.textContaining('播放 2 次'), findsOneWidget);
    expect(find.text('约 10 分钟'), findsOneWidget);
    expect(find.text('3:00'), findsNothing);
    expect(find.text('Song 3'), findsNothing);
  });

  testWidgets('no played songs shows hint without sections',
      (tester) async {
    final library = FakeLibraryRepository(
      songs: [_song(1, playCount: 0)],
      exposeSongsInWatch: true,
    );

    tester.platformDispatcher.localesTestValue = const [Locale('zh')];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryRepositoryProvider.overrideWithValue(library),
        ],
        child: const MaterialApp(
            locale: Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: StatsPage()),
      ),
    );
    await tester.idle();
    await tester.pumpAndSettle();

    expect(find.text('还没有统计数据，先去听几首歌吧'), findsOneWidget);
    expect(find.text('最常播放'), findsNothing);
  });
}
