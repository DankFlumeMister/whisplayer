import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:whisplayer/core/providers/repository_providers.dart';
import 'package:whisplayer/domain/entities/play_history_entry.dart';
import 'package:whisplayer/domain/entities/play_stats.dart';
import 'package:whisplayer/domain/entities/song.dart';
import 'package:whisplayer/domain/repositories/playlist_repository.dart';
import 'package:whisplayer/features/library/presentation/widgets/song_list_view.dart';
import 'package:whisplayer/features/player/application/player_controller.dart';

const int _mergeGapToleranceMs = 15000;

/// Groups consecutive plays of the same song that happened back-to-back
/// (e.g. loop-one wraps) into single groups so the list shows one row
/// per listening session instead of one row per loop iteration.
///
/// Entries must be ordered by [PlayHistoryEntry.playedAtMs] descending.
List<List<PlayHistoryEntry>> groupConsecutivePlays(
  List<PlayHistoryEntry> entries,
) {
  final groups = <List<PlayHistoryEntry>>[];
  for (final entry in entries) {
    final last = groups.isEmpty ? null : groups.last;
    if (last != null && _belongsTo(last, entry)) {
      last.add(entry);
    } else {
      groups.add([entry]);
    }
  }
  return groups;
}

bool _belongsTo(List<PlayHistoryEntry> group, PlayHistoryEntry entry) {
  final newest = group.last;
  if (entry.songId != newest.songId) {
    return false;
  }
  final gap = newest.playedAtMs - entry.playedAtMs;
  if (gap < 0) {
    return false;
  }
  return gap <= newest.playedMs + _mergeGapToleranceMs;
}

String formatRelativeTime(int playedAtMs, {int? nowMs}) {
  final now = DateTime.fromMillisecondsSinceEpoch(
    nowMs ?? DateTime.now().millisecondsSinceEpoch,
  );
  final played = DateTime.fromMillisecondsSinceEpoch(playedAtMs);
  final diff = now.difference(played);
  if (diff.inMinutes < 1) {
    return '刚刚';
  }
  if (diff.inMinutes < 60) {
    return '${diff.inMinutes}分钟前';
  }
  if (diff.inHours < 24) {
    return '${diff.inHours}小时前';
  }
  if (diff.inDays < 7) {
    return '${diff.inDays}天前';
  }
  return '${played.year}/${played.month}/${played.day}';
}

class RecentlyPlayedPage extends ConsumerWidget {
  const RecentlyPlayedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(historyRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('最近播放')),
      body: StreamBuilder<List<PlayHistoryEntry>>(
        stream: repo.watchRecent(limit: 50),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snapshot.data ?? const <PlayHistoryEntry>[];
          if (entries.isEmpty) {
            return const Center(child: Text('还没有播放记录'));
          }
          final groups = groupConsecutivePlays(entries);
          final songs = <Song>[];
          for (final group in groups) {
            final song = group.first.song;
            if (songs.every((s) => s.id != song.id)) {
              songs.add(song);
            }
          }
          return Column(
            children: [
              _StatsHeader(repo: repo),
              Expanded(
                child: ListView.builder(
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    final entry = group.first;
                    final song = entry.song;
                    final extra = formatRelativeTime(entry.playedAtMs);
                    final mergedExtra = group.length > 1
                        ? '$extra · ×${group.length}'
                        : extra;
                    return SongRow(
                      key: ValueKey(entry.id),
                      song: song,
                      songs: songs,
                      index: songs.indexWhere((s) => s.id == song.id),
                      subtitleExtra: mergedExtra,
                      onTap: () => _playFrom(
                        context,
                        ref,
                        songs,
                        songs.indexWhere((s) => s.id == song.id),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _playFrom(
    BuildContext context,
    WidgetRef ref,
    List<Song> songs,
    int index,
  ) {
    unawaited(
      ref
          .read(playerControllerProvider.notifier)
          .playSongs(songs, startIndex: index),
    );
    unawaited(context.push('/player'));
  }
}

class _StatsHeader extends StatelessWidget {
  const _StatsHeader({required this.repo});

  final HistoryRepository repo;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PlayStats>(
      future: repo.overallStats(),
      builder: (context, snapshot) {
        final stats = snapshot.data;
        if (stats == null || stats.totalPlays == 0) {
          return const SizedBox.shrink();
        }
        final minutes = stats.totalPlayedMs ~/ 60000;
        return Card(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '共播放 ${stats.totalPlays} 次'
                    ' · 完播 ${stats.completedPlays} 次'
                    ' · 累计约 $minutes 分钟',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
