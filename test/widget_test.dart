import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synchro/main.dart';
import 'package:synchro/screens/app_shell.dart';
import 'package:synchro/theme/theme_controller.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    appThemeMode.value = ThemeMode.light;
  });

  testWidgets('starts with the local sign-in and sign-up pages', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(const SynchroApp());
    await tester.pumpAndSettle();

    expect(find.text('Welcome to SYNCHRO.'), findsOneWidget);
    expect(find.text('Local demo · No account required'), findsOneWidget);
    expect(find.byKey(const Key('access-name-field')), findsOneWidget);
    expect(find.byKey(const Key('access-college-field')), findsOneWidget);
    expect(find.byKey(const Key('access-email-field')), findsOneWidget);
    expect(find.byKey(const Key('access-password-field')), findsOneWidget);
    expect(find.text('Continue with Google'), findsNothing);

    await tester.tap(find.text('Create account').first);
    await tester.pumpAndSettle();
    expect(find.text('Create your local profile'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('local sign-up opens the workspace without verification', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(const SynchroApp());
    await tester.pumpAndSettle();
    await _completeAccess(tester, createAccount: true);

    expect(find.text('Your scheduling workspace'), findsOneWidget);
    expect(find.text('Welcome to SYNCHRO.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('local sign-out closes previously pushed workspace routes', (
    tester,
  ) async {
    _phone(tester);
    await _bootSignedIn(tester);
    final signOut = tester.widget<AppShell>(find.byType(AppShell)).onSignOut;
    final openLibrary = find.byKey(const Key('open-timetable-library-button'));
    await tester.dragUntilVisible(
      openLibrary,
      find.byType(Scrollable).first,
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    await tester.tap(openLibrary);
    await tester.pumpAndSettle();
    expect(find.text('My timetables'), findsOneWidget);

    signOut.call();
    await tester.pumpAndSettle();
    expect(find.text('Welcome to SYNCHRO.'), findsOneWidget);
    expect(find.text('My timetables'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens the four-area workspace without a backend', (
    tester,
  ) async {
    _phone(tester);
    await _bootSignedIn(tester);

    expect(find.text('Your scheduling workspace'), findsOneWidget);
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Setup'), findsOneWidget);
    expect(find.text('Generate & Timetable'), findsOneWidget);
    expect(find.text('Issues'), findsOneWidget);
    expect(find.text('No timetable has been generated yet.'), findsNothing);
  });

  testWidgets(
    'timetable is absent before generation and appears after generation',
    (tester) async {
      _phone(tester);
      await _bootSignedIn(tester);

      await tester.tap(find.text('Generate & Timetable'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Generate timetable'),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Status: not generated'), findsOneWidget);
      expect(find.text('Generate timetable'), findsOneWidget);

      await tester.tap(find.text('Generate timetable'));
      await tester.pumpAndSettle();

      expect(find.text('Generated timetable'), findsOneWidget);
      expect(find.textContaining('Generated '), findsWidgets);
      expect(find.text('No timetable sessions yet.'), findsNothing);
    },
  );

  testWidgets('opens the timetable library from Overview without a new tab', (
    tester,
  ) async {
    _phone(tester);
    await _bootSignedIn(tester);

    await tester.scrollUntilVisible(
      find.byKey(const Key('open-timetable-library-button')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(
      find.byKey(const Key('open-timetable-library-button')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('open-timetable-library-button')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('open-timetable-library-button')));
    await tester.pumpAndSettle();

    expect(find.text('My timetables'), findsOneWidget);
    expect(find.byKey(const Key('create-timetable-button')), findsOneWidget);
    expect(find.text('Demo timetable · local sample'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Your scheduling workspace'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Your scheduling workspace'), findsOneWidget);
  });

  testWidgets('signing out and back in preserves the local timetable draft', (
    tester,
  ) async {
    _phone(tester);
    await _bootSignedIn(tester);

    await tester.tap(find.text('Generate & Timetable'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Generate timetable'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Generate timetable'));
    await tester.pumpAndSettle();
    expect(find.text('Generated timetable'), findsOneWidget);

    final signOutFinder = find.byTooltip('Sign out');
    final demoSignOutFinder = find.byTooltip('Sign out of local demo');
    await tester.tap(
      signOutFinder.evaluate().isNotEmpty
          ? signOutFinder.first
          : demoSignOutFinder.first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Welcome to SYNCHRO.'), findsOneWidget);

    await _completeAccess(tester);

    await tester.tap(find.text('Generate & Timetable'));
    await tester.pumpAndSettle();
    expect(find.text('Generated timetable'), findsOneWidget);
  });

  testWidgets('setup exposes editable term rhythm and issues stays honest', (
    tester,
  ) async {
    _phone(tester);
    await _bootSignedIn(tester);

    await tester.tap(find.text('Setup'));
    await tester.pumpAndSettle();
    expect(find.text('Make the term fit'), findsOneWidget);
    expect(find.text('Working days'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Scheduling collections'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Scheduling collections'), findsOneWidget);

    await tester.tap(find.text('Issues'));
    await tester.pumpAndSettle();
    expect(find.text('No timetable generated yet'), findsOneWidget);
    expect(find.textContaining('server'), findsNothing);
  });
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _bootSignedIn(WidgetTester tester) async {
  await tester.pumpWidget(const SynchroApp());
  await tester.pumpAndSettle();
  expect(find.text('Welcome to SYNCHRO.'), findsOneWidget);
  await _completeAccess(tester);
}

Future<void> _completeAccess(
  WidgetTester tester, {
  bool createAccount = false,
}) async {
  if (createAccount) {
    await tester.tap(find.text('Create account').first);
    await tester.pumpAndSettle();
  }
  await tester.enterText(
    find.byKey(const Key('access-name-field')),
    'Aarya Dsouza',
  );
  await tester.enterText(
    find.byKey(const Key('access-college-field')),
    'College of Engineering & Arts',
  );
  await tester.enterText(
    find.byKey(const Key('access-email-field')),
    'planner@campus.edu',
  );
  await tester.enterText(
    find.byKey(const Key('access-password-field')),
    'demo-password',
  );
  await tester.ensureVisible(find.byKey(const Key('access-submit-button')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('access-submit-button')));
  await tester.pumpAndSettle();
}
