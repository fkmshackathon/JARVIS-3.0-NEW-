import 'dart:async';

/// Identity comes only from the authentication SDK, never from profile storage.
class AuthUser {
  const AuthUser({
    required this.uid,
    required this.emailVerified,
    this.email,
    this.displayName,
  });

  final String uid;
  final String? email;
  final String? displayName;
  final bool emailVerified;
}

/// Non-credential metadata. No passwords or authentication tokens belong here.
class AuthProfile {
  AuthProfile({required String displayName, required String collegeName})
      : displayName = displayName.trim(),
        collegeName = collegeName.trim();

  final String displayName;
  final String collegeName;

  bool get isValid => AuthValidators.name(displayName) == null &&
      AuthValidators.college(collegeName) == null;

  Map<String, String> toJson() => {
    'display_name': displayName,
    'college_name': collegeName,
  };

  static AuthProfile? fromJson(Object? value) {
    if (value is! Map || value['display_name'] is! String ||
        value['college_name'] is! String) {
      return null;
    }
    final profile = AuthProfile(
      displayName: value['display_name'] as String,
      collegeName: value['college_name'] as String,
    );
    return profile.isValid ? profile : null;
  }
}

abstract final class AuthValidators {
  static String? email(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Email is required.';
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)
        ? null : 'Enter a valid email address.';
  }

  static String? password(String? value, {bool creatingAccount = false}) {
    if (value == null || value.isEmpty) return 'Password is required.';
    if (creatingAccount && value.length < 6) {
      return 'Use at least 6 characters for your password.';
    }
    return value.length > 4096 ? 'Password is too long.' : null;
  }

  static String? name(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Name is required.';
    return name.length > 120 ? 'Use 120 characters or fewer for your name.' : null;
  }

  static String? college(String? value) {
    final college = value?.trim() ?? '';
    if (college.isEmpty) return 'College is required.';
    return college.length > 200 ? 'Use 200 characters or fewer for your college.' : null;
  }
}

/// SDK/provider diagnostics are never displayed verbatim or logged.
class AuthFailure implements Exception {
  const AuthFailure(this.code);
  final String code;

  bool get wasCancelled => code == 'cancelled';

  String get message => switch (code) {
    'invalid-credential' || 'wrong-password' || 'user-not-found' =>
      'The email or password is incorrect. Try again or reset your password.',
    'email-already-in-use' =>
      'Unable to create this account. Try signing in or resetting your password.',
    'weak-password' => 'Use a stronger password that meets the project password policy.',
    'invalid-email' => 'Enter a valid email address.',
    'user-disabled' => 'This account is disabled. Contact your administrator.',
    'too-many-requests' => 'Too many attempts. Please wait before trying again.',
    'network-request-failed' || 'timeout' =>
      'Cannot reach authentication services. Check your internet connection.',
    'operation-not-allowed' =>
      'This sign-in provider is not enabled in Firebase Authentication.',
    'unauthorized-domain' =>
      'This website domain is not authorized in Firebase Authentication settings.',
    'popup-blocked' => 'Allow the Google sign-in popup, then try again.',
    'account-exists-with-different-credential' =>
      'Sign in using the method originally used for this account.',
    'google-configuration' =>
      'Check the Google provider, Android package, SHA certificates and OAuth client configuration.',
    'profile-invalid' => 'Enter your full name and college to continue.',
    'profile-storage' => 'Cannot save your profile on this device. Allow local storage and try again.',
    'configuration' => 'Firebase authentication needs valid platform configuration.',
    'invalid-api-key' || 'app-not-authorized' || 'invalid-app-credential' =>
      'Firebase client configuration is not valid for this app. Check the app registration and API key restrictions.',
    'unsupported-platform' => 'Authentication is configured for Web and Android only.',
    'cancelled' => 'Google sign-in was cancelled. No account was signed in.',
    'session-changed' => 'The authentication session changed. Please try again.',
    _ => 'Authentication could not be completed. Please try again.',
  };
}

abstract interface class AuthRepository {
  AuthUser? get currentUser;
  Stream<AuthUser?> get userChanges;
  Future<AuthUser> signIn(String email, String password);
  Future<AuthUser> signUp(String email, String password);
  Future<AuthUser> signInWithGoogle();
  Future<void> updateDisplayName(String uid, String name);
  Future<void> sendVerificationEmail(String uid);
  Future<AuthUser?> reloadUser(String uid);
  Future<void> sendPasswordReset(String email);
  Future<void> signOut();
  void dispose();
}

abstract interface class AuthProfileStore {
  Future<AuthProfile?> read(String uid);
  Future<void> write(String uid, AuthProfile profile);
}
