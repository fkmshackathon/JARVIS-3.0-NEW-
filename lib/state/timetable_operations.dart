import 'manual_timetable_controller.dart';

enum TimetableProposalStatus { validated, infeasible, applied, rejected, stale }

/// A local, reviewable change. Candidate sessions are never applied by an LLM.
class TimetableProposal {
  TimetableProposal({
    required this.id,
    required this.timetableId,
    required this.baseFingerprint,
    required this.title,
    required this.reason,
    required this.kind,
    required this.replacements,
    this.faculty = const [],
    this.rooms = const [],
    this.explanation = '',
    this.errors = const [],
    this.status = TimetableProposalStatus.validated,
  });
  final String id;
  final String? timetableId;
  final String baseFingerprint;
  final String title;
  final String reason;
  final String kind;
  final List<ManualSession> replacements;
  final List<ManualFaculty> faculty;
  final List<ManualRoom> rooms;
  final String explanation;
  List<String> errors;
  TimetableProposalStatus status;
}

/// Authoritative local tools for the operations assistant and coordinator UI.
/// Uses the current workspace, configured qualifications and availability.
/// The existing bounded generator remains the only semester generator.
class TimetableOperations {
  TimetableOperations(this.workspace, {this.activeTimetableId});
  final ManualTimetableController workspace;
  final String? Function()? activeTimetableId;

  static String fingerprint(ManualTimetableController workspace) {
    return workspace.schedulingFingerprint;
  }

  bool qualified(ManualFaculty teacher, String subjectId) =>
      teacher.qualifiedSubjectIds.contains(subjectId) ||
      workspace.requirements.any(
        (r) => r.facultyId == teacher.id && r.subjectId == subjectId,
      );

  List<ManualSession> affectedSessions({
    String? facultyId,
    String? roomId,
    required Set<int> days,
    int start = 0,
    int end = 1440,
  }) => workspace.sessions
      .where(
        (s) =>
            days.contains(s.day) &&
            _overlap(s.startMinute, s.endMinute, start, end) &&
            (facultyId == null || s.facultyId == facultyId) &&
            (roomId == null || s.roomId == roomId),
      )
      .toList();

  /// Eligibility is mandatory; workload/day/consecutive-load ranking follows.
  List<ManualFaculty> eligibleSubstitutes(ManualSession session) {
    final candidates = workspace.faculty
        .where(
          (teacher) =>
              teacher.id != session.facultyId &&
              qualified(teacher, session.subjectId) &&
              validateChanges([session.copyWith(facultyId: teacher.id)])
                  .isEmpty,
        )
        .toList();
    double score(ManualFaculty teacher) {
      final day = workspace.sessions.where(
        (s) => s.facultyId == teacher.id && s.day == session.day,
      );
      final adjacent = day
          .where(
            (s) =>
                s.endMinute == session.startMinute ||
                s.startMinute == session.endMinute,
          )
          .length;
      return workspace.workloadFor(teacher.id) /
              (teacher.maxWeeklyHours > 0 ? teacher.maxWeeklyHours * 60 : 1) *
              100 +
          day.length * 4 +
          adjacent * 8;
    }

    candidates.sort((a, b) {
      final order = score(a).compareTo(score(b));
      return order != 0 ? order : a.id.compareTo(b.id);
    });
    return candidates;
  }

  List<TimetableProposal> absence({
    required String facultyId,
    required Set<int> days,
    int start = 0,
    int end = 1440,
    String reason = 'Teacher absence',
  }) {
    final teacher = workspace.facultyById(facultyId);
    if (teacher == null) return [];
    final affected = affectedSessions(
      facultyId: facultyId,
      days: days,
      start: start,
      end: end,
    );
    final changedTeacher = teacher.copyWith(
      absences: [
        ...teacher.absences,
        for (final day in days)
          ManualAbsence(
            day: day,
            startMinute: start,
            endMinute: end,
            reason: reason,
          ),
      ],
    );
    final chosen = <ManualSession>[];
    for (final session in affected) {
      final candidates = eligibleSubstitutes(session);
      ManualSession? replacement;
      for (final candidate in candidates) {
        final proposed = session.copyWith(facultyId: candidate.id);
        if (validateChanges([...chosen, proposed]).isEmpty) {
          replacement = proposed;
          break;
        }
      }
      if (replacement == null) {
        return [
          _proposal(
            'Teacher absence',
            reason,
            'absence',
            chosen,
            faculty: [changedTeacher],
            errors: [
              'No free, authorised substitute for ${session.id}. '
                  'Configure subject eligibility or move the lecture; no change has been applied.',
            ],
          ),
        ];
      }
      chosen.add(replacement);
    }
    if (affected.isEmpty) {
      return [
        _proposal(
          'Record teacher absence',
          reason,
          'absence',
          [],
          faculty: [changedTeacher],
          explanation: 'No lectures fall in this window. Only the availability restriction changes.',
        ),
      ];
    }
    return [
      _proposal(
        'Assign eligible substitutes',
        reason,
        'absence',
        chosen,
        faculty: [changedTeacher],
        explanation:
            'Subject authorisation, full-campus availability and hard workload caps checked. '
            'Lower workload and fewer adjacent classes are preferred. Other sessions stay unchanged.',
      ),
    ];
  }

