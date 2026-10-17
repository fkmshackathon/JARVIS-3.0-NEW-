import 'package:flutter_test/flutter_test.dart';
import 'package:synchro/state/demo_session.dart';

void main() {
  test('email and password validators expose useful inline messages', () {
    expect(DemoSession.validateEmail('not-an-email'), isNotNull);
    expect(DemoSession.validateEmail('planner@campus.edu'), isNull);
    expect(DemoSession.validatePassword(''), 'Password is required.');
    expect(DemoSession.validatePassword('demo-password'), isNull);
  });

  test('sign-in and sign-up retain profile metadata without credentials', () {
    final session = DemoSession();
    addTearDown(session.dispose);

    expect(
      session.signIn(email: ' Planner@Campus.edu ', password: 'secret'),
      isTrue,
    );
    expect(session.isAuthenticated, isTrue);
    expect(session.email, 'planner@campus.edu');
    expect(session.profileMetadata['email'], 'planner@campus.edu');
    expect(session.profileMetadata.containsKey('password'), isFalse);
    expect(session.profile.toString(), isNot(contains('secret')));

    session.signOut();
    expect(session.isAuthenticated, isFalse);
    expect(session.profile, isNull);
    expect(session.profileMetadata, isEmpty);
  });
}
