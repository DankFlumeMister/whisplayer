import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:whisplayer/core/providers/repository_providers.dart';
import 'package:whisplayer/domain/entities/song.dart';
import 'package:whisplayer/features/player/application/player_controller.dart';
import 'package:whisplayer/l10n/app_localizations.dart';

class SongsPage extends ConsumerWidget {
  const SongsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(libraryRepositoryProvider);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.songsPageTitle)),
      body: StreamBuilder<List<Song>>(
        stream: repo.watchLocalSongs(
          sort: SongSort.title,
          descending: false,
        ),
        builder: (context, snapshot) {
          final songs = snapshot.data;
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }
          if (songs == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (songs.isEmpty) {
            return Center(child: Text(l10n.songsPageEmpty));
          }
          return ListView.builder(
            itemCount: songs.length,
            itemBuilder: (context, index) {
              final song = songs[index];
              return ListTile(
                leading: _Thumb(path: song.artworkPath),
                title: Text(
                  song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  song.artistName ?? song.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(_duration(song.durationMs)),
                onTap: () => ref
                    .read(playerControllerProvider.notifier)
                    .playSongs(songs, startIndex: index),
              );
            },
          );
        },
      ),
    );
  }

  String _duration(int ms) {
    final total = ms ~/ 1000;
    final minutes = total ~/ 60;
    final seconds = total % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.path});

  final String? path;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (path == null) {
      return ColoredBox(
        color: scheme.secondaryContainer,
        child: Icon(
          Icons.music_note,
          size: 24,
          color: scheme.onSecondaryContainer,
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.file(
        File(path!),
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => ColoredBox(
          color: scheme.secondaryContainer,
          child: Icon(
            Icons.music_note,
            color: scheme.onSecondaryContainer,
          ),
        ),
      ),
    );
  }
}
