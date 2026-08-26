import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:whisplayer/core/providers/repository_providers.dart';
import 'package:whisplayer/domain/entities/album.dart';
import 'package:whisplayer/domain/entities/song.dart';
import 'package:whisplayer/features/library/presentation/widgets/song_list_view.dart';
import 'package:whisplayer/features/player/application/player_controller.dart';
import 'package:whisplayer/l10n/app_localizations.dart';

class AlbumDetailPage extends ConsumerStatefulWidget {
  const AlbumDetailPage({required this.albumId, this.album, super.key});

  final int albumId;
  final Album? album;

  @override
  ConsumerState<AlbumDetailPage> createState() => _AlbumDetailPageState();
}

class _AlbumDetailPageState extends ConsumerState<AlbumDetailPage> {
  late final Future<List<Song>> _songsFuture;

  @override
  void initState() {
    super.initState();
    _songsFuture =
        ref.read(libraryRepositoryProvider).songsByAlbum(widget.albumId);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.album?.title ?? l10n.albumFallback),
      ),
      body: FutureBuilder<List<Song>>(
        future: _songsFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final songs = snapshot.data!;
          final album = widget.album;
          final coverPath = album?.artworkPath ??
              [
                for (final song in songs)
                  if (song.artworkPath != null) song.artworkPath!,
              ].firstOrNull;
          final title =
              album?.title ?? songs.firstOrNull?.albumTitle ?? '';
          final subtitle = [
            album?.artistName ?? songs.firstOrNull?.artistName ?? '',
            if (album?.year != null) '${album!.year}',
            l10n.countSongs(songs.length),
          ].where((part) => part.isNotEmpty).join(' · ');

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Hero(
                      tag: 'album-${widget.albumId}',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          width: 132,
                          height: 132,
                          child: (coverPath != null &&
                                  File(coverPath).existsSync())
                              ? Image.file(
                                  File(coverPath),
                                  fit: BoxFit.cover,
                                )
                              : ColoredBox(
                                  color: scheme.secondaryContainer,
                                  child: Icon(
                                    Icons.album_outlined,
                                    size: 48,
                                    color: scheme.onSecondaryContainer,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            onPressed: songs.isEmpty
                                ? null
                                : () => ref
                                    .read(playerControllerProvider.notifier)
                                    .playSongs(songs),
                            icon:
                                const Icon(Icons.play_arrow_rounded),
                            label: Text(l10n.playAll),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(child: SongListView(songs: songs)),
            ],
          );
        },
      ),
    );
  }
}
