import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Curated seed colors shown in Settings → 外观.
typedef ThemePalette = ({String name, Color seed});

abstract final class AppTheme {
  static const defaultSeed = Color(0xFFFA2D48);

  static const List<ThemePalette> palettes = <ThemePalette>[
    (name: '樱粉', seed: Color(0xFFFA2D48)),
    (name: '珊瑚', seed: Color(0xFFF4511E)),
    (name: '琥珀', seed: Color(0xFFF9A825)),
    (name: '抹茶', seed: Color(0xFF43A047)),
    (name: '青瓷', seed: Color(0xFF00897B)),
    (name: '晴空', seed: Color(0xFF1E88E5)),
    (name: '黛蓝', seed: Color(0xFF3949AB)),
    (name: '紫藤', seed: Color(0xFF8E24AA)),
    (name: '山茶', seed: Color(0xFFD81B60)),
    (name: '墨青', seed: Color(0xFF546E7A)),
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
