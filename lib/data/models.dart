/// The subset of the domain the client has to draw. Field names match the API's JSON
/// exactly — the solver, the validator and the audit trail all stay server-side.
library;

String formatMinutes(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

const List<String> _dayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

String dayName(int day) =>
    day >= 0 && day < _dayNames.length ? _dayNames[day] : 'Day $day';

Map<String, dynamic> jsonMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const <String, dynamic>{};

List<Map<String, dynamic>> jsonMapList(Object? value) =>
    (value as List<dynamic>? ?? const <dynamic>[]).map(jsonMap).toList();

class Slot {
  const Slot({
    required this.day,
    required this.index,
    required this.start,
    required this.end,
  });

  final int day;
  final int index;
  final int start;
  final int end;

  static Slot fromMap(Map<String, dynamic> m) => Slot(
    day: m['day'] as int,
    index: m['index'] as int,
    start: m['start'] as int,
    end: m['end'] as int,
  );
}

class Faculty {
  const Faculty({
    required this.id,
    required this.name,
    required this.department,
    required this.maxWeeklyHours,
  });

  final String id;
  final String name;
  final String department;
  final int maxWeeklyHours;

  static Faculty fromMap(Map<String, dynamic> m) => Faculty(
    id: m['id'] as String,
    name: m['name'] as String,
    department: (m['department'] as String?) ?? '',
    maxWeeklyHours: (m['max_weekly_hours'] as int?) ?? 24,
  );
}

class Room {
  const Room({
    required this.id,
    required this.name,
    required this.kind,
    required this.capacity,
    required this.department,
    required this.borrowable,
  });

  final String id;
  final String name;
  final String kind;
  final int capacity;
  final String department;
  final bool borrowable;

  bool get isLab => kind == 'laboratory';

  static Room fromMap(Map<String, dynamic> m) => Room(
    id: m['id'] as String,
    name: m['name'] as String,
    kind: (m['kind'] as String?) ?? 'classroom',
    capacity: (m['capacity'] as int?) ?? 0,
    department: (m['department'] as String?) ?? '',
    borrowable: (m['borrowable'] as bool?) ?? true,
  );
}

class Batch {
  const Batch({
    required this.id,
    required this.name,
    required this.year,
    required this.size,
  });

  final String id;
  final String name;
  final int year;
  final int size;

  static Batch fromMap(Map<String, dynamic> m) => Batch(
    id: m['id'] as String,
    name: m['name'] as String,
    year: (m['year'] as int?) ?? 0,
    size: (m['size'] as int?) ?? 0,
  );
}

class Subject {
  const Subject({
    required this.id,
    required this.name,
    required this.lectureHours,
    required this.labHours,
    required this.labDurationSlots,
  });

  final String id;
  final String name;
  final int lectureHours;
  final int labHours;
  final int labDurationSlots;

  static Subject fromMap(Map<String, dynamic> m) => Subject(
    id: m['id'] as String,
    name: m['name'] as String,
    lectureHours: (m['lecture_hours'] as int?) ?? 0,
    labHours: (m['lab_hours'] as int?) ?? 0,
    labDurationSlots: (m['lab_duration_slots'] as int?) ?? 1,
  );
}

class Campus {
  Campus({
    required this.name,
    required this.payload,
    required this.slots,
    required this.faculty,
    required this.rooms,
    required this.batches,
    required this.subjects,
  });

  final String name;

  /// Sent back verbatim on `PUT` — re-deriving these fields client-side would risk
  /// disagreeing with the definition the validator checks against.
  final Map<String, dynamic> payload;
  final List<Slot> slots;
  final List<Faculty> faculty;
  final List<Room> rooms;
  final List<Batch> batches;
  final List<Subject> subjects;

  late final Map<String, Faculty> facultyById = {
    for (final f in faculty) f.id: f,
  };
  late final Map<String, Room> roomsById = {for (final r in rooms) r.id: r};
  late final Map<String, Batch> batchesById = {
    for (final b in batches) b.id: b,
  };
  late final Map<String, Subject> subjectsById = {
    for (final s in subjects) s.id: s,
  };
  late final Map<String, Slot> slotByKey = {
    for (final s in slots) '${s.day}:${s.index}': s,
  };

  factory Campus.fromPayload(String name, Map<String, dynamic> payload) {
    List<T> parse<T>(String key, T Function(Map<String, dynamic>) build) {
      final raw = payload[key] as List<dynamic>?;
      if (raw == null) return <T>[];
      return raw
          .map((e) => build(Map<String, dynamic>.from(e as Map)))
          .toList();
    }

    return Campus(
      name: name,
      payload: payload,
      slots: parse<Slot>('slots', Slot.fromMap),
      faculty: parse<Faculty>('faculty', Faculty.fromMap),
      rooms: parse<Room>('rooms', Room.fromMap),
      batches: parse<Batch>('batches', Batch.fromMap),
      subjects: parse<Subject>('subjects', Subject.fromMap),
    );
  }

  String subjectName(String id) => subjectsById[id]?.name ?? id;
  String facultyName(String id) => facultyById[id]?.name ?? id;
  String roomName(String id) => roomsById[id]?.name ?? id;
  String batchName(String id) => batchesById[id]?.name ?? id;

  /// Period indexes present on the campus, ascending — the rows of the grid.
  late final List<int> periodIndexes =
      slots.map((s) => s.index).toSet().toList()..sort();

  /// Earliest start recorded for a period index; staggered entries mean the index is
  /// the shared label, the time is whichever batch starts there first.
  late final Map<int, int> periodStart = <int, int>{
    for (final index in periodIndexes)
      index: slots
          .where((s) => s.index == index)
          .map((s) => s.start)
          .reduce((a, b) => a < b ? a : b),
  };

  late final List<int> dayNumbers = slots.map((s) => s.day).toSet().toList()
    ..sort();

  bool isBreak(int day, int index) => breakKeys.contains('$day:$index');

  late final Set<String> breakKeys = {
    for (final pair in (payload['break_slots'] as List<dynamic>? ?? const []))
      '${pair[0]}:${pair[1]}',
  };
}

class Assignment {
  const Assignment({
    required this.sessionId,
    required this.batchId,
    required this.subjectId,
    required this.facultyId,
    required this.roomId,
    required this.day,
    required this.index,
    required this.start,
    required this.end,
    required this.isLab,
    required this.roomKind,
    required this.department,
  });

  final String sessionId;
  final String batchId;
  final String subjectId;
  final String facultyId;
  final String roomId;
  final int day;
  final int index;
  final int start;
  final int end;
  final bool isLab;
  final String roomKind;
  final String department;

  static Assignment fromMap(Map<String, dynamic> m) => Assignment(
    sessionId: m['session_id'] as String,
    batchId: m['batch_id'] as String,
    subjectId: m['subject_id'] as String,
    facultyId: m['faculty_id'] as String,
    roomId: m['room_id'] as String,
    day: m['day'] as int,
    index: m['index'] as int,
    start: m['start'] as int,
    end: m['end'] as int,
    isLab: m['is_lab'] as bool? ?? false,
    roomKind: m['room_kind'] as String? ?? 'classroom',
    department: m['department'] as String? ?? '',
  );

  Map<String, dynamic> toMap() => {
    'session_id': sessionId,
    'batch_id': batchId,
    'subject_id': subjectId,
    'faculty_id': facultyId,
    'room_id': roomId,
    'day': day,
    'index': index,
    'start': start,
    'end': end,
    'is_lab': isLab,
    'room_kind': roomKind,
    'department': department,
  };
}

class Violation {
  const Violation({
    required this.code,
    required this.message,
    required this.refs,
  });

  final String code;
  final String message;
  final List<String> refs;

  static Violation fromMap(Map<String, dynamic> m) => Violation(
    code: m['code'] as String,
    message: m['message'] as String,
    refs: (m['refs'] as List<dynamic>? ?? const <dynamic>[])
        .map((e) => '$e')
        .toList(),
  );
}

class Summary {
  const Summary(this.raw);

  final Map<String, dynamic> raw;

  Map<String, dynamic> get _periods => jsonMap(raw['periods']);
  Map<String, dynamic> get _demand => jsonMap(raw['demand']);
  Map<String, dynamic> get _supply => jsonMap(raw['supply']);

  int get totalPeriods => _periods['total'] as int? ?? 0;
  int get usablePeriods => _periods['usable'] as int? ?? 0;
  int get dayCount => _periods['days'] as int? ?? 0;
  int get sessions => _demand['sessions'] as int? ?? 0;
  int get lecturePeriods => _demand['lecture_periods'] as int? ?? 0;
  int get labPeriods => _demand['lab_periods'] as int? ?? 0;
  int get classrooms => _supply['classrooms'] as int? ?? 0;
  int get laboratories => _supply['laboratories'] as int? ?? 0;
  int get classroomCapacity => _supply['classroom_periods'] as int? ?? 0;
  int get laboratoryCapacity => _supply['laboratory_periods'] as int? ?? 0;

  bool get canGenerate => raw['can_generate'] as bool? ?? false;
  String? get blocker => raw['blocker'] as String?;

  List<String> get warnings =>
      ((raw['warnings'] as List<dynamic>?) ?? const []).cast<String>();

  List<Map<String, dynamic>> get faculty => _rows('faculty');
  List<Map<String, dynamic>> get batches => _rows('batches');
  List<Map<String, dynamic>> get rooms => _rows('rooms');

  List<Map<String, dynamic>> _rows(String key) => jsonMapList(raw[key]);
}

class Utilisation {
  const Utilisation({
    required this.roomsInUse,
    required this.roomsOnCampus,
    required this.borrowedPeriods,
    required this.busiest,
  });

  final int roomsInUse;
  final int roomsOnCampus;
  final int borrowedPeriods;
  final List<Map<String, dynamic>> busiest;

  static Utilisation? fromMap(Object? value) {
    if (value is! Map) return null;
    final m = jsonMap(value);
    return Utilisation(
      roomsInUse: m['rooms_in_use'] as int? ?? 0,
      roomsOnCampus: m['rooms_on_campus'] as int? ?? 0,
      borrowedPeriods: m['borrowed_periods'] as int? ?? 0,
      busiest: jsonMapList(m['busiest']),
    );
  }
}

class GenerationResult {
  const GenerationResult({
    required this.runId,
    required this.status,
    required this.solverStatus,
    required this.softCost,
    required this.wallTimeMs,
    required this.message,
    required this.assignments,
    required this.violations,
    required this.publishable,
    this.utilisation,
  });

  final int runId;
  final String status;
  final String solverStatus;
  final int? softCost;
  final int wallTimeMs;
  final String message;
  final List<Assignment> assignments;
  final List<Violation> violations;
  final bool publishable;
  final Utilisation? utilisation;

  bool get solved => status == 'solved';

  static GenerationResult fromMap(Map<String, dynamic> m) => GenerationResult(
    runId: m['run_id'] as int? ?? 0,
    status: m['status'] as String? ?? 'infeasible',
    solverStatus: m['solver_status'] as String? ?? '',
    softCost: m['soft_cost'] as int?,
    wallTimeMs: m['wall_time_ms'] as int? ?? 0,
    message: m['message'] as String? ?? '',
    assignments: jsonMapList(m['assignments']).map(Assignment.fromMap).toList(),
    violations: jsonMapList(m['violations']).map(Violation.fromMap).toList(),
    publishable: m['publishable'] as bool? ?? false,
    utilisation: Utilisation.fromMap(m['utilisation']),
  );
}

class RunRecord {
  const RunRecord({
    required this.id,
    required this.createdAt,
    required this.status,
    required this.solverStatus,
    required this.softCost,
    required this.wallTimeMs,
    required this.sessionCount,
    required this.message,
  });

  final int id;
  final String createdAt;
  final String status;
  final String solverStatus;
  final int? softCost;
  final int wallTimeMs;
  final int sessionCount;
  final String message;

  static RunRecord fromMap(Map<String, dynamic> m) => RunRecord(
    id: m['id'] as int? ?? 0,
    createdAt: m['created_at'] as String? ?? '',
    status: m['status'] as String? ?? '',
    solverStatus: m['solver_status'] as String? ?? '',
    softCost: m['soft_cost'] as int?,
    wallTimeMs: m['wall_time_ms'] as int? ?? 0,
    sessionCount: m['session_count'] as int? ?? 0,
    message: m['message'] as String? ?? '',
  );
}
