export 'manual_timetable_models.dart';

import 'manual_timetable_models.dart';

/// The outcome of a local timetable generation attempt.
enum TimetableGenerationStatus { generated, infeasible, invalidInput, empty }

extension TimetableGenerationStatusX on TimetableGenerationStatus {
  bool get isSuccess => this == TimetableGenerationStatus.generated;

  String get label => switch (this) {
    TimetableGenerationStatus.generated => 'generated',
    TimetableGenerationStatus.infeasible => 'infeasible',
    TimetableGenerationStatus.invalidInput => 'invalid input',
    TimetableGenerationStatus.empty => 'empty',
  };
}

/// One batch/subject/faculty teaching obligation.
///
/// [lectureHours] and [labHours] default to the values on the referenced
/// [ManualSubject]. A lecture hour expands to one lecture session. Lab hours
/// describe one practical block by default (for example, two lab hours become
/// one 120-minute practical); [labSessions] and [labDurationMinutes] can be
/// supplied when a course uses a different pattern.
class TimetableTeachingRequirement {
  const TimetableTeachingRequirement({
    this.id = '',
    required this.subjectId,
    required this.batchId,
    required this.facultyId,
    this.lectureHours,
    this.labHours,
    this.lectureSessions,
    this.labSessions,
    this.isPractical = false,
    this.practical = false,
    this.sessionDurationMinutes,
    this.durationMinutes,
    this.lectureDurationMinutes,
    this.labDurationMinutes,
    this.department,
    this.preferredDays = const <int>[],
    this.preferredStartMinutes = const <int>[],
    this.preferredRoomIds = const <String>[],
  });

  /// A caller-owned stable identifier. An identifier is derived from the
  /// referenced entities when this is empty.
  final String id;
  final String subjectId;
  final String batchId;
  final String facultyId;
  final int? lectureHours;
  final int? labHours;

  /// Explicit occurrence counts override the hour-derived defaults.
  final int? lectureSessions;
  final int? labSessions;

  /// Either flag marks this requirement as practical-only.
  final bool isPractical;
  final bool practical;

  /// [sessionDurationMinutes] and [durationMinutes] are generic aliases. The
  /// more specific duration fields take precedence for their session type.
  final int? sessionDurationMinutes;
  final int? durationMinutes;
  final int? lectureDurationMinutes;
  final int? labDurationMinutes;
  final String? department;
  final List<int> preferredDays;
  final List<int> preferredStartMinutes;
  final List<String> preferredRoomIds;

  String get stableId =>
      id.trim().isNotEmpty ? id.trim() : '$batchId:$subjectId:$facultyId';

  bool get practicalOnly => isPractical || practical;

  TimetableTeachingRequirement copyWith({
    String? id,
    String? subjectId,
    String? batchId,
    String? facultyId,
    int? lectureHours,
    int? labHours,
    int? lectureSessions,
    int? labSessions,
    bool? isPractical,
    bool? practical,
    int? sessionDurationMinutes,
    int? durationMinutes,
    int? lectureDurationMinutes,
    int? labDurationMinutes,
    String? department,
    List<int>? preferredDays,
    List<int>? preferredStartMinutes,
    List<String>? preferredRoomIds,
  }) => TimetableTeachingRequirement(
    id: id ?? this.id,
    subjectId: subjectId ?? this.subjectId,
    batchId: batchId ?? this.batchId,
    facultyId: facultyId ?? this.facultyId,
    lectureHours: lectureHours ?? this.lectureHours,
    labHours: labHours ?? this.labHours,
    lectureSessions: lectureSessions ?? this.lectureSessions,
    labSessions: labSessions ?? this.labSessions,
    isPractical: isPractical ?? this.isPractical,
    practical: practical ?? this.practical,
    sessionDurationMinutes:
        sessionDurationMinutes ?? this.sessionDurationMinutes,
    durationMinutes: durationMinutes ?? this.durationMinutes,
    lectureDurationMinutes:
        lectureDurationMinutes ?? this.lectureDurationMinutes,
    labDurationMinutes: labDurationMinutes ?? this.labDurationMinutes,
    department: department ?? this.department,
    preferredDays: preferredDays ?? this.preferredDays,
    preferredStartMinutes: preferredStartMinutes ?? this.preferredStartMinutes,
    preferredRoomIds: preferredRoomIds ?? this.preferredRoomIds,
  );
}

/// Common aliases keep the model pleasant to use from different timetable
/// call sites without introducing another domain representation.
typedef TimetableRequirement = TimetableTeachingRequirement;
typedef ManualTeachingRequirement = TimetableTeachingRequirement;
typedef TeachingRequirement = TimetableTeachingRequirement;

/// All local data needed for one deterministic generation attempt.
class TimetableGenerationInput {
  const TimetableGenerationInput({
    this.faculty = const <ManualFaculty>[],
    this.teachers = const <ManualFaculty>[],
    this.rooms = const <ManualRoom>[],
    this.batches = const <ManualBatch>[],
    this.subjects = const <ManualSubject>[],
    this.timeSlots = const <ManualTimeSlot>[],
    this.slots = const <ManualTimeSlot>[],
    this.breakSlots = const <ManualTimeSlot>[],
    this.breaks = const <ManualTimeSlot>[],
    this.requirements = const <TimetableTeachingRequirement>[],
    this.existingSessions = const <ManualSession>[],
    this.sessions = const <ManualSession>[],
    this.maxSearchNodes = 20000,
    this.maxCandidatesPerRequirement = 256,
  });

  final List<ManualFaculty> faculty;
  final List<ManualFaculty> teachers;
  final List<ManualRoom> rooms;
  final List<ManualBatch> batches;
  final List<ManualSubject> subjects;
  final List<ManualTimeSlot> timeSlots;
  final List<ManualTimeSlot> slots;
  final List<ManualTimeSlot> breakSlots;
  final List<ManualTimeSlot> breaks;
  final List<TimetableTeachingRequirement> requirements;
  final List<ManualSession> existingSessions;
  final List<ManualSession> sessions;
  final int maxSearchNodes;
  final int maxCandidatesPerRequirement;

  List<ManualFaculty> get allFaculty => <ManualFaculty>[
    ...faculty,
    ...teachers,
  ];

