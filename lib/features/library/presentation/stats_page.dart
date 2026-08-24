import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:whisplayer/core/providers/repository_providers.dart';
import 'package:whisplayer/domain/entities/song.dart';
import 'package:whisplayer/features/library/presentation/widgets/song_list_view.dart';
import 'package:whisplayer/features/player/application/player_controller.dart';

const int _topLimit = 10;

/// Returns songs played at least once, ordered by play count descending
/// (total listened time breaks ties), limited to [limit] entries.
List<Song> topPlayedSongs(List<Song> songs, {required int limit}) {
  final played =
      songs.where((song) => song.playCount > 0).toList()
        ..sort((a, b) {
          final byCount = b.playCount.compareTo(a.playCount);
          if (byCount != 0) {
            return byCount;
          }
          return b.totalPlayMs.compareTo(a.totalPlayMs);
        });
  return played.take(limit).toList();
}

/// Formats total listening time as 约N分钟 / 约N小时 / N小时M分钟.
String formatTotalDuration(int ms) {
  final minutes = ms ~/ 60000;
  if (minutes < 60) {
    return '约 $minutes 分钟';
  }
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  if (remainder == 0) {
    return '约 $hours 小时';
  }
  return '$hours 小时 $remainder 分钟';
}

class StatsPage extends ConsumerWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryRepo = ref.watch(libraryRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('播放统计')),
      body: StreamBuilder<List<Song>>(
        stream: libraryRepo.watchSongs(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final songs = snapshot.data ?? const <Song>[];
          final top = topPlayedSongs(songs, limit: _topLimit);
          if (top.isEmpty) {
            return const Center(child: Text('还没有统计数据，先去听几首歌吧'));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(0, 4, 0, 140),
            children: [
              const _SectionHeader(title: '最常播放'),
              for (var i = 0; i < top.length; i++)
                SongRow(
                  key: ValueKey(top[i].id),
                  song: top[i],
                  songs: top,
                  index: i,
                  subtitleExtra: '播放 ${top[i].playCount} 次',
                  trailingText: formatTotalDuration(top[i].totalPlayMs),
                  onTap: () => _playFrom(context, ref, top, i),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}
