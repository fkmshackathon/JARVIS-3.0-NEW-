import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'auth/auth_bootstrap.dart';
import 'auth/auth_session.dart';
import 'data/assistant_greeting.dart';
import 'screens/account_completion_screen.dart';
import 'screens/firebase_access_screen.dart';
import 'screens/app_shell.dart';
import 'screens/architecture_screen.dart';
import 'screens/generate_timetable_screen.dart';
import 'screens/manual_issues_screen.dart';
import 'screens/setup_screen.dart';
import 'screens/timetable_library_screen.dart';
import 'screens/timetable_operations_screen.dart';
import 'state/assistant_controller.dart';
import 'state/timetable_library_controller.dart';
import 'theme/synchro_theme.dart';
import 'theme/theme_controller.dart';
import 'widgets/app_frame.dart';
import 'widgets/assistant_panel.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(FirebaseAuthBootstrap(builder: (session) => SynchroApp(session: session)));
}

class SynchroApp extends StatefulWidget {
  const SynchroApp({super.key, required this.session});
  final AuthSession session;

  @override
  State<SynchroApp> createState() => _SynchroAppState();
}

class _SynchroAppState extends State<SynchroApp> {
  late final AuthSession _session = widget.session;
  TimetableLibraryController? _library;
  String? _accountUid;
  bool _workspaceReady = false;
  final AssistantController _assistant = AssistantController();
  final AssistantGreeting _greeting = AssistantGreeting();
  final GlobalKey<NavigatorState> _navigator = GlobalKey<NavigatorState>();
  String _page = 'Overview';
  bool _assistantOpen = false;

  @override
  void initState() {
    super.initState();
    _session.addListener(_authChanged);
    _authChanged();
  }

  void _authChanged() {
    final uid = _session.isSignedIn ? _session.user!.uid : null;
    if (uid == _accountUid) return;
    final previous = _library;
    _accountUid = uid;
    _library = null;
    _workspaceReady = false;
    _assistant.clear();
    _assistantOpen = false;
    previous?.dispose();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _accountUid == uid) {
        _navigator.currentState?.popUntil((route) => route.isFirst);
      }
    });
    if (uid != null) {
      final library = TimetableLibraryController(ownerUid: uid);
      _library = library;
      unawaited(library.restore().then((_) {
        if (mounted && identical(_library, library) && _accountUid == uid &&
            _session.isSignedIn) {
          setState(() => _workspaceReady = true);
        }
      }));
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _session.removeListener(_authChanged);
    _library?.dispose();
    _session.dispose();
    _assistant.dispose();
    _greeting.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, mode, _) => MaterialApp(
        title: 'SYNCHRO',
        navigatorKey: _navigator,
        debugShowCheckedModeBanner: false,
        theme: SynchroTheme.light,
        darkTheme: SynchroTheme.dark,
        themeMode: mode,
        builder: (context, child) => ListenableBuilder(
          listenable: _session,
          builder: (context, _) => AppFrame(
            child: Stack(
              children: [
                child ?? const SizedBox.shrink(),
                if (!kIsWeb && _session.isSignedIn && _workspaceReady && !_assistantOpen)
                  Positioned(
                    left: 16,
                    bottom: 92,
                    child: Semantics(
                      label: 'SYNCHRO Assistant',
                      button: true,
                      child: Material(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        elevation: 3,
                        shape: const StadiumBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          key: const Key('assistant-launcher'),
                          onTap: _openAssistant,
                          child: const SizedBox(
                            height: 48,
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.eco_outlined),
                                  SizedBox(width: 6),
                                  Text('Assistant'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        home: ListenableBuilder(
          listenable: _session,
          builder: (context, _) => _authenticationHome(),
        ),
      ),
    );
  }

  Widget _authenticationHome() {
    if (_session.stage == AuthStage.restoring) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_session.stage == AuthStage.profileRequired ||
        _session.stage == AuthStage.verificationRequired) {
      return AccountCompletionScreen(
        key: ValueKey(_session.user?.uid), session: _session,
      );
    }
    if (!_session.isSignedIn) return FirebaseAccessScreen(session: _session);
    final library = _library;
    if (!_workspaceReady || library == null) {
      return const Scaffold(body: Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [CircularProgressIndicator(), SizedBox(height: 16),
          Text('Loading your timetables…')],
      )));
    }
    return AppShell(
      library: library,
      onSignOut: () { unawaited(_session.signOut()); },
      onPageChanged: (page) => _page = page,
    );
  }

  void _openAssistant() {
    final library = _library;
    if (library == null || !_session.isSignedIn || !_workspaceReady) return;
    final context = _navigator.currentState?.overlay?.context;
    if (context == null) return;
    _greeting.play();
    setState(() => _assistantOpen = true);
    showDialog<void>(
      context: context,
      builder: (_) => AssistantPanel(
        assistant: _assistant,
        workspace: library.workspace,
        page: _page,
        onNavigate: _navigateFromAssistant,
      ),
    ).whenComplete(() {
      if (mounted) setState(() => _assistantOpen = false);
    });
  }

  void _navigateFromAssistant(String action) {
    final library = _library;
    if (library == null || !_session.isSignedIn || !_workspaceReady) return;
    final workspace = library.workspace;
    final Widget screen = switch (action) {
      'architecture' => const ArchitectureScreen(),
      'library' => TimetableLibraryScreen(library: library),
      'issues' => _secondary(
        'Issues',
        ManualIssuesScreen(controller: workspace),
      ),
      'changes' => _secondary(
        'Handle a change',
        TimetableOperationsScreen(
          controller: workspace,
          activeTimetableId: () => library.activeId,
        ),
      ),
      'timetable' => _secondary(
        'Timetable',
        GenerateTimetableScreen(controller: workspace),
      ),
      _ => _secondary('Setup', SetupScreen(controller: workspace)),
    };
    _navigator.currentState?.push(
      MaterialPageRoute<void>(
        settings: RouteSettings(name: action),
        builder: (_) => screen,
      ),
    );
  }

  Widget _secondary(String title, Widget body) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: body,
  );
}
