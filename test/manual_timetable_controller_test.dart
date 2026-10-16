import 'package:flutter_test/flutter_test.dart';
import 'package:synchro/state/manual_timetable_controller.dart';

void main() {
  test('manual draft supports add, edit, move, delete and save/discard', () {
    final controller = ManualTimetableController();
    final originalCount = controller.sessions.length;
    final first = controller.sessions.first;

    final added = controller.addSession(
      ManualSession(
        id: '',
        subjectId: controller.subjects.first.id,
        facultyId: controller.faculty.first.id,
        batchId: controller.batches.first.id,
        roomId: controller.rooms.first.id,
        day: 5,
        startMinute: 900,
        endMinute: 960,
      ),
    );
    expect(controller.sessions.length, originalCount + 1);
    expect(controller.hasUnsavedChanges, isTrue);

    expect(controller.editSession(added.id, note: 'Moved for seminar'), isTrue);
    expect(
      controller.moveSession(
        added.id,
        day: 4,
        startMinute: 960,
        endMinute: 1020,
      ),
      isTrue,
    );
    expect(controller.sessionById(added.id)?.day, 4);

    controller.saveDraft();
    expect(controller.hasUnsavedChanges, isFalse);
    expect(controller.deleteSession(first.id), isTrue);
    expect(controller.hasUnsavedChanges, isTrue);
    controller.discardDraft();
    expect(controller.sessionById(first.id), isNotNull);
    expect(controller.sessionById(added.id), isNotNull);
  });

  test('manual validation detects teacher, room and batch overlap', () {
    final controller = ManualTimetableController();
    final base = controller.sessions.first;
    final overlapping = base.copyWith(id: 'overlap');

    controller.addSession(overlapping);

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

  test(
    'workload and available room calculations use current draft sessions',
    () {
      final controller = ManualTimetableController();
      final teacher = controller.faculty.first;
      final workloadBefore = controller.workloadHoursFor(teacher.id);
      expect(workloadBefore, greaterThan(0));

      final roomChoices = controller.availableRoomsFor(
        day: 5,
        startMinute: 900,
        endMinute: 960,
      );
      expect(roomChoices, isNotEmpty);

      final room = roomChoices.first;
      controller.markRoomUnavailable(
        room.id,
        day: 5,
        startMinute: 900,
        endMinute: 960,
        reason: 'Construction',
      );
      expect(
        controller
            .availableRoomsFor(day: 5, startMinute: 900, endMinute: 960)
            .any((candidate) => candidate.id == room.id),
        isFalse,
      );

      final addedFaculty = ManualFaculty(
        id: 'faculty-demo-new',
        name: 'Demo Faculty',
        department: 'Information Technology',
        maxWeeklyHours: 12,
      );
      expect(controller.addFaculty(addedFaculty), isTrue);
      expect(
        controller.editFaculty(addedFaculty.copyWith(name: 'Updated Faculty')),
        isTrue,
      );
      expect(
        controller.facultyById('faculty-demo-new')?.name,
        'Updated Faculty',
      );

      final addedRoom = ManualRoom(
        id: 'room-demo-new',
        name: 'CR-Demo',
        kind: 'classroom',
        capacity: 45,
        department: 'Information Technology',
      );
      expect(controller.addRoom(addedRoom), isTrue);
      expect(controller.editRoom(addedRoom.copyWith(capacity: 50)), isTrue);
      expect(controller.roomById('room-demo-new')?.capacity, 50);
    },
  );

  test('absence, proxy and swap workflows remain local and reviewable', () {
    final controller = ManualTimetableController();
    final teacher = controller.faculty.first;
    final session = controller.sessions.firstWhere(
      (item) => item.facultyId == teacher.id,
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
    final swap = controller.requestSwap(session.id, targetFacultyId: proxy.id);
    expect(swap?.status, 'draft');
    expect(controller.swapRequests, hasLength(1));
  });
}