  List<ManualTimeSlot> get allTimeSlots => <ManualTimeSlot>[
    ...timeSlots,
    ...slots,
  ];

  List<ManualTimeSlot> get allBreakSlots => <ManualTimeSlot>[
    ...breakSlots,
    ...breaks,
  ];

  List<ManualSession> get allExistingSessions => <ManualSession>[
    ...existingSessions,
    ...sessions,
  ];
}

typedef TimetableGeneratorInput = TimetableGenerationInput;
typedef TimetableInput = TimetableGenerationInput;
typedef GenerationStatus = TimetableGenerationStatus;

/// A single occurrence that the generator could not place.
class TimetableUnassignedRequirement {
  const TimetableUnassignedRequirement({
    required this.id,
    required this.requirementId,
    required this.subjectId,
    required this.batchId,
    required this.facultyId,
    required this.isPractical,
    required this.durationMinutes,
    required this.reason,
  });

  final String id;
  final String requirementId;
  final String subjectId;
  final String batchId;
  final String facultyId;
  final bool isPractical;
  final int durationMinutes;
  final String reason;

  bool get isLab => isPractical;
}

typedef UnassignedTimetableRequirement = TimetableUnassignedRequirement;

/// Immutable, UI-independent output from [TimetableGenerator].
class TimetableGenerationResult {
  TimetableGenerationResult({
    required this.id,
    required this.status,
    required this.message,
    required List<ManualSession> generatedSessions,
    required List<TimetableUnassignedRequirement> unassignedRequirements,
    required List<ManualIssue> validationIssues,
    required this.score,
    required this.searchNodes,
  }) : generatedSessions = List<ManualSession>.unmodifiable(generatedSessions),
       unassignedRequirements =
           List<TimetableUnassignedRequirement>.unmodifiable(
             unassignedRequirements,
           ),
       validationIssues = List<ManualIssue>.unmodifiable(validationIssues);

  /// Stable fingerprint of the input that produced this result.
  final String id;
  final TimetableGenerationStatus status;
  final String message;
  final List<ManualSession> generatedSessions;
  final List<TimetableUnassignedRequirement> unassignedRequirements;
  final List<ManualIssue> validationIssues;
  final int score;
  final int searchNodes;

  List<ManualSession> get sessions => generatedSessions;
  List<ManualSession> get generated => generatedSessions;
  List<TimetableUnassignedRequirement> get unassigned => unassignedRequirements;
  List<ManualIssue> get issues => validationIssues;
  List<ManualIssue> get validation => validationIssues;
  List<ManualIssue> get hardIssues =>
      validationIssues.where((issue) => issue.isHard).toList(growable: false);
  List<ManualIssue> get softWarnings =>
      validationIssues.where((issue) => !issue.isHard).toList(growable: false);
  int get softScore => score;
  bool get isSuccess => status == TimetableGenerationStatus.generated;
  bool get isGenerated => isSuccess;
  bool get isInfeasible => status == TimetableGenerationStatus.infeasible;
  bool get isValid => !validationIssues.any((issue) => issue.isHard);
  String get statusName => status.label;
}

/// Deterministic local timetable engine.
///
/// The engine uses a bounded depth-first search. Candidate windows and rooms
/// are sorted by stable IDs and times, so the same input produces the same
/// sessions regardless of hash-map iteration order. Search stops at
/// [maxSearchNodes], retaining the best complete or partial schedule found.
class TimetableGenerator {
  const TimetableGenerator({
    this.maxSearchNodes = 20000,
    this.maxCandidatesPerRequirement = 256,
  });

  final int maxSearchNodes;
  final int maxCandidatesPerRequirement;

  TimetableGenerationResult generate(TimetableGenerationInput input) =>
      _GenerationRun(
        input,
        maxSearchNodes: maxSearchNodes,
        maxCandidatesPerRequirement: maxCandidatesPerRequirement,
      ).run();
}

/// Convenience function for callers that do not need to retain a generator.
TimetableGenerationResult generateTimetable(
  TimetableGenerationInput input, {
  int maxSearchNodes = 20000,
  int maxCandidatesPerRequirement = 256,
}) => TimetableGenerator(
  maxSearchNodes: maxSearchNodes,
  maxCandidatesPerRequirement: maxCandidatesPerRequirement,
).generate(input);

class _GenerationRun {
  _GenerationRun(
    this.input, {
    required this.maxSearchNodes,
    required this.maxCandidatesPerRequirement,
  });

  final TimetableGenerationInput input;
  final int maxSearchNodes;
  final int maxCandidatesPerRequirement;

  final List<ManualIssue> _issues = <ManualIssue>[];
  final List<TimetableUnassignedRequirement> _preassigned =
      <TimetableUnassignedRequirement>[];
  final List<_WorkItem> _work = <_WorkItem>[];
  final List<_WorkItem> _searchWork = <_WorkItem>[];
  final Map<int, List<_PlacementOption>> _optionsByWork =
      <int, List<_PlacementOption>>{};
  final Map<String, ManualFaculty> _facultyById = <String, ManualFaculty>{};
  final Map<String, ManualRoom> _roomById = <String, ManualRoom>{};
  final Map<String, ManualBatch> _batchById = <String, ManualBatch>{};
  final Map<String, ManualSubject> _subjectById = <String, ManualSubject>{};
  final Map<String, List<ManualSession>> _facultySessions =
      <String, List<ManualSession>>{};
  final Map<String, List<ManualSession>> _roomSessions =
      <String, List<ManualSession>>{};
  final Map<String, List<ManualSession>> _batchSessions =
      <String, List<ManualSession>>{};
  final Map<String, int> _facultyLoads = <String, int>{};
  final Map<int, _Placement> _current = <int, _Placement>{};

  Map<int, _Placement> _best = <int, _Placement>{};
  int _bestCount = 0;
  int _bestScore = 1 << 60;
  String _bestKey = '';
  int _nodes = 0;
  bool _searchLimitReached = false;
  int _requirementSequence = 0;

