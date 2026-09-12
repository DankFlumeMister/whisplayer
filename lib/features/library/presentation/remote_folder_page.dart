import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:whisplayer/core/providers/repository_providers.dart';
import 'package:whisplayer/core/util/natural_compare.dart';
import 'package:whisplayer/data/navidrome/navidrome_models.dart';
import 'package:whisplayer/data/remote/remote_library_service.dart';
import 'package:whisplayer/domain/entities/remote_server.dart';
import 'package:whisplayer/domain/entities/song.dart';
import 'package:whisplayer/features/library/presentation/remote_cover.dart';
import 'package:whisplayer/features/library/presentation/stats_page.dart';
import 'package:whisplayer/features/player/application/player_controller.dart';
import 'package:whisplayer/l10n/app_localizations.dart';

/// One work inside the cloud "folders" browse mode. Lists the audio files
/// of a top-level library directory, descending level by level; tapping a
/// file lazily syncs it into the local library and starts playback.
class RemoteFolderPage extends ConsumerStatefulWidget {
  const RemoteFolderPage({
    required this.server,
    required this.folderName,
    this.subPath,
    super.key,
  });

  final RemoteServer server;
  final String folderName;

  /// Sub-directory relative to [folderName]; empty for the work root.
  final String? subPath;

  @override
  ConsumerState<RemoteFolderPage> createState() => _RemoteFolderPageState();
}

class _RemoteFolderPageState extends ConsumerState<RemoteFolderPage> {
  bool _playingAll = false;

  String get _baseDir {
    final sub = widget.subPath;
    return sub == null || sub.isEmpty
        ? widget.folderName
        : '${widget.folderName}/$sub';
  }

  String get _title {
    final sub = widget.subPath;
    if (sub == null || sub.isEmpty) {
      return widget.folderName;
    }
    final slash = sub.lastIndexOf('/');
    return slash < 0 ? sub : sub.substring(slash + 1);
  }

  ({List<String> dirs, List<NavidromeSong> files}) _splitLevels(
    List<NavidromeSong> songs,
  ) {
    final basePrefix = '$_baseDir/';
    final dirs = <String>{};
    final files = <NavidromeSong>[];
    for (final song in songs) {
      if (!song.path.startsWith(basePrefix)) {
        continue;
      }
      final rest = song.path.substring(basePrefix.length);
      final slash = rest.indexOf('/');
      if (slash < 0) {
        files.add(song);
      } else {
        dirs.add(rest.substring(0, slash));
      }
    }
    final sortedDirs = dirs.toList()..sort(naturalCompare);
    final sortedFiles = [...files]
      ..sort(
        (a, b) {
          final byTitle = naturalCompare(
            a.title.toLowerCase(),
            b.title.toLowerCase(),
          );
          return byTitle != 0 ? byTitle : a.path.compareTo(b.path);
        },
      );
    return (dirs: sortedDirs, files: sortedFiles);
  }

  Future<List<Song>> _syncAll(List<NavidromeSong> remotes) async {
    final service = ref.read(remoteLibraryServiceProvider);
    String? donorId;
    for (final remote in remotes) {
      if (remote.hasCoverArt) {
        donorId = remote.id;
        break;
      }
    }
    // One cover for the whole work — usually already on disk from the
    // browse list, in which case this is a pure cache hit. Falls back to
    // the album cover when no song carries embedded art.
    final albumId = _firstAlbumId(remotes);
    String? artworkPath;
    if (donorId != null) {
      artworkPath = await service.folderCover(
        server: widget.server,
        songId: donorId,
      );
    }
    // A donor that fails to download (e.g. id without the Subsonic prefix)
    // must still fall back to the album cover instead of leaving the song
    // without artwork.
    artworkPath ??= albumId == null
        ? null
        : await service.albumCover(
            server: widget.server,
            albumId: albumId,
          );
    // Untagged works: the shared placeholder album is skipped, so fall
    // back to the folder-based album's cover (folder.jpg) by name.
    artworkPath ??= await service.folderAlbumCover(
      server: widget.server,
      folderName: widget.folderName,
    );
    final localSongs = <Song>[];
    for (final remote in remotes) {
      final song = await service.syncSingleSong(
        server: widget.server,
        remote: remote,
        artworkPath: artworkPath,
      );
      if (song != null) {
        localSongs.add(song);
      }
    }
    return localSongs;
  }

