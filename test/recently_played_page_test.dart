import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:whisplayer/core/providers/repository_providers.dart';
import 'package:whisplayer/domain/entities/play_history_entry.dart';
import 'package:whisplayer/domain/entities/play_stats.dart';
import 'package:whisplayer/domain/entities/song.dart';
import 'package:whisplayer/domain/entities/source_type.dart';
import 'package:whisplayer/domain/repositories/playlist_repository.dart';
import 'package:whisplayer/features/library/presentation/recently_played_page.dart';

Song _song(int id) => Song(
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
      playCount: 0,
      skipCount: 0,
      totalPlayMs: 0,
      lastPositionMs: 0,
      isFavorite: false,
    );

PlayHistoryEntry _entry(
  int id,
  int songId,
  int playedAtMs, {
  int playedMs = 180000,
  bool completed = true,
}) =>
    PlayHistoryEntry(
      id: id,
      songId: songId,
      playedAtMs: playedAtMs,
      playedMs: playedMs,
      completed: completed,
      song: _song(songId),
    );

class _FakeHistoryRepository implements HistoryRepository {
  _FakeHistoryRepository({this.entries = const [], this.stats});

  final List<PlayHistoryEntry> entries;
  final PlayStats? stats;

  @override
  Future<void> addPlayRecord({
    required int songId,
    required int playedAtMs,
    required int playedMs,
    required bool completed,
  }) async {}

  @override
  Stream<List<PlayHistoryEntry>> watchRecent({int? limit}) {
    return Stream.value(entries);
  }

  @override
  Future<PlayStats> overallStats() async {
    return stats ??
        const PlayStats(
          totalPlays: 0,
          totalPlayedMs: 0,
          completedPlays: 0,
        );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('formatRelativeTime', () {
    final now = DateTime(2026, 8, 24, 12).millisecondsSinceEpoch;

    test('under a minute reads 刚刚', () {
      expect(
        formatRelativeTime(now - 30 * 1000, nowMs: now),
        '刚刚',
      );
    });

    test('minutes read N分钟前', () {
      expect(
        formatRelativeTime(now - 5 * 60 * 1000, nowMs: now),
        '5分钟前',
      );
    });

    test('hours read N小时前', () {
      expect(
        formatRelativeTime(now - 3 * 3600 * 1000, nowMs: now),
        '3小时前',
      );
    });

    test('days within a week read N天前', () {
      expect(
        formatRelativeTime(now - 2 * 24 * 3600 * 1000, nowMs: now),
        '2天前',
      );
    });

    test('older than a week reads a date', () {
      expect(
        formatRelativeTime(now - 9 * 24 * 3600 * 1000, nowMs: now),
        '2026/8/15',
      );
    });
  });

  group('groupConsecutivePlays', () {
    final t = DateTime(2026, 8, 24, 12).millisecondsSinceEpoch;

    test('different songs stay in separate groups', () {
      final groups = groupConsecutivePlays([
        _entry(1, 1, t),
        _entry(2, 2, t - 1000),
      ]);
      expect(groups.length, 2);
      expect(groups[0], hasLength(1));
      expect(groups[1], hasLength(1));
    });

    test('back-to-back same-song plays merge into one group', () {
      final groups = groupConsecutivePlays([
        _entry(1, 1, t),
        _entry(2, 1, t - 180000),
        _entry(3, 1, t - 360000),
      ]);
      expect(groups.length, 1);
      expect(groups.single, hasLength(3));
    });

    test('same song with a long gap stays separate', () {
      final groups = groupConsecutivePlays([
        _entry(1, 1, t),
        _entry(2, 1, t - 600000),
      ]);
      expect(groups.length, 2);
    });

    test('skip followed by instant replay merges', () {
      final groups = groupConsecutivePlays([
        _entry(1, 1, t),
        _entry(2, 1, t - 15000, playedMs: 10000, completed: false),
      ]);
      expect(groups.length, 1);
      expect(groups.single, hasLength(2));
    });

    test('interleaved songs break the run', () {
      final groups = groupConsecutivePlays([
        _entry(1, 1, t),
        _entry(2, 2, t - 180000),
        _entry(3, 1, t - 360000),
      ]);
      expect(groups.length, 3);
    });
  });

  testWidgets('renders stats header and relative time per row',
      (tester) async {
    final playedAt =
        DateTime.now().millisecondsSinceEpoch - 5 * 60 * 1000;
    final fake = _FakeHistoryRepository(
      entries: [
        PlayHistoryEntry(
          id: 1,
          songId: _song(1).id,
          playedAtMs: playedAt,
          playedMs: 120000,
          completed: true,
          song: _song(1),
        ),
      ],
      stats: const PlayStats(
        totalPlays: 12,
        totalPlayedMs: 45 * 60 * 1000,
        completedPlays: 3,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          historyRepositoryProvider.overrideWithValue(fake),
        ],
        child: const MaterialApp(home: RecentlyPlayedPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Song 1'), findsOneWidget);
    expect(find.textContaining('分钟前'), findsOneWidget);
    expect(find.textContaining('共播放 12 次'), findsOneWidget);
    expect(find.textContaining('完播 3 次'), findsOneWidget);
    expect(find.textContaining('累计约 45 分钟'), findsOneWidget);
  });

  testWidgets('merges consecutive loop plays into one row with count',
      (tester) async {
    final playedAt = DateTime.now().millisecondsSinceEpoch - 60 * 1000;
    final fake = _FakeHistoryRepository(
      entries: [
        _entry(1, 1, playedAt),
        _entry(2, 1, playedAt - 180000),
        _entry(3, 2, playedAt - 360001),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          historyRepositoryProvider.overrideWithValue(fake),
        ],
        child: const MaterialApp(home: RecentlyPlayedPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Song 1'), findsOneWidget);
    expect(find.text('Song 2'), findsOneWidget);
    expect(find.textContaining('×2'), findsOneWidget);
  });

  testWidgets('empty history shows hint without stats header',
      (tester) async {
    final fake = _FakeHistoryRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          historyRepositoryProvider.overrideWithValue(fake),
        ],
        child: const MaterialApp(home: RecentlyPlayedPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('还没有播放记录'), findsOneWidget);
    expect(find.textContaining('共播放'), findsNothing);
  });
}