  List<ManualRoom> compatibleRooms(
    ManualSession session, {
    Set<String> excluded = const {},
    List<String> equipment = const [],
  }) => workspace.rooms.where((room) {
    final batch = workspace.batchById(session.batchId);
    final practical =
        session.isPractical ||
        workspace.subjectById(session.subjectId)?.isPractical == true;
    return !excluded.contains(room.id) &&
        (!practical || room.isLab) &&
        room.capacity >= (batch?.size ?? 0) &&
        equipment.every(room.equipment.contains) &&
        (room.department == batch?.department ||
            (workspace.allowCrossDepartmentSharing && room.borrowable)) &&
        validateChanges([session.copyWith(roomId: room.id)]).isEmpty;
  }).toList();

  /// Room closures and room reservations for events share the same safe tool.
  /// An option can change several directly affected sessions as one transaction.
  List<TimetableProposal> closeRoom({
    required String roomId,
    required Set<int> days,
    int start = 0,
    int end = 1440,
    String reason = 'Room closure',
    String kind = 'closure',
  }) {
    final room = workspace.roomById(roomId);
    if (room == null) return [];
    final changedRoom = room.copyWith(
      unavailableSlots: [
        ...room.unavailableSlots,
        for (final day in days)
          ManualRoomClosure(
            day: day,
            startMinute: start,
            endMinute: end,
            reason: reason,
          ),
      ],
    );
    final changed = <ManualSession>[];
    final affected = affectedSessions(
      roomId: roomId,
      days: days,
      start: start,
      end: end,
    );
    for (final session in affected) {
      ManualSession? replacement;
      for (final candidate in compatibleRooms(session, excluded: {roomId})) {
        final proposal = session.copyWith(roomId: candidate.id);
        if (validateChanges([...changed, proposal]).isEmpty) {
          replacement = proposal;
          break;
        }
      }
      // Prefer keeping time. Only when no room fits do we search valid slots.
      if (replacement == null) {
        for (final candidate in findSlots(
          session,
          accept: (candidate) =>
              candidate.roomId != roomId ||
              !days.contains(candidate.day) ||
              !_overlap(candidate.startMinute, candidate.endMinute, start, end),
        )) {
          if (validateChanges([...changed, candidate]).isEmpty) {
            replacement = candidate;
            break;
          }
        }
      }
      if (replacement == null) {
        return [
          _proposal(
            'No safe local adjustment',
            reason,
            kind,
            changed,
            rooms: [changedRoom],
            errors: [
              'No compatible room or valid time was found for ${session.id}. '
                  'Try a different event room/window or revise the available resources.',
            ],
          ),
        ];
      }
      changed.add(replacement);
    }
    return [
      _proposal(
        kind == 'seminar'
            ? 'Reserve event room and relocate classes'
            : 'Close room and relocate affected classes',
        reason,
        kind,
        changed,
        rooms: [changedRoom],
        explanation:
            'Room type, capacity, department sharing, closures, '
            'teacher/batch availability, breaks and teaching window checked. Unaffected sessions are preserved.',
      ),
    ];
  }

  /// Searches actual teaching starts and jointly checks faculty, batch and room.
  List<ManualSession> findSlots(
    ManualSession session, {
    Set<String> excludedRooms = const {},
    int limit = 8,
    bool Function(ManualSession)? accept,
  }) {
    final results = <ManualSession>[];
    for (final slot in workspace.timeSlots.where((s) => !s.isBreak)) {
      for (final room in workspace.rooms.where(
        (r) => !excludedRooms.contains(r.id),
      )) {
        final candidate = session.copyWith(
          day: slot.day,
          startMinute: slot.startMinute,
          endMinute: slot.startMinute + session.durationMinutes,
          roomId: room.id,
        );
        if ((accept == null || accept(candidate)) &&
            validateChanges([candidate]).isEmpty) {
          results.add(candidate);
          if (results.length >= limit) return results;
        }
      }
    }
    return results;
  }

