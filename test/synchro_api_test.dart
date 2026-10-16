import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:synchro/data/models.dart';
import 'package:synchro/data/synchro_api.dart';
import 'package:synchro/state/scheduling_controller.dart';

/// A campus small enough to read, shaped exactly like `/sample-campus`.
final Map<String, dynamic> samplePayload = {
  'slots': [
    {'day': 0, 'index': 0, 'start': 555, 'end': 615},
    {'day': 0, 'index': 1, 'start': 615, 'end': 675},
    {'day': 1, 'index': 0, 'start': 555, 'end': 615},
    {'day': 1, 'index': 1, 'start': 615, 'end': 675},
  ],
  'break_slots': [
    [0, 1]
  ],
  'faculty': [
    {
      'id': 'fac0',
      'name': 'Kavita Nair',
      'department': 'IT',
      'max_weekly_hours': 20,
      'unavailable': [],
      'qualified_subjects': [],
    }
  ],
  'rooms': [
    {'id': 'cr0', 'name': 'CR-100', 'kind': 'classroom', 'capacity': 70, 'department': 'IT', 'borrowable': true, 'closed': []}
  ],
  'batches': [
    {'id': 'y1d1a', 'name': 'SEIT-Y1-D1-A', 'year': 1, 'size': 40, 'division_id': 'y1d1', 'stagger_group': 0}
  ],
  'subjects': [
    {'id': 'sub0', 'name': 'Data Structures', 'lecture_hours': 2, 'lab_hours': 0, 'lab_duration_slots': 1, 'department': 'IT'}
  ],
  'requirements': [
    {'batch_id': 'y1d1a', 'subject_id': 'sub0', 'faculty_id': 'fac0', 'department': 'IT', 'lecture_hours': null, 'lab_hours': null}
  ],
};

final Map<String, dynamic> sampleSummary = {
  'periods': {'total': 4, 'usable': 3, 'break': 1, 'days': 2},
  'demand': {'sessions': 2, 'lecture_periods': 2, 'lab_periods': 0},
  'supply': {
    'classrooms': 1,
    'laboratories': 0,
    'borrowable_from_other_departments': 0,
    'classroom_periods': 3,
    'laboratory_periods': 0,
  },
  'faculty': [
    {
      'id': 'fac0',
      'name': 'Kavita Nair',
      'department': 'IT',
      'sessions': 2,
      'assigned_hours': 2,
      'max_weekly_hours': 20,
      'available_periods': 2,
      'overloaded': false,
      'no_capacity': false,
      'subjects': ['sub0'],
    }
  ],
  'batches': [
    {'id': 'y1d1a', 'name': 'SEIT-Y1-D1-A', 'year': 1, 'division_id': 'y1d1', 'size': 40, 'lecture_hours': 2, 'lab_periods': 0, 'subjects': ['sub0']}
  ],
  'rooms': [
    {'id': 'cr0', 'name': 'CR-100', 'kind': 'classroom', 'capacity': 70, 'department': 'IT', 'borrowable': true, 'closed_periods': 0, 'usable_periods': 3}
  ],
  'warnings': <String>[],
  'blocker': null,
  'can_generate': true,
};

Map<String, dynamic> assignment(String id, int day, int index) => {
      'session_id': id,
      'batch_id': 'y1d1a',
      'subject_id': 'sub0',
      'faculty_id': 'fac0',
      'room_id': 'cr0',
      'day': day,
      'index': index,
      'start': 555 + index * 60,
      'end': 615 + index * 60,
      'is_lab': false,
      'room_kind': 'classroom',
      'department': 'IT',
    };

SynchroApi apiReturning(int statusCode, String body, {void Function(http.Request)? onTap}) => SynchroApi(
      baseUrl: 'http://backend.test',
      client: MockClient((request) async {
        onTap?.call(request);
        return http.Response(body, statusCode, headers: {'content-type': 'application/json'});
      }),
    );

