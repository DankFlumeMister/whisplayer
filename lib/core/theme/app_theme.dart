import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Curated seed colors shown in Settings → 外观.
typedef ThemePalette = ({String name, Color seed});

abstract final class AppTheme {
  static const defaultSeed = Color(0xFFFA2D48);

  /// 24 curated seeds spread across the hue wheel (≥15° apart) plus a few
  /// low-chroma neutrals. Same-hue tone variants are deliberately excluded:
  /// Material 3 derives the whole scheme from the seed's hue, so tone-only
  /// variants would render as duplicate themes.
  static const List<ThemePalette> palettes = <ThemePalette>[
    (name: '樱粉', seed: Color(0xFFFA2D48)),
    (name: '品红', seed: Color(0xFFF01A96)),
    (name: '紫藤', seed: Color(0xFF8E24AA)),
    (name: '深紫', seed: Color(0xFF673AB7)),
    (name: '雾紫', seed: Color(0xFFB39DDB)),
    (name: '鸢尾', seed: Color(0xFF5C6BC0)),
    (name: '藏青', seed: Color(0xFF1A237E)),
    (name: '晴空', seed: Color(0xFF1E88E5)),
    (name: '湖水', seed: Color(0xFF26C6DA)),
    (name: '青瓷', seed: Color(0xFF00897B)),
    (name: '亮绿', seed: Color(0xFF00E676)),
    (name: '抹茶', seed: Color(0xFF43A047)),
    (name: '青柠', seed: Color(0xFFCDDC39)),
    (name: '橄榄', seed: Color(0xFF9E9D24)),
    (name: '柠黄', seed: Color(0xFFFDD835)),
    (name: '棕咖', seed: Color(0xFF795548)),
    (name: '橙', seed: Color(0xFFFF9800)),
    (name: '珊瑚', seed: Color(0xFFF4511E)),
    (name: '蜜桃', seed: Color(0xFFFF8A65)),
    (name: '正红', seed: Color(0xFFF44336)),
    (name: '酒红', seed: Color(0xFF722F37)),
    (name: '玫瑰金', seed: Color(0xFFB76E79)),
    (name: '蓝灰', seed: Color(0xFF607D8B)),
    (name: '灰', seed: Color(0xFF9E9E9E)),
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
