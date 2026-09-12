import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:whisplayer/core/providers/cloud_providers.dart';
import 'package:whisplayer/core/util/natural_compare.dart';
import 'package:whisplayer/domain/entities/cloud_directory.dart';
import 'package:whisplayer/domain/entities/song.dart';
import 'package:whisplayer/features/player/application/player_controller.dart';
import 'package:whisplayer/l10n/app_localizations.dart';

/// One directory of the WebDAV share, read straight from the local database.
///
/// Sub-directories and audio files are listed together, directories first.
/// Nothing is fetched and nothing is synced: the scan that imported the songs
/// also recorded every path, so opening a folder is a local query.
class CloudFolderPage extends ConsumerWidget {
  const CloudFolderPage({required this.directoryPath, super.key});

  /// Absolute logical path, e.g. `webdav://1/RJ01008335/02_mp3`.
  final String directoryPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final dirs =
        ref.watch(cloudDirectoriesProvider(directoryPath)).value ??
            const <CloudDirectory>[];
    final songs =
        ref.watch(cloudDirectorySongsProvider(directoryPath)).value ??
            const <Song>[];

    final sortedDirs = [...dirs]
      ..sort((a, b) => naturalCompare(a.name, b.name));
    final sortedSongs = [...songs]..sort(_byName);

    return Scaffold(
      appBar: AppBar(
        title: Text(directoryNameOf(directoryPath)),
        actions: [
          if (sortedSongs.isNotEmpty)
            IconButton(
              tooltip: l10n.playAll,
              onPressed: () => _play(ref, context, sortedSongs, 0),
              icon: const Icon(Icons.play_arrow_rounded),
            ),
        ],
      ),
      body: sortedDirs.isEmpty && sortedSongs.isEmpty
          ? Center(child: Text(l10n.folderDetailEmpty))
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 140),
              itemCount: sortedDirs.length + sortedSongs.length,
              itemBuilder: (context, index) {
                if (index < sortedDirs.length) {
                  final dir = sortedDirs[index];
                  return ListTile(
                    leading: const Icon(Icons.folder_outlined),
                    title: Text(dir.name),
                    subtitle: Text(
                      l10n.countSongs(dir.totalSongCount),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => unawaited(
                      context.push(
                        '/cloud/dir?path=${Uri.encodeComponent(dir.path)}',
                      ),
                    ),
                  );
                }
                final songIndex = index - sortedDirs.length;
                final song = sortedSongs[songIndex];
                return ListTile(
                  leading: const Icon(Icons.music_note_outlined),
                  title: Text(song.title),
                  subtitle: _subtitle(l10n, song),
                  onTap: () => _play(ref, context, sortedSongs, songIndex),
                );
              },
            ),
    );
  }

  Widget? _subtitle(AppLocalizations l10n, Song song) {
    // durationMs stays 0 until the player learns the real value and writes it
    // back, so an unknown length shows the file format instead of "0:00".
    if (song.durationMs > 0) {
      return Text(_formatDuration(song.durationMs));
    }
    return song.format.isEmpty ? null : Text(song.format.toUpperCase());
  }

  void _play(WidgetRef ref, BuildContext context, List<Song> songs, int index) {
    unawaited(
      ref
          .read(playerControllerProvider.notifier)
          .playSongs(songs, startIndex: index),
    );
    unawaited(context.push('/player'));
  }

  /// Natural order over the file name, so `2` precedes `10`.
  static int _byName(Song a, Song b) =>
      naturalCompare(a.fileName.toLowerCase(), b.fileName.toLowerCase());
}

String _formatDuration(int milliseconds) {
  final totalSeconds = milliseconds ~/ 1000;
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
