import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synchro/state/manual_timetable_controller.dart';
import 'package:synchro/state/timetable_library_controller.dart';
import 'package:synchro/state/timetable_operations.dart';
import 'package:synchro/state/timetable_view.dart';

ManualTimetableController fixture({bool substitute = true}) {
  final workspace = ManualTimetableController.blank(
    faculty: [
      const ManualFaculty(
        id: 'teacher-a',
        name: 'Teacher A',
        department: 'IT',
        qualifiedSubjectIds: ['math'],
      ),
      ManualFaculty(
        id: 'teacher-b',
        name: 'Teacher B',
        department: 'IT',
        qualifiedSubjectIds: substitute ? ['math'] : [],
      ),
      const ManualFaculty(
        id: 'teacher-busy',
        name: 'Busy',
        department: 'IT',
        qualifiedSubjectIds: ['math'],
      ),
    ],
    subjects: const [
      ManualSubject(id: 'math', name: 'Mathematics', code: 'MATH'),
    ],
    batches: const [
      ManualBatch(id: 'a', name: 'IT A', year: 1, size: 20),
      ManualBatch(id: 'b', name: 'IT B', year: 2, size: 20),
    ],
    rooms: const [
      ManualRoom(
        id: 'r1',
        name: 'Room 1',
        kind: 'classroom',
        capacity: 30,
        department: 'IT',
        equipment: ['projector'],
      ),
      ManualRoom(
        id: 'r2',
        name: 'Room 2',
        kind: 'classroom',
        capacity: 30,
        department: 'IT',
      ),
      ManualRoom(
        id: 'lab',
        name: 'Lab',
        kind: 'laboratory',
        capacity: 30,
        department: 'IT',
      ),
    ],
    sessions: const [
      ManualSession(
        id: 's1',
        subjectId: 'math',
        facultyId: 'teacher-a',
        batchId: 'a',
        roomId: 'r1',
        day: 0,
        startMinute: 540,
        endMinute: 590,
      ),
      ManualSession(
        id: 'busy',
        subjectId: 'math',
        facultyId: 'teacher-busy',
        batchId: 'b',
        roomId: 'lab',
        day: 0,
        startMinute: 540,
        endMinute: 590,
      ),
    ],
  );
  workspace.updateSetup(institution: 'Test campus');
  return workspace;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('absence excludes busy/unqualified teachers, requires confirmation and updates all projections', () {
    final workspace = fixture();
    final tools = TimetableOperations(workspace);
    expect(
      tools.eligibleSubstitutes(workspace.sessions.first).map((f) => f.id),
      ['teacher-b'],
    );
    final proposal = tools.absence(facultyId: 'teacher-a', days: {0}).single;
    expect(
      proposal.status,
      TimetableProposalStatus.validated,
      reason: proposal.errors.join('\n'),
    );
    expect(tools.apply(proposal, confirmed: false), isFalse);
    expect(workspace.sessionById('s1')!.facultyId, 'teacher-a');
    expect(tools.apply(proposal, confirmed: true), isTrue);
    expect(workspace.sessionById('s1')!.facultyId, 'teacher-b');
    expect(workspace.sessionById('busy')!.facultyId, 'teacher-busy');
    for (final filter in const [
      TimetableViewFilter(kind: TimetableViewKind.master),
      TimetableViewFilter(department: 'Information Technology'),
      TimetableViewFilter(batchId: 'a'),
    ]) {
      expect(
        filter.sessions(workspace).firstWhere((s) => s.id == 's1').facultyId,
        'teacher-b',
      );
    }
    expect(workspace.hardConflicts, isEmpty);
    expect(workspace.changeAudit.single['status'], 'applied');
    expect(workspace.undoLastLocalChange(), isTrue);
    expect(workspace.sessionById('s1')!.facultyId, 'teacher-a');
    expect(workspace.changeAudit.single['status'], 'undone');
  });

  test(
    'no eligible substitute is an honest infeasible proposal with no mutation',
    () {
      final workspace = fixture(substitute: false);
      final before = workspace.schedulingFingerprint;
      final tools = TimetableOperations(workspace);
      final proposal = tools.absence(facultyId: 'teacher-a', days: {0}).single;
      expect(proposal.status, TimetableProposalStatus.infeasible);
      expect(proposal.errors.join(' '), contains('No free, authorised'));
      expect(tools.apply(proposal, confirmed: true), isFalse);
      expect(workspace.schedulingFingerprint, before);
    },
  );

  test('closure and seminar relocate only affected classes and preserve capacity/type', () {
    for (final seminar in [false, true]) {
      final workspace = fixture();
      final tools = TimetableOperations(workspace);
      final proposals = seminar
          ? tools.seminar(
              name: 'Workshop',
              days: {0},
              start: 540,
              end: 590,
              capacity: 25,
              equipment: ['projector'],
              preferredRoomId: 'r1',
            )
          : tools.closeRoom(roomId: 'r1', days: {0}, start: 540, end: 590);
      final proposal = proposals.first;
      expect(
        proposal.status,
        TimetableProposalStatus.validated,
        reason: proposal.errors.join('\n'),
      );
      expect(tools.apply(proposal, confirmed: true), isTrue);
      expect(workspace.sessionById('s1')!.roomId, 'r2');
      expect(workspace.sessionById('s1')!.startMinute, 540);
      expect(workspace.sessionById('busy')!.roomId, 'lab');
      expect(workspace.roomById('r1')!.isUnavailableAt(0, 540, 590), isTrue);
      expect(workspace.hardConflicts, isEmpty);
    }
  });

  test(
    'extra lecture verifies teacher, batch, room, break and hard workload cap',
    () {
      final workspace = fixture();
      final tools = TimetableOperations(workspace);
      const request = ManualSession(
        id: 'extra',
        subjectId: 'math',
        facultyId: 'teacher-b',
        batchId: 'a',
        roomId: 'r2',
        day: 0,
        startMinute: 540,
        endMinute: 590,
      );
      expect(
        tools.extraLecture(request, fixedTime: true).single.status,
        TimetableProposalStatus.infeasible,
      );
      final options = tools.extraLecture(request);
      expect(options.first.status, TimetableProposalStatus.validated);
      expect(tools.apply(options.first, confirmed: true), isTrue);
      expect(workspace.sessions, hasLength(3));
      expect(workspace.hardConflicts, isEmpty);
      final invalid = request.copyWith(
        id: 'break',
        startMinute: 720,
        endMinute: 750,
      );
      expect(tools.validateChanges([invalid]).join(' '), contains('break'));
      workspace.editFaculty(
        workspace.facultyById('teacher-b')!.copyWith(hardWeeklyHourLimit: 1),
      );
      expect(
        tools
            .validateChanges([request.copyWith(id: 'limit', day: 1)])
            .join(' '),
        contains('limit'),
      );
    },
  );

  test(
    'lab closure preserves lab suitability and can move to another open day',
    () {
      final workspace = fixture();
      workspace.addSubject(
        const ManualSubject(
          id: 'practical',
          name: 'Practical',
          code: 'LAB',
          isPractical: true,
        ),
      );
      workspace.addSession(
        const ManualSession(
          id: 'p1',
          subjectId: 'practical',
          facultyId: 'teacher-a',
          batchId: 'a',
          roomId: 'lab',
          day: 1,
          startMinute: 540,
          endMinute: 650,
          type: ManualSessionType.practical,
        ),
      );
      final tools = TimetableOperations(workspace);
      final proposal = tools.closeRoom(roomId: 'lab', days: {1, 2, 3}).single;
      expect(
        proposal.status,
        TimetableProposalStatus.validated,
        reason: proposal.errors.join('\n'),
      );
      expect(tools.apply(proposal, confirmed: true), isTrue);
      final changed = workspace.sessionById('p1')!;
      expect(changed.roomId, 'lab');
      expect({1, 2, 3}.contains(changed.day), isFalse);
      expect(workspace.hardConflicts, isEmpty);
    },
  );

  test(
    'teacher swap checks both subject qualifications and applies atomically',
    () {
      final workspace = fixture();
      workspace.addSession(
        const ManualSession(
          id: 's2',
          subjectId: 'math',
          facultyId: 'teacher-b',
          batchId: 'b',
          roomId: 'r2',
          day: 1,
          startMinute: 540,
          endMinute: 590,
        ),
      );
      final tools = TimetableOperations(workspace);
      final swap = tools.swapTeachers('s1', 's2');
      expect(
        swap.status,
        TimetableProposalStatus.validated,
        reason: swap.errors.join('\n'),
      );
      expect(tools.apply(swap, confirmed: true), isTrue);
      expect(workspace.sessionById('s1')!.facultyId, 'teacher-b');
      expect(workspace.sessionById('s2')!.facultyId, 'teacher-a');
      expect(workspace.sessionById('busy')!.facultyId, 'teacher-busy');
      expect(workspace.hardConflicts, isEmpty);
      workspace.editFaculty(
        workspace.facultyById('teacher-a')!.copyWith(qualifiedSubjectIds: []),
      );
      final invalid = tools.swapTeachers('s1', 's2');
      expect(invalid.status, TimetableProposalStatus.infeasible);
    },
  );

  test('stale proposals and cross-timetable changes are refused; audit survives reload', () async {
    final library = TimetableLibraryController(workspace: fixture());
    final first = library.createBlank();
    library.workspace.importSnapshot(fixture().exportSnapshot());
    final tools = TimetableOperations(
      library.workspace,
      activeTimetableId: () => library.activeId,
    );
    final proposal = tools.closeRoom(roomId: 'r1', days: {0}).single;
    final second = library.duplicate(first.id)!;
    expect(tools.apply(proposal, confirmed: true), isFalse);
    expect(proposal.status, TimetableProposalStatus.stale);
    library.switchTo(first.id);
    final fresh = tools.closeRoom(roomId: 'r1', days: {0}).single;
    expect(tools.apply(fresh, confirmed: true), isTrue);
    await library.flush();
    final restored = TimetableLibraryController();
    await restored.restore();
    expect(restored.workspace.changeAudit, hasLength(1));
    restored.switchTo(second.id);
    expect(restored.workspace.sessionById('s1')!.roomId, 'r1');
  });
}