  TimetableGenerationResult run() {
    _indexEntities();
    final generationId = _stableGenerationId();
    _validateSlots();
    _seedExistingSessions();
    _expandRequirements();

    if (_issues.any((issue) => issue.isHard && issue.code == 'INVALID_INPUT')) {
      final invalidUnassigned = <TimetableUnassignedRequirement>[
        ..._preassigned,
        for (final item in _work)
          _unassignedFor(item, 'Input validation failed before placement.'),
      ];
      return _result(
        generationId,
        TimetableGenerationStatus.invalidInput,
        'Input contains invalid timetable data. Correct the listed entities or requirements and try again.',
        unassigned: invalidUnassigned,
      );
    }

    if (_work.isEmpty) {
      final status = input.requirements.isEmpty
          ? TimetableGenerationStatus.empty
          : TimetableGenerationStatus.generated;
      final message = input.requirements.isEmpty
          ? 'No teaching requirements were supplied.'
          : 'No sessions were required by the supplied teaching requirements.';
      return _result(generationId, status, message);
    }

    _buildPlacementOptions();
    _prepareSearch();
    _search(0);

    final generated = _best.values
        .map((placement) => placement.session)
        .toList(growable: false);
    final orderedGenerated = List<ManualSession>.from(generated)
      ..sort(_sessionCompare);
    final unassigned = <TimetableUnassignedRequirement>[
      ..._preassigned,
      for (final item in _searchWork)
        if (!_best.containsKey(item.searchIndex))
          _unassignedFor(item, _reasonFor(item)),
    ];

    _appendUnassignedIssues(unassigned);
    _appendGeneratedValidationIssues(orderedGenerated);
    _appendSoftIssues(orderedGenerated);

    final hasUnassigned = unassigned.isNotEmpty;
    final status = hasUnassigned
        ? TimetableGenerationStatus.infeasible
        : TimetableGenerationStatus.generated;
    final scheduledCount = orderedGenerated.length;
    final requestedCount = _work.length + _preassigned.length;
    final message = hasUnassigned
        ? _infeasibleMessage(
            scheduledCount: scheduledCount,
            requestedCount: requestedCount,
          )
        : 'Generated $scheduledCount sessions for ${input.requirements.length} teaching requirements.';
    return _result(
      generationId,
      status,
      message,
      sessions: orderedGenerated,
      unassigned: unassigned,
    );
  }

  TimetableGenerationResult _result(
    String generationId,
    TimetableGenerationStatus status,
    String message, {
    List<ManualSession> sessions = const <ManualSession>[],
    List<TimetableUnassignedRequirement> unassigned =
        const <TimetableUnassignedRequirement>[],
  }) => TimetableGenerationResult(
    id: generationId,
    status: status,
    message: message,
    generatedSessions: sessions,
    unassignedRequirements: unassigned,
    validationIssues: _issues,
    score: _best.isEmpty ? 0 : _scheduleScore(_best.values),
    searchNodes: _nodes,
  );

  void _indexEntities() {
    _index(input.allFaculty, _facultyById, entityName: 'faculty');
    _index(input.rooms, _roomById, entityName: 'room');
    _index(input.batches, _batchById, entityName: 'batch');
    _index(input.subjects, _subjectById, entityName: 'subject');
  }

  void _index<T>(
    List<T> values,
    Map<String, T> target, {
    required String entityName,
  }) {
    for (final value in values) {
      final id = switch (value) {
        ManualFaculty item => item.id,
        ManualRoom item => item.id,
        ManualBatch item => item.id,
        ManualSubject item => item.id,
        _ => '',
      };
      if (id.trim().isEmpty || target.containsKey(id)) {
        _addInputIssue('Invalid or duplicate $entityName ID "${id.trim()}".');
        continue;
      }
      target[id] = value;
    }
  }

  void _validateSlots() {
    final allSlots = <ManualTimeSlot>[...input.allTimeSlots];
    final breakSlots = <ManualTimeSlot>[
      ...input.allBreakSlots,
      ...allSlots.where((slot) => slot.isBreak),
    ];
    for (final slot in <ManualTimeSlot>[...allSlots, ...breakSlots]) {
      if (slot.day < 0 ||
          slot.startMinute < 0 ||
          slot.endMinute <= slot.startMinute ||
          slot.endMinute > 24 * 60) {
        _addInputIssue(
          'Time slot ${slot.key} must have a valid day and end after start.',
        );
      }
    }
  }

  void _seedExistingSessions() {
    final seen = <String>{};
    for (final session in input.allExistingSessions) {
      if (!seen.add(session.id)) continue;
      final subject = _subjectById[session.subjectId];
      final faculty = _facultyById[session.facultyId];
      final batch = _batchById[session.batchId];
      final room = _roomById[session.roomId];
      if (session.id.trim().isEmpty ||
          subject == null ||
          faculty == null ||
          batch == null ||
          room == null ||
          session.day < 0 ||
          session.startMinute < 0 ||
          session.endMinute <= session.startMinute) {
        _addInputIssue(
          'Existing session ${session.id} references invalid entities or has an invalid interval.',
        );
        continue;
      }
      _addOccupiedSession(session);
    }
  }

  void _addOccupiedSession(ManualSession session) {
    _facultySessions
        .putIfAbsent(session.facultyId, () => <ManualSession>[])
        .add(session);
    _roomSessions
        .putIfAbsent(session.roomId, () => <ManualSession>[])
        .add(session);
    _batchSessions
        .putIfAbsent(session.batchId, () => <ManualSession>[])
        .add(session);
    _facultyLoads[session.facultyId] =
        (_facultyLoads[session.facultyId] ?? 0) + session.durationMinutes;
  }

