import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Full-height responsive workspace; desktops are no longer squeezed into a
/// phone mockup. A bounded wide canvas keeps schedules and forms readable.
class AppFrame extends StatelessWidget {
  const AppFrame({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: SynchroColors.outer,
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1600),
        child: child,
      ),
    ),
  );
}
