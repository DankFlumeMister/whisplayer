import 'dart:io';

import 'package:flutter/material.dart';

/// Cover art for a cloud entry, read from the file a scan already cached.
///
/// Unlike the Subsonic cover widget this never touches the network: the
/// WebDAV scan downloads artwork during the walk and records the local path,
/// so rendering is a plain file read that works offline.
class CloudCover extends StatelessWidget {
  const CloudCover({
    required this.artworkPath,
    this.size,
    this.fallbackIconSize = 40,
    this.radius = 12,
    super.key,
  });

  /// Local path recorded by the scan, or `null` when the work has no image.
  final String? artworkPath;

  /// Forces a square of this size. Leave null to fill the given constraints,
  /// which the caller must then make bounded.
  final double? size;

  final double fallbackIconSize;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final path = artworkPath;
    final content = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: path == null
          ? _fallback(scheme)
          : Image.file(
              File(path),
              fit: BoxFit.cover,
              // A cache can be evicted between the scan and the render, so a
              // missing file falls back instead of throwing.
              errorBuilder: (_, __, ___) => _fallback(scheme),
            ),
    );
    final fixed = size;
    return fixed == null
        ? content
        : SizedBox(width: fixed, height: fixed, child: content);
  }

  Widget _fallback(ColorScheme scheme) {
    return ColoredBox(
      color: scheme.secondaryContainer,
      child: Center(
        child: Icon(
          Icons.album_outlined,
          size: fallbackIconSize,
          color: scheme.onSecondaryContainer,
        ),
      ),
    );
  }
}