  List<TimetableProposal> seminar({
    required String name,
    required Set<int> days,
    required int start,
    required int end,
    int capacity = 0,
    bool laboratory = false,
    List<String> equipment = const [],
    String? preferredRoomId,
  }) {
    final available = workspace.rooms
        .where(
          (r) =>
              r.isAvailable &&
              r.capacity >= capacity &&
              (!laboratory || r.isLab) &&
              equipment.every(
                (e) => r.equipment
                    .map((v) => v.toLowerCase())
                    .contains(e.toLowerCase()),
              ) &&
              !days.any((day) => r.isUnavailableAt(day, start, end)),
        )
        .toList();
    available.sort((a, b) {
      if (a.id == preferredRoomId) return -1;
      if (b.id == preferredRoomId) return 1;
      return affectedSessions(
        roomId: a.id,
        days: days,
        start: start,
        end: end,
      ).length.compareTo(
        affectedSessions(
          roomId: b.id,
          days: days,
          start: start,
          end: end,
        ).length,
      );
    });
    if (available.isEmpty) {
      return [
        _proposal(
          'No suitable event room',
          name,
          'seminar',
          [],
          errors: [
            'No open room matches the required capacity/type/equipment. Configure the actual inventory or revise the request.',
          ],
        ),
      ];
    }
    return available
        .take(4)
        .expand(
          (r) => closeRoom(
            roomId: r.id,
            days: days,
            start: start,
            end: end,
            reason: '$name · ${r.name}',
            kind: 'seminar',
          ),
        )
        .toList();
  }

  List<TimetableProposal> extraLecture(
    ManualSession request, {
    bool fixedTime = false,
  }) {
    final candidates = fixedTime
        ? (validateChanges([request]).isEmpty ? [request] : <ManualSession>[])
        : findSlots(request);
    if (candidates.isEmpty) {
      return [
        _proposal(
          'No feasible extra lecture',
          'Extra lecture',
          'extra',
          [],
          errors: fixedTime
              ? validateChanges([request])
              : [
                  'No jointly available teacher, batch and suitable room slot was found.',
                ],
        ),
      ];
    }
    return candidates
        .map(
          (s) => _proposal(
            'Extra lecture · ${workspace.dayName(s.day)} ${s.startMinute ~/ 60}:${(s.startMinute % 60).toString().padLeft(2, '0')}',
            'Extra lecture',
            'extra',
            [s],
            explanation: 'Joint faculty, batch and room availability checked; the existing schedule is not regenerated.',
          ),
        )
        .toList();
  }

  TimetableProposal swapTeachers(
    String firstSessionId,
    String secondSessionId,
  ) {
    final first = workspace.sessionById(firstSessionId);
    final second = workspace.sessionById(secondSessionId);
    if (first == null || second == null || first.id == second.id) {
      return _proposal(
        'Teacher swap',
        'Teacher swap',
        'swap',
        [],
        errors: ['Choose two different existing sessions.'],
      );
    }
    return _proposal(
      'Swap teachers for two sessions',
      'Coordinator-approved teacher swap',
      'swap',
      [
        first.copyWith(facultyId: second.facultyId),
        second.copyWith(facultyId: first.facultyId),
      ],
      explanation: 'Both subject authorisations and both teachers’ availability are checked together. No messages or notifications are sent.',
    );
  }

