import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:whisplayer/core/providers/repository_providers.dart';
import 'package:whisplayer/domain/entities/playlist.dart';
import 'package:whisplayer/l10n/app_localizations.dart';

class PlaylistsPage extends ConsumerWidget {
  const PlaylistsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final repo = ref.watch(playlistRepositoryProvider);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(l10n.playlistTab),
            actions: [
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: l10n.createPlaylistTooltip,
                onPressed: () => _showCreateDialog(context, ref),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: StreamBuilder<List<Playlist>>(
              stream: repo.watchPlaylists(),
              builder: (context, snapshot) {
                final playlists = snapshot.data ?? const <Playlist>[];
                if (playlists.isEmpty) {
                  return const _EmptyHint();
                }
                return Column(
                  children: [
                    for (final playlist in playlists)
                      ListTile(
                        leading: const Icon(Icons.queue_music_outlined),
                        title: Text(playlist.name),
                        subtitle: Text(l10n.countSongs(playlist.songCount)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push(
                          '/playlists/${playlist.id}'
                          '?name=${Uri.encodeComponent(playlist.name)}',
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = AppLocalizations.of(context);
    final nameController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.createPlaylistTitle),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.nameLabel),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancelAction),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                return;
              }
              await ref
                  .read(playlistRepositoryProvider)
                  .createPlaylist(name);
              if (!dialogContext.mounted) {
                return;
              }
              Navigator.pop(dialogContext);
            },
            child: Text(l10n.createAction),
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.queue_music_outlined,
            size: 72,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.noPlaylists,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            l10n.playlistsHint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
