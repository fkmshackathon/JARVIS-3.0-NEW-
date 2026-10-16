import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:synchro/data/synchro_api.dart';
import 'package:synchro/main.dart';
import 'package:synchro/state/scheduling_controller.dart';
import 'package:synchro/theme/theme_controller.dart';
import 'package:synchro/theme/tokens.dart';

import 'synchro_api_test.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    // The theme is one app-wide notifier, so each test starts on the cream page.
    appThemeMode.value = ThemeMode.light;
  });

  testWidgets('an unreachable backend is reported, never papered over', (tester) async {
    _phone(tester);
    final api = SynchroApi(
      baseUrl: 'http://10.0.2.2:8000',
      client: MockClient((_) async => throw http.ClientException('connect failed')),
    );
    final controller = SchedulingController(api: api);

    await tester.pumpWidget(SynchroApp(controller: controller));
    await tester.pump();

    expect(find.text('Backend unreachable'), findsOneWidget);
    expect(find.textContaining('uvicorn app.main:app'), findsWidgets);
    expect(find.text('Retry connection'), findsOneWidget);
    expect(find.byIcon(Icons.bolt), findsNothing, reason: 'no timetable without the solver');
  });

  testWidgets('a solved run draws the grid the server returned', (tester) async {
    _phone(tester);
    final controller = _loadedController(assignments: [
      assignment('s0', 0, 0),
      assignment('s1', 1, 0),
      labAssignment('s2', 1, 1),
    ], violations: const []);

    await _bootIntoShell(tester, controller);

    await _generate(tester);

    expect(find.text('Timetable produced'), findsOneWidget);
    expect(find.text('Data Structures'), findsWidgets);
    expect(find.text('CR-100'), findsWidgets);
    expect(find.text('PUBLISHABLE'), findsOneWidget);
    expect(find.text('BREAK'), findsWidgets);
  });

  testWidgets('the conflict panel reports the validator rather than guessing', (tester) async {
    _phone(tester);
    final controller = _loadedController(assignments: [
      assignment('s0', 0, 0),
      assignment('s1', 0, 0),
    ], violations: [
      {
        'code': 'FACULTY_CLASH',
        'message': "faculty 'fac0' double-booked at day 0 period 0 by s0, s1.",
        'refs': ['s0', 's1'],
      }
    ]);

    await _bootIntoShell(tester, controller);

    await _generate(tester);
    await tester.tap(find.text('Conflicts'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('1 conflicts'), findsOneWidget);
    expect(find.text('A professor is in two places at once'), findsOneWidget);
    expect(find.text('NOT PUBLISHABLE'), findsOneWidget);
    expect(find.textContaining('s0 · s1'), findsOneWidget);
  });

  testWidgets('tapping a session opens its detail with the validator verdict', (tester) async {
    _phone(tester);
    final controller = _loadedController(assignments: [
      assignment('s0', 0, 0),
    ], violations: const []);

    await _bootIntoShell(tester, controller);
    await _generate(tester);

    final cell = find.text('Data Structures').first;
    await tester.scrollUntilVisible(cell, 200, scrollable: find.byType(Scrollable).first);
    await tester.pump();
    await tester.tap(cell);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Kavita Nair'), findsWidgets);
    expect(find.text('70 seats for 40 students'), findsOneWidget);
    expect(find.textContaining('found no problem in this session'), findsOneWidget);
  });

  testWidgets('the verdict tones stay legible after switching to dark', (tester) async {
    _phone(tester);
    final controller = _loadedController(assignments: [
      assignment('s0', 0, 0),
    ], violations: const []);

    await _bootIntoShell(tester, controller);
    await _generate(tester);

    final chip = find.text('VALIDATOR CLEAN');
    final onCream = tester.widget<Text>(chip).style!.color;
    expect(onCream, SynchroColors.ok, reason: 'the cream page keeps the deep verdict green');

    await tester.tap(find.byTooltip('Switch to dark'));
    await tester.pump();
    await tester.pump(SynchroMotion.standard);

    expect(Theme.of(tester.element(chip)).brightness, Brightness.dark);
    expect(tester.widget<Text>(chip).style!.color, SynchroColors.okOnNavy,
        reason: 'the same hue would sink into navy, so the dark scheme lifts it');
    expect(tester.takeException(), isNull, reason: 'the strip must refit, not overflow');
    expect(find.text('PUBLISHABLE'), findsOneWidget);
  });

  testWidgets('a preflight blocker disables generation instead of pretending', (tester) async {
    _phone(tester);
    final controller = _loadedController(
      assignments: const [],
      violations: const [],
      blocker: '36 laboratory blocks of 2 consecutive periods are required, but the 3 suitable '
          'laboratories fit at most 30.',
    );

    await _bootIntoShell(tester, controller);
    await tester.tap(find.text('Timetable'));
    await tester.pump();

    expect(find.textContaining('laboratories fit at most 30'), findsWidgets);
    final button = tester.widget<FilledButton>(
      find.ancestor(of: find.text('Generate timetable'), matching: find.byType(FilledButton)),
    );
    expect(button.onPressed, isNull);
  });
}

