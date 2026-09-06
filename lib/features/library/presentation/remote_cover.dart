import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:whisplayer/core/providers/repository_providers.dart';
import 'package:whisplayer/domain/entities/remote_server.dart';

/// Single seam for every remote cover tile (album, folder, song).
///
/// Albums resolve through [coverArtId] via RemoteLibraryService.cacheCover;
/// folders and songs resolve through a cover-donor [songId] via
/// RemoteLibraryService.folderCover, falling back to the folder's
/// [coverAlbumId] via RemoteLibraryService.albumCover when no song carries
/// embedded art. All three share the on-disk cache and the global download
/// gate, so a tile already seen elsewhere renders with zero extra network
/// traffic.
///
/// A missing/empty id or a decode failure degrades to [fallbackIcon] on a
/// tinted rounded square instead of throwing.
class RemoteCover extends ConsumerWidget {
  const RemoteCover({
    required this.server,
    super.key,
    this.coverArtId,
    this.songId,
    this.coverAlbumId,
    this.folderName,
    this.size,
    this.radius = 12,
    this.cacheWidth = 200,
    this.fallbackIcon = Icons.album_outlined,
    this.fallbackIconSize,
  });

  final RemoteServer? server;

  /// Album cover id for RemoteLibraryService.cacheCover. Mutually exclusive
  /// with [songId].
  final String? coverArtId;

  /// Cover-donor song id for RemoteLibraryService.folderCover (folder and
  /// song tiles). Mutually exclusive with [coverArtId].
  final String? songId;

  /// Album id whose cover stands in for folders without a song-level donor.
  final String? coverAlbumId;

  /// Folder name for RemoteLibraryService.folderAlbumCover: the last
  /// fallback for folders whose files are untagged (they share the
  /// placeholder album but their work has folder.jpg art).
  final String? folderName;

  /// Fixed square edge in logical pixels; `null` expands to fill the parent.
  final double? size;

  /// Corner radius for the clipped image and the fallback tile.
  final double radius;

  /// Width (px) the decoder caches the bitmap at — match the largest on-screen
  /// size to avoid blurry upscaling.
  final int cacheWidth;

  final IconData fallbackIcon;
  final double? fallbackIconSize;

  Future<String?> _load(WidgetRef ref) {
    final s = server;
    if (s == null) {
      return Future<String?>.value();
    }
    if (coverArtId != null && coverArtId!.isNotEmpty) {
      return ref
          .read(remoteLibraryServiceProvider)
          .cacheCover(server: s, coverArtId: coverArtId!, size: cacheWidth);
    }
    if (songId != null && songId!.isNotEmpty) {
      return _songCoverWithAlbumFallback(ref, s);
    }
    final album = coverAlbumId;
    if (album != null && album.isNotEmpty) {
      return ref
          .read(remoteLibraryServiceProvider)
          .albumCover(server: s, albumId: album, size: cacheWidth);
    }
    final folder = folderName;
    if (folder != null && folder.isNotEmpty) {
      return ref
          .read(remoteLibraryServiceProvider)
          .folderAlbumCover(server: s, folderName: folder, size: cacheWidth);
    }
    return Future<String?>.value();
  }

  Future<String?> _songCoverWithAlbumFallback(
    WidgetRef ref,
    RemoteServer s,
  ) async {
    final service = ref.read(remoteLibraryServiceProvider);
    final songCover =
        await service.folderCover(server: s, songId: songId!, size: cacheWidth);
    if (songCover != null) {
      return songCover;
    }
    final album = coverAlbumId;
    if (album != null && album.isNotEmpty) {
      final albumCover =
          await service.albumCover(server: s, albumId: album, size: cacheWidth);
      if (albumCover != null) {
        return albumCover;
      }
    }
    final folder = folderName;
    if (folder == null || folder.isEmpty) {
      return null;
    }
    return service.folderAlbumCover(
      server: s,
      folderName: folder,
      size: cacheWidth,
    );
  }

  Widget _fallback(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Bound the tile even when [size] is null: a null-width Container is
    // rejected by ListTile ("leading consumes entire tile width"). In grid /
    // folder tiles the parent (StackFit.expand / Expanded) overrides this with
    // a tight constraint and still makes the tile fill its cell.
    final edge = size ?? 48.0;
    final iconSize = fallbackIconSize ?? (size == null ? 44 : 24);
    final icon = Icon(
      fallbackIcon,
      size: iconSize,
      color: scheme.onSecondaryContainer,
    );
    return Container(
      width: edge,
      height: edge,
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: icon,
    );
  }

  Widget _image(BuildContext context, String path) {
    final image = Image.file(
      File(path),
      fit: BoxFit.cover,
      cacheWidth: cacheWidth,
      errorBuilder: (_, __, ___) => _fallback(context),
    );
    final clipped = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: image,
    );
    // No SizedBox.expand here: in list mode the cover is a ListTile leading
    // (unbounded height), and the parent already constrains it in grid
    // (StackFit.expand) and folder tiles (Expanded). Forcing expand would
    // demand infinite constraints and throw.
    return size == null
        ? clipped
        : SizedBox(width: size, height: size, child: clipped);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<String?>(
      future: _load(ref),
      builder: (context, snapshot) {
        final path = snapshot.data;
        if (path == null || !File(path).existsSync()) {
          return _fallback(context);
        }
        return _image(context, path);
      },
    );
  }
}
