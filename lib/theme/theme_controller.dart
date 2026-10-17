import 'package:flutter/material.dart';

/// A single notifier so any screen can flip the theme without threading callbacks
/// through every constructor. Navy-on-cream is the default; the dark scheme inverts
/// the page, not the identity.
final ValueNotifier<ThemeMode> appThemeMode = ValueNotifier<ThemeMode>(
  ThemeMode.light,
);

ThemeMode toggleTheme(ThemeMode current) =>
    current == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
