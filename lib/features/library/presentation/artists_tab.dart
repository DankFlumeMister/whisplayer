import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:whisplayer/core/providers/repository_providers.dart';
import 'package:whisplayer/domain/entities/artist.dart';
import 'package:whisplayer/l10n/app_localizations.dart';

class ArtistsTab extends ConsumerWidget {
  const ArtistsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(libraryRepositoryProvider);
    final l10n = AppLocalizations.of(context);
    return StreamBuilder<List<Artist>>(
      stream: repo.watchArtists(),
      builder: (context, snapshot) {
        final artists = snapshot.data ?? const <Artist>[];
        if (artists.isEmpty) {
          return Center(child: Text(l10n.noArtists));
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 140),
          itemCount: artists.length,
          itemBuilder: (context, index) {
            final artist = artists[index];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 26,
                backgroundColor:
                    Theme.of(context).colorScheme.secondaryContainer,
                child: Icon(
                  Icons.person_rounded,
                  color:
                      Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              ),
              title: Text(artist.name),
              subtitle: Text('${l10n.countAlbums(artist.albumCount)} · '
                  '${l10n.countSongs(artist.songCount)}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(
                '/library/artist/${artist.id}',
                extra: artist,
              ),
            );
          },
        );
      },
    );
  }
}
