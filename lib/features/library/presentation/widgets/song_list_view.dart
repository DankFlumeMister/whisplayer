import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:whisplayer/domain/entities/song.dart';
import 'package:whisplayer/features/player/application/player_controller.dart';

class SongListView extends StatelessWidget {
  const SongListView({required this.songs, super.key});

  final List<Song> songs;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 140),
      itemCount: songs.length,
      itemBuilder: (context, index) {
        final song = songs[index];
        return SongRow(song: song, songs: songs, index: index);
      },
    );
  }
}

class SongRow extends ConsumerWidget {
  const SongRow({
    required this.song,
    required this.songs,
    required this.index,
    this.onTap,
    this.subtitleExtra,
    this.trailingText,
    super.key,
  });

  final Song song;
  final List<Song> songs;
  final int index;
  final VoidCallback? onTap;
  final String? subtitleExtra;
  final String? trailingText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: SongArtwork(path: song.artworkPath),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        [
          song.artistName ?? '',
          song.albumTitle ?? '',
          subtitleExtra ?? '',
        ]
            .where((part) => part.isNotEmpty)
            .join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        trailingText ?? formatDuration(song.durationMs),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      onTap: onTap ??
          () => ref
              .read(playerControllerProvider.notifier)
              .playSongs(songs, startIndex: index),
    );
  }
}

String formatDuration(int ms) {
  final total = ms ~/ 1000;
  final minutes = total ~/ 60;
  final seconds = total % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

class SongArtwork extends StatelessWidget {
  const SongArtwork({
    required this.path,
    this.size = 48,
    super.key,
  });

  final String? path;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget fallback() => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.music_note,
            color: scheme.onSecondaryContainer,
          ),
        );
    if (path == null) {
      return fallback();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.file(
        File(path!),
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: 96,
        errorBuilder: (_, __, ___) => fallback(),
      ),
    );
  }
}
