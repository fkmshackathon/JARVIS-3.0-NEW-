/// Immutable data objects used by the local manual timetable prototype.
///
/// These objects deliberately do not mirror the server wire models. The manual
/// editor is a small, frontend-only draft surface and must remain useful when
/// there is no backend connection.
library;

enum ManualSessionType {
  lecture,
  practical;

  bool get isPractical => this == ManualSessionType.practical;

  String get label => switch (this) {
    ManualSessionType.lecture => 'Lecture',
    ManualSessionType.practical => 'Practical',
  };

  static ManualSessionType fromString(String value) =>
      value.toLowerCase() == 'practical'
      ? ManualSessionType.practical
      : ManualSessionType.lecture;
}

/// A manually placed class. Times are minutes since midnight and day is
/// zero-based (Monday = 0, Saturday = 5), which keeps sorting deterministic.
class ManualSession {
  const ManualSession({
    required this.id,
    required this.subjectId,
    required this.facultyId,
    required this.batchId,
    required this.roomId,
    required this.day,
    int? startMinute,
    int? endMinute,
    int? start,
    int? end,
    this.type = ManualSessionType.lecture,
    this.note = '',
  }) : startMinute = startMinute ?? start ?? 0,
       endMinute = endMinute ?? end ?? 0;

  final String id;
  final String subjectId;
  final String facultyId;
  final String batchId;
  final String roomId;
  final int day;
  final int startMinute;
  final int endMinute;
  final ManualSessionType type;
  final String note;

  /// Short aliases make this object convenient to use in timeline widgets.
  int get start => startMinute;
  int get end => endMinute;
  int get startTime => startMinute;
  int get endTime => endMinute;
  int get durationMinutes => (endMinute - startMinute).clamp(0, 24 * 60);
  bool get isPractical => type.isPractical;
  bool get isLab => isPractical;
  String get typeLabel => type.label;

  ManualSession copyWith({
    String? id,
    String? subjectId,
    String? facultyId,
    String? batchId,
    String? roomId,
    int? day,
    int? startMinute,
    int? endMinute,
    ManualSessionType? type,
    String? note,
  }) => ManualSession(
    id: id ?? this.id,
    subjectId: subjectId ?? this.subjectId,
    facultyId: facultyId ?? this.facultyId,
    batchId: batchId ?? this.batchId,
    roomId: roomId ?? this.roomId,
    day: day ?? this.day,
    startMinute: startMinute ?? this.startMinute,
    endMinute: endMinute ?? this.endMinute,
    type: type ?? this.type,
    note: note ?? this.note,
  );

  @override
  String toString() =>
      'ManualSession($id, $subjectId, day=$day, $startMinute-$endMinute)';
}

class ManualFaculty {
  const ManualFaculty({
    required this.id,
    required this.name,
    required this.department,
    this.maxWeeklyHours = 24,
    this.absences = const <ManualAbsence>[],
    this.isProxy = false,
  });

  final String id;
  final String name;
  final String department;
  final int maxWeeklyHours;
  final List<ManualAbsence> absences;
  final bool isProxy;

  bool isAbsentAt(int day, int startMinute, int endMinute) => absences.any(
    (absence) =>
        absence.day == day &&
        _overlaps(
          startMinute,
          endMinute,
          absence.startMinute,
          absence.endMinute,
        ),
  );

  ManualFaculty copyWith({
    String? id,
    String? name,
    String? department,
    int? maxWeeklyHours,
    List<ManualAbsence>? absences,
    bool? isProxy,
  }) => ManualFaculty(
    id: id ?? this.id,
    name: name ?? this.name,
    department: department ?? this.department,
    maxWeeklyHours: maxWeeklyHours ?? this.maxWeeklyHours,
    absences: List<ManualAbsence>.unmodifiable(absences ?? this.absences),
    isProxy: isProxy ?? this.isProxy,
  );
}

class ManualAbsence {
  const ManualAbsence({
    required this.day,
    required this.startMinute,
    required this.endMinute,
    this.reason = 'Unavailable',
  });

  final int day;
  final int startMinute;
  final int endMinute;
  final String reason;
}

class ManualRoom {
  const ManualRoom({
    required this.id,
    required this.name,
    required this.kind,
    required this.capacity,
    required this.department,
    this.borrowable = true,
    this.isAvailable = true,
    this.unavailableSlots = const <ManualRoomClosure>[],
  });

  final String id;
  final String name;
  final String kind;
  final int capacity;
  final String department;
  final bool borrowable;
  final bool isAvailable;
  final List<ManualRoomClosure> unavailableSlots;

  bool get isLab =>
      kind.toLowerCase() == 'laboratory' || kind.toLowerCase() == 'lab';

  bool isUnavailableAt(int day, int startMinute, int endMinute) =>
      !isAvailable ||
      unavailableSlots.any(
        (closure) =>
            closure.day == day &&
            _overlaps(
              startMinute,
              endMinute,
              closure.startMinute,
              closure.endMinute,
            ),
      );

  ManualRoom copyWith({
    String? id,
    String? name,
    String? kind,
    int? capacity,
    String? department,
    bool? borrowable,
    bool? isAvailable,
    List<ManualRoomClosure>? unavailableSlots,
  }) => ManualRoom(
    id: id ?? this.id,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    capacity: capacity ?? this.capacity,
    department: department ?? this.department,
    borrowable: borrowable ?? this.borrowable,
    isAvailable: isAvailable ?? this.isAvailable,
    unavailableSlots: List<ManualRoomClosure>.unmodifiable(
      unavailableSlots ?? this.unavailableSlots,
    ),
  );
}

class ManualRoomClosure {
  const ManualRoomClosure({
    required this.day,
    required this.startMinute,
    required this.endMinute,
    this.reason = 'Unavailable',
  });

  final int day;
  final int startMinute;
  final int endMinute;
  final String reason;
}

class ManualSubject {
  const ManualSubject({
    required this.id,
    required this.name,
    required this.code,
    this.isPractical = false,
    this.lectureHours = 0,
    this.labHours = 0,
  });

  final String id;
  final String name;
  final String code;
  final bool isPractical;
  final int lectureHours;
  final int labHours;
}

class ManualBatch {
  const ManualBatch({
    required this.id,
    required this.name,
    required this.year,
    required this.size,
    this.department = 'Information Technology',
  });

  final String id;
  final String name;
  final int year;
  final int size;
  final String department;
}

class ManualTimeSlot {
  const ManualTimeSlot({
    required this.day,
    required this.startMinute,
    required this.endMinute,
    this.isBreak = false,
    this.label,
  });

  final int day;
  final int startMinute;
  final int endMinute;
  final bool isBreak;
  final String? label;

  String get key => '$day:$startMinute';
}

/// A local issue is intentionally distinct from the server-side [Violation].
class ManualIssue {
  const ManualIssue({
    required this.code,
    required this.message,
    this.sessionIds = const <String>[],
    this.isHard = true,
  });

  final String code;
  final String message;
  final List<String> sessionIds;
  final bool isHard;

  bool get isWarning => !isHard;
  bool get isConflict => isHard;
  String get severity => isHard ? 'hard' : 'soft';
}

class ManualSwapRequest {
  const ManualSwapRequest({
    required this.id,
    required this.sessionId,
    this.targetFacultyId,
    this.targetSessionId,
    this.note = '',
    this.status = 'draft',
  });

  final String id;
  final String sessionId;
  final String? targetFacultyId;
  final String? targetSessionId;
  final String note;
  final String status;
}

bool _overlaps(int startA, int endA, int startB, int endB) =>
    startA < endB && startB < endA;
