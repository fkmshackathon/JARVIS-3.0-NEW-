import 'manual_timetable_controller.dart';

enum TimetableViewKind { department, master, classView, faculty }

extension TimetableViewKindLabel on TimetableViewKind {
  String get label => switch (this) {
    TimetableViewKind.department => 'Department',
    TimetableViewKind.master => 'Master',
    TimetableViewKind.classView => 'Class',
    TimetableViewKind.faculty => 'Faculty',
  };
}

/// A projection of the active workspace, never a second schedule. All filters
/// and exports resolve stable session IDs against the same controller.
class TimetableViewFilter {
  const TimetableViewFilter({
    this.kind = TimetableViewKind.classView,
    this.department,
    this.batchId,
    this.facultyId,
    this.roomId,
    this.year,
    this.day,
  });

  final TimetableViewKind kind;
  final String? department;
  final String? batchId;
  final String? facultyId;
  final String? roomId;
  final int? year;
  final int? day;

  List<ManualSession> sessions(ManualTimetableController workspace) => workspace
      .sessionsFor()
      .where((session) {
        final batch = workspace.batchById(session.batchId);
        return (department == null || batch?.department == department) &&
            (batchId == null || session.batchId == batchId) &&
            (facultyId == null || session.facultyId == facultyId) &&
            (roomId == null || session.roomId == roomId) &&
            (year == null || batch?.year == year) &&
            (day == null || session.day == day);
      })
      .toList(growable: false);

  String describe(ManualTimetableController workspace) => [
    '${kind.label} timetable',
    workspace.semesterLabel,
    ?department,
    if (batchId != null) workspace.batchById(batchId!)?.name ?? batchId!,
    if (facultyId != null)
      workspace.facultyById(facultyId!)?.name ?? facultyId!,
    if (roomId != null) workspace.roomById(roomId!)?.name ?? roomId!,
    if (year != null) 'Year $year',
    if (day != null) workspace.dayName(day!),
  ].join(' · ');

  static List<String> departments(ManualTimetableController workspace) =>
      (workspace.batches.map((batch) => batch.department).toSet().toList()
        ..sort());
}

String timetableClock(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
