import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:whisplayer/domain/entities/scan_progress.dart';
import 'package:whisplayer/features/settings/application/scan_controller.dart';

class ScanPage extends ConsumerWidget {
  const ScanPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(scanControllerProvider);
    final config = ref.watch(scanConfigProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('扫描音乐')),
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
                            const SnackBar(content: Text('需要音频文件访问权限')),
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
                          const SnackBar(
                            content: Text('未授予"所有文件访问"，歌词旁注文件（.lrc 等）将无法读取'),
                          ),
                        );
                      }
                    },
              icon: Icon(state.isScanning ? Icons.stop : Icons.refresh),
              label: Text(state.isScanning ? '停止' : '开始扫描'),
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
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_summary(progress), style: theme.textTheme.titleMedium),
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
              Text('尚未扫描', style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  String _summary(ScanProgress? p) {
    if (p == null) {
      return '准备就绪';
    }
    switch (p.phase) {
      case ScanPhase.done:
        return '完成：新增 ${p.addedCount} · 更新 ${p.updatedCount}'
            ' · 移除 ${p.removedCount}';
      case ScanPhase.error:
        return p.message ?? '扫描出错';
      case ScanPhase.walking:
        return '正在遍历目录…';
      case ScanPhase.parsing:
      case ScanPhase.cleanup:
        return '正在解析…';
    }
  }
}

class _DirectoryCard extends ConsumerWidget {
  const _DirectoryCard({required this.config});

  final ScanConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              title: const Text('添加目录'),
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