  /// Pure candidate validation. A detached clone owns all intermediate edits;
  /// the real workspace never exposes a half-applied operation.
  List<String> validateChanges(
    List<ManualSession> replacements, {
    List<ManualFaculty> faculty = const [],
    List<ManualRoom> rooms = const [],
  }) {
    final probe = _candidate(replacements, faculty: faculty, rooms: rooms);
    final errors = <String>{};
    // Ignore historical generator diagnostics. Current session-level checks are
    // independently recomputed, not accepted from an AI response.
    final currentSessionIds = probe.sessions.map((s) => s.id).toSet();
    for (final issue in probe.hardConflicts) {
      if (issue.sessionIds.any(currentSessionIds.contains)) {
        errors.add(issue.message);
      }
    }
    for (final session in probe.sessions) {
      if (!probe.workingDays.contains(session.day) ||
          session.startMinute < probe.teachingStart ||
          session.endMinute > probe.teachingEnd) {
        errors.add('${session.id}: outside configured teaching days/window.');
      }
      if (_overlap(
        session.startMinute,
        session.endMinute,
        probe.breakStart,
        probe.breakEnd,
      )) {
        errors.add('${session.id}: overlaps the mandatory break.');
      }
      final teacher = probe.facultyById(session.facultyId);
      final room = probe.roomById(session.roomId);
      final batch = probe.batchById(session.batchId);
      if (room != null &&
          batch != null &&
          room.department != batch.department &&
          !(probe.allowCrossDepartmentSharing && room.borrowable)) {
        errors.add('${session.id}: cross-department room use is not allowed.');
      }
      if (teacher?.hardWeeklyHourLimit != null &&
          probe.workloadFor(teacher!.id) > teacher.hardWeeklyHourLimit! * 60) {
        errors.add('${teacher.name}: hard weekly workload limit exceeded.');
      }
    }
    for (final changed in replacements) {
      final old = workspace.sessionById(changed.id);
      final teacher = probe.facultyById(changed.facultyId);
      if ((old == null ||
              old.facultyId != changed.facultyId ||
              old.subjectId != changed.subjectId) &&
          (teacher == null || !qualified(teacher, changed.subjectId))) {
        errors.add(
          '${changed.id}: faculty is not authorised for this subject.',
        );
      }
    }
    probe.dispose();
    return errors.toList();
  }

  /// Revalidates against the latest draft and requires a positive confirmation.
  /// Only a matching active record and unchanged base revision can be applied.
  bool apply(TimetableProposal proposal, {required bool confirmed}) {
    if (!confirmed || proposal.status != TimetableProposalStatus.validated) {
      return false;
    }
    if (proposal.timetableId != activeTimetableId?.call() ||
        proposal.baseFingerprint != fingerprint(workspace)) {
      proposal.status = TimetableProposalStatus.stale;
      proposal.errors = [
        'The selected timetable or its data changed. Request fresh recommendations.',
      ];
      return false;
    }
    final errors = validateChanges(
      proposal.replacements,
      faculty: proposal.faculty,
      rooms: proposal.rooms,
    );
    if (errors.isNotEmpty) {
      proposal.status = TimetableProposalStatus.infeasible;
      proposal.errors = errors;
      return false;
    }
    final candidate = _candidate(
      proposal.replacements,
      faculty: proposal.faculty,
      rooms: proposal.rooms,
    );
    final success = workspace.commitLocalChange(
      candidate.exportSnapshot(),
      kind: proposal.kind,
      reason: proposal.reason,
      sessionIds: proposal.replacements.map((s) => s.id).toList(),
    );
    candidate.dispose();
    if (success) proposal.status = TimetableProposalStatus.applied;
    return success;
  }

  void reject(TimetableProposal proposal) =>
      proposal.status = TimetableProposalStatus.rejected;

  ManualTimetableController _candidate(
    List<ManualSession> replacements, {
    List<ManualFaculty> faculty = const [],
    List<ManualRoom> rooms = const [],
  }) {
    final probe = ManualTimetableController.blank()
      ..importSnapshot(workspace.exportSnapshot());
    for (final teacher in faculty) {
      probe.editFaculty(teacher);
    }
    for (final room in rooms) {
      probe.editRoom(room);
    }
    for (final session in replacements) {
      probe.addSession(session);
    }
    probe.validate();
    return probe;
  }

  TimetableProposal _proposal(
    String title,
    String reason,
    String kind,
    List<ManualSession> replacements, {
    List<ManualFaculty> faculty = const [],
    List<ManualRoom> rooms = const [],
    String explanation = '',
    List<String> errors = const [],
  }) {
    final checks = [
      ...errors,
      ...validateChanges(replacements, faculty: faculty, rooms: rooms),
    ];
    return TimetableProposal(
      id: 'proposal-${DateTime.now().microsecondsSinceEpoch}',
      timetableId: activeTimetableId?.call(),
      baseFingerprint: fingerprint(workspace),
      title: title,
      reason: reason,
      kind: kind,
      replacements: List.unmodifiable(replacements),
      faculty: List.unmodifiable(faculty),
      rooms: List.unmodifiable(rooms),
      explanation: explanation,
      errors: checks,
      status: checks.isEmpty
          ? TimetableProposalStatus.validated
          : TimetableProposalStatus.infeasible,
    );
  }

  static bool _overlap(int start, int end, int otherStart, int otherEnd) =>
      start < otherEnd && otherStart < end;
}