  void _expandRequirements() {
    final usedRequirementIds = <String>{};
    for (final requirement in input.requirements) {
      final id = _uniqueRequirementId(requirement, usedRequirementIds);
      final subject = _subjectById[requirement.subjectId];
      final batch = _batchById[requirement.batchId];
      final faculty = _facultyById[requirement.facultyId];
      final lectureHours = requirement.lectureHours ?? subject?.lectureHours;
      final labHours = requirement.labHours ?? subject?.labHours;
      final practicalOnly =
          requirement.practicalOnly || subject?.isPractical == true;

      if (subject == null || batch == null || faculty == null) {
        final missing = <String>[
          if (subject == null) 'subject ${requirement.subjectId}',
          if (batch == null) 'batch ${requirement.batchId}',
          if (faculty == null) 'faculty ${requirement.facultyId}',
        ];
        _preassigned.add(
          TimetableUnassignedRequirement(
            id: '$id:L1',
            requirementId: id,
            subjectId: requirement.subjectId,
            batchId: requirement.batchId,
            facultyId: requirement.facultyId,
            isPractical: practicalOnly,
            durationMinutes: 0,
            reason: 'Missing ${missing.join(', ')}.',
          ),
        );
        _addInputIssue(
          'Requirement $id references missing ${missing.join(', ')}.',
          code: 'INVALID_INPUT',
        );
        continue;
      }

      if ((lectureHours ?? 0) < 0 || (labHours ?? 0) < 0) {
        _addInputIssue(
          'Requirement $id cannot use negative lecture or lab hours.',
          code: 'INVALID_INPUT',
        );
        continue;
      }
      final countsAndDurations = <int?>[
        requirement.lectureSessions,
        requirement.labSessions,
        requirement.sessionDurationMinutes,
        requirement.durationMinutes,
        requirement.lectureDurationMinutes,
        requirement.labDurationMinutes,
      ];
      if (countsAndDurations.any((value) => value != null && value < 0)) {
        _addInputIssue(
          'Requirement $id cannot use negative session counts or durations.',
          code: 'INVALID_INPUT',
        );
        continue;
      }

      final lectureCount = _count(requirement.lectureSessions, lectureHours);
      final labCount =
          requirement.labSessions ??
          (labHours != null && labHours > 0
              ? 1
              : practicalOnly
              ? 1
              : 0);

      if (lectureCount == 0 && labCount == 0) {
        _addInputIssue(
          'Requirement $id does not request any lecture or practical sessions.',
          code: 'INVALID_INPUT',
        );
        continue;
      }

      if (!practicalOnly) {
        for (var occurrence = 0; occurrence < lectureCount; occurrence++) {
          _work.add(
            _WorkItem(
              requirement: requirement,
              requirementId: id,
              subject: subject,
              batch: batch,
              faculty: faculty,
              isPractical: false,
              occurrence: occurrence,
              durationMinutes: _positiveOrNull(
                requirement.lectureDurationMinutes ??
                    requirement.sessionDurationMinutes ??
                    requirement.durationMinutes,
              ),
              slotCount: null,
            ),
          );
        }
      }

      if (labCount > 0) {
        for (var occurrence = 0; occurrence < labCount; occurrence++) {
          final defaultLabHours = labHours != null && labHours > 0
              ? labHours
              : 1;
          _work.add(
            _WorkItem(
              requirement: requirement,
              requirementId: id,
              subject: subject,
              batch: batch,
              faculty: faculty,
              isPractical: true,
              occurrence: occurrence,
              durationMinutes:
                  _positiveOrNull(
                    requirement.labDurationMinutes ??
                        requirement.sessionDurationMinutes ??
                        requirement.durationMinutes,
                  ) ??
                  defaultLabHours * 60,
              slotCount:
                  _positiveOrNull(
                        requirement.labDurationMinutes ??
                            requirement.sessionDurationMinutes ??
                            requirement.durationMinutes,
                      ) ==
                      null
                  ? defaultLabHours
                  : null,
            ),
          );
        }
      }
    }
    for (var index = 0; index < _work.length; index++) {
      _work[index].searchIndex = index;
    }
  }

  int _count(int? explicitCount, int? hours) =>
      (explicitCount ?? hours ?? 0).clamp(0, 10000);

  int? _positiveOrNull(int? value) => value != null && value > 0 ? value : null;

  String _uniqueRequirementId(
    TimetableTeachingRequirement requirement,
    Set<String> used,
  ) {
    final base = requirement.stableId.trim().isEmpty
        ? 'requirement-${_requirementSequence + 1}'
        : requirement.stableId.trim();
    var id = base;
    var suffix = 2;
    while (!used.add(id)) {
      id = '$base-$suffix';
      suffix++;
    }
    _requirementSequence++;
    return id;
  }

  void _buildPlacementOptions() {
    for (final item in _work) {
      final windows = _windowsFor(
        item.durationMinutes,
        slotCount: item.slotCount,
      );
      if (windows.isEmpty) {
        _preassigned.add(
          _unassignedFor(
            item,
            'No usable non-break time window is long enough.',
          ),
        );
        _issues.add(
          ManualIssue(
            code: 'NO_USABLE_SLOT',
            message:
                '${_subjectName(item)} for ${item.batch.name} has no usable non-break time window.',
          ),
        );
        continue;
      }

      final options = <_PlacementOption>[];
      for (final window in windows) {
        for (final room in _eligibleRooms(item, window)) {
          options.add(
            _PlacementOption(
              item: item,
              room: room,
              window: window,
              baseScore: _preferenceScore(item, window, room),
            ),
          );
        }
      }
      if (options.isNotEmpty &&
          windows.every(
            (window) => item.faculty.isAbsentAt(
              window.day,
              window.startMinute,
              window.endMinute,
            ),
          )) {
        _issues.add(
          ManualIssue(
            code: 'FACULTY_UNAVAILABLE',
            message:
                '${item.faculty.name} is absent during every usable window for ${_subjectName(item)}.',
          ),
        );
      }
      options.sort(_optionCompare);
      if (options.isEmpty) {
        final hasMatchingRoom = _roomById.values.any(
          (room) =>
              room.isLab == item.isPractical &&
              room.capacity >= item.batch.size &&
              _departmentAllows(item, room),
        );
        final code = hasMatchingRoom ? 'ROOM_UNAVAILABLE' : 'NO_ELIGIBLE_ROOM';
        final reason = hasMatchingRoom
            ? 'Every suitable room is closed or unavailable during the usable windows.'
            : 'No room has the required type and capacity for this batch.';
        _preassigned.add(_unassignedFor(item, reason));
        _issues.add(
          ManualIssue(
            code: code,
            message: '${_subjectName(item)} for ${item.batch.name}: $reason',
          ),
        );
        continue;
      }
      final limit = maxCandidatesPerRequirement.clamp(1, 100000);
      _optionsByWork[item.searchIndex] = options.length <= limit
          ? options
          : options.sublist(0, limit);
      _searchWork.add(item);
    }
  }

