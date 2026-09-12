import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:whisplayer/application/scanner/music_scanner.dart';
import 'package:whisplayer/core/providers/repository_providers.dart';
import 'package:whisplayer/core/providers/scanner_providers.dart';
import 'package:whisplayer/data/webdav/webdav_client.dart';
import 'package:whisplayer/data/webdav/webdav_metadata_reader.dart';
import 'package:whisplayer/data/webdav/webdav_sidecar_resolver.dart';
import 'package:whisplayer/data/webdav/webdav_storage_source.dart';
import 'package:whisplayer/domain/entities/scan_progress.dart';
import 'package:whisplayer/domain/entities/source_type.dart';
import 'package:whisplayer/domain/entities/webdav_server.dart';
import 'package:whisplayer/l10n/app_localizations.dart';

/// Walks a WebDAV share into the local library, showing live progress.
///
/// Reuses [MusicScanner] wholesale: the same incremental planner, the same
/// progress stream, the same cleanup — only the storage source and metadata
/// reader differ. Cleanup is scoped to [SourceType.webdav], so a share that
/// came back empty can never take the local library with it.
class WebDavScanSheet extends ConsumerStatefulWidget {
  const WebDavScanSheet({
    required this.server,
    this.clearFirst = false,
    super.key,
  });

  final WebDavServer server;

  /// Deletes every previously imported WebDAV song before walking the share.
  ///
  /// An incremental scan matches on path, so rows written by an older build
  /// with different path rules are never overwritten — they linger as
  /// duplicates or as dead entries the player cannot stream. Clearing first is
  /// the only way to be sure the library reflects the current rules. Local
  /// songs are never touched.
  final bool clearFirst;

  @override
  ConsumerState<WebDavScanSheet> createState() => _WebDavScanSheetState();
}

class _WebDavScanSheetState extends ConsumerState<WebDavScanSheet> {
  MusicScanner? _scanner;
  StreamSubscription<ScanProgress>? _sub;
  ScanProgress? _progress;
  var _running = false;

  @override
  void initState() {
    super.initState();
    scheduleMicrotask(_start);
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    // A sheet closed mid-scan must not keep walking in the background.
    _scanner?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    if (_running) {
      return;
    }
    setState(() {
      _running = true;
      _progress = null;
    });
    try {
      if (widget.clearFirst) {
        await ref
            .read(libraryWriterRepositoryProvider)
            .removeAllOfSource(SourceType.webdav);
        if (!mounted) {
          return;
        }
      }
      final scanner = await _buildScanner();
      if (!mounted) {
        scanner.cancel();
        return;
      }
      _scanner = scanner;
      _sub = scanner
          .scan(includeDirs: <String>[widget.server.rootPath])
          .listen((progress) {
        if (!mounted) {
          return;
        }
        setState(() {
          _progress = progress;
          if (progress.phase == ScanPhase.done ||
              progress.phase == ScanPhase.error) {
            _running = false;
          }
        });
      });
    } on Object catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _running = false;
        _progress = ScanProgress(
          phase: ScanPhase.error,
          message: '$e',
        );
      });
    }
  }

  Future<MusicScanner> _buildScanner() async {
    final repo = ref.read(webDavServerRepositoryProvider);
    final token = await repo.getToken(widget.server.id) ?? '';
    final client = WebDavClient(
      baseUrl: widget.server.baseUrl,
      username: widget.server.username,
      token: token,
    );
    final storageSource = WebDavStorageSource(
      lister: client,
      pathPrefix: widget.server.pathPrefix,
    );
    return MusicScanner(
      storageSource: storageSource,
      metadataReader: WebDavMetadataReader(
        // Sibling .lrc/.vtt/.srt files are indexed during the walk and
        // fetched once each during the parse phase.
        lyricsResolver: WebDavSidecarLyricsResolver(
          client: client,
          source: storageSource,
        ),
      ),
      writerRepository: ref.read(libraryWriterRepositoryProvider),
      sourceType: SourceType.webdav,
    );
  }

  void _stop() {
    _scanner?.cancel();
    setState(() => _running = false);
  }

  String _describe(AppLocalizations l10n, ScanProgress p) {
    switch (p.phase) {
      case ScanPhase.walking:
        return l10n.walking;
      case ScanPhase.parsing:
      case ScanPhase.cleanup:
        return l10n.parsing;
      case ScanPhase.done:
        return l10n.scanDone(
          p.addedCount,
          p.updatedCount,
          p.removedCount,
        );
      case ScanPhase.error:
        return p.message ?? l10n.scanError;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final progress = _progress;
    final done = progress?.phase == ScanPhase.done;
    final failed = progress?.phase == ScanPhase.error;
    final countable = progress != null &&
        (progress.phase == ScanPhase.parsing ||
            progress.phase == ScanPhase.cleanup);

    return AlertDialog(
      title: Text(widget.server.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(
            // Indeterminate while walking; pinned full once the scan has
            // ended, so the bar does not spin forever after completion.
            value: countable
                ? progress.fraction
                : (done || failed ? 1.0 : null),
          ),
          const SizedBox(height: 12),
          Text(
            progress == null
                ? l10n.walking
                : _describe(l10n, progress),
            style: theme.textTheme.bodyMedium,
          ),
          if (countable && progress.total > 0) ...[
            const SizedBox(height: 4),
            Text(
              '${progress.processed} / ${progress.total}',
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (progress != null && progress.failedCount > 0) ...[
            const SizedBox(height: 4),
            Text(
              '${l10n.scanFailedPrefix}: ${progress.failedCount}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(done || failed ? l10n.closeAction : l10n.stopAction),
        ),
        if (!done && !failed)
          FilledButton(
            onPressed: _running ? _stop : null,
            child: Text(l10n.stopAction),
          ),
      ],
    );
  }
}
