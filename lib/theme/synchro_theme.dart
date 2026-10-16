import 'package:flutter/material.dart';

import 'tokens.dart';

/// Material 3 surfaces assembled from [SynchroColors] rather than a generated seed,
/// because a seeded scheme drifts toward violet and the brand is navy on cream.
abstract final class SynchroTheme {
  static ThemeData get light {
    const scheme = ColorScheme.light(
      primary: SynchroColors.navy,
      onPrimary: SynchroColors.onNavy,
      primaryContainer: SynchroColors.cream,
      onPrimaryContainer: SynchroColors.navyDeep,
      secondary: SynchroColors.orange,
      onSecondary: SynchroColors.navyDeep,
      secondaryContainer: SynchroColors.creamPale,
      onSecondaryContainer: SynchroColors.orangeDeep,
      tertiary: SynchroColors.navySoft,
      surface: SynchroColors.surface,
      onSurface: SynchroColors.ink,
      surfaceContainerLowest: SynchroColors.surface,
      surfaceContainerLow: SynchroColors.creamPale,
      surfaceContainer: SynchroColors.surfaceQuiet,
      outline: SynchroColors.hairline,
      outlineVariant: SynchroColors.hairline,
      error: SynchroColors.danger,
    );

    return _base(scheme, SynchroColors.creamPale).copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: SynchroColors.creamPale,
        foregroundColor: SynchroColors.navyDeep,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: SynchroColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SynchroRadius.card),
          side: const BorderSide(color: SynchroColors.hairline),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: SynchroColors.surface,
        indicatorColor: SynchroColors.cream,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
    );
  }

  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: SynchroColors.cream,
      onPrimary: SynchroColors.navyDeep,
      primaryContainer: SynchroColors.navySoft,
      onPrimaryContainer: SynchroColors.cream,
      secondary: SynchroColors.orange,
      onSecondary: SynchroColors.navyDeep,
      surface: SynchroColors.navyDeep,
      onSurface: SynchroColors.onNavy,
      surfaceContainerLowest: Color(0xFF061634),
      surfaceContainerLow: Color(0xFF0A2048),
      surfaceContainer: SynchroColors.navy,
      outline: SynchroColors.navySoft,
      outlineVariant: SynchroColors.navySoft,
      error: Color(0xFFFF8A80),
    );

    return _base(scheme, SynchroColors.navyDeep).copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: SynchroColors.navyDeep,
        foregroundColor: SynchroColors.cream,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: SynchroColors.navy,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SynchroRadius.card),
          side: const BorderSide(color: SynchroColors.navySoft),
        ),
      ),
      dividerTheme: const DividerThemeData(color: SynchroColors.navySoft, thickness: 1, space: 1),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: SynchroColors.navy,
        indicatorColor: SynchroColors.navySoft,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
    );
  }

  static ThemeData _base(ColorScheme scheme, Color scaffold) {
    final text = TextTheme(
      displaySmall: _style(SynchroType.display, FontWeight.w700, scheme.onSurface,
          letterSpacing: -0.4, height: 1.1),
      headlineSmall: _style(SynchroType.title, FontWeight.w700, scheme.onSurface, height: 1.2),
      titleMedium: _style(SynchroType.section, FontWeight.w600, scheme.onSurface),
      titleSmall: _style(SynchroType.label, FontWeight.w700, scheme.onSurface),
      bodyLarge: _style(SynchroType.body + 1, FontWeight.w400, scheme.onSurface, height: 1.45),
      bodyMedium: _style(SynchroType.body, FontWeight.w400, scheme.onSurface, height: 1.45),
      bodySmall: _style(SynchroType.label, FontWeight.w400, scheme.onSurfaceVariant, height: 1.4),
      labelLarge: _style(SynchroType.label, FontWeight.w700, scheme.onPrimary),
      labelMedium: _style(SynchroType.label, FontWeight.w600, scheme.onSurface),
      labelSmall: _style(SynchroType.micro, FontWeight.w700, scheme.onSurfaceVariant,
          letterSpacing: SynchroType.overlineTracking),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      textTheme: text,
      splashFactory: InkRipple.splashFactory,
      visualDensity: VisualDensity.standard,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: SynchroColors.navy,
          foregroundColor: SynchroColors.onNavy,
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: SynchroSpacing.xl),
          textStyle: _style(SynchroType.body, FontWeight.w700, SynchroColors.onNavy),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SynchroRadius.card)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          minimumSize: const Size(0, 46),
          side: BorderSide(color: scheme.outline),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SynchroRadius.card)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle: _style(SynchroType.label, FontWeight.w600, scheme.onSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SynchroRadius.chip)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.outlineVariant,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: SynchroColors.navyDeep,
        contentTextStyle: _style(SynchroType.label, FontWeight.w500, SynchroColors.onNavy),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SynchroRadius.chip)),
      ),
    );
  }

  static TextStyle _style(
    double size,
    FontWeight weight,
    Color color, {
    double letterSpacing = SynchroType.tracking,
    double height = 1.25,
  }) =>
      TextStyle(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );
}
