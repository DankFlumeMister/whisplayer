import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:whisplayer/core/providers/repository_providers.dart';
import 'package:whisplayer/data/navidrome/navidrome_models.dart';
import 'package:whisplayer/domain/entities/remote_server.dart';
import 'package:whisplayer/domain/entities/song.dart';
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

/// Splits strings into digit and non-digit runs so embedded numbers compare
/// by value: "track 2" sorts before "track 10".
int naturalCompare(String a, String b) {
  var i = 0;
  var j = 0;
  while (i < a.length && j < b.length) {
    final codeA = a.codeUnitAt(i);
    final codeB = b.codeUnitAt(j);
    final digitA = _isDigit(codeA);
    final digitB = _isDigit(codeB);
    if (digitA && digitB) {
      final startI = i;
      final startJ = j;
      while (i < a.length && _isDigit(a.codeUnitAt(i))) {
        i++;
      }
      while (j < b.length && _isDigit(b.codeUnitAt(j))) {
        j++;
      }
      final numberA = int.tryParse(a.substring(startI, i));
      final numberB = int.tryParse(b.substring(startJ, j));
      if (numberA != null && numberB != null && numberA != numberB) {
        return numberA.compareTo(numberB);
      }
      // Equal values with different padding (07 vs 7) — keep stable order.
      final fallback = a
          .substring(startI, i)
          .compareTo(b.substring(startJ, j));
      if (fallback != 0) {
        return fallback;
      }
    } else {
      if (codeA != codeB) {
        return codeA.compareTo(codeB);
      }
      i++;
      j++;
    }
  }
  return (a.length - i).compareTo(b.length - j);
}

bool _isDigit(int codeUnit) => codeUnit >= 0x30 && codeUnit <= 0x39;

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
    // browse list, in which case this is a pure cache hit.
    final artworkPath = donorId == null
        ? null
        : await service.folderCover(
            server: widget.server,
            songId: donorId,
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
      final targetPath =
          'subsonic://${widget.server.id}/${remote.id}';
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
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        width: 132,
                        height: 132,
                        child: _FolderArtwork(
                          server: widget.server,
                          donorId: _coverDonorId(all),
                        ),
                      ),
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
                          ? _SongThumb(
                              server: widget.server,
                              songId: file.id,
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
class _SongThumb extends ConsumerWidget {
  const _SongThumb({required this.server, required this.songId});

  final RemoteServer server;
  final String songId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    Widget fallback() => Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.music_note_outlined,
            size: 22,
            color: scheme.onSecondaryContainer,
          ),
        );
    final future = ref
        .read(remoteLibraryServiceProvider)
        .folderCover(server: server, songId: songId, size: 96);
    return FutureBuilder<String?>(
      future: future,
      builder: (context, snapshot) {
        final path = snapshot.data;
        if (path == null || !File(path).existsSync()) {
          return fallback();
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.file(
            File(path),
            width: 48,
            height: 48,
            fit: BoxFit.cover,
            cacheWidth: 96,
            errorBuilder: (_, __, ___) => fallback(),
          ),
        );
      },
    );
  }
}

/// Big cover for the overview header; shares the folder cover cache so a
/// tile already seen in the browse list renders with zero network traffic.
class _FolderArtwork extends ConsumerWidget {
  const _FolderArtwork({required this.server, required this.donorId});

  final RemoteServer server;
  final String? donorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    Widget fallback() => ColoredBox(
          color: scheme.secondaryContainer,
          child: Icon(
            Icons.folder_outlined,
            size: 48,
            color: scheme.onSecondaryContainer,
          ),
        );
    if (donorId == null) {
      return fallback();
    }
    final future = ref
        .read(remoteLibraryServiceProvider)
        .folderCover(server: server, songId: donorId!, size: 200);
    return FutureBuilder<String?>(
      future: future,
      builder: (context, snapshot) {
        final path = snapshot.data;
        if (path == null || !File(path).existsSync()) {
          return fallback();
        }
        return Image.file(
          File(path),
          fit: BoxFit.cover,
          cacheWidth: 264,
          errorBuilder: (_, __, ___) => fallback(),
        );
      },
    );
  }
}
