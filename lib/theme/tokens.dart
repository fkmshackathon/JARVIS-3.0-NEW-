import 'package:flutter/material.dart';

/// SYNCHRO design tokens.
///
/// Buildasaur Round 2: restrained botanical surfaces with high-contrast forest
/// actions. Legacy colour names remain aliases so existing widgets share the
/// new identity without rewriting timetable business logic.
abstract final class SynchroColors {
  static const Color forest = Color(0xFF176B45);
  static const Color deepGreen = Color(0xFF104C35);
  static const Color leaf = Color(0xFF39A96B);
  static const Color mint = Color(0xFFE7F5E9);
  static const Color natural = Color(0xFFF5F8EF);
  static const Color navy = forest;
  static const Color navyDeep = deepGreen;
  static const Color navySoft = Color(0xFF28734F);
  static const Color cream = mint;
  static const Color creamPale = natural;
  static const Color orange = Color(0xFFB3E9BE);
  static const Color orangeDeep = forest;

  static const Color ink = Color(0xFF17251C);
  static const Color inkMuted = Color(0xFF5B6D60);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceQuiet = Color(0xFFEEF5E9);
  static const Color hairline = Color(0xFFD8E5D7);
  static const Color outer = Color(0xFFE8EEE1);

  static const Color ok = Color(0xFF218653);
  static const Color warn = Color(0xFF946011);
  static const Color danger = Color(0xFFC93C3C);

  /// The three verdict tones above are legible on cream but sink into navy, so the
  /// dark scheme lifts the same hues rather than reusing them.
  static const Color okOnNavy = Color(0xFF63D9A0);
  static const Color warnOnNavy = Color(0xFFFFC46B);
  static const Color dangerOnNavy = Color(0xFFFF8A80);

  static const Color onNavy = Color(0xFFFFFFFF);
  static const Color onNavyMuted = Color(0xFFC9E9D4);
}

abstract final class SynchroSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double gutter = 20;
}

abstract final class SynchroRadius {
  static const double chip = 8;
  static const double card = 14;
  static const double sheet = 22;
  static const double pill = 999;
}

abstract final class SynchroMotion {
  /// Branded launch only. Anything on the path to a timetable stays under 400ms.
  static const Duration splash = Duration(milliseconds: 1500);
  static const Duration quick = Duration(milliseconds: 160);
  static const Duration standard = Duration(milliseconds: 260);
  static const Duration settle = Duration(milliseconds: 420);
  static const Curve emphasis = Curves.easeOutCubic;
  static const Curve entrance = Curves.easeOutQuart;
}

/// One phone-width canvas. Below this the layout must simply fit.
abstract final class SynchroLayout {
  static const double phoneWidth = 430;
  static const double phoneHeight = 932;
  static const double compactWidth = 340;
}

abstract final class SynchroType {
  static const double display = 32;
  static const double title = 22;
  static const double section = 17;
  static const double body = 15;
  static const double label = 13;
  static const double micro = 11;

  static const double tracking = 0.4;
  static const double overlineTracking = 1.6;
}