  Future<void> _play(
    NavidromeSong remote,
    List<NavidromeSong> levelFiles,
  ) async {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.syncingTo(remote.title))));
    try {
      final localSongs = await _syncAll(levelFiles);
      if (!mounted || localSongs.isEmpty) {
        return;
      }
      final targetPath = encodeSubsonicPath(widget.server.id, remote.id);
      var startIndex =
          localSongs.indexWhere((s) => s.path == targetPath);
      if (startIndex < 0) {
        startIndex = 0;
      }
      await ref
          .read(playerControllerProvider.notifier)
          .playSongs(localSongs, startIndex: startIndex);
      if (!mounted) {
        return;
      }
      unawaited(context.push('/player'));
    } on Exception catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.playFailedPrefix}: $e')),
      );
    }
  }

  void _openSub(String dir) {
    final sub = widget.subPath == null || widget.subPath!.isEmpty
        ? dir
        : '${widget.subPath!}/$dir';
    unawaited(
      context.push(
        '/cloud/folder/${widget.server.id}'
        '?name=${Uri.encodeComponent(widget.folderName)}'
        '&sub=${Uri.encodeComponent(sub)}',
        extra: widget.server,
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    return '$minutes:${rest.toString().padLeft(2, '0')}';
  }

  String? _coverDonorId(List<NavidromeSong> all) {
    for (final song in all) {
      if (song.hasCoverArt) {
        return song.id;
      }
    }
    return null;
  }

  String? _firstAlbumId(List<NavidromeSong> all) {
    for (final song in all) {
      final album = song.album;
      final id = song.albumId;
      // Skip the shared placeholder album of untagged files: its cover
      // would be stamped on every folder and every synced song.
      final meaningful = album != null &&
          album.isNotEmpty &&
          !(album.startsWith('[') && album.endsWith(']'));
      if (meaningful && id != null && id.isNotEmpty) {
        return id;
      }
    }
    return null;
  }

  /// Plays the current level only (sub-directories excluded), per product
  /// decision. Syncing is a local DB upsert per file — no audio download.
  Future<void> _playAll(List<NavidromeSong> files) async {
    setState(() => _playingAll = true);
    try {
      final localSongs = await _syncAll(files);
      if (!mounted || localSongs.isEmpty) {
        return;
      }
      await ref
          .read(playerControllerProvider.notifier)
          .playSongs(localSongs);
      if (!mounted) {
        return;
      }
      unawaited(context.push('/player'));
    } on Exception catch (e) {
      if (!mounted) {
        return;
      }
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.playFailedPrefix}: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _playingAll = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: FutureBuilder<List<NavidromeSong>>(
        future: ref
            .read(remoteLibraryServiceProvider)
            .folderSongs(widget.server.id, widget.folderName),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('${l10n.loadFailedPrefix}: ${snapshot.error}'),
            );
          }
          final all = snapshot.data ?? const <NavidromeSong>[];
          final levels = _splitLevels(all);
          if (levels.dirs.isEmpty && levels.files.isEmpty) {
            return Center(child: Text(l10n.folderNoSongs));
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RemoteCover(
                      server: widget.server,
                      songId: _coverDonorId(all),
                      coverAlbumId: _firstAlbumId(all),
                      folderName: widget.folderName,
                      size: 132,
                      radius: 16,
                      cacheWidth: 264,
                      fallbackIcon: Icons.folder_outlined,
                      fallbackIconSize: 48,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.folderName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            [
                              l10n.countSongs(levels.files.length),
                              if (levels.files.isNotEmpty)
                                formatTotalDuration(
                                  l10n,
                                  levels.files.fold<int>(
                                    0,
                                    (sum, s) => sum + s.durationSec * 1000,
                                  ),
                                ),
                            ].where((part) => part.isNotEmpty).join(' · '),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            onPressed:
                                levels.files.isEmpty || _playingAll
                                    ? null
                                    : () =>
                                        unawaited(_playAll(levels.files)),
                            icon: _playingAll
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.play_arrow_rounded),
                            label: Text(l10n.playAll),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 140),
                  itemCount: levels.dirs.length + levels.files.length,
                  itemBuilder: (context, index) {
                    if (index < levels.dirs.length) {
                      final dir = levels.dirs[index];
                      return ListTile(
                        leading: Icon(
                          Icons.folder_outlined,
                          color: scheme.primary,
                        ),
                        title: Text(dir),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openSub(dir),
                      );
                    }
                    final file =
                        levels.files[index - levels.dirs.length];
                    return ListTile(
                      leading: file.hasCoverArt
                          ? RemoteCover(
                              server: widget.server,
                              songId: file.id,
                              size: 48,
                              radius: 10,
                              cacheWidth: 96,
                              fallbackIcon: Icons.music_note_outlined,
                              fallbackIconSize: 22,
                            )
                          : const Icon(Icons.music_note_outlined),
                      title: Text(
                        file.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        [
                          file.artist ?? '',
                          _formatDuration(file.durationSec),
                        ]
                            .where((part) => part.isNotEmpty)
                            .join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () =>
                          unawaited(_play(file, levels.files)),
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
}

/// Small artwork for an audio row: only requested when Navidrome
/// reports the file has cover art; goes through the global gate and
/// shares the on-disk cache with every other cover consumer.

/// Big cover for the overview header; shares the folder cover cache so a
/// tile already seen in the browse list renders with zero network traffic.
