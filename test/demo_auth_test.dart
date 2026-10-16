import 'package:flutter_test/flutter_test.dart';
import 'package:synchro/state/demo_auth.dart';

void main() {
  test('demo sign-in creates an in-memory session from a valid email', () {
    final auth = DemoAuth();

    expect(auth.signIn(email: 'demo@school.edu', password: 'demo'), isNull);
    expect(auth.isSignedIn, isTrue);
    expect(auth.currentUser?.name, 'Demo');
    expect(auth.currentUser?.role, 'coordinator');
  });

  test('demo sign-up validates fields and stores only the profile session', () {
    final auth = DemoAuth();

    expect(
      auth.signUp(
        name: 'Asha Rao',
        email: 'asha@school.edu',
        password: 'demo',
        confirmPassword: 'demo',
        institution: 'Chronos College',
        role: 'faculty',
      ),
      isNull,
    );
    expect(auth.currentUser?.name, 'Asha Rao');
    expect(auth.currentUser?.institution, 'Chronos College');
    expect(auth.currentUser?.role, 'faculty');

    auth.signOut();
    expect(auth.isSignedIn, isFalse);
  });

  test(
    'demo sign-up rejects mismatched passwords without creating a session',
    () {
      final auth = DemoAuth();

      expect(
        auth.signUp(
          name: 'Asha Rao',
          email: 'asha@school.edu',
          password: 'demo',
          confirmPassword: 'different',
          institution: '',
          role: 'student',
        ),
        'Passwords do not match.',
      );
      expect(auth.isSignedIn, isFalse);
    },
  );
}
