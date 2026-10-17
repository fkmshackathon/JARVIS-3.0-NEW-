import 'package:flutter_test/flutter_test.dart';
import 'package:synchro/state/timetable_generator.dart';

void main() {
  test('generates every configured lecture deterministically', () {
    final input = _input(
      timeSlots: _slots(<int>[0, 1], count: 2),
      subjects: const <ManualSubject>[
        ManualSubject(
          id: 'subject-dsa',
          name: 'Data Structures',
          code: 'DSA',
          lectureHours: 2,
        ),
      ],
      requirements: const <TimetableTeachingRequirement>[
        TimetableTeachingRequirement(
          id: 'req-dsa',
          subjectId: 'subject-dsa',
          batchId: 'batch-a',
          facultyId: 'faculty-a',
        ),
      ],
    );

    final first = TimetableGenerator().generate(input);
    final second = TimetableGenerator().generate(input);

    expect(first.status, TimetableGenerationStatus.generated);
    expect(first.generatedSessions, hasLength(2));
    expect(first.unassignedRequirements, isEmpty);
    expect(first.validationIssues.where((issue) => issue.isHard), isEmpty);
    expect(
      first.generatedSessions.toString(),
      second.generatedSessions.toString(),
    );
    expect(first.id, second.id);
  });

  test('a changed preference changes the generated placement', () {
    final base = _input(
      timeSlots: _slots(<int>[0, 1], count: 1),
      subjects: const <ManualSubject>[
        ManualSubject(
          id: 'subject-dsa',
          name: 'Data Structures',
          code: 'DSA',
          lectureHours: 1,
        ),
      ],
      requirements: const <TimetableTeachingRequirement>[
        TimetableTeachingRequirement(
          id: 'req-dsa',
          subjectId: 'subject-dsa',
          batchId: 'batch-a',
          facultyId: 'faculty-a',
        ),
      ],
    );
    final preferred = TimetableGenerator().generate(
      TimetableGenerationInput(
        faculty: base.faculty,
        rooms: base.rooms,
        batches: base.batches,
        subjects: base.subjects,
        timeSlots: base.timeSlots,
        requirements: const <TimetableTeachingRequirement>[
          TimetableTeachingRequirement(
            id: 'req-dsa',
            subjectId: 'subject-dsa',
            batchId: 'batch-a',
            facultyId: 'faculty-a',
            preferredDays: <int>[1],
          ),
        ],
      ),
    );
    final ordinary = TimetableGenerator().generate(base);

    expect(ordinary.isSuccess, isTrue);
    expect(preferred.isSuccess, isTrue);
    expect(ordinary.generatedSessions.single.day, 0);
    expect(preferred.generatedSessions.single.day, 1);
    expect(preferred.id, isNot(ordinary.id));
  });

  test('never overlaps faculty, room, or batch intervals', () {
    final result = TimetableGenerator().generate(
      _input(
        faculty: const <ManualFaculty>[
          ManualFaculty(
            id: 'faculty-a',
            name: 'A',
            department: 'IT',
            maxWeeklyHours: 12,
          ),
        ],
        rooms: const <ManualRoom>[
          ManualRoom(
            id: 'room-a',
            name: 'Room A',
            kind: 'classroom',
            capacity: 50,
            department: 'IT',
          ),
          ManualRoom(
            id: 'room-b',
            name: 'Room B',
            kind: 'classroom',
            capacity: 50,
            department: 'IT',
          ),
        ],
        batches: const <ManualBatch>[
          ManualBatch(id: 'batch-a', name: 'A', year: 1, size: 30),
          ManualBatch(id: 'batch-b', name: 'B', year: 2, size: 30),
        ],
        timeSlots: _slots(<int>[0, 1], count: 3),
        subjects: const <ManualSubject>[
          ManualSubject(id: 'subject-a', name: 'A', code: 'A', lectureHours: 2),
        ],
        requirements: const <TimetableTeachingRequirement>[
          TimetableTeachingRequirement(
            id: 'req-a',
            subjectId: 'subject-a',
            batchId: 'batch-a',
            facultyId: 'faculty-a',
          ),
          TimetableTeachingRequirement(
            id: 'req-b',
            subjectId: 'subject-a',
            batchId: 'batch-b',
            facultyId: 'faculty-a',
          ),
        ],
      ),
    );

    expect(result.isSuccess, isTrue, reason: result.message);
    for (var left = 0; left < result.sessions.length; left++) {
      for (var right = left + 1; right < result.sessions.length; right++) {
        final first = result.sessions[left];
        final second = result.sessions[right];
        if (first.day != second.day) continue;
        final overlap =
            first.startMinute < second.endMinute &&
            second.startMinute < first.endMinute;
        if (!overlap) continue;
        expect(first.facultyId == second.facultyId, isFalse);
        expect(first.roomId == second.roomId, isFalse);
        expect(first.batchId == second.batchId, isFalse);
      }
    }
  });

  test('allows adjacent endpoints to reuse a room', () {
    final result = TimetableGenerator().generate(
      _input(
        rooms: const <ManualRoom>[
          ManualRoom(
            id: 'room-a',
            name: 'Room A',
            kind: 'classroom',
            capacity: 50,
            department: 'IT',
          ),
        ],
        timeSlots: const <ManualTimeSlot>[
          ManualTimeSlot(day: 0, startMinute: 540, endMinute: 600),
          ManualTimeSlot(day: 0, startMinute: 600, endMinute: 660),
        ],
        subjects: const <ManualSubject>[
          ManualSubject(id: 'subject-a', name: 'A', code: 'A', lectureHours: 1),
        ],
        batches: const <ManualBatch>[
          ManualBatch(id: 'batch-a', name: 'A', year: 1, size: 30),
          ManualBatch(id: 'batch-b', name: 'B', year: 2, size: 30),
        ],
        requirements: const <TimetableTeachingRequirement>[
          TimetableTeachingRequirement(
            id: 'req-a',
            subjectId: 'subject-a',
            batchId: 'batch-a',
            facultyId: 'faculty-a',
          ),
          TimetableTeachingRequirement(
            id: 'req-b',
            subjectId: 'subject-a',
            batchId: 'batch-b',
            facultyId: 'faculty-b',
          ),
        ],
        faculty: const <ManualFaculty>[
          ManualFaculty(id: 'faculty-a', name: 'A', department: 'IT'),
          ManualFaculty(id: 'faculty-b', name: 'B', department: 'IT'),
        ],
      ),
    );

    expect(result.isSuccess, isTrue, reason: result.message);
    expect(
      result.sessions.map((session) => session.startMinute).toList(),
      containsAll(<int>[540, 600]),
    );
    expect(
      result.sessions.every((session) => session.roomId == 'room-a'),
      isTrue,
    );
  });

  test('places practical work only in compatible laboratories', () {
    final result = TimetableGenerator().generate(
      _input(
        timeSlots: const <ManualTimeSlot>[
          ManualTimeSlot(day: 0, startMinute: 540, endMinute: 600),
        ],
        rooms: const <ManualRoom>[
          ManualRoom(
            id: 'room-class',
            name: 'Classroom',
            kind: 'classroom',
            capacity: 50,
            department: 'IT',
          ),
          ManualRoom(
            id: 'room-lab',
            name: 'Lab',
            kind: 'laboratory',
            capacity: 50,
            department: 'IT',
          ),
        ],
        subjects: const <ManualSubject>[
          ManualSubject(
            id: 'subject-lab',
            name: 'Networks Lab',
            code: 'NL',
            isPractical: true,
            labHours: 1,
          ),
        ],
        requirements: const <TimetableTeachingRequirement>[
          TimetableTeachingRequirement(
            id: 'req-lab',
            subjectId: 'subject-lab',
            batchId: 'batch-a',
            facultyId: 'faculty-a',
          ),
        ],
      ),
    );

    expect(result.isSuccess, isTrue, reason: result.message);
    expect(result.sessions.single.type, ManualSessionType.practical);
    expect(result.sessions.single.roomId, 'room-lab');
  });

  test('supports a practical block across staggered teaching slots', () {
    final result = TimetableGenerator().generate(
      _input(
        timeSlots: const <ManualTimeSlot>[
          ManualTimeSlot(day: 0, startMinute: 540, endMinute: 590),
          ManualTimeSlot(day: 0, startMinute: 600, endMinute: 650),
        ],
        rooms: const <ManualRoom>[
          ManualRoom(
            id: 'room-lab',
            name: 'Lab',
            kind: 'lab',
            capacity: 50,
            department: 'IT',
          ),
        ],
        subjects: const <ManualSubject>[
          ManualSubject(
            id: 'subject-lab',
            name: 'Networks Lab',
            code: 'NL',
            isPractical: true,
            labHours: 2,
          ),
        ],
        requirements: const <TimetableTeachingRequirement>[
          TimetableTeachingRequirement(
            id: 'req-lab',
            subjectId: 'subject-lab',
            batchId: 'batch-a',
            facultyId: 'faculty-a',
          ),
        ],
      ),
    );

    expect(result.isSuccess, isTrue, reason: result.message);
    expect(result.sessions, hasLength(1));
    expect(result.sessions.single.startMinute, 540);
    expect(result.sessions.single.endMinute, 650);
  });

  test('does not place work over a break slot', () {
    final result = TimetableGenerator().generate(
      _input(
        timeSlots: const <ManualTimeSlot>[
          ManualTimeSlot(day: 0, startMinute: 540, endMinute: 600),
          ManualTimeSlot(
            day: 0,
            startMinute: 600,
            endMinute: 660,
            isBreak: true,
            label: 'Lunch',
          ),
          ManualTimeSlot(day: 0, startMinute: 660, endMinute: 720),
        ],
        subjects: const <ManualSubject>[
          ManualSubject(id: 'subject-a', name: 'A', code: 'A', lectureHours: 2),
        ],
        requirements: const <TimetableTeachingRequirement>[
          TimetableTeachingRequirement(
            id: 'req-a',
            subjectId: 'subject-a',
            batchId: 'batch-a',
            facultyId: 'faculty-a',
          ),
        ],
      ),
    );

    expect(result.isSuccess, isTrue, reason: result.message);
    expect(result.sessions, hasLength(2));
    expect(
      result.sessions.every(
        (session) => session.endMinute <= 600 || session.startMinute >= 660,
      ),
      isTrue,
    );
  });

  test('prevents a faculty clash across batch years', () {
    final result = TimetableGenerator().generate(
      _input(
        timeSlots: const <ManualTimeSlot>[
          ManualTimeSlot(day: 0, startMinute: 540, endMinute: 600),
          ManualTimeSlot(day: 0, startMinute: 600, endMinute: 660),
        ],
        batches: const <ManualBatch>[
          ManualBatch(id: 'batch-first', name: 'First Year', year: 1, size: 30),
          ManualBatch(id: 'batch-final', name: 'Final Year', year: 4, size: 30),
        ],
        subjects: const <ManualSubject>[
          ManualSubject(id: 'subject-a', name: 'A', code: 'A', lectureHours: 1),
        ],
        requirements: const <TimetableTeachingRequirement>[
          TimetableTeachingRequirement(
            id: 'req-first',
            subjectId: 'subject-a',
            batchId: 'batch-first',
            facultyId: 'faculty-a',
          ),
          TimetableTeachingRequirement(
            id: 'req-final',
            subjectId: 'subject-a',
            batchId: 'batch-final',
            facultyId: 'faculty-a',
          ),
        ],
      ),
    );

    expect(result.isSuccess, isTrue, reason: result.message);
    final facultySessions = result.sessions
        .where((session) => session.facultyId == 'faculty-a')
        .toList();
    expect(facultySessions, hasLength(2));
    expect(
      facultySessions[0].startMinute == facultySessions[1].startMinute,
      isFalse,
    );
  });

  test('explains an infeasible room requirement', () {
    final result = TimetableGenerator().generate(
      _input(
        timeSlots: const <ManualTimeSlot>[
          ManualTimeSlot(day: 0, startMinute: 540, endMinute: 600),
        ],
        rooms: const <ManualRoom>[
          ManualRoom(
            id: 'room-small',
            name: 'Small classroom',
            kind: 'classroom',
            capacity: 20,
            department: 'IT',
          ),
        ],
        batches: const <ManualBatch>[
          ManualBatch(id: 'batch-large', name: 'Large', year: 1, size: 40),
        ],
        subjects: const <ManualSubject>[
          ManualSubject(id: 'subject-a', name: 'A', code: 'A', lectureHours: 1),
        ],
        requirements: const <TimetableTeachingRequirement>[
          TimetableTeachingRequirement(
            id: 'req-a',
            subjectId: 'subject-a',
            batchId: 'batch-large',
            facultyId: 'faculty-a',
          ),
        ],
      ),
    );

    expect(result.status, TimetableGenerationStatus.infeasible);
    expect(result.generatedSessions, isEmpty);
    expect(result.unassignedRequirements, hasLength(1));
    expect(result.message.toLowerCase(), contains('room'));
    expect(
      result.validationIssues.any((issue) => issue.code == 'NO_ELIGIBLE_ROOM'),
      isTrue,
    );
  });
}

