import 'package:flutter/material.dart';

import '../auth/auth_models.dart';
import '../auth/auth_session.dart';
import '../brand/synchro_mark.dart';
import '../widgets/ui.dart';

/// Production access: only SDK authentication can open the workspace.
class FirebaseAccessScreen extends StatefulWidget {
  const FirebaseAccessScreen({super.key, required this.session});
  final AuthSession session;

  @override
  State<FirebaseAccessScreen> createState() => _FirebaseAccessScreenState();
}

class _FirebaseAccessScreenState extends State<FirebaseAccessScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _college = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _creating = false;
  bool _obscure = true;
  bool _submitted = false;

  @override
  void dispose() {
    for (final controller in [_name, _college, _email, _password, _confirm]) {
      controller.clear();
      controller.dispose();
    }
    super.dispose();
  }

  AuthProfile get _profile => AuthProfile(
    displayName: _name.text, collegeName: _college.text,
  );

  Future<void> _submit() async {
    if (widget.session.busy) return;
    setState(() => _submitted = true);
    if (!(_form.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    if (_creating) {
      await widget.session.signUp(email: _email.text.trim(),
        password: _password.text, profile: _profile);
    } else {
      await widget.session.signIn(email: _email.text.trim(),
        password: _password.text, profile: _profile);
    }
    if (mounted && widget.session.user != null) {
      _password.clear();
      _confirm.clear();
    }
  }

  void _google() {
    if (widget.session.busy) return;
    // Do not validate email/password or await other work before the popup.
    widget.session.signInWithGoogle(profile: _profile.isValid ? _profile : null);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final session = widget.session;
      return AuthPage(
        title: 'Welcome to SYNCHRO.',
        subtitle: 'Plan smarter. Build better timetables.',
        child: SectionCard(
          overline: 'ACCOUNT', title: _creating ? 'Create account' : 'Sign in',
          child: Form(
            key: _form,
            autovalidateMode: _submitted ? AutovalidateMode.onUserInteraction
                : AutovalidateMode.disabled,
            child: AutofillGroup(child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Sign in')),
                    ButtonSegment(value: true, label: Text('Sign up')),
                  ], selected: {_creating}, showSelectedIcon: false,
                  onSelectionChanged: session.busy ? null : (selection) {
                    setState(() { _creating = selection.first; _submitted = false; });
                    _password.clear(); _confirm.clear();
                  },
                ),
                const SizedBox(height: 16),
                Text(_creating
                    ? 'Create a Firebase account. Verify your email before entering the workspace.'
                    : 'Sign in with your registered email and password. All fields are required.'),
                const SizedBox(height: 16),
                AuthFeedback(session: session),
                AuthProfileFields(name: _name, college: _college, enabled: !session.busy),
                TextFormField(
                  key: const Key('access-email-field'), controller: _email,
                  enabled: !session.busy, keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.username, AutofillHints.email],
                  decoration: const InputDecoration(labelText: 'Email address',
                    prefixIcon: Icon(Icons.alternate_email)),
                  validator: AuthValidators.email,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('access-password-field'), controller: _password,
                  enabled: !session.busy, obscureText: _obscure,
                  enableSuggestions: false, autocorrect: false,
                  textInputAction: _creating ? TextInputAction.next : TextInputAction.done,
                  autofillHints: [_creating ? AutofillHints.newPassword : AutofillHints.password],
                  decoration: InputDecoration(labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      tooltip: _obscure ? 'Show password' : 'Hide password',
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    )),
                  validator: (value) => AuthValidators.password(value, creatingAccount: _creating),
                  onFieldSubmitted: _creating ? null : (_) => _submit(),
                ),
                if (_creating) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('auth-confirm-password'), controller: _confirm,
                    enabled: !session.busy, obscureText: _obscure,
                    enableSuggestions: false, autocorrect: false,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: const InputDecoration(labelText: 'Confirm password',
                      prefixIcon: Icon(Icons.lock_outline)),
                    validator: (value) => value == _password.text && (value?.isNotEmpty ?? false)
                        ? null : 'Passwords must match.',
                    onFieldSubmitted: (_) => _submit(),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('access-submit-button'),
                  onPressed: session.busy ? null : _submit,
                  child: Text(_creating ? 'Create account' : 'Sign in'),
                ),
                TextButton(
                  key: const Key('auth-reset-password'),
                  onPressed: session.busy ? null : () => session.sendPasswordReset(_email.text),
                  child: const Text('Forgot password?'),
                ),
                const Divider(),
                OutlinedButton(
                  key: const Key('auth-google-button'),
                  onPressed: session.busy ? null : _google,
                  child: const Text('Continue with Google'),
                ),
                if (session.busy) const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(),
                ),
              ],
            )),
          ),
        ),
      );
    },
  );
}

class AuthProfileFields extends StatelessWidget {
  const AuthProfileFields({super.key, required this.name,
    required this.college, required this.enabled});
  final TextEditingController name;
  final TextEditingController college;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Column(children: [
    TextFormField(
      key: const Key('access-name-field'), controller: name, enabled: enabled,
      keyboardType: TextInputType.name, textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.next, autofillHints: const [AutofillHints.name],
      decoration: const InputDecoration(labelText: 'Full name',
        prefixIcon: Icon(Icons.person_outline)),
      validator: AuthValidators.name,
    ),
    const SizedBox(height: 12),
    TextFormField(
      key: const Key('access-college-field'), controller: college, enabled: enabled,
      textCapitalization: TextCapitalization.words, textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.organizationName],
      decoration: const InputDecoration(labelText: 'College name',
        prefixIcon: Icon(Icons.school_outlined)),
      validator: AuthValidators.college,
    ),
    const SizedBox(height: 12),
  ]);
}

class AuthFeedback extends StatelessWidget {
  const AuthFeedback({super.key, required this.session});
  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    final text = session.error ?? session.info;
    if (text == null) return const SizedBox.shrink();
    return Semantics(
      liveRegion: true,
      child: Notice(text: text, tone: session.error != null ? Tone.bad : Tone.good),
    );
  }
}

class AuthPage extends StatelessWidget {
  const AuthPage({super.key, required this.title, required this.child, this.subtitle});
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SynchroWordmark(size: 58, onDark: Theme.of(context).brightness == Brightness.dark),
          const SizedBox(height: 24),
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(subtitle!, style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            )),
          ],
          const SizedBox(height: 24),
          child,
        ]),
      )),
    )),
  );
}
