import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:whisplayer/domain/entities/scan_progress.dart';
import 'package:whisplayer/features/settings/application/scan_controller.dart';
import 'package:whisplayer/l10n/app_localizations.dart';

class ScanPage extends ConsumerWidget {
  const ScanPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(scanControllerProvider);
    final config = ref.watch(scanConfigProvider);
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.scanTitle)),
      body: config.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (cfg) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ProgressCard(state: state),
            const SizedBox(height: 16),
            _DirectoryCard(config: cfg),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: state.isScanning
                  ? () =>
                      ref.read(scanControllerProvider.notifier).cancel()
                  : () async {
                      if (!await _ensureAudioPermission()) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
              content: Text(l10n.needAudioPermission),
            ),
                          );
                        }
                        return;
                      }
                      final allFiles = await _ensureAllFilesAccess();
                      await ref
                          .read(scanControllerProvider.notifier)
                          .start(cfg);
                      if (!allFiles && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l10n.allFilesDenied),
                          ),
                        );
                      }
                    },
              icon: Icon(state.isScanning ? Icons.stop : Icons.refresh),
              label: Text(
                state.isScanning
                    ? l10n.stopAction
                    : l10n.startScanAction,
              ),
              style: FilledButton.styleFrom(
                backgroundColor:
                    state.isScanning ? scheme.error : scheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _ensureAudioPermission() async {
    final status = await Permission.audio.request();
    return status.isGranted || status.isLimited;
  }

  /// Asks for "All files access" so non-media files (lyric sidecars
  /// such as .lrc/.vtt/.srt) can be read on Android 11+ scoped storage.
  /// Media playback and scanning work without it; only sidecar reads
  /// require it, so a denial is not fatal.
  Future<bool> _ensureAllFilesAccess() async {
    if (!Platform.isAndroid) {
      return true;
    }
    final status = await Permission.manageExternalStorage.request();
    return status.isGranted;
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.state});

  final ScanUiState state;

  @override
  Widget build(BuildContext context) {
    final progress = state.progress;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_summary(l10n, progress), style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            // While scanning: determinate when a fraction is known,
            // indeterminate during the directory walk. Once finished the
            // bar must freeze at the final fraction — a null value here
            // would start the endless indeterminate animation.
            LinearProgressIndicator(
              value: state.isScanning
                  ? progress?.fraction
                  : (progress?.fraction ?? 0),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
            const SizedBox(height: 10),
            if (progress != null)
              Text(
                '${progress.processed}/${progress.total} · '
                '${progress.currentFile}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              )
            else
              Text(l10n.notScannedYet, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  String _summary(AppLocalizations l10n, ScanProgress? p) {
    if (p == null) {
      return l10n.ready;
    }
    switch (p.phase) {
      case ScanPhase.done:
        return l10n.scanDone(p.addedCount, p.updatedCount, p.removedCount);
      case ScanPhase.error:
        return p.message ?? l10n.scanError;
      case ScanPhase.walking:
        return l10n.walking;
      case ScanPhase.parsing:
      case ScanPhase.cleanup:
        return l10n.parsing;
    }
  }
}

class _DirectoryCard extends ConsumerWidget {
  const _DirectoryCard({required this.config});

  final ScanConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            for (final dir in config.includeDirs)
              ListTile(
                dense: true,
                leading: const Icon(Icons.folder_outlined),
                title: Text(
                  dir,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => _removeDir(ref, dir),
                ),
              ),
            ListTile(
              leading: const Icon(Icons.add),
              title: Text(l10n.addDirectory),
              onTap: () => _addDir(ref),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addDir(WidgetRef ref) async {
    final path = await FilePicker.getDirectoryPath();
    if (path == null) {
      return;
    }
    final cfg = await ref.read(scanConfigProvider.future);
    final dirs = cfg.includeDirs.contains(path)
        ? cfg.includeDirs
        : [...cfg.includeDirs, path];
    await ref
        .read(scanControllerProvider.notifier)
        .saveConfig(cfg.copyWith(includeDirs: dirs));
    ref.invalidate(scanConfigProvider);
  }

  Future<void> _removeDir(WidgetRef ref, String dir) async {
    final cfg = await ref.read(scanConfigProvider.future);
    if (cfg.includeDirs.length <= 1) {
      return;
    }
    final next = cfg.copyWith(
      includeDirs: [...cfg.includeDirs]..remove(dir),
    );
    await ref.read(scanControllerProvider.notifier).saveConfig(next);
    ref.invalidate(scanConfigProvider);
  }
}
