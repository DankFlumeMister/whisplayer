import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:whisplayer/core/providers/repository_providers.dart';
import 'package:whisplayer/domain/entities/source_type.dart';
import 'package:whisplayer/l10n/app_localizations.dart';

class FoldersTab extends ConsumerStatefulWidget {
  const FoldersTab({super.key});

  @override
  ConsumerState<FoldersTab> createState() => _FoldersTabState();
}

class _FoldersTabState extends ConsumerState<FoldersTab> {
  String _dirname(String path) {
    final normalized = path.replaceAll(r'\', '/');
    final idx = normalized.lastIndexOf('/');
    return idx <= 0 ? normalized : normalized.substring(0, idx);
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(libraryRepositoryProvider);
    final l10n = AppLocalizations.of(context);
    return FutureBuilder(
      future: repo.getAllSongs(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final songs = snapshot.data!;
        final counts = <String, int>{};
        for (final song in songs) {
          if (song.sourceType != SourceType.local) {
            continue;
          }
          final dir = _dirname(song.path);
          counts[dir] = (counts[dir] ?? 0) + 1;
        }
        final entries = counts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        if (entries.isEmpty) {
          return Center(child: Text(l10n.noFolders));
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 140),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries[index];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.folder_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(entry.key.split('/').last),
              subtitle: Text(l10n.countSongs(entry.value)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () =>
                  context.push('/library/folder', extra: entry.key),
            );
          },
        );
      },
    );
  }
}
