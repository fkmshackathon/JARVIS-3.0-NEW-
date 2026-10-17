import 'dart:async';

import 'package:flutter/material.dart';

import '../brand/synchro_mark.dart';
import '../state/demo_session.dart';
import '../theme/tokens.dart';
import '../widgets/ui.dart';

/// Optional submission hook for a host that wants to observe or gate the local
/// demo action. Returning false keeps the form in place and shows an error;
/// returning true or null allows the in-memory session to authenticate.
typedef DemoAccessSubmit = FutureOr<bool?> Function(
  String email,
  String password,
  bool isCreatingAccount,
);

enum AccessMode { signIn, createAccount }

/// Cream/navy/orange entry surface for the local SYNCHRO demo.
class AccessScreen extends StatefulWidget {
  const AccessScreen({
    super.key,
    required this.onAuthenticated,
    this.onSubmit,
    this.session,
  });

  /// Accepts either a no-argument callback or one that receives the profile.
  /// The no-argument form is convenient for navigation; the profile form is
  /// useful when a host wants to read the signed-in email immediately.
  final Function onAuthenticated;

  final DemoAccessSubmit? onSubmit;

  /// An injected session makes the local state easy to observe in a host or
  /// test. When omitted, the screen owns and disposes an in-memory session.
  final DemoSession? session;

  @override
  State<AccessScreen> createState() => _AccessScreenState();
}

