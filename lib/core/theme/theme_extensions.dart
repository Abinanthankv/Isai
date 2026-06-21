import 'package:flutter/material.dart';

extension ThemeColors on BuildContext {
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  Color get accentColor => colorScheme.primary;
  Color get accentGradientEnd => colorScheme.secondary;
  List<Color> get accentGradient => [colorScheme.primary, colorScheme.secondary];
}