/// Opens the Timetable tab and asks the solver for a run, letting the scripted
/// backend's futures settle before the assertions read the grid.
Future<void> _generate(WidgetTester tester) async {
  await tester.tap(find.text('Timetable'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.widgetWithText(FilledButton, 'Generate timetable').first);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 60));
  await tester.pump(const Duration(milliseconds: 400));
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _bootIntoShell(WidgetTester tester, SchedulingController controller) async {
  await tester.pumpWidget(SynchroApp(controller: controller));
  // The splash holds the brand for its own beat before handing over.
  await tester.pump(const Duration(milliseconds: 1700));
  await tester.pump(const Duration(milliseconds: 400));
}

Map<String, dynamic> labAssignment(String id, int day, int index) => {
      'session_id': id,
      'batch_id': 'y1d1a',
      'subject_id': 'sub0',
      'faculty_id': 'fac0',
      'room_id': 'cr0',
      'day': day,
      'index': index,
      'start': 555 + index * 60,
      'end': 675 + index * 60,
      'is_lab': true,
      'room_kind': 'laboratory',
      'department': 'IT',
    };

/// A controller whose campus, summary and timetable all come from one scripted
/// backend, so the UI is exercised against the real wire format.
SchedulingController _loadedController({
  required List<Map<String, dynamic>> assignments,
  required List<Map<String, dynamic>> violations,
  String? blocker,
}) {
  final summary = Map<String, dynamic>.from(sampleSummary)
    ..['can_generate'] = blocker == null
    ..['blocker'] = blocker;
  final campus = Map<String, dynamic>.from(samplePayload);

  final api = SynchroApi(
    baseUrl: 'http://backend.test',
    client: MockClient((request) async {
      switch (request.url.path) {
        case '/health':
          return _json({'status': 'ok'});
        case '/sample-campus':
          return _json({'name': 'SLRTCE demo semester', 'campus': campus, 'summary': summary});
        case '/campuses/demo-slrtce':
          return _json({'id': 'demo-slrtce', 'name': 'SLRTCE demo semester', 'campus': campus, 'summary': summary});
        case '/campuses/demo-slrtce/preview':
          return _json({'can_generate': blocker == null, 'blocker': blocker, 'summary': summary});
        case '/campuses/demo-slrtce/generate':
          return _json({
            'run_id': 12,
            'campus_id': 'demo-slrtce',
            'status': 'solved',
            'solver_status': 'OPTIMAL',
            'soft_cost': 4,
            'wall_time_ms': 913,
            'message': '',
            'assignments': assignments,
            'violations': violations,
            'publishable': violations.isEmpty,
            'utilisation': {
              'rooms_in_use': 1,
              'rooms_on_campus': 1,
              'borrowed_periods': 0,
              'busiest': [
                {'room_id': 'cr0', 'name': 'CR-100', 'sessions': assignments.length}
              ],
            },
          });
        case '/campuses/demo-slrtce/runs':
          return _json({
            'campus_id': 'demo-slrtce',
            'runs': [
              {
                'id': 12,
                'created_at': '2026-10-16T09:00:00+00:00',
                'status': 'solved',
                'solver_status': 'OPTIMAL',
                'soft_cost': 4,
                'wall_time_ms': 913,
                'message': '',
                'session_count': assignments.length,
              }
            ],
          });
      }
      return _json({'detail': 'unexpected ${request.url.path}'}, 404);
    }),
  );
  addTearDown(api.close);
  return SchedulingController(api: api);
}

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});
