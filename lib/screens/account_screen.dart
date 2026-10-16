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
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
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
                  const SizedBox(height: SynchroSpacing.lg),
                  FilledButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.login),
                    label: const Text('Sign in'),
                  ),
                  const SizedBox(height: SynchroSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    label: const Text('Create account'),
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