void main() {
  test('campus payload parses into the client model', () {
    final campus = Campus.fromPayload('Demo', samplePayload);

    expect(campus.slots, hasLength(4));
    expect(campus.dayNumbers, [0, 1]);
    expect(campus.periodIndexes, [0, 1]);
    expect(campus.isBreak(0, 1), isTrue);
    expect(campus.isBreak(0, 0), isFalse);
    expect(campus.subjectName('sub0'), 'Data Structures');
    expect(campus.facultyName('fac0'), 'Kavita Nair');
    // An id the campus does not know falls back to the id rather than throwing.
    expect(campus.roomName('nope'), 'nope');
    expect(formatMinutes(555), '09:15');
    expect(dayName(0), 'Monday');
  });

  test('a FastAPI error detail becomes a readable message with its status', () async {
    final api = apiReturning(422, '{"detail":"faculty[0]: \'name\' is required"}');
    await expectLater(
      () async => throw await api.health(),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 422)),
    );
  });

  test('an unreachable backend reports a transport failure, not an empty timetable', () async {
    final api = SynchroApi(
      baseUrl: 'http://10.0.2.2:8000',
      client: MockClient((_) async => throw http.ClientException('no route to host')),
    );
    addTearDown(api.close);

    Object? caught;
    try {
      await api.health();
    } on ApiException catch (e) {
      caught = e;
    }
    expect(caught, isA<ApiException>());
    expect((caught as ApiException).isTransport, isTrue);
    expect(caught.message, contains('10.0.2.2:8000'));
  });

  test('the solver response parses into assignments, verdicts and utilisation', () async {
    final api = apiReturning(
      200,
      jsonEncode({
        'run_id': 7,
        'campus_id': 'demo',
        'status': 'solved',
        'solver_status': 'OPTIMAL',
        'soft_cost': 360,
        'wall_time_ms': 7774,
        'message': '',
        'assignments': [assignment('s0', 0, 0), assignment('s1', 1, 0)],
        'violations': [
          {'code': 'ROOM_CLASH', 'message': 'CR-100 double-booked', 'refs': ['s0', 's1']}
        ],
        'publishable': false,
        'utilisation': {
          'rooms_in_use': 1,
          'rooms_on_campus': 1,
          'borrowed_periods': 0,
          'busiest': [
            {'room_id': 'cr0', 'name': 'CR-100', 'sessions': 2}
          ],
        },
      }),
    );
    addTearDown(api.close);

    final result = GenerationResult.fromMap(await api.generate('demo', timeLimitSeconds: 10, randomSeed: 1));

    expect(result.solved, isTrue);
    expect(result.publishable, isFalse, reason: 'a clash means the server said no');
    expect(result.assignments, hasLength(2));
    expect(result.violations.single.code, 'ROOM_CLASH');
    expect(result.utilisation!.roomsInUse, 1);
  });

  test('the controller loads, saves and previews the campus it was given', () async {
    final requests = <String>[];
    final api = SynchroApi(
      baseUrl: 'http://backend.test',
      client: MockClient((request) async {
        requests.add('${request.method} ${request.url.path}');
        switch (request.url.path) {
          case '/health':
            return _json({'status': 'ok'});
          case '/sample-campus':
            return _json({'name': 'SLRTCE demo semester', 'campus': samplePayload, 'summary': sampleSummary});
          case '/campuses/demo-slrtce':
            expect(request.method, 'PUT');
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(body['name'], 'SLRTCE demo semester');
            expect(jsonMap(body['campus'])['slots'], hasLength(4));
            return _json({'id': 'demo-slrtce', 'name': 'SLRTCE demo semester', 'campus': samplePayload, 'summary': sampleSummary});
          case '/campuses/demo-slrtce/preview':
            return _json({'can_generate': true, 'blocker': null, 'summary': sampleSummary});
          default:
            return _json({'detail': 'unexpected ${request.url.path}'}, 404);
        }
      }),
    );
    addTearDown(api.close);

    final controller = SchedulingController(api: api);
    await controller.loadDemoCampus();

    expect(controller.phase, LinkPhase.ready);
    expect(controller.hasCampus, isTrue);
    expect(controller.canGenerate, isTrue);
    expect(controller.summary!.usablePeriods, 3);
    expect(controller.batchId, 'y1d1a');
    expect(requests, contains('PUT /campuses/demo-slrtce'));
  });

  test('a blocker from preflight stops the controller claiming it can generate', () async {
    final blocked = Map<String, dynamic>.from(sampleSummary)
      ..['can_generate'] = false
      ..['blocker'] = '36 laboratory blocks are required, but only 30 fit.';
    final api = SynchroApi(
      baseUrl: 'http://backend.test',
      client: MockClient((request) async {
        if (request.url.path == '/health') return _json({'status': 'ok'});
        if (request.url.path == '/sample-campus') {
          return _json({'name': 'Demo', 'campus': samplePayload, 'summary': blocked});
        }
        if (request.url.path == '/campuses/demo-slrtce') {
          return _json({'id': 'demo-slrtce', 'name': 'Demo', 'campus': samplePayload, 'summary': blocked});
        }
        if (request.url.path.endsWith('/preview')) {
          return _json({'can_generate': false, 'blocker': blocked['blocker'], 'summary': blocked});
        }
        return _json({'detail': 'unexpected'}, 404);
      }),
    );
    addTearDown(api.close);

    final controller = SchedulingController(api: api);
    await controller.loadDemoCampus();

    expect(controller.canGenerate, isFalse);
    expect(controller.summary!.blocker, contains('only 30 fit'));
  });
}

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});