TimetableGenerationInput _input({
  List<ManualFaculty> faculty = const <ManualFaculty>[
    ManualFaculty(id: 'faculty-a', name: 'Faculty A', department: 'IT'),
    ManualFaculty(id: 'faculty-b', name: 'Faculty B', department: 'IT'),
  ],
  List<ManualRoom> rooms = const <ManualRoom>[
    ManualRoom(
      id: 'room-a',
      name: 'Room A',
      kind: 'classroom',
      capacity: 50,
      department: 'IT',
    ),
  ],
  List<ManualBatch> batches = const <ManualBatch>[
    ManualBatch(id: 'batch-a', name: 'Batch A', year: 1, size: 30),
  ],
  List<ManualSubject> subjects = const <ManualSubject>[],
  List<ManualTimeSlot> timeSlots = const <ManualTimeSlot>[],
  List<TimetableTeachingRequirement> requirements =
      const <TimetableTeachingRequirement>[],
}) => TimetableGenerationInput(
  faculty: faculty,
  rooms: rooms,
  batches: batches,
  subjects: subjects,
  timeSlots: timeSlots,
  requirements: requirements,
);

List<ManualTimeSlot> _slots(List<int> days, {required int count}) => [
  for (final day in days)
    for (var index = 0; index < count; index++)
      ManualTimeSlot(
        day: day,
        startMinute: 540 + index * 60,
        endMinute: 600 + index * 60,
      ),
];
