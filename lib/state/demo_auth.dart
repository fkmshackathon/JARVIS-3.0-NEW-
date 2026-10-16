import 'package:flutter/foundation.dart';

/// Local-only demo identity for the Chrome walkthrough.
///
/// This deliberately does not store passwords, write a database, or claim to
/// provide authorization. A real identity provider can replace this adapter
/// without changing the scheduling controller or solver contract.
class DemoAuth extends ChangeNotifier {
  DemoUser? _currentUser;

  DemoUser? get currentUser => _currentUser;

  bool get isSignedIn => _currentUser != null;

  String? signIn({required String email, required String password}) {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      return 'Enter a valid email address.';
    }
    if (password.isEmpty) return 'Enter a password to continue.';

    _currentUser = DemoUser(
      name: _displayNameFromEmail(cleanEmail),
      email: cleanEmail,
      institution: 'Demo campus workspace',
      role: 'coordinator',
    );
    notifyListeners();
    return null;
  }

  String? signUp({
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
    required String institution,
    required String role,
  }) {
    final cleanName = name.trim();
    final cleanEmail = email.trim();
    final cleanInstitution = institution.trim();
    if (cleanName.isEmpty) return 'Enter your full name.';
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      return 'Enter a valid email address.';
    }
    if (password.length < 4) {
      return 'Use at least 4 characters for the demo password.';
    }
    if (password != confirmPassword) return 'Passwords do not match.';

    _currentUser = DemoUser(
      name: cleanName,
      email: cleanEmail,
      institution: cleanInstitution.isEmpty
          ? 'Demo campus workspace'
          : cleanInstitution,
      role: role,
    );
    notifyListeners();
    return null;
  }

  void signOut() {
    _currentUser = null;
    notifyListeners();
  }

  static String _displayNameFromEmail(String email) {
    final local = email
        .split('@')
        .first
        .replaceAll(RegExp(r'[._-]+'), ' ')
        .trim();
    if (local.isEmpty) return 'Demo coordinator';
    return local
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }
}

class DemoUser {
  const DemoUser({
    required this.name,
    required this.email,
    required this.institution,
    required this.role,
  });

  final String name;
  final String email;
  final String institution;
  final String role;
}
