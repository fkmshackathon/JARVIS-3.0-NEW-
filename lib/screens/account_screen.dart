import 'package:flutter/material.dart';

import '../brand/synchro_mark.dart';
import '../theme/tokens.dart';
import '../widgets/ui.dart';

/// Account presentation only. There is no authentication provider in the
/// current app, so both submit controls stay disabled rather than simulating a
/// session or storing credentials locally.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key, this.onBack});

  final VoidCallback? onBack;

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
      body: SafeArea(
        top: false,
        child: ListView(
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
              'Account access is shown here so the hand-off is clear when a provider is connected.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: SynchroSpacing.xl),
            const Notice(
              tone: Tone.warn,
              icon: Icons.lock_outline,
              text: 'Authentication provider is not configured. Sign-in and account creation are unavailable.',
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
                    onSelectionChanged: (selection) =>
                        setState(() => _createAccount = selection.first),
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
                    onPressed: null,
                    icon: const Icon(Icons.login),
                    label: Text(_createAccount ? 'Create account' : 'Sign in'),
                  ),
                  const SizedBox(height: SynchroSpacing.md),
                  Text(
                    'These controls will become available only after an authentication provider is configured.',
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
                    'These details can be saved after a real account provider and profile endpoint are connected.',
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
                          onSelected: (_) => setState(() => _role = role.key),
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
    );
  }

  void _goBack() {
    if (widget.onBack != null) {
      widget.onBack!();
    } else {
      Navigator.of(context).maybePop();
    }
  }
}
