import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synchro/state/manual_timetable_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('workspace starts empty and generates from configured requirements', () {
    final controller = ManualTimetableController();

    expect(controller.sessions, isEmpty);
    expect(controller.hasGeneratedTimetable, isFalse);
    expect(controller.requirements, isNotEmpty);

    final result = controller.generateTimetable();

    expect(result.isSuccess, isTrue, reason: result.message);
    expect(result.generatedSessions, isNotEmpty);
    expect(result.unassignedRequirements, isEmpty, reason: result.message);
    expect(result.hardIssues, isEmpty);
    expect(controller.hasGeneratedTimetable, isTrue);
    expect(controller.sessions.length, result.generatedSessions.length);
  });

  test(
    'manual edit invalidates the latest validation and can be discarded',
    () {
      final controller = ManualTimetableController();
      controller.generateTimetable();
      final original = controller.sessions.first;
      final moved = original.copyWith(day: 5, startMinute: 900, endMinute: 950);

      expect(controller.editSession(moved), isTrue);
      expect(controller.hasUnsavedChanges, isTrue);
      expect(controller.hasLocalValidation, isFalse);
      expect(controller.sessionById(original.id)?.day, 5);

      expect(controller.validate(), isEmpty);
      expect(controller.hasLocalValidation, isTrue);

      controller.discardDraft();
      expect(controller.sessionById(original.id)?.day, original.day);
    },
  );

  test('local save and restore preserve the generated timetable', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final source = ManualTimetableController();
    source.generateTimetable();
    final edited = source.sessions.first.copyWith(note: 'Moved for seminar');
    source.editSession(edited);
    source.validate();
    await source.saveDraft();

    final restored = ManualTimetableController();
    await restored.restoreDraft();

    expect(restored.hasGeneratedTimetable, isTrue);
    expect(restored.sessions.length, source.sessions.length);
    expect(restored.sessionById(edited.id)?.note, 'Moved for seminar');
    expect(restored.isRestoring, isFalse);
  });

  test(
    'malformed local storage leaves the clean ungenerated workspace usable',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'synchro.workspace.v2': '{not valid json',
      });
      final controller = ManualTimetableController();

      await controller.restoreDraft();

      expect(controller.sessions, isEmpty);
      expect(controller.requirements, isNotEmpty);
      expect(controller.hasGeneratedTimetable, isFalse);
      expect(controller.isRestoring, isFalse);
    },
  );

  test('validation detects teacher, room, and batch interval overlaps', () {
    final controller = ManualTimetableController(
      sessions: const <ManualSession>[
        ManualSession(
          id: 'first',
          subjectId: 'subject-mathematics',
          facultyId: 'faculty-kavita',
          batchId: 'batch-fy-it-a',
          roomId: 'room-cr-101',
          day: 0,
          startMinute: 540,
          endMinute: 600,
        ),
        ManualSession(
          id: 'second',
          subjectId: 'subject-mathematics',
          facultyId: 'faculty-kavita',
          batchId: 'batch-fy-it-a',
          roomId: 'room-cr-101',
          day: 0,
          startMinute: 590,
          endMinute: 650,
        ),
      ],
    );

    controller.validate();

    expect(
      controller.hardConflicts.any((issue) => issue.code == 'TEACHER_OVERLAP'),
      isTrue,
    );
    expect(
      controller.hardConflicts.any((issue) => issue.code == 'ROOM_OVERLAP'),
      isTrue,
    );
    expect(
      controller.hardConflicts.any((issue) => issue.code == 'BATCH_OVERLAP'),
      isTrue,
    );
  });

  test('adjacent sessions are not reported as overlaps', () {
    final controller = ManualTimetableController(
      sessions: const <ManualSession>[
        ManualSession(
          id: 'first',
          subjectId: 'subject-mathematics',
          facultyId: 'faculty-kavita',
          batchId: 'batch-fy-it-a',
          roomId: 'room-cr-101',
          day: 0,
          startMinute: 540,
          endMinute: 590,
        ),
        ManualSession(
          id: 'second',
          subjectId: 'subject-mathematics',
          facultyId: 'faculty-kavita',
          batchId: 'batch-fy-it-a',
          roomId: 'room-cr-101',
          day: 0,
          startMinute: 590,
          endMinute: 640,
        ),
      ],
    );

    controller.validate();

    expect(
      controller.hardConflicts.where((issue) => issue.code.endsWith('OVERLAP')),
      isEmpty,
    );
  });

  test(
    'workload, room availability, absence, proxy, and swap remain local',
    () {
      final controller = ManualTimetableController();
      controller.generateTimetable();
      final teacher = controller.faculty.first;
      final session = controller.sessions.firstWhere(
        (item) => item.facultyId == teacher.id,
      );

      expect(controller.workloadHoursFor(teacher.id), greaterThan(0));
      expect(
        controller
            .availableRoomsFor(
              day: session.day,
              startMinute: session.startMinute,
              endMinute: session.endMinute,
              excludeSessionId: session.id,
            )
            .any((room) => room.id == session.roomId),
        isTrue,
      );

      controller.handleAbsence(
        teacher.id,
        day: session.day,
        startMinute: session.startMinute,
        endMinute: session.endMinute,
      );
      expect(
        controller.hardConflicts.any(
          (issue) => issue.code == 'TEACHER_UNAVAILABLE',
        ),
        isTrue,
      );

      final proxy = controller.createProxy(teacher.id);
      expect(proxy.isProxy, isTrue);
      final swap = controller.requestSwap(
        session.id,
        targetFacultyId: proxy.id,
      );
      expect(swap?.status, 'draft');
    },
  );
}
