import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synchro/screens/overview_screen.dart';
import 'package:synchro/screens/setup_screen.dart';
import 'package:synchro/state/manual_timetable_controller.dart';
import 'package:synchro/theme/synchro_theme.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('overview renders local term summary and hands off generation', (
    tester,
  ) async {
    _phone(tester);
    final controller = ManualTimetableController();
    var generated = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: SynchroTheme.light,
        home: OverviewScreen(
          controller: controller,
          onGenerate: () => generated = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('SHREE LR TIWARI COLLEGE OF ENGINEERING'), findsOneWidget);
    expect(find.text('Semester 2 · 2026'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('Faculty'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Faculty'), findsOneWidget);
    expect(find.text('Batches'), findsOneWidget);
    expect(find.text('Subjects'), findsOneWidget);
    expect(find.text('Rooms'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Generate timetable'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Generate timetable'), findsOneWidget);

    await tester.tap(find.text('Generate timetable'));
    expect(generated, isTrue);

    controller.dispose();
  });

  testWidgets('setup exposes editable term rhythm and completion callback', (
    tester,
  ) async {
    _phone(tester);
    final controller = ManualTimetableController();
    var completed = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: SynchroTheme.light,
        home: SetupScreen(
          controller: controller,
          onSetupComplete: () => completed = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Make the term fit'), findsOneWidget);
    expect(find.text('Working days'), findsWidgets);
    expect(find.text('Break'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Faculty'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Faculty'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Complete setup'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Complete setup'));
    await tester.pump();
    expect(find.text('Complete setup'), findsOneWidget);

    await tester.tap(find.text('Complete setup'));
    expect(completed, isTrue);

    controller.dispose();
  });
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}