class _AccessScreenState extends State<AccessScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _collegeController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final DemoSession _session;
  late final bool _ownsSession;

  AccessMode _mode = AccessMode.signIn;
  bool _obscurePassword = true;
  bool _hasSubmitted = false;
  bool _isSubmitting = false;
  String? _feedbackMessage;
  bool _feedbackIsError = false;

  bool get _isCreatingAccount => _mode == AccessMode.createAccount;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _collegeController = TextEditingController();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _session = widget.session ?? DemoSession();
    _ownsSession = widget.session == null;
  }

  @override
  void dispose() {
    _nameController.clear();
    _collegeController.clear();
    _emailController.clear();
    _passwordController.clear();
    _nameController.dispose();
    _collegeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    if (_ownsSession) _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pageColor = isDark ? SynchroColors.navyDeep : SynchroColors.creamPale;
    final headingColor = isDark ? SynchroColors.onNavy : SynchroColors.navyDeep;

    return Scaffold(
      backgroundColor: pageColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth < 360
                ? SynchroSpacing.lg
                : SynchroSpacing.xl;
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                SynchroSpacing.xxl,
                horizontalPadding,
                SynchroSpacing.xxl,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SynchroWordmark(size: 58, onDark: isDark),
                      const SizedBox(height: SynchroSpacing.xxl),
                      _HeroAccent(
                        color: isDark
                            ? SynchroColors.orange
                            : SynchroColors.orangeDeep,
                      ),
                      const SizedBox(height: SynchroSpacing.md),
                      Text(
                        'Welcome to SYNCHRO.',
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: headingColor,
                          fontSize: 30,
                        ),
                      ),
                      const SizedBox(height: SynchroSpacing.sm),
                      Text(
                        'Plan smarter. Build better timetables.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: isDark
                              ? SynchroColors.onNavyMuted
                              : SynchroColors.inkMuted,
                        ),
                      ),
                      const SizedBox(height: SynchroSpacing.xxl),
                      _accessCard(theme),
                      const SizedBox(height: SynchroSpacing.lg),
                      Center(
                        child: Text(
                          'Local demo · No account required',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? SynchroColors.onNavyMuted
                                : SynchroColors.inkMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _accessCard(ThemeData theme) {
    final title = _isCreatingAccount ? 'Create your local profile' : 'Sign in';
    final helper = _isCreatingAccount
        ? 'Create your local profile with your name and college. All fields are required.'
        : 'Enter your name, college, email and password for the local demo. All fields are required.';

    return SectionCard(
      overline: 'ACCESS',
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<AccessMode>(
            segments: const [
              ButtonSegment<AccessMode>(
                value: AccessMode.signIn,
                label: Text('Sign in'),
              ),
              ButtonSegment<AccessMode>(
                value: AccessMode.createAccount,
                label: Text('Create account'),
              ),
            ],
            selected: {_mode},
            showSelectedIcon: false,
            onSelectionChanged: (selection) {
              if (selection.isNotEmpty) _changeMode(selection.first);
            },
          ),
          const SizedBox(height: SynchroSpacing.lg),
          Text(helper, style: theme.textTheme.bodySmall),
          const SizedBox(height: SynchroSpacing.lg),
          if (_feedbackMessage != null) ...[
            Semantics(
              container: true,
              liveRegion: true,
              label: _feedbackMessage,
              child: Notice(
                text: _feedbackMessage!,
                tone: _feedbackIsError ? Tone.bad : Tone.good,
                icon: _feedbackIsError
                    ? Icons.error_outline
                    : Icons.check_circle_outline,
              ),
            ),
          ],
          Form(
            key: _formKey,
            autovalidateMode: _hasSubmitted
                ? AutovalidateMode.onUserInteraction
                : AutovalidateMode.disabled,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    key: const Key('access-name-field'),
                    controller: _nameController,
                    keyboardType: TextInputType.name,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                    decoration: const InputDecoration(
                      labelText: 'Full name',
                      hintText: 'Enter your name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: DemoSession.validateName,
                    onChanged: (_) => _clearFeedbackOnEdit(),
                  ),
                  const SizedBox(height: SynchroSpacing.md),
                  TextFormField(
                    key: const Key('access-college-field'),
                    controller: _collegeController,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.organizationName],
                    decoration: const InputDecoration(
                      labelText: 'College name',
                      hintText: 'Enter your college',
                      prefixIcon: Icon(Icons.school_outlined),
                    ),
                    validator: DemoSession.validateCollege,
                    onChanged: (_) => _clearFeedbackOnEdit(),
                  ),
                  const SizedBox(height: SynchroSpacing.md),
                  TextFormField(
                    key: const Key('access-email-field'),
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [
                      AutofillHints.username,
                      AutofillHints.email,
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                      hintText: 'you@campus.edu',
                      prefixIcon: Icon(Icons.alternate_email),
                    ),
                    validator: DemoSession.validateEmail,
                    onChanged: (_) => _clearFeedbackOnEdit(),
                  ),
                  const SizedBox(height: SynchroSpacing.md),
                  TextFormField(
                    key: const Key('access-password-field'),
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    enableSuggestions: false,
                    autocorrect: false,
                    textInputAction: TextInputAction.done,
                    autofillHints: <String>[
                      _isCreatingAccount
                          ? AutofillHints.newPassword
                          : AutofillHints.password,
                    ],
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'Enter your password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        key: const Key('toggle-password-visibility'),
                        tooltip: _obscurePassword
                            ? 'Show password'
                            : 'Hide password',
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                    validator: DemoSession.validatePassword,
                    onFieldSubmitted: (_) => _submit(),
                    onChanged: (_) => _clearFeedbackOnEdit(),
                  ),
                  const SizedBox(height: SynchroSpacing.xl),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const Key('access-submit-button'),
                      onPressed: _isSubmitting ? null : _submit,
                      icon: Icon(
                        _isCreatingAccount
                            ? Icons.arrow_forward_rounded
                            : Icons.login_rounded,
                      ),
                      label: Text(
                        _isCreatingAccount ? 'Create account' : 'Sign in',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: SynchroColors.navy,
                        foregroundColor: SynchroColors.onNavy,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _changeMode(AccessMode mode) {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      _hasSubmitted = false;
      _feedbackMessage = null;
    });
    _formKey.currentState?.reset();
  }

  void _clearFeedbackOnEdit() {
    if (_feedbackMessage == null) return;
    setState(() => _feedbackMessage = null);
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _hasSubmitted = true;
      _feedbackMessage = null;
    });

    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      setState(() {
        _feedbackIsError = true;
        _feedbackMessage = 'Check the highlighted fields and try again.';
      });
      return;
    }

    setState(() => _isSubmitting = true);
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      final accepted = widget.onSubmit == null
          ? true
          : await widget.onSubmit!(email, password, _isCreatingAccount);
      if (accepted == false) {
        _showError('We could not continue in this demo. Try again.');
        return;
      }

      final didAuthenticate = _isCreatingAccount
          ? _session.signUp(
              email: email,
              password: password,
              displayName: _nameController.text.trim(),
              collegeName: _collegeController.text.trim(),
            )
          : _session.signIn(
              email: email,
              password: password,
              displayName: _nameController.text.trim(),
              collegeName: _collegeController.text.trim(),
            );
      if (!didAuthenticate || _session.profile == null) {
        _showError('Check the highlighted fields and try again.');
        return;
      }

      final profile = _session.profile!;
      _passwordController.clear();
      _showSuccess('You are in. Your local workspace is ready.');
      if (mounted) _notifyAuthenticated(profile);
    } on Object {
      _showError('We could not continue in this demo. Try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    setState(() {
      _feedbackIsError = false;
      _feedbackMessage = message;
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _feedbackIsError = true;
      _feedbackMessage = message;
    });
  }

  void _notifyAuthenticated(DemoProfile profile) {
    final callback = widget.onAuthenticated;
    if (callback is VoidCallback) {
      callback();
      return;
    }
    if (callback is ValueChanged<DemoProfile>) {
      callback(profile);
      return;
    }
    if (callback is ValueChanged<String>) {
      callback(profile.email);
      return;
    }

    // A dynamically typed closure is still useful to a small host/demo. Apply
    // the profile first, then support the navigation-style no-argument form.
    try {
      Function.apply(callback, <Object?>[profile]);
    } on NoSuchMethodError {
      Function.apply(callback, const <Object?>[]);
    }
  }
}

class _HeroAccent extends StatelessWidget {
  const _HeroAccent({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 5,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(SynchroRadius.pill),
          ),
        ),
        const SizedBox(width: SynchroSpacing.sm),
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ],
    );
  }
}
