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

  test('name and college are validated in both access modes', () {
    expect(DemoSession.validateName('  '), 'Name is required.');
    expect(DemoSession.validateCollege(' '), 'College is required.');
    expect(DemoSession.validateName('आर्या डी-सूज़ा'), isNull);
    expect(
      DemoSession.validateCollege('College of Engineering & Arts'),
      isNull,
    );
    expect(DemoSession.validateName('a' * 121), isNotNull);
    expect(DemoSession.validateCollege('a' * 201), isNotNull);

    final session = DemoSession();
    addTearDown(session.dispose);
    for (final createAccount in [false, true]) {
      final authenticate = createAccount ? session.signUp : session.signIn;
      expect(
        authenticate(
          email: ' Planner@Campus.edu ',
          password: 'demo-password',
          displayName: '  Aarya Dsouza  ',
          collegeName: '  College of Engineering & Arts  ',
        ),
        isTrue,
      );
      expect(session.profile?.displayName, 'Aarya Dsouza');
      expect(session.profile?.collegeName, 'College of Engineering & Arts');
      expect(
        session.profileMetadata['collegeName'],
        'College of Engineering & Arts',
      );
      expect(session.profileMetadata.containsKey('password'), isFalse);
      expect(
        authenticate(
          email: 'planner@campus.edu',
          password: 'demo-password',
          displayName: ' ',
          collegeName: 'College of Engineering & Arts',
        ),
        isFalse,
      );
      session.signOut();
      expect(session.profileMetadata, isEmpty);
    }
  });
}
