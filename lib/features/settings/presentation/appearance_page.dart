import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:whisplayer/core/theme/app_theme.dart';
import 'package:whisplayer/core/theme/theme_controller.dart';
import 'package:whisplayer/l10n/app_localizations.dart';

String _paletteName(AppLocalizations l10n, String key) {
  return switch (key) {
    'sakura' => l10n.colorSakura,
    'magenta' => l10n.colorMagenta,
    'wisteria' => l10n.colorWisteria,
    'deepPurple' => l10n.colorDeepPurple,
    'lavender' => l10n.colorLavender,
    'iris' => l10n.colorIris,
    'navy' => l10n.colorNavy,
    'sky' => l10n.colorSky,
    'lake' => l10n.colorLake,
    'celadon' => l10n.colorCeladon,
    'mint' => l10n.colorMint,
    'matcha' => l10n.colorMatcha,
    'lime' => l10n.colorLime,
    'olive' => l10n.colorOlive,
    'lemon' => l10n.colorLemon,
    'brown' => l10n.colorBrown,
    'orange' => l10n.colorOrange,
    'coral' => l10n.colorCoral,
    'peach' => l10n.colorPeach,
    'red' => l10n.colorRed,
    'wine' => l10n.colorWine,
    'roseGold' => l10n.colorRoseGold,
    'blueGrey' => l10n.colorBlueGrey,
    'grey' => l10n.colorGrey,
    _ => key,
  };
}

class AppearancePage extends ConsumerWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeControllerProvider);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appearanceTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
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
                    l10n.themeModeLabel,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<ThemeMode>(
                    segments: [
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text(l10n.themeModeFollowSystem),
                        icon: const Icon(Icons.brightness_auto_outlined),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text(l10n.themeModeLight),
                        icon: const Icon(Icons.light_mode_outlined),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text(l10n.themeModeDark),
                        icon: const Icon(Icons.dark_mode_outlined),
                      ),
                    ],
                    selected: {theme.mode},
                    onSelectionChanged: (selection) {
                      unawaited(
                        ref
                            .read(themeControllerProvider.notifier)
                            .setMode(selection.first),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
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
                     l10n.themeColorLabel,
                     style: Theme.of(context).textTheme.titleMedium,
                   ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.themeColorHint,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final palette in AppTheme.palettes)
                        _SeedSwatch(
                          palette: palette,
                          selected:
                              palette.seed.toARGB32() ==
                                  theme.seed.toARGB32(),
                          onTap: () => unawaited(
                            ref
                                .read(themeControllerProvider.notifier)
                                .setSeed(palette.seed),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SeedSwatch extends StatelessWidget {
  const _SeedSwatch({
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  final ThemePalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final onSeed =
        ThemeData.estimateBrightnessForColor(palette.seed) == Brightness.dark
            ? Colors.white
            : Colors.black87;
    return Tooltip(
      message: _paletteName(AppLocalizations.of(context), palette.key),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: palette.seed,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).colorScheme.outlineVariant,
              width: selected ? 3 : 1,
            ),
          ),
          child: selected
              ? Icon(Icons.check_rounded, size: 22, color: onSeed)
              : null,
        ),
      ),
    );
  }
}
