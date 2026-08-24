import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:whisplayer/core/theme/theme_controller.dart';
import 'package:whisplayer/features/settings/application/overlay_controller.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeControllerProvider);
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
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '外观',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment(
                            value: ThemeMode.system,
                            label: Text('跟随系统'),
                            icon: Icon(Icons.brightness_auto_outlined),
                          ),
                          ButtonSegment(
                            value: ThemeMode.light,
                            label: Text('浅色'),
                            icon: Icon(Icons.light_mode_outlined),
                          ),
                          ButtonSegment(
                            value: ThemeMode.dark,
                            label: Text('深色'),
                            icon: Icon(Icons.dark_mode_outlined),
                          ),
                        ],
                        selected: {mode},
                        onSelectionChanged: (selection) {
                          ref
                              .read(themeControllerProvider.notifier)
                              .themeMode = selection.first;
                        },
                      ),
                    ],
                  ),
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
      child: SwitchListTile(
        secondary: const Icon(Icons.lyrics_outlined),
        title: const Text('桌面歌词'),
        subtitle: Text(enabled ? '已开启，可在其他应用上方显示' : '在其他应用上方显示当前歌词行'),
        value: enabled,
        onChanged: (value) async {
          final messenger = ScaffoldMessenger.of(context);
          final applied = await ref
              .read(overlayControllerProvider.notifier)
              .setEnabled(value: value);
          if (!applied) {
            messenger.showSnackBar(
              const SnackBar(content: Text('需要“显示在应用上层”权限才能开启桌面歌词')),
            );
          }
        },
      ),
    );
  }
}