  List<_Window> _windowsFor(int? durationMinutes, {int? slotCount}) {
    final slots = _usableSlots();
    if (slots.isEmpty) return <_Window>[];
    final windows = <_Window>[];
    for (var startIndex = 0; startIndex < slots.length; startIndex++) {
      final first = slots[startIndex];
      if (slotCount != null) {
        var previous = first;
        var count = 1;
        for (
          var endIndex = startIndex + 1;
          endIndex < slots.length && count < slotCount;
          endIndex++
        ) {
          final current = slots[endIndex];
          if (!_slotsCanFollow(previous, current)) break;
          previous = current;
          count++;
        }
        if (count == slotCount) {
          windows.add(
            _Window(
              day: first.day,
              startMinute: first.startMinute,
              endMinute: previous.endMinute,
            ),
          );
        }
        continue;
      }
      if (durationMinutes == null) {
        windows.add(
          _Window(
            day: first.day,
            startMinute: first.startMinute,
            endMinute: first.endMinute,
          ),
        );
        continue;
      }
      var contiguousEnd = first.endMinute;
      for (var endIndex = startIndex; endIndex < slots.length; endIndex++) {
        final current = slots[endIndex];
        if (endIndex != startIndex || current.day != first.day) {
          final previous = slots[endIndex - 1];
          if (!_slotsCanFollow(previous, current)) {
            break;
          }
          contiguousEnd = current.endMinute;
        }
        if (contiguousEnd - first.startMinute >= durationMinutes) {
          windows.add(
            _Window(
              day: first.day,
              startMinute: first.startMinute,
              endMinute: first.startMinute + durationMinutes,
            ),
          );
          break;
        }
      }
    }
    final deduped = <String, _Window>{};
    for (final window in windows) {
      deduped[window.key] = window;
    }
    final result = deduped.values.toList(growable: false)..sort(_windowCompare);
    return result;
  }

  bool _slotsCanFollow(ManualTimeSlot previous, ManualTimeSlot current) {
    if (previous.day != current.day ||
        current.startMinute < previous.endMinute) {
      return false;
    }
    final gap = current.startMinute - previous.endMinute;
    if (gap > previous.endMinute - previous.startMinute) return false;
    return !_hasBreakBetween(
      previous.day,
      previous.endMinute,
      current.startMinute,
    );
  }

  bool _hasBreakBetween(int day, int startMinute, int endMinute) {
    if (endMinute <= startMinute) return false;
    return <ManualTimeSlot>[
      ...input.allBreakSlots,
      ...input.allTimeSlots.where((slot) => slot.isBreak),
    ].any(
      (breakSlot) =>
          breakSlot.day == day &&
          _overlaps(
            startMinute,
            endMinute,
            breakSlot.startMinute,
            breakSlot.endMinute,
          ),
    );
  }

  List<ManualTimeSlot> _usableSlots() {
    final all = <ManualTimeSlot>[...input.allTimeSlots]
      ..sort((a, b) {
        final day = a.day.compareTo(b.day);
        if (day != 0) return day;
        final start = a.startMinute.compareTo(b.startMinute);
        if (start != 0) return start;
        return a.endMinute.compareTo(b.endMinute);
      });
    final breaks = <ManualTimeSlot>[
      ...input.allBreakSlots,
      ...all.where((slot) => slot.isBreak),
    ];
    return all
        .where(
          (slot) =>
              !slot.isBreak &&
              !_overlapsAnyBreak(slot, breaks) &&
              slot.endMinute > slot.startMinute,
        )
        .toList(growable: false);
  }

  bool _overlapsAnyBreak(ManualTimeSlot slot, List<ManualTimeSlot> breaks) =>
      breaks.any(
        (breakSlot) =>
            breakSlot.day == slot.day &&
            _overlaps(
              slot.startMinute,
              slot.endMinute,
              breakSlot.startMinute,
              breakSlot.endMinute,
            ),
      );

  List<ManualRoom> _eligibleRooms(_WorkItem item, _Window window) {
    final rooms = _roomById.values
        .where(
          (room) =>
              room.isLab == item.isPractical &&
              room.capacity >= item.batch.size &&
              _departmentAllows(item, room) &&
              !room.isUnavailableAt(
                window.day,
                window.startMinute,
                window.endMinute,
              ),
        )
        .toList();
    rooms.sort((a, b) => a.id.compareTo(b.id));
    return rooms;
  }

  bool _departmentAllows(_WorkItem item, ManualRoom room) {
    final department = item.requirement.department?.trim() ?? '';
    final wanted = department.isNotEmpty ? department : item.batch.department;
    if (wanted.trim().isEmpty || room.department.trim().isEmpty) return true;
    return room.department == wanted || room.borrowable;
  }

  int _preferenceScore(_WorkItem item, _Window window, ManualRoom room) {
    var score = 0;
    final days = item.requirement.preferredDays;
    final starts = item.requirement.preferredStartMinutes;
    final roomIds = item.requirement.preferredRoomIds;
    if (days.isNotEmpty && !days.contains(window.day)) score += 40;
    if (starts.isNotEmpty && !starts.contains(window.startMinute)) score += 20;
    if (roomIds.isNotEmpty && !roomIds.contains(room.id)) score += 10;
    final department = item.requirement.department?.trim() ?? '';
    final wanted = department.isNotEmpty ? department : item.batch.department;
    if (wanted.isNotEmpty &&
        room.department.isNotEmpty &&
        room.department != wanted) {
      score += 2;
    }
    return score;
  }

  void _prepareSearch() {
    _searchWork.sort((left, right) {
      final leftOptions = _optionsByWork[left.searchIndex]!.length;
      final rightOptions = _optionsByWork[right.searchIndex]!.length;
      final scarcity = leftOptions.compareTo(rightOptions);
      if (scarcity != 0) return scarcity;
      if (left.isPractical != right.isPractical) {
        return left.isPractical ? -1 : 1;
      }
      final duration = (right.durationMinutes ?? 0).compareTo(
        left.durationMinutes ?? 0,
      );
      if (duration != 0) return duration;
      final requirement = left.requirementId.compareTo(right.requirementId);
      if (requirement != 0) return requirement;
      return left.sessionId.compareTo(right.sessionId);
    });
  }

