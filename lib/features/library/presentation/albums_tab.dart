import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';

import 'package:whisplayer/core/providers/repository_providers.dart';
import 'package:whisplayer/domain/entities/album.dart';

class AlbumsTab extends ConsumerWidget {
  const AlbumsTab({super.key});

  static const _ratios = [1.0, 0.82, 1.15, 0.9];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(libraryRepositoryProvider);
    return StreamBuilder<List<Album>>(
      stream: repo.watchAlbums(),
      builder: (context, snapshot) {
        final albums = snapshot.data ?? const <Album>[];
        if (albums.isEmpty) {
          return const Center(child: Text('暂无专辑'));
        }
        return MasonryGridView.count(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 140),
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          itemCount: albums.length,
          itemBuilder: (context, index) {
            final album = albums[index];
            final ratio = _ratios[index % _ratios.length];
            return _AlbumCard(album: album, aspectRatio: ratio);
          },
        );
      },
    );
  }
}

class _AlbumCard extends StatelessWidget {
  const _AlbumCard({required this.album, required this.aspectRatio});

  final Album album;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => context.push('/library/album/${album.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: album.artworkPath != null
                  ? Image.file(
                      File(album.artworkPath!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _fallback(scheme),
                    )
                  : _fallback(scheme),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            album.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          Text(
            [
              album.artistName ?? '未知艺术家',
              if (album.year != null) '${album.year}',
              '${album.songCount}首',
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _fallback(ColorScheme scheme) {
    return ColoredBox(
      color: scheme.secondaryContainer,
      child: Icon(
        Icons.album_outlined,
        size: 56,
        color: scheme.onSecondaryContainer,
      ),
    );
  }
}
