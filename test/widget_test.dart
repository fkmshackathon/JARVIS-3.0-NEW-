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

  testWidgets('opens the local timetable workspace without a backend', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(const SynchroApp());
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    expect(find.text('Create timetable'), findsOneWidget);
    expect(find.text('DEMO SAMPLE · LOCAL DRAFT ONLY'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Timetable'), findsOneWidget);
    expect(find.text('Issues'), findsOneWidget);
  });

  testWidgets('manual editor exposes add class from an empty workflow', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(const SynchroApp());
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create timetable'));
    await tester.pumpAndSettle();

    expect(find.text('Manual timetable'), findsOneWidget);
    expect(find.text('Add class'), findsWidgets);
    expect(find.text('DEMO SAMPLE · LOCAL DRAFT ONLY'), findsOneWidget);

    await tester.tap(find.text('Add class').last);
    await tester.pumpAndSettle();

    expect(find.text('Add class'), findsWidgets);
    expect(find.text('Subject'), findsOneWidget);
    expect(find.text('Faculty'), findsOneWidget);
    expect(find.text('Batch'), findsWidgets);
    expect(find.text('Add to draft'), findsOneWidget);
  });

  testWidgets('issues destination is local and initially honest', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(const SynchroApp());
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Issues'));
    await tester.pumpAndSettle();

    expect(find.text('Manual issues'), findsOneWidget);
    expect(find.text('No local issues'), findsOneWidget);
    expect(find.textContaining('server validation'), findsNothing);
  });
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}
