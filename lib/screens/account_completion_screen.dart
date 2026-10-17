import 'package:flutter/material.dart';

import '../auth/auth_models.dart';
import '../auth/auth_session.dart';
import '../widgets/ui.dart';
import 'firebase_access_screen.dart';

class AccountCompletionScreen extends StatefulWidget {
  const AccountCompletionScreen({super.key, required this.session});
  final AuthSession session;

  @override
  State<AccountCompletionScreen> createState() => _AccountCompletionScreenState();
}

class _AccountCompletionScreenState extends State<AccountCompletionScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _college;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.session.profile?.displayName ??
      widget.session.user?.displayName ?? '');
    _college = TextEditingController(text: widget.session.profile?.collegeName ?? '');
  }

  @override
  void dispose() {
    _name.clear(); _college.clear();
    _name.dispose(); _college.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    await widget.session.completeProfile(AuthProfile(
      displayName: _name.text, collegeName: _college.text,
    ));
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final session = widget.session;
      final needsProfile = session.stage == AuthStage.profileRequired;
      return AuthPage(
        title: needsProfile ? 'Complete your profile' : 'Verify your email',
        subtitle: session.user?.email,
        child: SectionCard(
          title: needsProfile ? 'Name and college' : 'Check your inbox',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            AuthFeedback(session: session),
            if (needsProfile) Form(
              key: _form,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('Confirm your name and college. College information stays on this device, scoped to your Firebase account.'),
                const SizedBox(height: 16),
                AuthProfileFields(name: _name, college: _college, enabled: !session.busy),
                FilledButton(
                  key: const Key('auth-profile-submit'),
                  onPressed: session.busy ? null : _save,
                  child: const Text('Save profile'),
                ),
              ]),
            ) else ...[
              const Text('Open the verification email from Firebase, then return here. An unverified email account cannot enter the workspace.'),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('auth-refresh-verification'),
                onPressed: session.busy ? null : session.refreshVerification,
                child: const Text('I verified my email'),
              ),
              TextButton(
                onPressed: session.busy ? null : session.resendVerification,
                child: const Text('Resend verification email'),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton(
              key: const Key('auth-sign-out'),
              onPressed: session.busy ? null : session.signOut,
              child: const Text('Use another account'),
            ),
            if (session.busy) const LinearProgressIndicator(),
          ]),
        ),
      );
    },
  );
}
