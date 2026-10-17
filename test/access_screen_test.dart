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
    await tester.tap(find.byKey(const Key('access-submit-button')));
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
    await tester.tap(find.byKey(const Key('access-submit-button')));
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
    await tester.tap(find.byKey(const Key('access-submit-button')));
    await tester.pumpAndSettle();

    expect(authenticated, isTrue);
    expect(session.isAuthenticated, isTrue);
    expect(session.email, 'planner@campus.edu');
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
    await tester.tap(find.byKey(const Key('access-submit-button')));
    await tester.pumpAndSettle();

    expect(authenticatedProfile?.email, 'planner@campus.edu');
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

    await tester.tap(find.byKey(const Key('toggle-password-visibility')));
    await tester.pump();

    expect(tester.widget<TextField>(password).obscureText, isFalse);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
  });
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
    find.byKey(const Key('access-email-field')),
    'planner@campus.edu',
  );
  await tester.enterText(
    find.byKey(const Key('access-password-field')),
    password,
  );
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}
