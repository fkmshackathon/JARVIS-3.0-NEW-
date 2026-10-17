import 'dart:async';

import 'package:flutter/material.dart';

import '../screens/firebase_access_screen.dart';
import '../theme/synchro_theme.dart';
import '../widgets/ui.dart';
import 'auth_models.dart';
import 'auth_session.dart';
import 'firebase_auth_repository.dart';
import 'firebase_configuration.dart';
import 'local_profile_store.dart';

class FirebaseAuthBootstrap extends StatefulWidget {
  const FirebaseAuthBootstrap({super.key, required this.builder});
  final Widget Function(AuthSession session) builder;

  @override
  State<FirebaseAuthBootstrap> createState() => _FirebaseAuthBootstrapState();
}

class _FirebaseAuthBootstrapState extends State<FirebaseAuthBootstrap> {
  late Future<AuthSession> _initialization;
  AuthSession? _session;

  @override
  void initState() {
    super.initState();
    _initialization = _initialize();
  }

  Future<AuthSession> _initialize() async {
    await FirebaseConfiguration.initialize().timeout(const Duration(seconds: 25));
    final repository = await FirebaseAuthRepository.create().timeout(const Duration(seconds: 15));
    final session = AuthSession(repository: repository, profiles: LocalProfileStore());
    if (!mounted) {
      session.dispose();
      throw const AuthFailure('session-changed');
    }
    _session = session;
    return session;
  }

  @override
  void dispose() {
    _session?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<AuthSession>(
    future: _initialization,
    builder: (context, snapshot) {
      if (snapshot.hasData) return widget.builder(snapshot.data!);
      final pending = snapshot.connectionState != ConnectionState.done;
      final error = snapshot.error;
      final message = error is AuthFailure ? error.message
          : error is TimeoutException ? const AuthFailure('timeout').message
          : 'Firebase could not initialize. Check the platform configuration and internet connection.';
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: SynchroTheme.light, darkTheme: SynchroTheme.dark,
        home: AuthPage(
          title: pending ? 'Connecting securely…' : 'Firebase setup required',
          child: pending ? const Center(child: CircularProgressIndicator())
              : SectionCard(title: 'Authentication is not ready', child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Notice(text: message, tone: Tone.bad),
                  const Text('Web: provide the Firebase Web app configuration using '
                    '--dart-define-from-file=firebase.web.json. An Android app ID cannot be used for Web.'),
                  const SizedBox(height: 12),
                  const Text('Android: register com.synchro.synchro in the Firebase project '
                    'and add its matching android/app/google-services.json.'),
                  const SizedBox(height: 12),
                  const Text('Enable Email/Password and Google in Firebase Authentication. '
                    'Authorize localhost for local web sign-in. There is no demo-login fallback.'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => setState(() => _initialization = _initialize()),
                    child: const Text('Retry Firebase initialization'),
                  ),
                ],
              )),
        ),
      );
    },
  );
}
