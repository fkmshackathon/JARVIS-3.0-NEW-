import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synchro/main.dart';
import 'package:synchro/theme/theme_controller.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    appThemeMode.value = ThemeMode.light;
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

    await tester.tap(find.byTooltip('Sign out of local demo').first);
    await tester.pumpAndSettle();
    expect(find.text('Welcome to SYNCHRO.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('access-email-field')),
      'planner@campus.edu',
    );
    await tester.enterText(
      find.byKey(const Key('access-password-field')),
      'demo-password',
    );
    await tester.tap(find.byKey(const Key('access-submit-button')));
    await tester.pumpAndSettle();

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
  await tester.enterText(
    find.byKey(const Key('access-email-field')),
    'planner@campus.edu',
  );
  await tester.enterText(
    find.byKey(const Key('access-password-field')),
    'demo-password',
  );
  await tester.tap(find.byKey(const Key('access-submit-button')));
  await tester.pumpAndSettle();
}
