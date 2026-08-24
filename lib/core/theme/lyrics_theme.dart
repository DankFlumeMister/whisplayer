import 'package:flutter/material.dart';

class LyricsTheme extends ThemeExtension<LyricsTheme> {
  const LyricsTheme({
    this.activeColor,
    this.inactiveColor,
    this.activeFontSize = 22,
    this.inactiveFontSize = 18,
    this.lineSpacing = 34,
  });

  final Color? activeColor;
  final Color? inactiveColor;
  final double activeFontSize;
  final double inactiveFontSize;
  final double lineSpacing;

  @override
  LyricsTheme copyWith({
    Color? activeColor,
    Color? inactiveColor,
    double? activeFontSize,
    double? inactiveFontSize,
    double? lineSpacing,
  }) {
    return LyricsTheme(
      activeColor: activeColor ?? this.activeColor,
      inactiveColor: inactiveColor ?? this.inactiveColor,
      activeFontSize: activeFontSize ?? this.activeFontSize,
      inactiveFontSize: inactiveFontSize ?? this.inactiveFontSize,
      lineSpacing: lineSpacing ?? this.lineSpacing,
    );
  }

  @override
  LyricsTheme lerp(ThemeExtension<LyricsTheme>? other, double t) {
    if (other is! LyricsTheme) {
      return this;
    }
    return LyricsTheme(
      activeColor: Color.lerp(activeColor, other.activeColor, t),
      inactiveColor:
          Color.lerp(inactiveColor, other.inactiveColor, t),
      activeFontSize:
          activeFontSize + (other.activeFontSize - activeFontSize) * t,
      inactiveFontSize: inactiveFontSize +
          (other.inactiveFontSize - inactiveFontSize) * t,
      lineSpacing:
          lineSpacing + (other.lineSpacing - lineSpacing) * t,
    );
  }
}
