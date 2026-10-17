import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synchro/screens/access_screen.dart';
import 'package:synchro/state/demo_session.dart';
import 'package:synchro/theme/synchro_theme.dart';

void main() {
  testWidgets('shows inline validation for an invalid email', (tester) async {
    _phone(tester);
    await _pumpAccess(tester);

    await tester.enterText(
      find.byKey(const Key('access-email-field')),
      'not-an-email',
    );
    await _tapSubmit(tester);
    await tester.pump();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(
      find.text('Check the highlighted fields and try again.'),
      findsOneWidget,
    );
  });

  testWidgets('shows inline validation for an empty password', (tester) async {
    _phone(tester);
    await _pumpAccess(tester);

    await tester.enterText(
      find.byKey(const Key('access-email-field')),
      'planner@campus.edu',
    );
    await _tapSubmit(tester);
    await tester.pump();

    expect(find.text('Password is required.'), findsOneWidget);
  });

  testWidgets('successful sign-in updates the session and calls the callback', (
    tester,
  ) async {
    _phone(tester);
    final session = DemoSession();
    addTearDown(session.dispose);
    var authenticated = false;

    await _pumpAccess(
      tester,
      session: session,
      onAuthenticated: () => authenticated = true,
    );
    await _enterCredentials(tester);
    await _tapSubmit(tester);
    await tester.pumpAndSettle();

    expect(authenticated, isTrue);
    expect(session.isAuthenticated, isTrue);
    expect(session.email, 'planner@campus.edu');
    expect(session.profile?.displayName, 'Aarya Dsouza');
    expect(session.profile?.collegeName, 'College of Engineering & Arts');
    expect(
      find.text('You are in. Your local workspace is ready.'),
      findsOneWidget,
    );
  });

  testWidgets('successful sign-up calls the callback', (tester) async {
    _phone(tester);
    final session = DemoSession();
    addTearDown(session.dispose);
    DemoProfile? authenticatedProfile;

    await _pumpAccess(
      tester,
      session: session,
      onAuthenticated: (DemoProfile profile) => authenticatedProfile = profile,
    );
    await tester.tap(find.text('Create account').first);
    await tester.pump();
    await _enterCredentials(tester, password: 'new-demo-password');
    await _tapSubmit(tester);
    await tester.pumpAndSettle();

    expect(authenticatedProfile?.email, 'planner@campus.edu');
    expect(authenticatedProfile?.displayName, 'Aarya Dsouza');
    expect(authenticatedProfile?.collegeName, 'College of Engineering & Arts');
    expect(session.isAuthenticated, isTrue);
  });

  testWidgets('password visibility toggle reveals and hides the field', (
    tester,
  ) async {
    _phone(tester);
    await _pumpAccess(tester);

    final password = find.descendant(
      of: find.byKey(const Key('access-password-field')),
      matching: find.byType(TextField),
    );
    expect(tester.widget<TextField>(password).obscureText, isTrue);
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const Key('toggle-password-visibility')),
    );
    await tester.tap(find.byKey(const Key('toggle-password-visibility')));
    await tester.pump();

    expect(tester.widget<TextField>(password).obscureText, isFalse);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
  });

  for (final createAccount in [false, true]) {
    testWidgets(
      'name and college are required for ${createAccount ? 'sign-up' : 'sign-in'}',
      (tester) async {
        _phone(tester);
        final session = DemoSession();
        addTearDown(session.dispose);
        await _pumpAccess(tester, session: session);
        if (createAccount) {
          await tester.tap(find.text('Create account').first);
          await tester.pump();
        }
        await tester.enterText(
          find.byKey(const Key('access-name-field')),
          '  ',
        );
        await tester.enterText(
          find.byKey(const Key('access-email-field')),
          'planner@campus.edu',
        );
        await tester.enterText(
          find.byKey(const Key('access-password-field')),
          'demo-password',
        );
        await _tapSubmit(tester);
        await tester.pumpAndSettle();
        expect(find.text('Name is required.'), findsOneWidget);
        expect(find.text('College is required.'), findsOneWidget);
        expect(session.isSignedIn, isFalse);
      },
    );
  }

  for (final size in [const Size(375, 812), const Size(844, 390)]) {
    for (final dark in [false, true]) {
      testWidgets(
        'profile form fits $size in ${dark ? 'dark' : 'light'} mode',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            MaterialApp(
              theme: dark ? SynchroTheme.dark : SynchroTheme.light,
              home: AccessScreen(onAuthenticated: () {}),
            ),
          );
          await tester.pumpAndSettle();
          await _enterCredentials(tester);
          await _tapSubmit(tester);
          await tester.pumpAndSettle();
          expect(
            find.text('You are in. Your local workspace is ready.'),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

Future<void> _pumpAccess(
  WidgetTester tester, {
  DemoSession? session,
  Function? onAuthenticated,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: SynchroTheme.light,
      home: AccessScreen(
        session: session,
        onAuthenticated: onAuthenticated ?? () {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _enterCredentials(
  WidgetTester tester, {
  String password = 'demo-password',
}) async {
  await tester.enterText(
    find.byKey(const Key('access-name-field')),
    ' Aarya Dsouza ',
  );
  await tester.enterText(
    find.byKey(const Key('access-college-field')),
    ' College of Engineering & Arts ',
  );
  await tester.enterText(
    find.byKey(const Key('access-email-field')),
    'planner@campus.edu',
  );
  await tester.enterText(
    find.byKey(const Key('access-password-field')),
    password,
  );
}

Future<void> _tapSubmit(WidgetTester tester) async {
  final submit = find.byKey(const Key('access-submit-button'));
  await tester.ensureVisible(submit);
  await tester.pumpAndSettle();
  await tester.tap(submit);
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}
