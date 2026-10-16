import 'package:flutter/material.dart';

/// SYNCHRO design tokens.
///
/// Navy is the identity, cream is the page, orange is only ever an action or an
/// important signal — the moment orange decorates, it stops meaning "do this".
abstract final class SynchroColors {
  static const Color navy = Color(0xFF0D2B60);
  static const Color navyDeep = Color(0xFF081C40);
  static const Color navySoft = Color(0xFF1B3D76);
  static const Color cream = Color(0xFFFFF0C7);
  static const Color creamPale = Color(0xFFFBF6E7);
  static const Color orange = Color(0xFFFF8A32);
  static const Color orangeDeep = Color(0xFFE2671A);

  static const Color ink = Color(0xFF101828);
  static const Color inkMuted = Color(0xFF55618A);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceQuiet = Color(0xFFF6F3EA);
  static const Color hairline = Color(0xFFE2DCC9);

  static const Color ok = Color(0xFF1F7A4D);
  static const Color warn = Color(0xFFB4790A);
  static const Color danger = Color(0xFFB42318);

  /// The three verdict tones above are legible on cream but sink into navy, so the
  /// dark scheme lifts the same hues rather than reusing them.
  static const Color okOnNavy = Color(0xFF63D9A0);
  static const Color warnOnNavy = Color(0xFFFFC46B);
  static const Color dangerOnNavy = Color(0xFFFF8A80);

  static const Color onNavy = Color(0xFFF7F4EC);
  static const Color onNavyMuted = Color(0xFFA9B6D6);
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
