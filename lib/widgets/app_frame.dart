import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Centres the app in a phone-width canvas when it runs on web or desktop, and
/// disappears entirely on a real handset. Demoing on a laptop should not stretch a
/// layout designed for one hand.
class AppFrame extends StatelessWidget {
  const AppFrame({super.key, required this.child});

  final Widget child;

  static const double _breakpoint = 720;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    if (size.width <= _breakpoint) return child;

    final width = math.max(240.0, math.min(SynchroLayout.phoneWidth, size.width - SynchroSpacing.xl * 2));
    final height = math.max(360.0, math.min(SynchroLayout.phoneHeight, size.height - SynchroSpacing.xl * 2));

    return ColoredBox(
      color: SynchroColors.navyDeep,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: SizedBox(width: width, height: height, child: child),
        ),
      ),
    );
  }
}
