import 'package:flutter/material.dart';

import 'screens/access_screen.dart';
import 'screens/app_shell.dart';
import 'state/demo_session.dart';
import 'state/manual_timetable_controller.dart';
import 'theme/synchro_theme.dart';
import 'theme/theme_controller.dart';
import 'widgets/app_frame.dart';

void main() {
  runApp(const SynchroApp());
}

class SynchroApp extends StatefulWidget {
  const SynchroApp({super.key});

  @override
  State<SynchroApp> createState() => _SynchroAppState();
}

class _SynchroAppState extends State<SynchroApp> {
  final DemoSession _session = DemoSession();
  final ManualTimetableController _controller = ManualTimetableController();

  @override
  void initState() {
    super.initState();
    _controller.restoreDraft();
  }

  @override
  void dispose() {
    _controller.dispose();
    _session.dispose();
    super.dispose();
  }

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
        home: ListenableBuilder(
          listenable: _session,
          builder: (context, _) => _session.isSignedIn
              ? AppShell(controller: _controller, onSignOut: _session.signOut)
              : AccessScreen(session: _session, onAuthenticated: () {}),
        ),
      ),
    );
  }
}
