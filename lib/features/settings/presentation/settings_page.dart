import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:whisplayer/features/settings/application/overlay_controller.dart';
import 'package:whisplayer/features/settings/application/theme_font_size.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar.large(title: Text('设置')),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('外观'),
                  subtitle: const Text('主题模式与主题色'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/appearance'),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListTile(
                  leading: const Icon(Icons.library_music_outlined),
                  title: const Text('扫描音乐'),
                  subtitle: const Text('导入本地音频文件'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/scan'),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListTile(
                  leading: const Icon(Icons.leaderboard_rounded),
                  title: const Text('播放统计'),
                  subtitle: const Text('最常播放与累计时长'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/library/stats'),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListTile(
                  leading: const Icon(Icons.dns_outlined),
                  title: const Text('远程音乐服务器'),
                  subtitle: const Text('Navidrome / Subsonic 自建服务'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/remote-servers'),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _DesktopLyricsCard(),
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopLyricsCard extends ConsumerStatefulWidget {
  const _DesktopLyricsCard();

  @override
  ConsumerState<_DesktopLyricsCard> createState() =>
      _DesktopLyricsCardState();
}

class _DesktopLyricsCardState extends ConsumerState<_DesktopLyricsCard> {
  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(overlayControllerProvider);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.lyrics_outlined),
            title: const Text('桌面歌词'),
            subtitle:
                Text(enabled ? '已开启，可在其他应用上方显示' : '在其他应用上方显示当前歌词行'),
            value: enabled,
            onChanged: (value) async {
              final messenger = ScaffoldMessenger.of(context);
              final applied = await ref
                  .read(overlayControllerProvider.notifier)
                  .setEnabled(value: value);
              if (!applied) {
                messenger.showSnackBar(
                  const SnackBar(
                      content: Text('需要“显示在应用上层”权限才能开启桌面歌词')),
                );
              }
            },
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.format_size_rounded, size: 22),
                const SizedBox(width: 16),
                Expanded(
                  child: Slider(
                    value: ref.watch(overlayFontSizeProvider),
                    min: minOverlayFontSize,
                    max: maxOverlayFontSize,
                    divisions: 11,
                    label: ref
                        .watch(overlayFontSizeProvider)
                        .toStringAsFixed(0),
                    onChanged: (value) {
                      unawaited(
                        ref
                            .read(overlayFontSizeProvider.notifier)
                            .set(value),
                      );
                      unawaited(
                        ref
                            .read(overlayControllerProvider.notifier)
                            .applyFontSize(value),
                      );
                    },
                  ),
                ),
                SizedBox(
                  width: 36,
                  child: Text(
                    ref
                        .watch(overlayFontSizeProvider)
                        .toStringAsFixed(0),
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