  void _search(int index) {
    if (_nodes >= _effectiveNodeLimit) {
      _searchLimitReached = true;
      return;
    }
    _nodes++;
    if (index >= _searchWork.length) {
      _considerCurrent();
      return;
    }
    final remaining = _searchWork.length - index;
    if (_current.length + remaining < _bestCount) return;

    final item = _searchWork[index];
    final options =
        List<_PlacementOption>.from(_optionsByWork[item.searchIndex]!)
          ..sort((left, right) {
            final leftScore = _dynamicScore(left);
            final rightScore = _dynamicScore(right);
            if (leftScore != rightScore) return leftScore.compareTo(rightScore);
            return _optionCompare(left, right);
          });
    for (final option in options) {
      if (!_canPlace(option)) continue;
      final placement = _place(option);
      _current[item.searchIndex] = placement;
      _search(index + 1);
      _current.remove(item.searchIndex);
      _unplace(placement);
      if (_searchLimitReached && _bestCount == _searchWork.length) return;
    }

    // Skipping is what lets the bounded search return a useful partial result
    // and explain the exact requirements that could not be fitted.
    _search(index + 1);
  }

  int get _effectiveNodeLimit => maxSearchNodes.clamp(1, 1000000);

  int _dynamicScore(_PlacementOption option) {
    var score = option.baseScore;
    final facultySessions =
        _facultySessions[option.item.faculty.id] ?? const <ManualSession>[];
    for (final session in facultySessions) {
      if (session.day != option.window.day) continue;
      if (session.endMinute == option.window.startMinute ||
          option.window.endMinute == session.startMinute) {
        score += 10;
      }
    }
    final currentLoad = _facultyLoads[option.item.faculty.id] ?? 0;
    final average = _facultyLoads.values.isEmpty
        ? 0
        : _facultyLoads.values.reduce((left, right) => left + right) /
              _facultyLoads.length;
    if (currentLoad > average) score += ((currentLoad - average) / 30).ceil();
    return score;
  }

  bool _canPlace(_PlacementOption option) {
    final item = option.item;
    final start = option.window.startMinute;
    final end = option.window.endMinute;
    if (item.faculty.isAbsentAt(option.window.day, start, end)) return false;
    final maxMinutes = item.faculty.maxWeeklyHours * 60;
    if (maxMinutes > 0 &&
        (_facultyLoads[item.faculty.id] ?? 0) + (end - start) > maxMinutes) {
      return false;
    }
    if (_hasOverlap(
      _facultySessions[item.faculty.id],
      option.window.day,
      start,
      end,
    )) {
      return false;
    }
    if (_hasOverlap(
      _roomSessions[option.room.id],
      option.window.day,
      start,
      end,
    )) {
      return false;
    }
    if (_hasOverlap(
      _batchSessions[item.batch.id],
      option.window.day,
      start,
      end,
    )) {
      return false;
    }
    return true;
  }

  bool _hasOverlap(List<ManualSession>? sessions, int day, int start, int end) {
    if (sessions == null) return false;
    return sessions.any(
      (session) =>
          session.day == day &&
          _overlaps(start, end, session.startMinute, session.endMinute),
    );
  }

  _Placement _place(_PlacementOption option) {
    final session = ManualSession(
      id: option.item.sessionId,
      subjectId: option.item.subject.id,
      facultyId: option.item.faculty.id,
      batchId: option.item.batch.id,
      roomId: option.room.id,
      day: option.window.day,
      startMinute: option.window.startMinute,
      endMinute: option.window.endMinute,
      type: option.item.isPractical
          ? ManualSessionType.practical
          : ManualSessionType.lecture,
      note: 'Generated from ${option.item.requirementId}',
    );
    _addOccupiedSession(session);
    return _Placement(option: option, session: session);
  }

  void _unplace(_Placement placement) {
    final session = placement.session;
    _removeSession(_facultySessions[session.facultyId], session);
    _removeSession(_roomSessions[session.roomId], session);
    _removeSession(_batchSessions[session.batchId], session);
    final load =
        (_facultyLoads[session.facultyId] ?? 0) - session.durationMinutes;
    if (load <= 0) {
      _facultyLoads.remove(session.facultyId);
    } else {
      _facultyLoads[session.facultyId] = load;
    }
  }

  void _removeSession(List<ManualSession>? sessions, ManualSession target) {
    sessions?.removeWhere((session) => session.id == target.id);
  }

  void _considerCurrent() {
    final count = _current.length;
    final score = _scheduleScore(_current.values);
    final key = _scheduleKey(_current.values);
    if (count > _bestCount ||
        (count == _bestCount &&
            (score < _bestScore ||
                (score == _bestScore &&
                    (_bestKey.isEmpty || key.compareTo(_bestKey) < 0))))) {
      _bestCount = count;
      _bestScore = score;
      _bestKey = key;
      _best = Map<int, _Placement>.from(_current);
    }
  }

  int _scheduleScore(Iterable<_Placement> placements) {
    final list = placements.toList(growable: false);
    var score = 0;
    final loads = <String, int>{for (final id in _facultyById.keys) id: 0};
    for (final placement in list) {
      final option = placement.option;
      score += option.baseScore;
      loads[option.item.faculty.id] =
          (loads[option.item.faculty.id] ?? 0) +
          placement.session.durationMinutes;
    }
    for (var left = 0; left < list.length; left++) {
      final first = list[left].session;
      for (var right = left + 1; right < list.length; right++) {
        final second = list[right].session;
        if (first.facultyId != second.facultyId || first.day != second.day) {
          continue;
        }
        if (first.endMinute == second.startMinute ||
            second.endMinute == first.startMinute) {
          score += 10;
        }
      }
    }
    if (loads.length > 1) {
      final values = loads.values.toList()..sort();
      score += (values.last - values.first) ~/ 30;
    }
    return score;
  }

  String _scheduleKey(Iterable<_Placement> placements) {
    final sessions = placements.map((placement) => placement.session).toList()
      ..sort(_sessionCompare);
    return sessions
        .map(
          (session) =>
              '${session.id}@${session.day}:${session.startMinute}:${session.roomId}',
        )
        .join('|');
  }

