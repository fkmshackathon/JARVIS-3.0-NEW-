import 'package:flutter/material.dart';

import '../brand/synchro_mark.dart';
import '../state/demo_auth.dart';
import '../theme/tokens.dart';
import '../widgets/ui.dart';

/// Demo-only account surface. It intentionally keeps identity in memory and
/// never stores passwords or talks to a database.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key, this.onBack, required this.auth});

  final VoidCallback? onBack;
  final DemoAuth auth;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _institution = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirmPassword = TextEditingController();
  bool _obscurePassword = true;
  bool _createAccount = false;
  String _role = 'coordinator';
  String? _formError;

  @override
  void dispose() {
    _name.dispose();
    _institution.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: _goBack,
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Account'),
      ),
      body: ListenableBuilder(
        listenable: widget.auth,
        builder: (context, _) => SafeArea(
          top: false,
          child: widget.auth.isSignedIn
              ? _SignedInBody(auth: widget.auth)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                    SynchroSpacing.gutter,
                    SynchroSpacing.lg,
                    SynchroSpacing.gutter,
                    SynchroSpacing.xxl,
                  ),
                  children: [
                    const Center(child: SynchroMark(size: 64, badge: true)),
                    const SizedBox(height: SynchroSpacing.lg),
                    Text(
                      'Keep your workspace close.',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: SynchroSpacing.sm),
                    Text(
                      'Use a local demo identity for this Chrome walkthrough. No password is stored.',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: SynchroSpacing.xl),
                    const Notice(
                      tone: Tone.neutral,
                      icon: Icons.science_outlined,
                      text: 'Demo mode is active. Identity stays in memory and is not sent to the solver backend.',
                    ),
                    if (_formError != null)
                      Notice(
                        tone: Tone.bad,
                        icon: Icons.error_outline,
                        text: _formError!,
                      ),
                    const SizedBox(height: SynchroSpacing.sm),
                    SectionCard(
                      overline: 'Account access',
                      title: 'Sign in or create an account',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment<bool>(
                                value: false,
                                label: Text('Sign in'),
                                icon: Icon(Icons.login),
                              ),
                              ButtonSegment<bool>(
                                value: true,
                                label: Text('Create account'),
                                icon: Icon(Icons.person_add_alt_1_outlined),
                              ),
                            ],
                            selected: {_createAccount},
                            onSelectionChanged: (selection) => setState(
                              () => _createAccount = selection.first,
                            ),
                          ),
                          if (_createAccount) ...[
                            const SizedBox(height: SynchroSpacing.md),
                            TextField(
                              controller: _name,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.name],
                              decoration: const InputDecoration(
                                labelText: 'Full name',
                                prefixIcon: Icon(Icons.badge_outlined),
                              ),
                            ),
                          ],
                          const SizedBox(height: SynchroSpacing.md),
                          TextField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [
                              AutofillHints.username,
                              AutofillHints.email,
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              hintText: 'name@example.edu',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                          ),
                          const SizedBox(height: SynchroSpacing.md),
                          TextField(
                            controller: _password,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.password_outlined),
                              suffixIcon: IconButton(
                                tooltip: _obscurePassword
                                    ? 'Show password'
                                    : 'Hide password',
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                          ),
                          if (_createAccount) ...[
                            const SizedBox(height: SynchroSpacing.md),
                            TextField(
                              controller: _confirmPassword,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              decoration: const InputDecoration(
                                labelText: 'Confirm password',
                                prefixIcon: Icon(Icons.verified_user_outlined),
                              ),
                            ),
                          ] else ...[
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: null,
                                child: const Text('Forgot password?'),
                              ),
                            ),
                          ],
                          const SizedBox(height: SynchroSpacing.lg),
                          FilledButton.icon(
                            onPressed: _submit,
                            icon: const Icon(Icons.login),
                            label: Text(
                              _createAccount ? 'Create account' : 'Sign in',
                            ),
                          ),
                          const SizedBox(height: SynchroSpacing.md),
                          Text(
                            'Any valid-looking demo email works for sign in. Sign up accepts a temporary in-memory profile.',
                            style: Theme.of(context).textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: SynchroSpacing.lg),
                    SectionCard(
                      overline: 'Profile and role',
                      title: 'Prepare your workspace',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Profile fields are used for this session only. Server-side role authorization is not changed.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: SynchroSpacing.md),
                          TextField(
                            controller: _institution,
                            decoration: const InputDecoration(
                              labelText: 'Institution or college',
                              prefixIcon: Icon(Icons.school_outlined),
                            ),
                          ),
                          const SizedBox(height: SynchroSpacing.md),
                          Text(
                            'Role in institution',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          const SizedBox(height: SynchroSpacing.sm),
                          Wrap(
                            spacing: SynchroSpacing.sm,
                            runSpacing: SynchroSpacing.sm,
                            children: [
                              for (final role in const {
                                'coordinator': 'Timetable coordinator',
                                'faculty': 'Faculty / teacher',
                                'student': 'Student',
                              }.entries)
                                ChoiceChip(
                                  label: Text(role.value),
                                  selected: _role == role.key,
                                  onSelected: (_) =>
                                      setState(() => _role = role.key),
                                ),
                            ],
                          ),
                          const SizedBox(height: SynchroSpacing.lg),
                          OutlinedButton.icon(
                            onPressed: null,
                            icon: const Icon(Icons.save_outlined),
                            label: const Text('Save profile'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  void _submit() {
    final error = _createAccount
        ? widget.auth.signUp(
            name: _name.text,
            email: _email.text,
            password: _password.text,
            confirmPassword: _confirmPassword.text,
            institution: _institution.text,
            role: _role,
          )
        : widget.auth.signIn(email: _email.text, password: _password.text);
    setState(() {
      _formError = error;
    });
  }

  void _goBack() {
    if (widget.onBack != null) {
      widget.onBack!();
    } else {
      Navigator.of(context).maybePop();
    }
  }
}

class _SignedInBody extends StatelessWidget {
  const _SignedInBody({required this.auth});

  final DemoAuth auth;

  @override
  Widget build(BuildContext context) {
    final user = auth.currentUser!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        SynchroSpacing.gutter,
        SynchroSpacing.xl,
        SynchroSpacing.gutter,
        SynchroSpacing.xxl,
      ),
      children: [
        const Center(child: SynchroWordmark(size: 46, onDark: false)),
        const SizedBox(height: SynchroSpacing.xl),
        SectionCard(
          overline: 'Local demo session',
          title: 'You are signed in',
          trailing: const StatusChip(
            label: 'active',
            tone: Tone.good,
            icon: Icons.verified_outlined,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user.name, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: SynchroSpacing.xs),
              Text(user.email, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: SynchroSpacing.lg),
              _ProfileLine('Institution', user.institution),
              _ProfileLine('Role', _roleLabel(user.role)),
              const SizedBox(height: SynchroSpacing.lg),
              const Notice(
                tone: Tone.neutral,
                icon: Icons.memory_outlined,
                text: 'This demo identity lives only in the running app. It does not authorize backend requests.',
              ),
              const SizedBox(height: SynchroSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: auth.signOut,
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign out of demo session'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _roleLabel(String role) => switch (role) {
    'faculty' => 'Faculty / teacher',
    'student' => 'Student',
    _ => 'Timetable coordinator',
  };
}

class _ProfileLine extends StatelessWidget {
  const _ProfileLine(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: SynchroSpacing.xs),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(label, style: Theme.of(context).textTheme.labelSmall),
        ),
        Expanded(
          child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    ),
  );
}
