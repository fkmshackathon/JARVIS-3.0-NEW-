import 'package:flutter/material.dart';

import 'screens/splash_screen.dart';
import 'state/scheduling_controller.dart';
import 'theme/synchro_theme.dart';
import 'theme/theme_controller.dart';
import 'widgets/app_frame.dart';

void main() {
  runApp(SynchroApp(controller: SchedulingController()));
}

class SynchroApp extends StatefulWidget {
  const SynchroApp({super.key, required this.controller});

  final SchedulingController controller;

  @override
  State<SynchroApp> createState() => _SynchroAppState();
}

class _SynchroAppState extends State<SynchroApp> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, mode, _) => MaterialApp(
        title: 'SYNCHRO',
        debugShowCheckedModeBanner: false,
        theme: SynchroTheme.light,
        darkTheme: SynchroTheme.dark,
        themeMode: mode,
        builder: (context, child) =>
            AppFrame(child: child ?? const SizedBox.shrink()),
        home: SplashScreen(controller: widget.controller),
      ),
    );
  }
}
