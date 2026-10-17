import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synchro/screens/timetable_library_screen.dart';
import 'package:synchro/state/timetable_library_controller.dart';
import 'package:synchro/theme/synchro_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
    'creates, duplicates, renames, deletes, switches, and persists library rows',
    (tester) async {
      final library = TimetableLibraryController();
      addTearDown(library.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: SynchroTheme.light,
          home: TimetableLibraryScreen(library: library),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No timetables saved'), findsOneWidget);

      await _create(tester, name: 'First timetable', term: 'Fall 2026');
      await _create(tester, name: 'Second timetable', term: 'Spring 2027');
      expect(find.text('First timetable'), findsOneWidget);
      expect(find.text('Second timetable'), findsOneWidget);
      expect(library.records, hasLength(2));

      final first = library.records.firstWhere(
        (record) => record.name == 'First timetable',
      );
      final second = library.records.firstWhere(
        (record) => record.name == 'Second timetable',
      );
      library.workspace.updateSetup(institution: 'Second Institute');
      expect(library.switchTo(first.id), isTrue);
      library.workspace.updateSetup(institution: 'First Institute');
      expect(library.switchTo(second.id), isTrue);
      expect(library.workspace.institutionName, 'Second Institute');
      expect(library.switchTo(first.id), isTrue);
      expect(library.workspace.institutionName, 'First Institute');

      await _openActions(tester, 'First timetable');
      await tester.tap(find.text('Duplicate').last);
      await tester.pumpAndSettle();
      expect(find.text('First timetable copy'), findsOneWidget);
      expect(library.records, hasLength(3));

      await _openActions(tester, 'First timetable copy');
      await tester.tap(find.text('Rename').last);
      await tester.pumpAndSettle();
      final renameField = find.byType(TextField).last;
      await tester.enterText(renameField, 'Renamed duplicate');
      await tester.tap(find.text('Rename').last);
      await tester.pumpAndSettle();
      expect(find.text('Renamed duplicate'), findsOneWidget);

      await _openActions(tester, 'Renamed duplicate');
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      expect(find.text('Delete “Renamed duplicate”?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Renamed duplicate'), findsOneWidget);

      await _openActions(tester, 'Renamed duplicate');
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete timetable'));
      await tester.pumpAndSettle();
      expect(find.text('Renamed duplicate'), findsNothing);
      expect(library.records, hasLength(2));

      await library.flush();
      final reloaded = TimetableLibraryController();
      addTearDown(reloaded.dispose);
      await reloaded.restore();
      expect(reloaded.records, hasLength(2));
      expect(
        reloaded.records.map((record) => record.name),
        containsAll(<String>['First timetable', 'Second timetable']),
      );
      expect(reloaded.workspace.institutionName, 'First Institute');
    },
  );
}

Future<void> _create(
  WidgetTester tester, {
  required String name,
  required String term,
}) async {
  await tester.tap(find.byKey(const Key('create-timetable-button')));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const Key('new-timetable-name-field')),
    name,
  );
  await tester.enterText(
    find.byKey(const Key('new-timetable-term-field')),
    term,
  );
  await tester.tap(find.byKey(const Key('confirm-create-timetable-button')));
  await tester.pumpAndSettle();
}

Future<void> _openActions(WidgetTester tester, String name) async {
  await tester.tap(find.byTooltip('Timetable actions for $name'));
  await tester.pumpAndSettle();
}
