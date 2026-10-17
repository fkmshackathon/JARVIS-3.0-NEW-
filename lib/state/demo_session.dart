import 'package:flutter/foundation.dart';

/// Profile metadata kept for the local-only demo session.
///
/// A profile deliberately has no credential fields. The access screen receives
/// a password long enough to validate and authenticate the demo action, but it
/// is never copied into this object or into [DemoSession].
class DemoProfile {
  const DemoProfile({required this.email, this.displayName, this.collegeName});

  final String email;
  final String? displayName;
  final String? collegeName;

  /// A small, safe snapshot for UI consumers that need profile metadata.
  Map<String, String> get metadata => Map.unmodifiable({
    'email': email,
    if (displayName != null && displayName!.isNotEmpty)
      'displayName': displayName!,
    if (collegeName != null && collegeName!.isNotEmpty)
      'collegeName': collegeName!,
  });

  @override
  String toString() => 'DemoProfile(email: $email, displayName: $displayName)';
}

/// In-memory authentication state for the frontend-only SYNCHRO demo.
///
/// Any syntactically valid email and non-empty password can enter the demo.
/// This is intentionally not an account store: signing out clears the one
/// profile held in memory, and no password is retained anywhere on the
/// session.
class DemoSession extends ChangeNotifier {
  DemoProfile? _profile;

  DemoProfile? get profile => _profile;

  String? get email => _profile?.email;

  String? get signedInEmail => _profile?.email;

  bool get isAuthenticated => _profile != null;

  bool get isSignedIn => isAuthenticated;

  /// Safe metadata exposed for UI or diagnostics; it has no credential data.
  Map<String, String> get profileMetadata =>
      _profile?.metadata ?? const <String, String>{};

  /// Validates and enters the demo using a local profile only.
  bool signIn({
    required String email,
    required String password,
    String? displayName,
    String? collegeName,
  }) {
    return _authenticate(
      email: email,
      password: password,
      displayName: displayName,
      collegeName: collegeName,
    );
  }

  /// Validates and creates a local demo profile.
  ///
  /// There is no remote account creation in this experience, so sign-up and
  /// sign-in intentionally share the same in-memory behavior.
  bool signUp({
    required String email,
    required String password,
    String? displayName,
    String? collegeName,
  }) {
    return _authenticate(
      email: email,
      password: password,
      displayName: displayName,
      collegeName: collegeName,
    );
  }

  /// Clears the signed-in profile and notifies listeners when it changes.
  void signOut() {
    if (_profile == null) return;
    _profile = null;
    notifyListeners();
  }

  /// Returns an inline validation message, or null when the email is valid.
  static String? validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Email is required.';

    final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
    return valid ? null : 'Enter a valid email address.';
  }

  /// Returns an inline validation message, or null when the password is usable
  /// for the local demo. The demo intentionally requires presence only.
  static String? validatePassword(String? value) {
    return value == null || value.isEmpty ? 'Password is required.' : null;
  }

  static bool isValidEmail(String? value) => validateEmail(value) == null;

  static bool isValidPassword(String? value) => validatePassword(value) == null;

  static String? validateName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Name is required.';
    return name.length > 120
        ? 'Use 120 characters or fewer for your name.'
        : null;
  }

  static String? validateCollege(String? value) {
    final college = value?.trim() ?? '';
    if (college.isEmpty) return 'College is required.';
    return college.length > 200
        ? 'Use 200 characters or fewer for your college.'
        : null;
  }

  bool _authenticate({
    required String email,
    required String password,
    String? displayName,
    String? collegeName,
  }) {
    final normalizedEmail = email.trim().toLowerCase();
    if (!isValidEmail(normalizedEmail) || !isValidPassword(password)) {
      return false;
    }
    if ((displayName != null && validateName(displayName) != null) ||
        (collegeName != null && validateCollege(collegeName) != null)) {
      return false;
    }

    _profile = DemoProfile(
      email: normalizedEmail,
      displayName: displayName?.trim().isNotEmpty == true
          ? displayName!.trim()
          : null,
      collegeName: collegeName?.trim().isNotEmpty == true
          ? collegeName!.trim()
          : null,
    );
    notifyListeners();
    return true;
  }
}

/// Top-level aliases keep the validators convenient for plain Flutter forms.
String? validateDemoEmail(String? value) => DemoSession.validateEmail(value);

String? validateDemoPassword(String? value) =>
    DemoSession.validatePassword(value);
