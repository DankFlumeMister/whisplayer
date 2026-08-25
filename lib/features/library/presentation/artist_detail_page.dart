import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:whisplayer/core/providers/repository_providers.dart';
import 'package:whisplayer/domain/entities/artist.dart';
import 'package:whisplayer/domain/entities/song.dart';
import 'package:whisplayer/features/library/presentation/widgets/song_list_view.dart';
import 'package:whisplayer/features/player/application/player_controller.dart';
import 'package:whisplayer/l10n/app_localizations.dart';

class ArtistDetailPage extends ConsumerStatefulWidget {
  const ArtistDetailPage({required this.artistId, this.artist, super.key});

  final int artistId;
  final Artist? artist;

  @override
  ConsumerState<ArtistDetailPage> createState() => _ArtistDetailPageState();
}

class _ArtistDetailPageState extends ConsumerState<ArtistDetailPage> {
  late final Future<List<Song>> _songsFuture;

  @override
  void initState() {
    super.initState();
    _songsFuture =
        ref.read(libraryRepositoryProvider).songsByArtist(widget.artistId);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.artist?.name ?? l10n.artistFallback),
      ),
      body: FutureBuilder<List<Song>>(
        future: _songsFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final songs = snapshot.data!;
          final name = widget.artist?.name ??
              songs.firstOrNull?.artistName ??
              l10n.unknownArtist;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: scheme.secondaryContainer,
                      child: Icon(
                        Icons.person_rounded,
                        size: 40,
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.countSongs(songs.length),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: songs.isEmpty
                    ? null
                    : () => ref
                        .read(playerControllerProvider.notifier)
                        .playSongs(songs),
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(l10n.playAll),
              ),
              const Divider(height: 20),
              Expanded(child: SongListView(songs: songs)),
            ],
          );
        },
      ),
    );
  }
}