  String _reasonFor(_WorkItem item) {
    final options = _optionsByWork[item.searchIndex];
    if (options == null || options.isEmpty) {
      return 'No eligible room and time-window combination remains.';
    }
    final physical = options.any(
      (option) => option.item.faculty.absences.every(
        (absence) =>
            !_overlaps(
              option.window.startMinute,
              option.window.endMinute,
              absence.startMinute,
              absence.endMinute,
            ) ||
            absence.day != option.window.day,
      ),
    );
    if (!physical) return 'Faculty absence blocks every candidate window.';
    return _searchLimitReached
        ? 'The bounded search limit was reached before this requirement could be placed.'
        : 'All candidate windows are occupied by another faculty, room, or batch session.';
  }

  TimetableUnassignedRequirement _unassignedFor(
    _WorkItem item,
    String reason,
  ) => TimetableUnassignedRequirement(
    id: item.sessionId,
    requirementId: item.requirementId,
    subjectId: item.subject.id,
    batchId: item.batch.id,
    facultyId: item.faculty.id,
    isPractical: item.isPractical,
    durationMinutes: item.durationMinutes ?? 0,
    reason: reason,
  );

  void _appendUnassignedIssues(
    List<TimetableUnassignedRequirement> unassigned,
  ) {
    final existing = _issues.map((issue) => issue.message).toSet();
    for (final item in unassigned) {
      final subject = _subjectById[item.subjectId];
      final batch = _batchById[item.batchId];
      final faculty = _facultyById[item.facultyId];
      final message =
          'Could not place ${subject?.name ?? item.subjectId} for '
          '${batch?.name ?? item.batchId} (${faculty?.name ?? item.facultyId}): '
          '${item.reason}';
      if (existing.add(message)) {
        _issues.add(
          ManualIssue(
            code: 'UNASSIGNED_REQUIREMENT',
            message: message,
            sessionIds: <String>[item.id],
          ),
        );
      }
    }
  }

  void _appendGeneratedValidationIssues(List<ManualSession> sessions) {
    for (final session in sessions) {
      final subject = _subjectById[session.subjectId];
      final batch = _batchById[session.batchId];
      final faculty = _facultyById[session.facultyId];
      final room = _roomById[session.roomId];
      final practical = session.isPractical || subject?.isPractical == true;
      if (subject == null || batch == null || faculty == null || room == null) {
        _issues.add(
          ManualIssue(
            code: 'INVALID_SESSION',
            message:
                'Generated session ${session.id} references an invalid entity.',
            sessionIds: <String>[session.id],
          ),
        );
        continue;
      }
      if (session.endMinute <= session.startMinute) {
        _issues.add(
          ManualIssue(
            code: 'INVALID_SESSION',
            message: 'Generated session ${session.id} has an invalid interval.',
            sessionIds: <String>[session.id],
          ),
        );
      }
      if (practical != room.isLab) {
        _issues.add(
          ManualIssue(
            code: 'ROOM_TYPE',
            message:
                '${room.name} is not compatible with ${_subjectNameFor(subject)}.',
            sessionIds: <String>[session.id],
          ),
        );
      }
      if (room.capacity < batch.size) {
        _issues.add(
          ManualIssue(
            code: 'ROOM_CAPACITY',
            message: '${room.name} cannot seat ${batch.name}.',
            sessionIds: <String>[session.id],
          ),
        );
      }
      if (faculty.isAbsentAt(
        session.day,
        session.startMinute,
        session.endMinute,
      )) {
        _issues.add(
          ManualIssue(
            code: 'FACULTY_ABSENCE',
            message: '${faculty.name} is absent during ${session.id}.',
            sessionIds: <String>[session.id],
          ),
        );
      }
      if (room.isUnavailableAt(
        session.day,
        session.startMinute,
        session.endMinute,
      )) {
        _issues.add(
          ManualIssue(
            code: 'ROOM_CLOSED',
            message: '${room.name} is unavailable during ${session.id}.',
            sessionIds: <String>[session.id],
          ),
        );
      }
      if (_overlapsBreak(session)) {
        _issues.add(
          ManualIssue(
            code: 'BREAK_OVERLAP',
            message: 'Generated session ${session.id} overlaps a break.',
            sessionIds: <String>[session.id],
          ),
        );
      }
    }
    for (var left = 0; left < sessions.length; left++) {
      final first = sessions[left];
      for (var right = left + 1; right < sessions.length; right++) {
        final second = sessions[right];
        if (first.day != second.day ||
            !_overlaps(
              first.startMinute,
              first.endMinute,
              second.startMinute,
              second.endMinute,
            )) {
          continue;
        }
        final ids = <String>[first.id, second.id];
        if (first.facultyId == second.facultyId) {
          _issues.add(
            ManualIssue(
              code: 'FACULTY_OVERLAP',
              message: 'Faculty overlap between ${ids.join(' and ')}.',
              sessionIds: ids,
            ),
          );
        }
        if (first.roomId == second.roomId) {
          _issues.add(
            ManualIssue(
              code: 'ROOM_OVERLAP',
              message: 'Room overlap between ${ids.join(' and ')}.',
              sessionIds: ids,
            ),
          );
        }
        if (first.batchId == second.batchId) {
          _issues.add(
            ManualIssue(
              code: 'BATCH_OVERLAP',
              message: 'Batch overlap between ${ids.join(' and ')}.',
              sessionIds: ids,
            ),
          );
        }
      }
    }
  }

  bool _overlapsBreak(ManualSession session) {
    final breaks = <ManualTimeSlot>[
      ...input.allBreakSlots,
      ...input.allTimeSlots.where((slot) => slot.isBreak),
    ];
    return breaks.any(
      (breakSlot) =>
          breakSlot.day == session.day &&
          _overlaps(
            session.startMinute,
            session.endMinute,
            breakSlot.startMinute,
            breakSlot.endMinute,
          ),
    );
  }

