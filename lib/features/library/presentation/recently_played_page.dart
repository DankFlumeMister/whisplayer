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
import 'package:whisplayer/l10n/app_localizations.dart';

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

String formatRelativeTime(
  AppLocalizations l10n,
  int playedAtMs, {
  int? nowMs,
}) {
  final now = DateTime.fromMillisecondsSinceEpoch(
    nowMs ?? DateTime.now().millisecondsSinceEpoch,
  );
  final played = DateTime.fromMillisecondsSinceEpoch(playedAtMs);
  final diff = now.difference(played);
  if (diff.inMinutes < 1) {
    return l10n.relJust;
  }
  if (diff.inMinutes < 60) {
    return l10n.relMinutesAgo(diff.inMinutes);
  }
  if (diff.inHours < 24) {
    return l10n.relHoursAgo(diff.inHours);
  }
  if (diff.inDays < 7) {
    return l10n.relDaysAgo(diff.inDays);
  }
  return '${played.year}/${played.month}/${played.day}';
}

class RecentlyPlayedPage extends ConsumerWidget {
  const RecentlyPlayedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(historyRepositoryProvider);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.recentTitle)),
      body: StreamBuilder<List<PlayHistoryEntry>>(
        stream: repo.watchRecent(limit: 50),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snapshot.data ?? const <PlayHistoryEntry>[];
          if (entries.isEmpty) {
            return Center(child: Text(l10n.recentEmpty));
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
                    final extra = formatRelativeTime(
                      l10n,
                      entry.playedAtMs,
                    );
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
        final l10n = AppLocalizations.of(context);
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
                    l10n.statsHeader(
                      stats.totalPlays,
                      stats.completedPlays,
                      minutes,
                    ),
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
