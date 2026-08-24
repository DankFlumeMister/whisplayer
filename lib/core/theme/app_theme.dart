import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Curated seed colors shown in Settings → 外观.
typedef ThemePalette = ({String key, Color seed});

abstract final class AppTheme {
  static const defaultSeed = Color(0xFFFA2D48);

  /// 24 curated seeds spread across the hue wheel (≥15° apart) plus a few
  /// low-chroma neutrals. Same-hue tone variants are deliberately excluded:
  /// Material 3 derives the whole scheme from the seed's hue, so tone-only
  /// variants would render as duplicate themes.
  static const List<ThemePalette> palettes = <ThemePalette>[
    (key: 'sakura', seed: Color(0xFFFA2D48)),
    (key: 'magenta', seed: Color(0xFFF01A96)),
    (key: 'wisteria', seed: Color(0xFF8E24AA)),
    (key: 'deepPurple', seed: Color(0xFF673AB7)),
    (key: 'lavender', seed: Color(0xFFB39DDB)),
    (key: 'iris', seed: Color(0xFF5C6BC0)),
    (key: 'navy', seed: Color(0xFF1A237E)),
    (key: 'sky', seed: Color(0xFF1E88E5)),
    (key: 'lake', seed: Color(0xFF26C6DA)),
    (key: 'celadon', seed: Color(0xFF00897B)),
    (key: 'mint', seed: Color(0xFF00E676)),
    (key: 'matcha', seed: Color(0xFF43A047)),
    (key: 'lime', seed: Color(0xFFCDDC39)),
    (key: 'olive', seed: Color(0xFF9E9D24)),
    (key: 'lemon', seed: Color(0xFFFDD835)),
    (key: 'brown', seed: Color(0xFF795548)),
    (key: 'orange', seed: Color(0xFFFF9800)),
    (key: 'coral', seed: Color(0xFFF4511E)),
    (key: 'peach', seed: Color(0xFFFF8A65)),
    (key: 'red', seed: Color(0xFFF44336)),
    (key: 'wine', seed: Color(0xFF722F37)),
    (key: 'roseGold', seed: Color(0xFFB76E79)),
    (key: 'blueGrey', seed: Color(0xFF607D8B)),
    (key: 'grey', seed: Color(0xFF9E9E9E)),
  ];

  static ThemeData light({Color seed = defaultSeed}) =>
      _build(Brightness.light, seed);

  static ThemeData dark({Color seed = defaultSeed}) =>
      _build(Brightness.dark, seed);

  static ThemeData _build(Brightness brightness, Color seed) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      visualDensity: VisualDensity.comfortable,
      splashFactory: NoSplash.splashFactory,
      highlightColor: scheme.onSurface.withValues(alpha: 0.04),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
          TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scheme.surface,
        titleTextStyle: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: scheme.onSurface,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.secondaryContainer,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      sliderTheme: const SliderThemeData(
        trackHeight: 4,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 7),
        overlayShape: RoundSliderOverlayShape(overlayRadius: 16),
      ),
      listTileTheme: ListTileThemeData(iconColor: scheme.primary),
    );
  }
}
