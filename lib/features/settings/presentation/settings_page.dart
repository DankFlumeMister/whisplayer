import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:whisplayer/core/locale/language_controller.dart';
import 'package:whisplayer/core/providers/repository_providers.dart';
import 'package:whisplayer/core/providers/startup_tab_provider.dart';
import 'package:whisplayer/features/settings/application/overlay_controller.dart';
import 'package:whisplayer/features/settings/application/theme_font_size.dart';
import 'package:whisplayer/l10n/app_localizations.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(languageControllerProvider).locale;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(title: Text(l10n.settingsTitle)),
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
                  title: Text(l10n.appearanceEntry),
                  subtitle: Text(l10n.appearanceSubtitle),
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
                  leading: const Icon(Icons.language_rounded),
                  title: Text(l10n.languageEntry),
                  subtitle: Text(_languageName(l10n, locale)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showLanguageDialog(context, ref),
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
                child: const _StartupTabCard(),
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
                  title: Text(l10n.scanEntry),
                  subtitle: Text(l10n.scanSubtitle),
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
                  title: Text(l10n.statsEntry),
                  subtitle: Text(l10n.statsSubtitle),
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
                  title: Text(l10n.remoteServersEntry),
                  subtitle: Text(l10n.remoteServersSubtitle),
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

  static String _languageName(AppLocalizations l10n, Locale? locale) {
    if (locale == null) {
      return l10n.languageFollowSystem;
    }
    return switch (locale.toLanguageTag()) {
      'zh' => l10n.languageZhHans,
      'zh-TW' => l10n.languageZhHant,
      'ja' => l10n.languageJa,
      'ko' => l10n.languageKo,
      'en' => l10n.languageEn,
      _ => l10n.languageFollowSystem,
    };
  }

  Future<void> _showLanguageDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = AppLocalizations.of(context);
    final current = ref.read(languageControllerProvider).locale;
    final options = <(Locale?, String)>[
      (null, l10n.languageFollowSystem),
      (const Locale('zh'), l10n.languageZhHans),
      (const Locale('zh', 'TW'), l10n.languageZhHant),
      (const Locale('ja'), l10n.languageJa),
      (const Locale('ko'), l10n.languageKo),
      (const Locale('en'), l10n.languageEn),
    ];
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(l10n.languageEntry),
        children: [
          RadioGroup<Locale?>(
            groupValue: current,
            onChanged: (value) async {
              await ref
                  .read(languageControllerProvider.notifier)
                  .setLocale(value);
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
            },
            child: Column(
              children: [
                for (final (locale, name) in options)
                  RadioListTile<Locale?>(
                    value: locale,
                    title: Text(name),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StartupTabCard extends ConsumerStatefulWidget {
  const _StartupTabCard();

  @override
  ConsumerState<_StartupTabCard> createState() =>
      _StartupTabCardState();
}

class _StartupTabCardState extends ConsumerState<_StartupTabCard> {
  String _value = 'local';

  @override
  void initState() {
    super.initState();
    scheduleMicrotask(_restore);
  }

  Future<void> _restore() async {
    try {
      final saved = await ref
          .read(settingsRepositoryProvider)
          .getString(keyStartupTab);
      if (!mounted || saved == null || saved == _value) {
        return;
      }
      setState(() => _value = saved);
    } on Exception catch (_) {
      // Settings storage unavailable - keep the default.
    }
  }

  Future<void> _showPickSheet(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final options = <(String, String)>[
      ('local', l10n.localTab),
      ('cloud', l10n.cloudTab),
    ];
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (value, label) in options)
              ListTile(
                title: Text(label),
                trailing:
                    _value == value ? const Icon(Icons.check) : null,
                onTap: () {
                  unawaited(
                    ref
                        .read(settingsRepositoryProvider)
                        .setString(keyStartupTab, value),
                  );
                  setState(() => _value = value);
                  Navigator.pop(sheetContext);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        leading: const Icon(Icons.rocket_launch_outlined),
        title: Text(l10n.startupPage),
        subtitle: Text(_value == 'cloud' ? l10n.cloudTab : l10n.localTab),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => unawaited(_showPickSheet(context)),
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
    final l10n = AppLocalizations.of(context);
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
            title: Text(l10n.desktopLyricsEntry),
            subtitle: Text(enabled
                ? l10n.desktopLyricsOn
                : l10n.desktopLyricsOff),
            value: enabled,
            onChanged: (value) async {
              final messenger = ScaffoldMessenger.of(context);
              final applied = await ref
                  .read(overlayControllerProvider.notifier)
                  .setEnabled(value: value);
              if (!applied) {
                messenger.showSnackBar(
                  SnackBar(content: Text(l10n.desktopLyricsPermission)),
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