  void _appendSoftIssues(List<ManualSession> sessions) {
    final seen = <String>{};
    for (var left = 0; left < sessions.length; left++) {
      final first = sessions[left];
      for (var right = left + 1; right < sessions.length; right++) {
        final second = sessions[right];
        if (first.day != second.day ||
            first.facultyId != second.facultyId ||
            (first.endMinute != second.startMinute &&
                second.endMinute != first.startMinute)) {
          continue;
        }
        final ids = <String>[first.id, second.id]..sort();
        if (!seen.add(ids.join('|'))) continue;
        _issues.add(
          ManualIssue(
            code: 'BACK_TO_BACK_TEACHING',
            message:
                '${_facultyById[first.facultyId]?.name ?? first.facultyId} has back-to-back teaching on day ${first.day + 1}.',
            sessionIds: ids,
            isHard: false,
          ),
        );
      }
    }
    final loads = <String, int>{for (final id in _facultyById.keys) id: 0};
    for (final session in sessions) {
      loads[session.facultyId] =
          (loads[session.facultyId] ?? 0) + session.durationMinutes;
    }
    if (loads.length > 1) {
      final values = loads.values.toList()..sort();
      final spread = values.last - values.first;
      if (spread >= 60) {
        _issues.add(
          ManualIssue(
            code: 'WORKLOAD_BALANCE',
            message:
                'Faculty workload differs by $spread minutes; consider balancing the teaching load.',
            isHard: false,
          ),
        );
      }
    }
  }

  String _infeasibleMessage({
    required int scheduledCount,
    required int requestedCount,
  }) {
    final count = requestedCount - scheduledCount;
    final suffix = _searchLimitReached
        ? ' The bounded search limit was reached.'
        : '';
    return 'Unable to place $count of $requestedCount required sessions; $scheduledCount were generated. Review the validation issues for room, faculty, batch, break, or availability conflicts.$suffix';
  }

  String _subjectName(_WorkItem item) => _subjectNameFor(item.subject);

  String _subjectNameFor(ManualSubject subject) =>
      subject.name.trim().isEmpty ? subject.id : subject.name;

  void _addInputIssue(String message, {String code = 'INVALID_INPUT'}) {
    _issues.add(ManualIssue(code: code, message: message));
  }

  String _stableGenerationId() {
    final parts = <String>[
      for (final faculty in _facultyById.values)
        'faculty:${faculty.id}:${faculty.maxWeeklyHours}:${faculty.isProxy}:${faculty.absences.map((absence) => '${absence.day}:${absence.startMinute}:${absence.endMinute}').join(',')}',
      for (final room in _roomById.values)
        'room:${room.id}:${room.kind}:${room.capacity}:${room.department}:${room.borrowable}:${room.isAvailable}:${room.unavailableSlots.map((closure) => '${closure.day}:${closure.startMinute}:${closure.endMinute}').join(',')}',
      for (final batch in _batchById.values)
        'batch:${batch.id}:${batch.year}:${batch.size}:${batch.department}',
      for (final subject in _subjectById.values)
        'subject:${subject.id}:${subject.isPractical}:${subject.lectureHours}:${subject.labHours}',
      for (final slot in input.allTimeSlots)
        'slot:${slot.day}:${slot.startMinute}:${slot.endMinute}:${slot.isBreak}',
      for (final slot in input.allBreakSlots)
        'break:${slot.day}:${slot.startMinute}:${slot.endMinute}:${slot.isBreak}',
      for (final requirement in input.requirements)
        'requirement:${requirement.stableId}:${requirement.subjectId}:${requirement.batchId}:${requirement.facultyId}:${requirement.lectureHours}:${requirement.labHours}:${requirement.lectureSessions}:${requirement.labSessions}:${requirement.isPractical}:${requirement.practical}:${requirement.sessionDurationMinutes}:${requirement.durationMinutes}:${requirement.lectureDurationMinutes}:${requirement.labDurationMinutes}:${requirement.department}:${requirement.preferredDays.join(',')}:${requirement.preferredStartMinutes.join(',')}:${requirement.preferredRoomIds.join(',')}',
      for (final session in input.allExistingSessions)
        'session:${session.id}:${session.subjectId}:${session.facultyId}:${session.batchId}:${session.roomId}:${session.day}:${session.startMinute}:${session.endMinute}:${session.type.name}',
    ];
    parts.sort();
    var hash = 2166136261;
    for (final codeUnit in parts.join('|').codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 16777619) & 0x7fffffff;
    }
    return 'timetable-${hash.toRadixString(16).padLeft(8, '0')}';
  }

  static int _windowCompare(_Window left, _Window right) {
    final day = left.day.compareTo(right.day);
    if (day != 0) return day;
    final start = left.startMinute.compareTo(right.startMinute);
    if (start != 0) return start;
    return left.endMinute.compareTo(right.endMinute);
  }

  static int _optionCompare(_PlacementOption left, _PlacementOption right) {
    final score = left.baseScore.compareTo(right.baseScore);
    if (score != 0) return score;
    final window = _windowCompare(left.window, right.window);
    if (window != 0) return window;
    return left.room.id.compareTo(right.room.id);
  }

  static int _sessionCompare(ManualSession left, ManualSession right) {
    final day = left.day.compareTo(right.day);
    if (day != 0) return day;
    final start = left.startMinute.compareTo(right.startMinute);
    if (start != 0) return start;
    final end = left.endMinute.compareTo(right.endMinute);
    if (end != 0) return end;
    return left.id.compareTo(right.id);
  }

  static bool _overlaps(int startA, int endA, int startB, int endB) =>
      startA < endB && startB < endA;
}

class _WorkItem {
  _WorkItem({
    required this.requirement,
    required this.requirementId,
    required this.subject,
    required this.batch,
    required this.faculty,
    required this.isPractical,
    required this.occurrence,
    required this.durationMinutes,
    required this.slotCount,
  });

  final TimetableTeachingRequirement requirement;
  final String requirementId;
  final ManualSubject subject;
  final ManualBatch batch;
  final ManualFaculty faculty;
  final bool isPractical;
  final int occurrence;
  final int? durationMinutes;
  final int? slotCount;
  int searchIndex = -1;

  String get sessionId =>
      '$requirementId:${isPractical ? 'P' : 'L'}${occurrence + 1}';
}

class _Window {
  const _Window({
    required this.day,
    required this.startMinute,
    required this.endMinute,
  });

  final int day;
  final int startMinute;
  final int endMinute;

  String get key => '$day:$startMinute:$endMinute';
}

class _PlacementOption {
  const _PlacementOption({
    required this.item,
    required this.room,
    required this.window,
    required this.baseScore,
  });

  final _WorkItem item;
  final ManualRoom room;
  final _Window window;
  final int baseScore;
}

class _Placement {
  const _Placement({required this.option, required this.session});

  final _PlacementOption option;
  final ManualSession session;
}
