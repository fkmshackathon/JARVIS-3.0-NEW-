import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synchro/main.dart';
import 'package:synchro/screens/architecture_screen.dart';
import 'package:synchro/screens/manual_timetable_screen.dart';
import 'package:synchro/screens/timetable_operations_screen.dart';
import 'package:synchro/state/assistant_controller.dart';
import 'package:synchro/state/manual_timetable_controller.dart';
import 'package:synchro/theme/synchro_theme.dart';
import 'package:synchro/widgets/assistant_panel.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final width in [375.0, 390.0, 430.0, 768.0, 1440.0]) {
    testWidgets('Round 2 panels fit ${width.toInt()}px without layout errors', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final workspace = ManualTimetableController()..generateTimetable();
      final assistant = AssistantController()..configure(useLive: false);
      for (final screen in [
        const ArchitectureScreen(),
        Scaffold(body: TimetableOperationsScreen(controller: workspace)),
        ManualTimetableScreen(controller: workspace),
        Scaffold(
          body: AssistantPanel(
            assistant: assistant,
            workspace: workspace,
            page: 'Issues',
            onNavigate: (_) {},
          ),
        ),
      ]) {
        await tester.pumpWidget(
          MaterialApp(theme: SynchroTheme.light, home: screen),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$screen at $width');
      }
      await tester.tap(find.text('How do I generate a timetable?'));
      await tester.pumpAndSettle();
      expect(assistant.messages.last.isUser, isFalse);
      expect(assistant.messages.last.live, isFalse);
      expect(assistant.messages.last.text, contains('Setup'));
      await tester.pumpWidget(const SizedBox.shrink());
      assistant.dispose();
      workspace.dispose();
    });
  }

  testWidgets(
    'global assistant opens, closes, preserves history and architecture is accessible',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const SynchroApp());
      await tester.pumpAndSettle();
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
      await tester.tap(find.byKey(const Key('assistant-launcher')));
      await tester.pumpAndSettle();
      expect(find.text('SYNCHRO Assistant'), findsOneWidget);
      await tester.tap(find.byTooltip('Close assistant'));
      await tester.pumpAndSettle();
      expect(find.text('SYNCHRO Assistant'), findsNothing);
      await tester.tap(find.text('Architecture'));
      await tester.pumpAndSettle();
      expect(find.text('System architecture'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
