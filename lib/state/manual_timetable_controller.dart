import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'timetable_generator.dart';

export 'manual_timetable_models.dart';
export 'timetable_generator.dart';

/// Owns the local timetable workspace used by setup, generation, editing, and
/// issue review.
///
/// This controller intentionally has no API client. It is a deterministic local
/// prototype: a coordinator configures teaching requirements, generates a
/// timetable, inspects local hard conflicts and soft warnings, then edits or
/// saves a draft. Persistence is limited to the device/browser.
class ManualTimetableController extends ChangeNotifier {
  static const String _storageKey = 'synchro.workspace.v2';

  static const String defaultInstitution = 'Northstar Institute of Technology';
  static const String defaultSemester = 'Semester 2 · 2026';

  ManualTimetableController({
    List<ManualSession>? sessions,
    List<ManualFaculty>? faculty,
    List<ManualRoom>? rooms,
    List<ManualSubject>? subjects,
    List<ManualBatch>? batches,
  }) : _initialSeedDemo = true {
    _initialize(
      sessions: sessions,
      faculty: faculty,
      rooms: rooms,
      subjects: subjects,
      batches: batches,
    );
  }

  /// Creates an empty local workspace. The regular constructor intentionally
  /// keeps its demo setup for existing callers; library records use this path
  /// when they need a genuinely blank timetable.
  ManualTimetableController.blank({
    List<ManualSession>? sessions,
    List<ManualFaculty>? faculty,
    List<ManualRoom>? rooms,
    List<ManualSubject>? subjects,
    List<ManualBatch>? batches,
  }) : _initialSeedDemo = false {
    _initialize(
      sessions: sessions,
      faculty: faculty,
      rooms: rooms,
      subjects: subjects,
      batches: batches,
    );
  }

  final bool _initialSeedDemo;

  void _initialize({
    List<ManualSession>? sessions,
    List<ManualFaculty>? faculty,
    List<ManualRoom>? rooms,
    List<ManualSubject>? subjects,
    List<ManualBatch>? batches,
  }) {
    if (_initialSeedDemo) {
      _seedDemoData();
    } else {
      _scenarioLabel = blankDataLabel;
      _rebuildTimeSlots();
    }
    if (sessions != null) _sessions = List<ManualSession>.from(sessions);
    if (faculty != null) _faculty = List<ManualFaculty>.from(faculty);
    if (rooms != null) _rooms = List<ManualRoom>.from(rooms);
    if (subjects != null) _subjects = List<ManualSubject>.from(subjects);
    if (batches != null) _batches = List<ManualBatch>.from(batches);

    _selectedBatchId = _batches.isEmpty ? '' : _batches.first.id;
    _selectedDay = 0;
    _savedSessions = List<ManualSession>.from(_sessions);
    _savedFaculty = List<ManualFaculty>.from(_faculty);
    _savedRooms = List<ManualRoom>.from(_rooms);
    _savedSwapRequests = const <ManualSwapRequest>[];
    _savedSubjects = List<ManualSubject>.from(_subjects);
    _savedBatches = List<ManualBatch>.from(_batches);
    _savedRequirements = List<TimetableTeachingRequirement>.from(_requirements);
    _savedScenarioLabel = _scenarioLabel;
    _savedInstitutionName = _institutionName;
    _savedSemesterLabel = _semesterLabel;
    _savedWorkingDays = Set<int>.from(_workingDays);
    _savedBreakStart = _breakStart;
    _savedBreakEnd = _breakEnd;
    _savedBreakLabel = _breakLabel;
    _savedTeachingStart = _teachingStart;
    _savedTeachingEnd = _teachingEnd;
    _savedSlotDurationMinutes = _slotDurationMinutes;
    _savedAllowStaggeredStartTimes = _allowStaggeredStartTimes;
    _savedAvoidBackToBack = _avoidBackToBack;
    _savedPreferBalancedWorkload = _preferBalancedWorkload;
    _savedAllowCrossDepartmentSharing = _allowCrossDepartmentSharing;
    _savedGenerationResult = _generationResult;
    _savedGenerationStatus = _generationStatus;
    _savedGenerationIssues = List<ManualIssue>.from(_generationIssues);
    _savedNeedsRegeneration = _needsRegeneration;
    _refreshIssues();
  }

  static const String sampleDataLabel = 'DEMO SAMPLE · LOCAL DRAFT ONLY';
  static const String blankDataLabel = 'BLANK LOCAL DRAFT';
  static const String conflictScenarioLabel = 'CONFLICT SCENARIO · LOCAL DEMO';
  static const List<String> dayNames = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  List<ManualSession> _sessions = <ManualSession>[];
  List<ManualFaculty> _faculty = <ManualFaculty>[];
  List<ManualRoom> _rooms = <ManualRoom>[];
  List<ManualSubject> _subjects = <ManualSubject>[];
  List<ManualBatch> _batches = <ManualBatch>[];
  List<ManualTimeSlot> _timeSlots = <ManualTimeSlot>[];
  List<ManualIssue> _hardConflicts = <ManualIssue>[];
  List<ManualIssue> _softWarnings = <ManualIssue>[];
  List<ManualIssue> _setupIssues = <ManualIssue>[];
  List<ManualSwapRequest> _swapRequests = <ManualSwapRequest>[];
  List<TimetableTeachingRequirement> _requirements =
      <TimetableTeachingRequirement>[];

  List<ManualSession> _savedSessions = <ManualSession>[];
  List<ManualFaculty> _savedFaculty = <ManualFaculty>[];
  List<ManualRoom> _savedRooms = <ManualRoom>[];
  List<ManualSwapRequest> _savedSwapRequests = <ManualSwapRequest>[];
  List<ManualSubject> _savedSubjects = <ManualSubject>[];
  List<ManualBatch> _savedBatches = <ManualBatch>[];
  List<TimetableTeachingRequirement> _savedRequirements =
      <TimetableTeachingRequirement>[];
  TimetableGenerationResult? _savedGenerationResult;
  TimetableGenerationStatus? _savedGenerationStatus;
  List<ManualIssue> _savedGenerationIssues = <ManualIssue>[];
  bool _savedNeedsRegeneration = false;

  String _selectedBatchId = '';
  int _selectedDay = 0;
  bool _showWeek = false;
  bool _hasUnsavedChanges = false;
  bool _hasLocalValidation = false;
  bool _isRestoring = false;
  String _scenarioLabel = sampleDataLabel;
  String _savedScenarioLabel = sampleDataLabel;
  String _institutionName = defaultInstitution;
  String _semesterLabel = defaultSemester;
  Set<int> _workingDays = <int>{0, 1, 2, 3, 4, 5};
  int _breakStart = 720;
  int _breakEnd = 750;
  String _breakLabel = 'Lunch break';
  int _teachingStart = 540;
  int _teachingEnd = 920;
  int _slotDurationMinutes = 50;
  bool _allowStaggeredStartTimes = true;
  bool _avoidBackToBack = true;
  bool _preferBalancedWorkload = true;
  bool _allowCrossDepartmentSharing = true;
  String _savedInstitutionName = defaultInstitution;
  String _savedSemesterLabel = defaultSemester;
  Set<int> _savedWorkingDays = <int>{0, 1, 2, 3, 4, 5};
  int _savedBreakStart = 720;
  int _savedBreakEnd = 750;
  String _savedBreakLabel = 'Lunch break';
  int _savedTeachingStart = 540;
  int _savedTeachingEnd = 920;
  int _savedSlotDurationMinutes = 50;
  bool _savedAllowStaggeredStartTimes = true;
  bool _savedAvoidBackToBack = true;
  bool _savedPreferBalancedWorkload = true;
  bool _savedAllowCrossDepartmentSharing = true;
  TimetableGenerationResult? _generationResult;
  TimetableGenerationStatus? _generationStatus;
  List<ManualIssue> _generationIssues = <ManualIssue>[];
  bool _isGenerating = false;
  bool _needsRegeneration = false;
  int _nextSessionNumber = 100;
  int _nextSwapNumber = 1;

  String get selectedBatchId => _selectedBatchId;
  set selectedBatchId(String value) => selectBatch(value);

  int get selectedDay => _selectedDay;
  set selectedDay(int value) => selectDay(value);

  bool get showWeek => _showWeek;
  set showWeek(bool value) => setShowWeek(value);

  bool get hasUnsavedChanges => _hasUnsavedChanges;
  bool get hasLocalValidation => _hasLocalValidation;
  bool get isRestoring => _isRestoring;
  String get dataLabel => _scenarioLabel;
  String get institutionName => _institutionName;
  String get semesterLabel => _semesterLabel;
  List<int> get workingDays =>
      List<int>.unmodifiable((_workingDays.toList()..sort()));
  int get breakStart => _breakStart;
  int get breakEnd => _breakEnd;
  String get breakLabel => _breakLabel;
  int get teachingStart => _teachingStart;
  int get teachingEnd => _teachingEnd;
  int get slotDurationMinutes => _slotDurationMinutes;
  bool get allowStaggeredStartTimes => _allowStaggeredStartTimes;
  bool get avoidBackToBack => _avoidBackToBack;
  bool get preferBalancedWorkload => _preferBalancedWorkload;
  bool get allowCrossDepartmentSharing => _allowCrossDepartmentSharing;
  List<TimetableTeachingRequirement> get requirements =>
      List<TimetableTeachingRequirement>.unmodifiable(_requirements);
  TimetableGenerationResult? get generationResult => _generationResult;
  TimetableGenerationStatus? get generationStatus => _generationStatus;
  bool get isGenerating => _isGenerating;
  bool get hasGeneratedTimetable => _generationResult != null;
  bool get needsRegeneration => _needsRegeneration;
  List<TimetableUnassignedRequirement> get unassignedRequirements =>
      _generationResult?.unassignedRequirements ??
      const <TimetableUnassignedRequirement>[];
  bool get canGenerate =>
      _institutionName.trim().isNotEmpty &&
      _semesterLabel.trim().isNotEmpty &&
      _workingDays.isNotEmpty &&
      _teachingEnd > _teachingStart &&
      _slotDurationMinutes > 0 &&
      _timeSlots.any((slot) => !slot.isBreak) &&
      _breakEnd - _breakStart >= 30 &&
      _faculty.isNotEmpty &&
      _rooms.isNotEmpty &&
      _batches.isNotEmpty &&
      _subjects.isNotEmpty &&
      _requirements.isNotEmpty;

  List<ManualSession> get sessions =>
      List<ManualSession>.unmodifiable(_sessions);
  List<ManualFaculty> get faculty => List<ManualFaculty>.unmodifiable(_faculty);
  List<ManualFaculty> get teachers => faculty;
  List<ManualRoom> get rooms => List<ManualRoom>.unmodifiable(_rooms);
  List<ManualSubject> get subjects =>
      List<ManualSubject>.unmodifiable(_subjects);
  List<ManualBatch> get batches => List<ManualBatch>.unmodifiable(_batches);
  List<ManualTimeSlot> get timeSlots =>
      List<ManualTimeSlot>.unmodifiable(_timeSlots);
  List<ManualTimeSlot> get breaks => List<ManualTimeSlot>.unmodifiable(
    _timeSlots.where((slot) => slot.isBreak),
  );
  List<ManualIssue> get hardConflicts =>
      List<ManualIssue>.unmodifiable(_hardConflicts);
  List<ManualIssue> get softWarnings =>
      List<ManualIssue>.unmodifiable(_softWarnings);
  List<ManualIssue> get setupIssues =>
      List<ManualIssue>.unmodifiable(_setupIssues);
  List<ManualIssue> get issues => List<ManualIssue>.unmodifiable(<ManualIssue>[
    ..._setupIssues,
    ..._hardConflicts,
    ..._softWarnings,
  ]);
  List<ManualSwapRequest> get swapRequests =>
      List<ManualSwapRequest>.unmodifiable(_swapRequests);

  ManualBatch? get selectedBatch => _findBatch(_selectedBatchId);

  /// Checks the current setup without generating a timetable. The returned
  /// issues identify the exact missing entity or load assignment that blocks a
  /// truthful generation attempt.
  List<ManualIssue> validateSetup() {
    final issues = <ManualIssue>[];
    if (_institutionName.trim().isEmpty) {
      issues.add(
        const ManualIssue(
          code: 'SETUP_INSTITUTION',
          message: 'Add an institution name before generating.',
        ),
      );
    }
    if (_semesterLabel.trim().isEmpty) {
      issues.add(
        const ManualIssue(
          code: 'SETUP_SEMESTER',
          message: 'Add a semester or term before generating.',
        ),
      );
    }
    if (_workingDays.isEmpty) {
      issues.add(
        const ManualIssue(
          code: 'SETUP_DAYS',
          message: 'Select at least one working day.',
        ),
      );
    }
    if (_breakEnd - _breakStart < 30) {
      issues.add(
        const ManualIssue(
          code: 'SETUP_BREAK',
          message: 'Reserve a mandatory break of at least 30 minutes.',
        ),
      );
    }
    if (_timeSlots.every((slot) => slot.isBreak)) {
      issues.add(
        const ManualIssue(
          code: 'SETUP_SLOTS',
          message: 'Define at least one available teaching slot.',
        ),
      );
    }
    if (_faculty.isEmpty) {
      issues.add(
        const ManualIssue(
          code: 'SETUP_FACULTY',
          message: 'Add at least one faculty member.',
        ),
      );
    }
    if (_batches.isEmpty) {
      issues.add(
        const ManualIssue(
          code: 'SETUP_BATCHES',
          message: 'Add at least one student batch or division.',
        ),
      );
    }
    if (_subjects.isEmpty) {
      issues.add(
        const ManualIssue(
          code: 'SETUP_SUBJECTS',
          message: 'Add at least one subject.',
        ),
      );
    }
    if (_rooms.isEmpty) {
      issues.add(
        const ManualIssue(
          code: 'SETUP_ROOMS',
          message: 'Add at least one classroom or laboratory.',
        ),
      );
    }
    if (_requirements.isEmpty) {
      issues.add(
        const ManualIssue(
          code: 'SETUP_REQUIREMENTS',
          message: 'Add at least one teaching requirement.',
        ),
      );
    }

    final loadMinutes = <String, int>{};
    for (final requirement in _requirements) {
      final subject = _findSubject(requirement.subjectId);
      final faculty = _findFaculty(requirement.facultyId);
      final batch = _findBatch(requirement.batchId);
      if (subject == null || faculty == null || batch == null) {
        issues.add(
          ManualIssue(
            code: 'SETUP_REFERENCE',
            message:
                'Requirement ${requirement.stableId} references a missing subject, faculty member, or batch.',
          ),
        );
        continue;
      }
      final lectureCount = requirement.lectureSessions ?? subject.lectureHours;
      final labCount =
          requirement.labSessions ??
          ((requirement.labHours ?? subject.labHours) > 0 ? 1 : 0);
      final lectureDuration =
          requirement.lectureDurationMinutes ??
          requirement.sessionDurationMinutes ??
          requirement.durationMinutes ??
          _slotDurationMinutes;
      final labDuration =
          requirement.labDurationMinutes ??
          requirement.sessionDurationMinutes ??
          requirement.durationMinutes ??
          ((requirement.labHours ?? subject.labHours) * 60);
      if (lectureCount < 0 ||
          labCount < 0 ||
          lectureDuration <= 0 ||
          (labCount > 0 && labDuration <= 0)) {
        issues.add(
          ManualIssue(
            code: 'SETUP_REQUIREMENT_VALUE',
            message:
                'Requirement ${requirement.stableId} has an invalid session count or duration.',
          ),
        );
      }
      loadMinutes[faculty.id] =
          (loadMinutes[faculty.id] ?? 0) +
          lectureCount * lectureDuration +
          labCount * labDuration;
    }
    for (final faculty in _faculty) {
      final minutes = loadMinutes[faculty.id] ?? 0;
      final target = faculty.maxWeeklyHours * 60;
      if (target > 0 && minutes > target) {
        issues.add(
          ManualIssue(
            code: 'FACULTY_LOAD_TARGET',
            message:
                '${faculty.name} has ${_formatHours(minutes)} of configured teaching against a ${faculty.maxWeeklyHours} hour target.',
          ),
        );
      }
    }
    _setupIssues = issues;
    notifyListeners();
    return List<ManualIssue>.unmodifiable(issues);
  }

  List<ManualSession> get selectedDaySessions =>
      sessionsFor(batchId: _selectedBatchId, day: _selectedDay);

  /// Rooms that are globally open. Use [availableRoomsFor] when an
  /// editor has a concrete time and should also exclude occupied rooms.
  List<ManualRoom> get availableRooms =>
      _rooms.where((room) => room.isAvailable).toList(growable: false);

  String dayName(int day) =>
      day >= 0 && day < dayNames.length ? dayNames[day] : 'Day ${day + 1}';

  List<ManualSession> sessionsFor({String? batchId, int? day}) {
    final visible = _sessions.where(
      (session) =>
          (batchId == null || batchId.isEmpty || session.batchId == batchId) &&
          (day == null || session.day == day),
    );
    final sorted = visible.toList();
    sorted.sort((a, b) {
      final dayOrder = a.day.compareTo(b.day);
      if (dayOrder != 0) return dayOrder;
      final startOrder = a.startMinute.compareTo(b.startMinute);
      if (startOrder != 0) return startOrder;
      return a.id.compareTo(b.id);
    });
    return List<ManualSession>.unmodifiable(sorted);
  }

  ManualSession? sessionById(String id) {
    for (final session in _sessions) {
      if (session.id == id) return session;
    }
    return null;
  }

  ManualSubject? subjectById(String id) => _findSubject(id);
  ManualFaculty? facultyById(String id) => _findFaculty(id);
  ManualRoom? roomById(String id) => _findRoom(id);
  ManualBatch? batchById(String id) => _findBatch(id);

  void selectBatch(String id) {
    if (_batches.every((batch) => batch.id != id) || _selectedBatchId == id) {
      return;
    }
    _selectedBatchId = id;
    notifyListeners();
  }

  void selectDay(int day) {
    final next = day.clamp(0, dayNames.length - 1);
    if (_selectedDay == next) return;
    _selectedDay = next;
    notifyListeners();
  }

  void setShowWeek(bool value) {
    if (_showWeek == value) return;
    _showWeek = value;
    notifyListeners();
  }

  /// Updates the term configuration used by the local generator. Slots are
  /// rebuilt from the selected days and break, so setup changes affect the next
  /// generation attempt rather than only changing a label in the UI.
  void updateSetup({
    String? institution,
    String? semester,
    Iterable<int>? workingDays,
    int? teachingStart,
    int? teachingEnd,
    int? slotDurationMinutes,
    bool? allowStaggeredStartTimes,
    int? breakStart,
    int? breakEnd,
    String? breakLabel,
  }) {
    final nextDays = workingDays == null
        ? _workingDays
        : workingDays.where((day) => day >= 0 && day < dayNames.length).toSet();
    final nextStart = breakStart ?? _breakStart;
    final nextEnd = breakEnd ?? _breakEnd;
    final nextTeachingStart = teachingStart ?? _teachingStart;
    final nextTeachingEnd = teachingEnd ?? _teachingEnd;
    final nextSlotDuration = slotDurationMinutes ?? _slotDurationMinutes;
    if (nextEnd <= nextStart ||
        nextTeachingEnd <= nextTeachingStart ||
        nextSlotDuration <= 0) {
      return;
    }
    final changed =
        (institution != null && institution.trim() != _institutionName) ||
        (semester != null && semester.trim() != _semesterLabel) ||
        nextDays.length != _workingDays.length ||
        !nextDays.containsAll(_workingDays) ||
        !_workingDays.containsAll(nextDays) ||
        nextStart != _breakStart ||
        nextEnd != _breakEnd ||
        nextTeachingStart != _teachingStart ||
        nextTeachingEnd != _teachingEnd ||
        nextSlotDuration != _slotDurationMinutes ||
        (allowStaggeredStartTimes != null &&
            allowStaggeredStartTimes != _allowStaggeredStartTimes) ||
        (breakLabel != null && breakLabel.trim() != _breakLabel);
    if (!changed) return;
    _institutionName = institution?.trim() ?? _institutionName;
    _semesterLabel = semester?.trim() ?? _semesterLabel;
    _workingDays = nextDays;
    _breakStart = nextStart;
    _breakEnd = nextEnd;
    _breakLabel = breakLabel?.trim().isNotEmpty == true
        ? breakLabel!.trim()
        : _breakLabel;
    _teachingStart = nextTeachingStart;
    _teachingEnd = nextTeachingEnd;
    _slotDurationMinutes = nextSlotDuration;
    _allowStaggeredStartTimes =
        allowStaggeredStartTimes ?? _allowStaggeredStartTimes;
    _rebuildTimeSlots();
    _invalidateGeneratedTimetable();
    _touchDraft();
  }

  void updatePreferences({
    bool? avoidBackToBack,
    bool? preferBalancedWorkload,
    bool? allowCrossDepartmentSharing,
  }) {
    final changed =
        (avoidBackToBack != null && avoidBackToBack != _avoidBackToBack) ||
        (preferBalancedWorkload != null &&
            preferBalancedWorkload != _preferBalancedWorkload) ||
        (allowCrossDepartmentSharing != null &&
            allowCrossDepartmentSharing != _allowCrossDepartmentSharing);
    if (!changed) return;
    _avoidBackToBack = avoidBackToBack ?? _avoidBackToBack;
    _preferBalancedWorkload = preferBalancedWorkload ?? _preferBalancedWorkload;
    _allowCrossDepartmentSharing =
        allowCrossDepartmentSharing ?? _allowCrossDepartmentSharing;
    _invalidateGeneratedTimetable();
    _touchDraft();
  }

  void setRequirements(List<TimetableTeachingRequirement> requirements) {
    _requirements = List<TimetableTeachingRequirement>.from(requirements);
    _invalidateGeneratedTimetable();
    _touchDraft();
  }

  bool editRequirement(TimetableTeachingRequirement requirement) {
    final index = _requirements.indexWhere(
      (item) => item.stableId == requirement.stableId,
    );
    if (index < 0) return false;
    _requirements[index] = requirement;
    _invalidateGeneratedTimetable();
    _touchDraft();
    return true;
  }

  bool addRequirement(TimetableTeachingRequirement requirement) {
    if (requirement.stableId.trim().isEmpty ||
        _requirements.any((item) => item.stableId == requirement.stableId)) {
      return false;
    }
    _requirements.add(requirement);
    _invalidateGeneratedTimetable();
    _touchDraft();
    return true;
  }

  bool removeRequirement(String id) {
    final before = _requirements.length;
    _requirements.removeWhere((item) => item.stableId == id || item.id == id);
    if (_requirements.length == before) return false;
    _invalidateGeneratedTimetable();
    _touchDraft();
    return true;
  }

  bool addSubject(ManualSubject subject) {
    if (subject.id.trim().isEmpty ||
        _subjects.any((item) => item.id == subject.id)) {
      return false;
    }
    _subjects.add(subject);
    _invalidateGeneratedTimetable();
    _touchDraft();
    return true;
  }

  bool editSubject(ManualSubject subject) {
    final index = _subjects.indexWhere((item) => item.id == subject.id);
    if (index < 0) return false;
    _subjects[index] = subject;
    _invalidateGeneratedTimetable();
    _touchDraft();
    return true;
  }

  String? subjectRemovalWarning(String subjectId) {
    final subject = _findSubject(subjectId);
    if (subject == null) return null;
    final requirements = _requirements
        .where((item) => item.subjectId == subjectId)
        .length;
    final sessions = _sessions
        .where((item) => item.subjectId == subjectId)
        .length;
    if (requirements == 0 && sessions == 0) return null;
    return '${subject.name} is used by $requirements teaching requirement${requirements == 1 ? '' : 's'} and $sessions timetable session${sessions == 1 ? '' : 's'}. Remove or reassign them first.';
  }

  bool removeSubject(String subjectId) {
    if (subjectRemovalWarning(subjectId) != null) return false;
    final before = _subjects.length;
    _subjects.removeWhere((item) => item.id == subjectId);
    if (_subjects.length == before) return false;
    _touchDraft();
    return true;
  }

  bool addBatch(ManualBatch batch) {
    if (batch.id.trim().isEmpty ||
        _batches.any((item) => item.id == batch.id)) {
      return false;
    }
    _batches.add(batch);
    _invalidateGeneratedTimetable();
    _touchDraft();
    return true;
  }

  bool editBatch(ManualBatch batch) {
    final index = _batches.indexWhere((item) => item.id == batch.id);
    if (index < 0) return false;
    _batches[index] = batch;
    _invalidateGeneratedTimetable();
    _touchDraft();
    return true;
  }

  String? batchRemovalWarning(String batchId) {
    final batch = _findBatch(batchId);
    if (batch == null) return null;
    final requirements = _requirements
        .where((item) => item.batchId == batchId)
        .length;
    final sessions = _sessions.where((item) => item.batchId == batchId).length;
    if (requirements == 0 && sessions == 0) return null;
    return '${batch.name} is used by $requirements teaching requirement${requirements == 1 ? '' : 's'} and $sessions timetable session${sessions == 1 ? '' : 's'}. Remove or reassign them first.';
  }

  bool removeBatch(String batchId) {
    if (batchRemovalWarning(batchId) != null) return false;
    final before = _batches.length;
    _batches.removeWhere((item) => item.id == batchId);
    if (_batches.length == before) return false;
    if (_selectedBatchId == batchId) {
      _selectedBatchId = _batches.isEmpty ? '' : _batches.first.id;
    }
    _touchDraft();
    return true;
  }

  /// Restores the last locally saved draft. Malformed or outdated storage is
  /// ignored so the clean demo remains available.
  Future<void> restoreDraft() async {
    _isRestoring = true;
    notifyListeners();
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_storageKey);
      if (raw == null || raw.trim().isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      _applySnapshotMap(
        Map<String, dynamic>.from(decoded),
        restoreUngeneratedSessions: false,
      );
    } catch (_) {
      // A broken local payload must never prevent the app from opening.
    } finally {
      _isRestoring = false;
      notifyListeners();
    }
  }

  /// Serializes every local field needed to reopen this workspace. The result
  /// is JSON rather than a live map, so callers cannot mutate controller state
  /// through a shared collection reference.
  String exportSnapshot() => jsonEncode(_draftMap());

  /// Alias for callers that prefer to name the persisted representation.
  String get serializedSnapshot => exportSnapshot();

  /// Imports a snapshot produced by [exportSnapshot]. The whole payload is
  /// decoded before it is applied; malformed or incomplete snapshots leave the
  /// current workspace untouched and return `false`.
  bool importSnapshot(String serializedSnapshot) {
    try {
      final decoded = jsonDecode(serializedSnapshot);
      if (decoded is! Map) return false;
      final applied = _applySnapshotMap(
        Map<String, dynamic>.from(decoded),
        restoreUngeneratedSessions: true,
      );
      if (!applied) return false;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Runs the deterministic local scheduler against the current setup data.
  /// The method is synchronous because the bounded prototype search is local;
  /// callers can still show [isGenerating] around it for a truthful status.
  TimetableGenerationResult generateTimetable() {
    final previousSessions = List<ManualSession>.from(_sessions);
    final hadPreviousResult =
        _generationResult != null && previousSessions.isNotEmpty;
    _isGenerating = true;
    _generationStatus = null;
    notifyListeners();
    final result = TimetableGenerator().generate(
      TimetableGenerationInput(
        faculty: _faculty,
        rooms: _rooms,
        batches: _batches,
        subjects: _subjects,
        timeSlots: _timeSlots,
        requirements: _requirements,
        avoidBackToBack: _avoidBackToBack,
        preferBalancedWorkload: _preferBalancedWorkload,
        allowCrossDepartmentSharing: _allowCrossDepartmentSharing,
      ),
    );
    _generationResult = result;
    _generationStatus = result.status;
    _generationIssues = result.validationIssues
        .where(
          (issue) =>
              issue.code != 'BACK_TO_BACK_TEACHING' &&
              issue.code != 'WORKLOAD_BALANCE',
        )
        .toList();
    if (result.isSuccess || !hadPreviousResult) {
      _sessions = List<ManualSession>.from(result.generatedSessions);
    } else {
      // A failed regeneration must not destroy the last usable timetable.
      _sessions = previousSessions;
    }
    _savedSessions = List<ManualSession>.from(_sessions);
    _savedFaculty = List<ManualFaculty>.from(_faculty);
    _savedRooms = List<ManualRoom>.from(_rooms);
    _savedSubjects = List<ManualSubject>.from(_subjects);
    _savedBatches = List<ManualBatch>.from(_batches);
    _savedRequirements = List<TimetableTeachingRequirement>.from(_requirements);
    _savedSwapRequests = List<ManualSwapRequest>.from(_swapRequests);
    _savedInstitutionName = _institutionName;
    _savedSemesterLabel = _semesterLabel;
    _savedWorkingDays = Set<int>.from(_workingDays);
    _savedBreakStart = _breakStart;
    _savedBreakEnd = _breakEnd;
    _savedBreakLabel = _breakLabel;
    _savedTeachingStart = _teachingStart;
    _savedTeachingEnd = _teachingEnd;
    _savedSlotDurationMinutes = _slotDurationMinutes;
    _savedAllowStaggeredStartTimes = _allowStaggeredStartTimes;
    _savedAvoidBackToBack = _avoidBackToBack;
    _savedPreferBalancedWorkload = _preferBalancedWorkload;
    _savedAllowCrossDepartmentSharing = _allowCrossDepartmentSharing;
    _savedGenerationResult = _generationResult;
    _savedGenerationStatus = _generationStatus;
    _savedGenerationIssues = List<ManualIssue>.from(_generationIssues);
    _needsRegeneration = !result.isSuccess;
    _savedNeedsRegeneration = _needsRegeneration;
    _hasUnsavedChanges = true;
    _hasLocalValidation = result.isSuccess || !hadPreviousResult;
    _isGenerating = false;
    _refreshIssues();
    notifyListeners();
    return result;
  }

  /// Alias used by the main generation screen and tests.
  TimetableGenerationResult generate() => generateTimetable();

  void clearGeneratedTimetable() {
    _sessions = <ManualSession>[];
    _generationResult = null;
    _generationStatus = null;
    _generationIssues = <ManualIssue>[];
    _hasLocalValidation = false;
    _needsRegeneration = false;
    _touchDraft();
  }

  /// Adds a class to the draft and immediately re-runs local validation.
  ManualSession addSession(ManualSession session) {
    final id = session.id.trim().isEmpty ? _newSessionId() : session.id;
    final added = session.copyWith(id: id);
    _sessions.removeWhere((item) => item.id == added.id);
    _sessions.add(added);
    _touchDraft();
    return added;
  }

  /// Edits either a complete [ManualSession] or a session id plus the supplied
  /// fields. The second form is handy for quick inline moves in a coordinator UI.
  bool editSession(
    Object sessionOrId, {
    String? subjectId,
    String? facultyId,
    String? batchId,
    String? roomId,
    int? day,
    int? startMinute,
    int? endMinute,
    int? start,
    int? end,
    ManualSessionType? type,
    String? note,
  }) {
    final index = _sessionIndex(sessionOrId);
    if (index < 0) return false;

    final existing = _sessions[index];
    final replacement = sessionOrId is ManualSession
        ? sessionOrId
        : existing.copyWith(
            subjectId: subjectId,
            facultyId: facultyId,
            batchId: batchId,
            roomId: roomId,
            day: day,
            startMinute: startMinute ?? start,
            endMinute: endMinute ?? end,
            type: type,
            note: note,
          );
    _sessions[index] = replacement;
    _touchDraft();
    return true;
  }

  /// Moves a class while preserving its subject, faculty and type.
  bool moveSession(
    Object sessionOrId, {
    int? day,
    int? startMinute,
    int? endMinute,
    int? start,
    int? end,
    String? roomId,
  }) {
    final index = _sessionIndex(sessionOrId);
    if (index < 0) return false;
    final existing = _sessions[index];
    final moved = existing.copyWith(
      day: day,
      startMinute: startMinute ?? start,
      endMinute: endMinute ?? end,
      roomId: roomId,
    );
    _sessions[index] = moved;
    _touchDraft();
    return true;
  }

  bool deleteSession(Object sessionOrId) {
    final index = _sessionIndex(sessionOrId);
    if (index < 0) return false;
    _sessions.removeAt(index);
    _touchDraft();
    return true;
  }

  /// Adds a faculty record to the local draft. IDs are kept stable so existing
  /// session assignments remain referentially safe.
  bool addFaculty(ManualFaculty teacher) {
    if (teacher.id.trim().isEmpty ||
        _faculty.any((item) => item.id == teacher.id)) {
      return false;
    }
    _faculty.add(teacher);
    _invalidateGeneratedTimetable();
    _touchDraft();
    return true;
  }

  /// Replaces a faculty record in the local draft without touching sessions.
  bool editFaculty(ManualFaculty teacher) {
    final index = _faculty.indexWhere((item) => item.id == teacher.id);
    if (index < 0) return false;
    _faculty[index] = teacher;
    _invalidateGeneratedTimetable();
    _touchDraft();
    return true;
  }

  String? facultyRemovalWarning(String facultyId) {
    final teacher = _findFaculty(facultyId);
    if (teacher == null) return null;
    final requirements = _requirements
        .where((item) => item.facultyId == facultyId)
        .length;
    final sessions = _sessions
        .where((item) => item.facultyId == facultyId)
        .length;
    if (requirements == 0 && sessions == 0) return null;
    return '${teacher.name} is used by $requirements teaching requirement${requirements == 1 ? '' : 's'} and $sessions timetable session${sessions == 1 ? '' : 's'}. Reassign them first.';
  }

  bool removeFaculty(String facultyId) {
    if (facultyRemovalWarning(facultyId) != null) return false;
    final before = _faculty.length;
    _faculty.removeWhere((item) => item.id == facultyId);
    if (_faculty.length == before) return false;
    _touchDraft();
    return true;
  }

  /// Adds a room or laboratory to the local draft.
  bool addRoom(ManualRoom room) {
    if (room.id.trim().isEmpty || _rooms.any((item) => item.id == room.id)) {
      return false;
    }
    _rooms.add(room);
    _invalidateGeneratedTimetable();
    _touchDraft();
    return true;
  }

  /// Replaces a room or laboratory in the local draft without reassigning it.
  bool editRoom(ManualRoom room) {
    final index = _rooms.indexWhere((item) => item.id == room.id);
    if (index < 0) return false;
    _rooms[index] = room;
    _invalidateGeneratedTimetable();
    _touchDraft();
    return true;
  }

  String? roomRemovalWarning(String roomId) {
    final room = _findRoom(roomId);
    if (room == null) return null;
    final sessions = _sessions.where((item) => item.roomId == roomId).length;
    return sessions == 0
        ? null
        : '${room.name} is assigned to $sessions timetable session${sessions == 1 ? '' : 's'}. Reassign them first.';
  }

  bool removeRoom(String roomId) {
    if (roomRemovalWarning(roomId) != null) return false;
    final before = _rooms.length;
    _rooms.removeWhere((item) => item.id == roomId);
    if (_rooms.length == before) return false;
    _touchDraft();
    return true;
  }

  /// Saves the current draft locally. No account, backend, or password is
  /// involved; this is browser/device persistence for the demo only.
  Future<void> saveDraft() async {
    _savedSessions = List<ManualSession>.from(_sessions);
    _savedFaculty = List<ManualFaculty>.from(_faculty);
    _savedRooms = List<ManualRoom>.from(_rooms);
    _savedSwapRequests = List<ManualSwapRequest>.from(_swapRequests);
    _savedSubjects = List<ManualSubject>.from(_subjects);
    _savedBatches = List<ManualBatch>.from(_batches);
    _savedRequirements = List<TimetableTeachingRequirement>.from(_requirements);
    _savedScenarioLabel = _scenarioLabel;
    _savedInstitutionName = _institutionName;
    _savedSemesterLabel = _semesterLabel;
    _savedWorkingDays = Set<int>.from(_workingDays);
    _savedBreakStart = _breakStart;
    _savedBreakEnd = _breakEnd;
    _savedBreakLabel = _breakLabel;
    _savedTeachingStart = _teachingStart;
    _savedTeachingEnd = _teachingEnd;
    _savedSlotDurationMinutes = _slotDurationMinutes;
    _savedAllowStaggeredStartTimes = _allowStaggeredStartTimes;
    _savedAvoidBackToBack = _avoidBackToBack;
    _savedPreferBalancedWorkload = _preferBalancedWorkload;
    _savedAllowCrossDepartmentSharing = _allowCrossDepartmentSharing;
    _savedGenerationResult = _generationResult;
    _savedGenerationStatus = _generationStatus;
    _savedGenerationIssues = List<ManualIssue>.from(_generationIssues);
    _savedNeedsRegeneration = _needsRegeneration;
    _hasUnsavedChanges = false;
    notifyListeners();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_storageKey, jsonEncode(_draftMap()));
    } catch (_) {
      // The in-memory checkpoint remains usable when storage is unavailable.
    }
  }

  void discardDraft() {
    _sessions = List<ManualSession>.from(_savedSessions);
    _faculty = List<ManualFaculty>.from(_savedFaculty);
    _rooms = List<ManualRoom>.from(_savedRooms);
    _swapRequests = List<ManualSwapRequest>.from(_savedSwapRequests);
    _subjects = List<ManualSubject>.from(_savedSubjects);
    _batches = List<ManualBatch>.from(_savedBatches);
    _requirements = List<TimetableTeachingRequirement>.from(_savedRequirements);
    _institutionName = _savedInstitutionName;
    _semesterLabel = _savedSemesterLabel;
    _workingDays = Set<int>.from(_savedWorkingDays);
    _breakStart = _savedBreakStart;
    _breakEnd = _savedBreakEnd;
    _breakLabel = _savedBreakLabel;
    _teachingStart = _savedTeachingStart;
    _teachingEnd = _savedTeachingEnd;
    _slotDurationMinutes = _savedSlotDurationMinutes;
    _allowStaggeredStartTimes = _savedAllowStaggeredStartTimes;
    _avoidBackToBack = _savedAvoidBackToBack;
    _preferBalancedWorkload = _savedPreferBalancedWorkload;
    _allowCrossDepartmentSharing = _savedAllowCrossDepartmentSharing;
    _rebuildTimeSlots();
    _scenarioLabel = _savedScenarioLabel;
    _hasUnsavedChanges = false;
    _hasLocalValidation = false;
    _generationResult = _savedGenerationResult;
    _generationStatus = _savedGenerationStatus;
    _generationIssues = List<ManualIssue>.from(_savedGenerationIssues);
    _needsRegeneration = _savedNeedsRegeneration;
    _refreshIssues();
    notifyListeners();
  }

  /// Restores the deterministic sample data and clears the local checkpoint.
  Future<void> resetDemo() async {
    _seedDemoData();
    _nextSessionNumber = 100;
    _nextSwapNumber = 1;
    _selectedBatchId = _batches.first.id;
    _selectedDay = 0;
    _showWeek = false;
    _savedSessions = List<ManualSession>.from(_sessions);
    _savedFaculty = List<ManualFaculty>.from(_faculty);
    _savedRooms = List<ManualRoom>.from(_rooms);
    _swapRequests = <ManualSwapRequest>[];
    _savedSwapRequests = <ManualSwapRequest>[];
    _savedSubjects = List<ManualSubject>.from(_subjects);
    _savedBatches = List<ManualBatch>.from(_batches);
    _savedRequirements = List<TimetableTeachingRequirement>.from(_requirements);
    _savedInstitutionName = _institutionName;
    _savedSemesterLabel = _semesterLabel;
    _savedWorkingDays = Set<int>.from(_workingDays);
    _savedBreakStart = _breakStart;
    _savedBreakEnd = _breakEnd;
    _savedBreakLabel = _breakLabel;
    _savedTeachingStart = _teachingStart;
    _savedTeachingEnd = _teachingEnd;
    _savedSlotDurationMinutes = _slotDurationMinutes;
    _savedAllowStaggeredStartTimes = _allowStaggeredStartTimes;
    _savedAvoidBackToBack = _avoidBackToBack;
    _savedPreferBalancedWorkload = _preferBalancedWorkload;
    _savedAllowCrossDepartmentSharing = _allowCrossDepartmentSharing;
    _savedGenerationResult = null;
    _savedGenerationStatus = null;
    _savedGenerationIssues = <ManualIssue>[];
    _savedNeedsRegeneration = false;
    _hasUnsavedChanges = false;
    _hasLocalValidation = false;
    _scenarioLabel = sampleDataLabel;
    _savedScenarioLabel = sampleDataLabel;
    _generationResult = null;
    _generationStatus = null;
    _generationIssues = <ManualIssue>[];
    _needsRegeneration = false;
    _refreshIssues();
    notifyListeners();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(_storageKey);
    } catch (_) {
      // The in-memory reset is still valid when storage is unavailable.
    }
  }

  /// Loads a deliberately broken but coherent scenario for demonstrating the
  /// Issues workflow. It is never presented as validated or publishable.
  void loadConflictDemo() {
    _seedDemoData();
    _scenarioLabel = conflictScenarioLabel;
    final base = ManualSession(
      id: 'demo-conflict-base',
      subjectId: _subjects.first.id,
      facultyId: _faculty.first.id,
      batchId: _batches.first.id,
      roomId: _rooms.first.id,
      day: workingDays.first,
      startMinute: 540,
      endMinute: 590,
    );
    _sessions = <ManualSession>[base];
    _sessions.add(base.copyWith(id: 'demo-conflict-overlap'));
    _sessions.add(base.copyWith(id: 'demo-conflict-missing-room', roomId: ''));
    _selectedBatchId = _batches.first.id;
    _selectedDay = 0;
    _showWeek = false;
    _hasUnsavedChanges = true;
    _hasLocalValidation = true;
    _refreshIssues();
    _generationIssues = List<ManualIssue>.from(<ManualIssue>[
      ..._hardConflicts,
      ..._softWarnings,
    ]);
    _generationStatus = TimetableGenerationStatus.infeasible;
    _generationResult = TimetableGenerationResult(
      id: 'conflict-demo',
      status: TimetableGenerationStatus.infeasible,
      message: 'Conflict scenario loaded for local issue review.',
      generatedSessions: _sessions,
      unassignedRequirements: const <TimetableUnassignedRequirement>[],
      validationIssues: _generationIssues,
      score: 0,
      searchNodes: 0,
    );
    notifyListeners();
  }

  /// Lists rooms that fit the proposed slot. A room occupied by the session
  /// being edited can be retained using [excludeSessionId].
  List<ManualRoom> availableRoomsFor({
    required int day,
    int startMinute = 0,
    int endMinute = 24 * 60,
    int? start,
    int? end,
    String? excludeSessionId,
    bool practical = false,
    int? capacity,
  }) {
    final effectiveStart = start ?? startMinute;
    final effectiveEnd = end ?? endMinute;
    final choices = _rooms.where((room) {
      if (practical && !room.isLab) return false;
      if (capacity != null && room.capacity < capacity) return false;
      if (room.isUnavailableAt(day, effectiveStart, effectiveEnd)) return false;
      return !_sessions.any(
        (session) =>
            session.id != excludeSessionId &&
            session.roomId == room.id &&
            session.day == day &&
            _overlaps(
              effectiveStart,
              effectiveEnd,
              session.startMinute,
              session.endMinute,
            ),
      );
    }).toList();
    return List<ManualRoom>.unmodifiable(choices);
  }

  /// Total scheduled minutes for each teacher. [workloadHours] and
  /// [workloadHoursFor] provide presentation-friendly values.
  Map<String, int> calculateWorkload() {
    final totals = <String, int>{for (final teacher in _faculty) teacher.id: 0};
    for (final session in _sessions) {
      totals[session.facultyId] =
          (totals[session.facultyId] ?? 0) + _duration(session);
    }
    return Map<String, int>.unmodifiable(totals);
  }

  Map<String, int> get workload => calculateWorkload();

  Map<String, double> get workloadHours => Map<String, double>.unmodifiable({
    for (final entry in calculateWorkload().entries)
      entry.key: entry.value / 60,
  });

  int workloadFor(String facultyId) => calculateWorkload()[facultyId] ?? 0;

  double workloadHoursFor(String facultyId) => workloadFor(facultyId) / 60;

  /// Recomputes all local hard conflicts and soft warnings. The returned list
  /// contains only hard conflicts; both public lists are updated together.
  List<ManualIssue> validate() {
    _refreshIssues();
    _hasLocalValidation = true;
    notifyListeners();
    return hardConflicts;
  }

  /// Adds or removes an all-day closure, or a closure for one day/time range.
  void markRoomUnavailable(
    String roomId, {
    int? day,
    int? startMinute,
    int? endMinute,
    int? start,
    int? end,
    bool unavailable = true,
    String reason = 'Room unavailable',
  }) {
    final index = _rooms.indexWhere((room) => room.id == roomId);
    if (index < 0) return;
    final room = _rooms[index];
    final effectiveStart = startMinute ?? start;
    final effectiveEnd = endMinute ?? end;
    if (day == null || effectiveStart == null || effectiveEnd == null) {
      _rooms[index] = room.copyWith(isAvailable: !unavailable);
    } else {
      final closures = List<ManualRoomClosure>.from(room.unavailableSlots);
      final existing = closures.indexWhere(
        (closure) =>
            closure.day == day &&
            closure.startMinute == effectiveStart &&
            closure.endMinute == effectiveEnd,
      );
      if (unavailable && existing < 0) {
        closures.add(
          ManualRoomClosure(
            day: day,
            startMinute: effectiveStart,
            endMinute: effectiveEnd,
            reason: reason,
          ),
        );
      } else if (!unavailable && existing >= 0) {
        closures.removeAt(existing);
      }
      _rooms[index] = room.copyWith(unavailableSlots: closures);
    }
    _touchDraft();
  }

  /// Records a teacher absence in the local draft. Validation then marks any
  /// affected class as a hard teacher-unavailable conflict.
  void handleAbsence(
    String facultyId, {
    int day = 0,
    int startMinute = 0,
    int endMinute = 24 * 60,
    int? start,
    int? end,
    String reason = 'Faculty unavailable',
  }) {
    final index = _faculty.indexWhere((teacher) => teacher.id == facultyId);
    if (index < 0) return;
    final effectiveStart = start ?? startMinute;
    final effectiveEnd = end ?? endMinute;
    final teacher = _faculty[index];
    final absences = List<ManualAbsence>.from(teacher.absences)
      ..add(
        ManualAbsence(
          day: day,
          startMinute: effectiveStart,
          endMinute: effectiveEnd,
          reason: reason,
        ),
      );
    _faculty[index] = teacher.copyWith(absences: absences);
    _touchDraft();
  }

  /// Creates a local proxy teacher. The coordinator can then edit a class to
  /// use the proxy; no remote notification is sent by this prototype.
  ManualFaculty createProxy(
    String absentFacultyId, {
    String? proxyFacultyId,
    String? name,
    int? maxWeeklyHours,
  }) {
    return _createProxy(
      absentFacultyId,
      proxyFacultyId: proxyFacultyId,
      name: name,
      maxWeeklyHours: maxWeeklyHours,
    );
  }

  ManualFaculty createProxyWithId(
    String absentFacultyId,
    String proxyFacultyId,
  ) => createProxy(absentFacultyId, proxyFacultyId: proxyFacultyId);

  ManualFaculty _createProxy(
    String absentFacultyId, {
    String? proxyFacultyId,
    String? name,
    int? maxWeeklyHours,
  }) {
    final source = _findFaculty(absentFacultyId);
    final baseId = proxyFacultyId?.trim().isNotEmpty == true
        ? proxyFacultyId!.trim()
        : 'proxy-${absentFacultyId.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '-')}';
    var id = baseId;
    var suffix = 2;
    while (_faculty.any((teacher) => teacher.id == id)) {
      id = '$baseId-$suffix';
      suffix++;
    }
    final proxy = ManualFaculty(
      id: id,
      name: name ?? 'Proxy for ${source?.name ?? absentFacultyId}',
      department: source?.department ?? 'Information Technology',
      maxWeeklyHours: maxWeeklyHours ?? source?.maxWeeklyHours ?? 12,
      isProxy: true,
    );
    _faculty.add(proxy);
    _touchDraft();
    return proxy;
  }

  /// Creates a local, reviewable swap request. It is deliberately labelled
  /// `draft` because this editor has no messaging or backend workflow.
  ManualSwapRequest? requestSwap(
    Object sessionOrId, {
    String? targetFacultyId,
    String? targetSessionId,
    String note = '',
  }) {
    return _requestSwap(
      sessionOrId,
      targetFacultyId: targetFacultyId,
      targetSessionId: targetSessionId,
      note: note,
    );
  }

  ManualSwapRequest? requestSwapWithTarget(
    Object sessionOrId,
    String targetFacultyId,
  ) => requestSwap(sessionOrId, targetFacultyId: targetFacultyId);

  ManualSwapRequest? _requestSwap(
    Object sessionOrId, {
    String? targetFacultyId,
    String? targetSessionId,
    String note = '',
  }) {
    final sessionId = sessionOrId is ManualSession
        ? sessionOrId.id
        : '$sessionOrId';
    if (sessionById(sessionId) == null) return null;
    final request = ManualSwapRequest(
      id: 'swap-${_nextSwapNumber++}',
      sessionId: sessionId,
      targetFacultyId: targetFacultyId,
      targetSessionId: targetSessionId,
      note: note,
    );
    _swapRequests.add(request);
    _touchDraft();
    return request;
  }

  void _touchDraft() {
    _hasUnsavedChanges = true;
    _hasLocalValidation = false;
    _setupIssues = <ManualIssue>[];
    _refreshIssues();
    notifyListeners();
  }

  Map<String, dynamic> _draftMap() => <String, dynamic>{
    'version': 2,
    'institution': _institutionName,
    'semester': _semesterLabel,
    'working_days': _workingDays.toList()..sort(),
    'break_start': _breakStart,
    'break_end': _breakEnd,
    'break_label': _breakLabel,
    'teaching_start': _teachingStart,
    'teaching_end': _teachingEnd,
    'slot_duration': _slotDurationMinutes,
    'allow_staggered_start_times': _allowStaggeredStartTimes,
    'avoid_back_to_back': _avoidBackToBack,
    'prefer_balanced_workload': _preferBalancedWorkload,
    'allow_cross_department_sharing': _allowCrossDepartmentSharing,
    'scenario_label': _scenarioLabel,
    'generated': _generationResult != null,
    'needs_regeneration': _needsRegeneration,
    'has_local_validation': _hasLocalValidation,
    'generation_id': _generationResult?.id,
    'generation_status': _generationStatus?.name,
    'generation_message': _generationResult?.message,
    'generation_score': _generationResult?.score,
    'generation_nodes': _generationResult?.searchNodes,
    'selected_batch_id': _selectedBatchId,
    'selected_day': _selectedDay,
    'show_week': _showWeek,
    'sessions': _sessions.map(_sessionMap).toList(),
    'faculty': _faculty.map(_facultyMap).toList(),
    'rooms': _rooms.map(_roomMap).toList(),
    'subjects': _subjects.map(_subjectMap).toList(),
    'batches': _batches.map(_batchMap).toList(),
    'requirements': _requirements.map(_requirementMap).toList(),
    'setup_issues': _setupIssues.map(_issueMap).toList(),
    'generation_issues': _generationIssues.map(_issueMap).toList(),
    'unassigned_requirements':
        (_generationResult?.unassignedRequirements ??
                const <TimetableUnassignedRequirement>[])
            .map(_unassignedMap)
            .toList(),
    'swaps': _swapRequests.map(_swapMap).toList(),
  };

  bool _applySnapshotMap(
    Map<String, dynamic> map, {
    required bool restoreUngeneratedSessions,
  }) {
    try {
      final decodedSessions = _decodeSessions(map['sessions']);
      final faculty = _decodeFaculty(map['faculty']);
      final rooms = _decodeRooms(map['rooms']);
      final subjects = _decodeSubjects(map['subjects']);
      final batches = _decodeBatches(map['batches']);
      final requirements = _decodeRequirements(map['requirements']);
      final swaps = _decodeSwaps(map['swaps']);
      if (decodedSessions == null ||
          faculty == null ||
          rooms == null ||
          subjects == null ||
          batches == null ||
          requirements == null ||
          swaps == null) {
        return false;
      }

      final sessions = map['generated'] == true || restoreUngeneratedSessions
          ? decodedSessions
          : <ManualSession>[];
      final institution = map['institution'] as String? ?? defaultInstitution;
      final semester = map['semester'] as String? ?? defaultSemester;
      final workingDays = _decodeWorkingDays(map['working_days']);
      final breakStart = _intOr(map['break_start'], 720);
      final breakEnd = _intOr(map['break_end'], 750);
      final breakLabel = map['break_label'] as String? ?? 'Lunch break';
      final teachingStart = _intOr(map['teaching_start'], 540);
      final teachingEnd = _intOr(map['teaching_end'], 920);
      final slotDurationMinutes = _intOr(map['slot_duration'], 50);
      final allowStaggeredStartTimes =
          map['allow_staggered_start_times'] as bool? ?? true;
      final avoidBackToBack = map['avoid_back_to_back'] as bool? ?? true;
      final preferBalancedWorkload =
          map['prefer_balanced_workload'] as bool? ?? true;
      final allowCrossDepartmentSharing =
          map['allow_cross_department_sharing'] as bool? ?? true;
      final generationStatus = _decodeGenerationStatus(
        map['generation_status'],
      );
      final setupIssues = _decodeIssues(map['setup_issues']);
      final generationIssues = _decodeIssues(map['generation_issues']);
      final generationResult = map['generated'] == true && sessions.isNotEmpty
          ? TimetableGenerationResult(
              id: map['generation_id'] as String? ?? 'restored-local-result',
              status: generationStatus ?? TimetableGenerationStatus.generated,
              message:
                  map['generation_message'] as String? ??
                  'Restored local timetable draft.',
              generatedSessions: sessions,
              unassignedRequirements: _decodeUnassigned(
                map['unassigned_requirements'],
              ),
              validationIssues: generationIssues,
              score: _intOr(map['generation_score'], 0),
              searchNodes: _intOr(map['generation_nodes'], 0),
            )
          : null;

      _sessions = List<ManualSession>.from(sessions);
      _faculty = List<ManualFaculty>.from(faculty);
      _rooms = List<ManualRoom>.from(rooms);
      _subjects = List<ManualSubject>.from(subjects);
      _batches = List<ManualBatch>.from(batches);
      _requirements = List<TimetableTeachingRequirement>.from(requirements);
      _swapRequests = List<ManualSwapRequest>.from(swaps);
      _institutionName = institution;
      _semesterLabel = semester;
      _workingDays = workingDays;
      _breakStart = breakStart;
      _breakEnd = breakEnd;
      _breakLabel = breakLabel;
      _teachingStart = teachingStart;
      _teachingEnd = teachingEnd;
      _slotDurationMinutes = slotDurationMinutes;
      _allowStaggeredStartTimes = allowStaggeredStartTimes;
      _avoidBackToBack = avoidBackToBack;
      _preferBalancedWorkload = preferBalancedWorkload;
      _allowCrossDepartmentSharing = allowCrossDepartmentSharing;
      _rebuildTimeSlots();

      final requestedBatchId = map['selected_batch_id'] as String?;
      _selectedBatchId =
          requestedBatchId != null &&
              _batches.any((batch) => batch.id == requestedBatchId)
          ? requestedBatchId
          : (_batches.isEmpty ? '' : _batches.first.id);
      _selectedDay = _intOr(
        map['selected_day'],
        0,
      ).clamp(0, dayNames.length - 1);
      _showWeek = map['show_week'] as bool? ?? false;
      _scenarioLabel = map['scenario_label'] as String? ?? sampleDataLabel;
      _hasUnsavedChanges = false;
      _hasLocalValidation = map['has_local_validation'] as bool? ?? false;
      _needsRegeneration = map['needs_regeneration'] as bool? ?? false;
      _setupIssues = List<ManualIssue>.from(setupIssues);
      _generationResult = generationResult;
      _generationStatus = generationResult?.status;
      _generationIssues = List<ManualIssue>.from(generationIssues);

      _savedSessions = List<ManualSession>.from(_sessions);
      _savedFaculty = List<ManualFaculty>.from(_faculty);
      _savedRooms = List<ManualRoom>.from(_rooms);
      _savedSwapRequests = List<ManualSwapRequest>.from(_swapRequests);
      _savedSubjects = List<ManualSubject>.from(_subjects);
      _savedBatches = List<ManualBatch>.from(_batches);
      _savedRequirements = List<TimetableTeachingRequirement>.from(
        _requirements,
      );
      _savedScenarioLabel = _scenarioLabel;
      _savedInstitutionName = _institutionName;
      _savedSemesterLabel = _semesterLabel;
      _savedWorkingDays = Set<int>.from(_workingDays);
      _savedBreakStart = _breakStart;
      _savedBreakEnd = _breakEnd;
      _savedBreakLabel = _breakLabel;
      _savedTeachingStart = _teachingStart;
      _savedTeachingEnd = _teachingEnd;
      _savedSlotDurationMinutes = _slotDurationMinutes;
      _savedAllowStaggeredStartTimes = _allowStaggeredStartTimes;
      _savedAvoidBackToBack = _avoidBackToBack;
      _savedPreferBalancedWorkload = _preferBalancedWorkload;
      _savedAllowCrossDepartmentSharing = _allowCrossDepartmentSharing;
      _savedGenerationResult = _generationResult;
      _savedGenerationStatus = _generationStatus;
      _savedGenerationIssues = List<ManualIssue>.from(_generationIssues);
      _savedNeedsRegeneration = _needsRegeneration;
      _updateCountersFromImportedData();
      _refreshIssues();
      return true;
    } catch (_) {
      return false;
    }
  }

  static Map<String, dynamic> _sessionMap(ManualSession session) =>
      <String, dynamic>{
        'id': session.id,
        'subject_id': session.subjectId,
        'faculty_id': session.facultyId,
        'batch_id': session.batchId,
        'room_id': session.roomId,
        'day': session.day,
        'start': session.startMinute,
        'end': session.endMinute,
        'type': session.type.name,
        'note': session.note,
      };

  static Map<String, dynamic> _facultyMap(ManualFaculty faculty) =>
      <String, dynamic>{
        'id': faculty.id,
        'name': faculty.name,
        'department': faculty.department,
        'max_weekly_hours': faculty.maxWeeklyHours,
        'is_proxy': faculty.isProxy,
        'absences': faculty.absences
            .map(
              (absence) => <String, dynamic>{
                'day': absence.day,
                'start': absence.startMinute,
                'end': absence.endMinute,
                'reason': absence.reason,
              },
            )
            .toList(),
      };

  static Map<String, dynamic> _roomMap(ManualRoom room) => <String, dynamic>{
    'id': room.id,
    'name': room.name,
    'kind': room.kind,
    'capacity': room.capacity,
    'department': room.department,
    'borrowable': room.borrowable,
    'is_available': room.isAvailable,
    'closures': room.unavailableSlots
        .map(
          (closure) => <String, dynamic>{
            'day': closure.day,
            'start': closure.startMinute,
            'end': closure.endMinute,
            'reason': closure.reason,
          },
        )
        .toList(),
  };

  static Map<String, dynamic> _swapMap(ManualSwapRequest request) =>
      <String, dynamic>{
        'id': request.id,
        'session_id': request.sessionId,
        'target_faculty_id': request.targetFacultyId,
        'target_session_id': request.targetSessionId,
        'note': request.note,
        'status': request.status,
      };

  static Map<String, dynamic> _subjectMap(ManualSubject subject) =>
      <String, dynamic>{
        'id': subject.id,
        'name': subject.name,
        'code': subject.code,
        'is_practical': subject.isPractical,
        'lecture_hours': subject.lectureHours,
        'lab_hours': subject.labHours,
      };

  static Map<String, dynamic> _batchMap(ManualBatch batch) => <String, dynamic>{
    'id': batch.id,
    'name': batch.name,
    'year': batch.year,
    'size': batch.size,
    'department': batch.department,
  };

  static Map<String, dynamic> _requirementMap(
    TimetableTeachingRequirement requirement,
  ) => <String, dynamic>{
    'id': requirement.id,
    'subject_id': requirement.subjectId,
    'batch_id': requirement.batchId,
    'faculty_id': requirement.facultyId,
    'lecture_hours': requirement.lectureHours,
    'lab_hours': requirement.labHours,
    'lecture_sessions': requirement.lectureSessions,
    'lab_sessions': requirement.labSessions,
    'is_practical': requirement.isPractical,
    'practical': requirement.practical,
    'session_duration': requirement.sessionDurationMinutes,
    'duration': requirement.durationMinutes,
    'lecture_duration': requirement.lectureDurationMinutes,
    'lab_duration': requirement.labDurationMinutes,
    'department': requirement.department,
    'preferred_days': requirement.preferredDays,
    'preferred_starts': requirement.preferredStartMinutes,
    'preferred_rooms': requirement.preferredRoomIds,
  };

  static Map<String, dynamic> _issueMap(ManualIssue issue) => <String, dynamic>{
    'code': issue.code,
    'message': issue.message,
    'session_ids': issue.sessionIds,
    'is_hard': issue.isHard,
  };

  static Map<String, dynamic> _unassignedMap(
    TimetableUnassignedRequirement item,
  ) => <String, dynamic>{
    'id': item.id,
    'requirement_id': item.requirementId,
    'subject_id': item.subjectId,
    'batch_id': item.batchId,
    'faculty_id': item.facultyId,
    'is_practical': item.isPractical,
    'duration': item.durationMinutes,
    'reason': item.reason,
  };

  List<ManualSession>? _decodeSessions(Object? value) {
    if (value is! List) return null;
    try {
      return value.map((raw) {
        final item = _map(raw);
        return ManualSession(
          id: item['id'] as String,
          subjectId: item['subject_id'] as String,
          facultyId: item['faculty_id'] as String,
          batchId: item['batch_id'] as String,
          roomId: item['room_id'] as String? ?? '',
          day: _int(item['day']),
          startMinute: _int(item['start']),
          endMinute: _int(item['end']),
          type: ManualSessionType.fromString(
            item['type'] as String? ?? 'lecture',
          ),
          note: item['note'] as String? ?? '',
        );
      }).toList();
    } catch (_) {
      return null;
    }
  }

  List<ManualFaculty>? _decodeFaculty(Object? value) {
    if (value is! List) return null;
    try {
      return value.map((raw) {
        final item = _map(raw);
        final absences = (item['absences'] as List? ?? const <Object?>[]).map((
          rawAbsence,
        ) {
          final absence = _map(rawAbsence);
          return ManualAbsence(
            day: _int(absence['day']),
            startMinute: _int(absence['start']),
            endMinute: _int(absence['end']),
            reason: absence['reason'] as String? ?? 'Unavailable',
          );
        }).toList();
        return ManualFaculty(
          id: item['id'] as String,
          name: item['name'] as String,
          department: item['department'] as String? ?? '',
          maxWeeklyHours: _int(item['max_weekly_hours']),
          isProxy: item['is_proxy'] as bool? ?? false,
          absences: absences,
        );
      }).toList();
    } catch (_) {
      return null;
    }
  }

  List<ManualRoom>? _decodeRooms(Object? value) {
    if (value is! List) return null;
    try {
      return value.map((raw) {
        final item = _map(raw);
        final closures = (item['closures'] as List? ?? const <Object?>[]).map((
          rawClosure,
        ) {
          final closure = _map(rawClosure);
          return ManualRoomClosure(
            day: _int(closure['day']),
            startMinute: _int(closure['start']),
            endMinute: _int(closure['end']),
            reason: closure['reason'] as String? ?? 'Unavailable',
          );
        }).toList();
        return ManualRoom(
          id: item['id'] as String,
          name: item['name'] as String,
          kind: item['kind'] as String? ?? 'classroom',
          capacity: _int(item['capacity']),
          department: item['department'] as String? ?? '',
          borrowable: item['borrowable'] as bool? ?? true,
          isAvailable: item['is_available'] as bool? ?? true,
          unavailableSlots: closures,
        );
      }).toList();
    } catch (_) {
      return null;
    }
  }

  List<ManualSubject>? _decodeSubjects(Object? value) {
    if (value is! List) return null;
    try {
      return value.map((raw) {
        final item = _map(raw);
        return ManualSubject(
          id: item['id'] as String,
          name: item['name'] as String,
          code: item['code'] as String,
          isPractical: item['is_practical'] as bool? ?? false,
          lectureHours: _intOr(item['lecture_hours'], 0),
          labHours: _intOr(item['lab_hours'], 0),
        );
      }).toList();
    } catch (_) {
      return null;
    }
  }

  List<ManualBatch>? _decodeBatches(Object? value) {
    if (value is! List) return null;
    try {
      return value.map((raw) {
        final item = _map(raw);
        return ManualBatch(
          id: item['id'] as String,
          name: item['name'] as String,
          year: _intOr(item['year'], 1),
          size: _intOr(item['size'], 0),
          department: item['department'] as String? ?? 'Information Technology',
        );
      }).toList();
    } catch (_) {
      return null;
    }
  }

  List<TimetableTeachingRequirement>? _decodeRequirements(Object? value) {
    if (value is! List) return null;
    try {
      return value.map((raw) {
        final item = _map(raw);
        return TimetableTeachingRequirement(
          id: item['id'] as String? ?? '',
          subjectId: item['subject_id'] as String,
          batchId: item['batch_id'] as String,
          facultyId: item['faculty_id'] as String,
          lectureHours: _nullableInt(item['lecture_hours']),
          labHours: _nullableInt(item['lab_hours']),
          lectureSessions: _nullableInt(item['lecture_sessions']),
          labSessions: _nullableInt(item['lab_sessions']),
          isPractical: item['is_practical'] as bool? ?? false,
          practical: item['practical'] as bool? ?? false,
          sessionDurationMinutes: _nullableInt(item['session_duration']),
          durationMinutes: _nullableInt(item['duration']),
          lectureDurationMinutes: _nullableInt(item['lecture_duration']),
          labDurationMinutes: _nullableInt(item['lab_duration']),
          department: item['department'] as String?,
          preferredDays: _intList(item['preferred_days']),
          preferredStartMinutes: _intList(item['preferred_starts']),
          preferredRoomIds: _stringList(item['preferred_rooms']),
        );
      }).toList();
    } catch (_) {
      return null;
    }
  }

  List<ManualIssue> _decodeIssues(Object? value) {
    if (value is! List) return <ManualIssue>[];
    return value.map((raw) {
      final item = _map(raw);
      return ManualIssue(
        code: item['code'] as String? ?? 'UNKNOWN',
        message: item['message'] as String? ?? 'Unknown issue',
        sessionIds: _stringList(item['session_ids']),
        isHard: item['is_hard'] as bool? ?? true,
      );
    }).toList();
  }

  List<TimetableUnassignedRequirement> _decodeUnassigned(Object? value) {
    if (value is! List) return <TimetableUnassignedRequirement>[];
    try {
      return value.map((raw) {
        final item = _map(raw);
        return TimetableUnassignedRequirement(
          id: item['id'] as String,
          requirementId: item['requirement_id'] as String,
          subjectId: item['subject_id'] as String,
          batchId: item['batch_id'] as String,
          facultyId: item['faculty_id'] as String,
          isPractical: item['is_practical'] as bool? ?? false,
          durationMinutes: _intOr(item['duration'], 0),
          reason: item['reason'] as String? ?? 'No placement found.',
        );
      }).toList();
    } catch (_) {
      return <TimetableUnassignedRequirement>[];
    }
  }

  Set<int> _decodeWorkingDays(Object? value) {
    final days = _intList(value)
        .where((day) => day >= 0 && day < dayNames.length)
        .toSet();
    return days.isEmpty ? <int>{0, 1, 2, 3, 4, 5} : days;
  }

  TimetableGenerationStatus? _decodeGenerationStatus(Object? value) {
    if (value is! String) return null;
    for (final status in TimetableGenerationStatus.values) {
      if (status.name == value) return status;
    }
    return null;
  }

  List<ManualSwapRequest>? _decodeSwaps(Object? value) {
    if (value is! List) return null;
    try {
      return value.map((raw) {
        final item = _map(raw);
        return ManualSwapRequest(
          id: item['id'] as String,
          sessionId: item['session_id'] as String,
          targetFacultyId: item['target_faculty_id'] as String?,
          targetSessionId: item['target_session_id'] as String?,
          note: item['note'] as String? ?? '',
          status: item['status'] as String? ?? 'draft',
        );
      }).toList();
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> _map(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  static int _int(Object? value) =>
      value is num ? value.toInt() : int.parse('$value');

  static int _intOr(Object? value, int fallback) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? fallback;

  static int? _nullableInt(Object? value) =>
      value == null ? null : _intOr(value, 0);

  static List<int> _intList(Object? value) => value is List
      ? value.whereType<num>().map((item) => item.toInt()).toList()
      : <int>[];

  static List<String> _stringList(Object? value) =>
      value is List ? value.whereType<String>().toList() : <String>[];

  void _rebuildTimeSlots() {
    final slots = <ManualTimeSlot>[];
    final step = _slotDurationMinutes + (_allowStaggeredStartTimes ? 10 : 0);
    for (final day in workingDays) {
      for (
        var start = _teachingStart;
        start + _slotDurationMinutes <= _teachingEnd;
        start += step
      ) {
        final end = start + _slotDurationMinutes;
        if (_overlaps(start, end, _breakStart, _breakEnd)) continue;
        slots.add(ManualTimeSlot(day: day, startMinute: start, endMinute: end));
      }
      slots.add(
        ManualTimeSlot(
          day: day,
          startMinute: _breakStart,
          endMinute: _breakEnd,
          isBreak: true,
          label: _breakLabel,
        ),
      );
    }
    slots.sort((left, right) {
      final day = left.day.compareTo(right.day);
      if (day != 0) return day;
      return left.startMinute.compareTo(right.startMinute);
    });
    _timeSlots = slots;
    if (_selectedDay >= dayNames.length ||
        !_workingDays.contains(_selectedDay)) {
      _selectedDay = workingDays.isEmpty ? 0 : workingDays.first;
    }
  }

  void _invalidateGeneratedTimetable() {
    if (_generationResult == null && _sessions.isEmpty) return;
    _needsRegeneration = true;
    _generationIssues = <ManualIssue>[];
    _hasLocalValidation = false;
  }

  void _refreshIssues() {
    final hard = <ManualIssue>[];
    final soft = <ManualIssue>[];

    for (final session in _sessions) {
      final missing = <String>[];
      if (session.subjectId.trim().isEmpty ||
          _findSubject(session.subjectId) == null) {
        missing.add('subject');
      }
      if (session.facultyId.trim().isEmpty ||
          _findFaculty(session.facultyId) == null) {
        missing.add('faculty');
      }
      if (session.batchId.trim().isEmpty ||
          _findBatch(session.batchId) == null) {
        missing.add('batch');
      }
      if (session.roomId.trim().isEmpty || _findRoom(session.roomId) == null) {
        missing.add('room');
      }
      if (missing.isNotEmpty || session.endMinute <= session.startMinute) {
        final details = missing.isEmpty
            ? 'end time must be after start time'
            : 'missing ${missing.join(', ')}${session.endMinute <= session.startMinute ? '; end time must be after start time' : ''}';
        hard.add(
          ManualIssue(
            code: 'MISSING_FIELD',
            message: 'Session ${session.id}: $details.',
            sessionIds: <String>[session.id],
          ),
        );
      }
      if (session.day < 0 || session.day >= dayNames.length) {
        hard.add(
          ManualIssue(
            code: 'UNKNOWN_DAY',
            message:
                'Session ${session.id}: choose a teaching day from Monday to Saturday.',
            sessionIds: <String>[session.id],
          ),
        );
      }

      final room = _findRoom(session.roomId);
      final subject = _findSubject(session.subjectId);
      final batch = _findBatch(session.batchId);
      final teacher = _findFaculty(session.facultyId);
      final practical = session.isPractical || subject?.isPractical == true;
      if (practical && room != null && !room.isLab) {
        hard.add(
          ManualIssue(
            code: 'PRACTICAL_ROOM',
            message:
                '${subject?.name ?? 'Practical class'} needs a laboratory, but ${room.name} is a classroom.',
            sessionIds: <String>[session.id],
          ),
        );
      }
      if (room != null &&
          room.isUnavailableAt(
            session.day,
            session.startMinute,
            session.endMinute,
          )) {
        hard.add(
          ManualIssue(
            code: 'ROOM_UNAVAILABLE',
            message:
                '${room.name} is unavailable for ${dayName(session.day)} ${_formatTime(session.startMinute)}.',
            sessionIds: <String>[session.id],
          ),
        );
      }
      if (room != null && batch != null && room.capacity < batch.size) {
        hard.add(
          ManualIssue(
            code: 'ROOM_CAPACITY',
            message:
                '${room.name} seats ${room.capacity}, but ${batch.name} has ${batch.size} students.',
            sessionIds: <String>[session.id],
          ),
        );
      }
      if (teacher != null &&
          teacher.isAbsentAt(
            session.day,
            session.startMinute,
            session.endMinute,
          )) {
        hard.add(
          ManualIssue(
            code: 'TEACHER_UNAVAILABLE',
            message:
                '${teacher.name} is marked unavailable during this session.',
            sessionIds: <String>[session.id],
          ),
        );
      }
    }

    for (var left = 0; left < _sessions.length; left++) {
      final first = _sessions[left];
      for (var right = left + 1; right < _sessions.length; right++) {
        final second = _sessions[right];
        if (first.day != second.day ||
            !_overlaps(
              first.startMinute,
              first.endMinute,
              second.startMinute,
              second.endMinute,
            )) {
          continue;
        }
        final refs = <String>[first.id, second.id];
        if (first.facultyId.isNotEmpty && first.facultyId == second.facultyId) {
          hard.add(
            ManualIssue(
              code: 'TEACHER_OVERLAP',
              message: 'Teacher overlap: one teacher is assigned to two sessions at the same time.',
              sessionIds: refs,
            ),
          );
        }
        if (first.roomId.isNotEmpty && first.roomId == second.roomId) {
          hard.add(
            ManualIssue(
              code: 'ROOM_OVERLAP',
              message:
                  'Room overlap: ${_findRoom(first.roomId)?.name ?? first.roomId} is double-booked.',
              sessionIds: refs,
            ),
          );
        }
        if (first.batchId.isNotEmpty && first.batchId == second.batchId) {
          hard.add(
            ManualIssue(
              code: 'BATCH_OVERLAP',
              message:
                  'Batch overlap: ${_findBatch(first.batchId)?.name ?? first.batchId} has two sessions at the same time.',
              sessionIds: refs,
            ),
          );
        }
      }
    }

    final warningKeys = <String>{};
    for (var left = 0; left < _sessions.length; left++) {
      final first = _sessions[left];
      for (var right = left + 1; right < _sessions.length; right++) {
        final second = _sessions[right];
        if (first.day != second.day) continue;
        final adjacent =
            first.endMinute == second.startMinute ||
            second.endMinute == first.startMinute;
        if (!adjacent) continue;
        if (first.facultyId.isNotEmpty && first.facultyId == second.facultyId) {
          final key =
              'faculty:${first.facultyId}:${first.day}:${first.id}:${second.id}';
          if (warningKeys.add(key)) {
            soft.add(
              ManualIssue(
                code: 'BACK_TO_BACK_TEACHER',
                message:
                    '${_findFaculty(first.facultyId)?.name ?? 'Teacher'} has back-to-back classes on ${dayName(first.day)}.',
                sessionIds: <String>[first.id, second.id],
                isHard: false,
              ),
            );
          }
        }
        if (first.batchId.isNotEmpty && first.batchId == second.batchId) {
          final key =
              'batch:${first.batchId}:${first.day}:${first.id}:${second.id}';
          if (warningKeys.add(key)) {
            soft.add(
              ManualIssue(
                code: 'BACK_TO_BACK_BATCH',
                message:
                    '${_findBatch(first.batchId)?.name ?? 'Batch'} has back-to-back classes on ${dayName(first.day)}.',
                sessionIds: <String>[first.id, second.id],
                isHard: false,
              ),
            );
          }
        }
      }
    }

    final allHard = <ManualIssue>[];
    final allSoft = <ManualIssue>[];
    final seen = <String>{};
    for (final issue in <ManualIssue>[..._generationIssues, ...hard, ...soft]) {
      final key =
          '${issue.code}|${issue.message}|${issue.sessionIds.join(',')}';
      if (!seen.add(key)) continue;
      (issue.isHard ? allHard : allSoft).add(issue);
    }
    _hardConflicts = allHard;
    _softWarnings = allSoft;
  }

  int _sessionIndex(Object sessionOrId) {
    final id = sessionOrId is ManualSession ? sessionOrId.id : '$sessionOrId';
    return _sessions.indexWhere((session) => session.id == id);
  }

  String _newSessionId() => 'manual-${_nextSessionNumber++}';

  void _updateCountersFromImportedData() {
    var nextSession = 100;
    for (final session in _sessions) {
      final match = RegExp(r'^manual-(\d+)$').firstMatch(session.id);
      final number = int.tryParse(match?.group(1) ?? '');
      if (number != null) {
        nextSession = number + 1 > nextSession ? number + 1 : nextSession;
      }
    }
    var nextSwap = 1;
    for (final request in _swapRequests) {
      final match = RegExp(r'^swap-(\d+)$').firstMatch(request.id);
      final number = int.tryParse(match?.group(1) ?? '');
      if (number != null) {
        nextSwap = number + 1 > nextSwap ? number + 1 : nextSwap;
      }
    }
    _nextSessionNumber = nextSession;
    _nextSwapNumber = nextSwap;
  }

  ManualSubject? _findSubject(String id) =>
      _firstWhereOrNull(_subjects, (item) => item.id == id);
  ManualFaculty? _findFaculty(String id) =>
      _firstWhereOrNull(_faculty, (item) => item.id == id);
  ManualRoom? _findRoom(String id) =>
      _firstWhereOrNull(_rooms, (item) => item.id == id);
  ManualBatch? _findBatch(String id) =>
      _firstWhereOrNull(_batches, (item) => item.id == id);

  static T? _firstWhereOrNull<T>(Iterable<T> items, bool Function(T) test) {
    for (final item in items) {
      if (test(item)) return item;
    }
    return null;
  }

  static int _duration(ManualSession session) =>
      (session.endMinute - session.startMinute).clamp(0, 24 * 60);

  static bool _overlaps(int startA, int endA, int startB, int endB) =>
      startA < endB && startB < endA;

  static String _formatTime(int minutes) {
    final hour = (minutes ~/ 60).toString().padLeft(2, '0');
    final minute = (minutes % 60).toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static String _formatHours(int minutes) =>
      '${(minutes / 60).toStringAsFixed(minutes % 60 == 0 ? 0 : 1)} h';

  void _seedDemoData() {
    _faculty = const <ManualFaculty>[
      ManualFaculty(
        id: 'faculty-kavita',
        name: 'Kavita Nair',
        department: 'Information Technology',
        maxWeeklyHours: 18,
      ),
      ManualFaculty(
        id: 'faculty-rohan',
        name: 'Rohan Mehta',
        department: 'Information Technology',
        maxWeeklyHours: 16,
      ),
      ManualFaculty(
        id: 'faculty-meera',
        name: 'Meera Shah',
        department: 'Information Technology',
        maxWeeklyHours: 20,
      ),
      ManualFaculty(
        id: 'faculty-anuj',
        name: 'Anuj Kulkarni',
        department: 'Information Technology',
        maxWeeklyHours: 18,
      ),
      ManualFaculty(
        id: 'faculty-sana',
        name: 'Sana Iyer',
        department: 'Information Technology',
        maxWeeklyHours: 18,
      ),
    ];
    _rooms = const <ManualRoom>[
      ManualRoom(
        id: 'room-cr-101',
        name: 'CR-101',
        kind: 'classroom',
        capacity: 60,
        department: 'Information Technology',
      ),
      ManualRoom(
        id: 'room-cr-102',
        name: 'CR-102',
        kind: 'classroom',
        capacity: 60,
        department: 'Information Technology',
      ),
      ManualRoom(
        id: 'room-cr-201',
        name: 'CR-201',
        kind: 'classroom',
        capacity: 72,
        department: 'Information Technology',
      ),
      ManualRoom(
        id: 'room-it-lab-1',
        name: 'IT Lab 1',
        kind: 'laboratory',
        capacity: 45,
        department: 'Information Technology',
      ),
      ManualRoom(
        id: 'room-it-lab-2',
        name: 'IT Lab 2',
        kind: 'laboratory',
        capacity: 45,
        department: 'Information Technology',
      ),
      ManualRoom(
        id: 'room-cse-lab-1',
        name: 'CSE Lab 1',
        kind: 'laboratory',
        capacity: 45,
        department: 'Computer Science',
        borrowable: true,
      ),
      ManualRoom(
        id: 'room-auditorium',
        name: 'Seminar Hall',
        kind: 'classroom',
        capacity: 180,
        department: 'Central Facilities',
      ),
    ];
    _batches = const <ManualBatch>[
      ManualBatch(id: 'batch-fy-it-a', name: 'FY IT A', year: 1, size: 42),
      ManualBatch(id: 'batch-fy-it-b', name: 'FY IT B', year: 1, size: 38),
      ManualBatch(id: 'batch-sy-it-a', name: 'SY IT A', year: 2, size: 36),
    ];
    _subjects = const <ManualSubject>[
      ManualSubject(
        id: 'subject-mathematics',
        name: 'Engineering Mathematics II',
        code: 'MATH-2',
        lectureHours: 4,
      ),
      ManualSubject(
        id: 'subject-data-structures',
        name: 'Data Structures',
        code: 'DS-201',
        lectureHours: 3,
      ),
      ManualSubject(
        id: 'subject-web-programming',
        name: 'Web Programming',
        code: 'WP-202',
        lectureHours: 2,
        labHours: 2,
      ),
      ManualSubject(
        id: 'subject-web-lab',
        name: 'Web Programming Lab',
        code: 'WP-202L',
        isPractical: true,
        labHours: 2,
      ),
      ManualSubject(
        id: 'subject-database',
        name: 'Database Management Systems',
        code: 'DBMS-203',
        lectureHours: 3,
      ),
      ManualSubject(
        id: 'subject-database-lab',
        name: 'Database Lab',
        code: 'DBMS-203L',
        isPractical: true,
        labHours: 2,
      ),
      ManualSubject(
        id: 'subject-networks',
        name: 'Computer Networks',
        code: 'CN-204',
        lectureHours: 3,
      ),
      ManualSubject(
        id: 'subject-software',
        name: 'Software Engineering',
        code: 'SE-205',
        lectureHours: 3,
      ),
      ManualSubject(
        id: 'subject-project',
        name: 'Mini Project Studio',
        code: 'PRJ-206',
        lectureHours: 2,
      ),
    ];
    _timeSlots = <ManualTimeSlot>[
      for (var day = 0; day < dayNames.length; day++) ...[
        ManualTimeSlot(day: day, startMinute: 540, endMinute: 590),
        ManualTimeSlot(day: day, startMinute: 600, endMinute: 650),
        ManualTimeSlot(day: day, startMinute: 660, endMinute: 710),
        ManualTimeSlot(
          day: day,
          startMinute: 720,
          endMinute: 750,
          isBreak: true,
          label: 'Lunch break',
        ),
        ManualTimeSlot(day: day, startMinute: 750, endMinute: 800),
        ManualTimeSlot(day: day, startMinute: 810, endMinute: 860),
        ManualTimeSlot(day: day, startMinute: 870, endMinute: 920),
      ],
    ];
    _sessions = <ManualSession>[
      const ManualSession(
        id: 'demo-mon-fya-math',
        subjectId: 'subject-mathematics',
        facultyId: 'faculty-kavita',
        batchId: 'batch-fy-it-a',
        roomId: 'room-cr-101',
        day: 0,
        startMinute: 540,
        endMinute: 590,
      ),
      const ManualSession(
        id: 'demo-mon-fya-ds',
        subjectId: 'subject-data-structures',
        facultyId: 'faculty-rohan',
        batchId: 'batch-fy-it-a',
        roomId: 'room-cr-101',
        day: 0,
        startMinute: 600,
        endMinute: 650,
      ),
      const ManualSession(
        id: 'demo-mon-fyb-math',
        subjectId: 'subject-mathematics',
        facultyId: 'faculty-meera',
        batchId: 'batch-fy-it-b',
        roomId: 'room-cr-102',
        day: 0,
        startMinute: 540,
        endMinute: 590,
      ),
      const ManualSession(
        id: 'demo-mon-sya-net',
        subjectId: 'subject-networks',
        facultyId: 'faculty-anuj',
        batchId: 'batch-sy-it-a',
        roomId: 'room-cse-lab-1',
        day: 0,
        startMinute: 750,
        endMinute: 800,
      ),
      const ManualSession(
        id: 'demo-tue-fyb-web',
        subjectId: 'subject-web-programming',
        facultyId: 'faculty-meera',
        batchId: 'batch-fy-it-b',
        roomId: 'room-cr-102',
        day: 1,
        startMinute: 540,
        endMinute: 590,
      ),
      const ManualSession(
        id: 'demo-tue-fya-web-lab',
        subjectId: 'subject-web-lab',
        facultyId: 'faculty-rohan',
        batchId: 'batch-fy-it-a',
        roomId: 'room-it-lab-1',
        day: 1,
        startMinute: 600,
        endMinute: 710,
        type: ManualSessionType.practical,
      ),
      const ManualSession(
        id: 'demo-tue-sya-web',
        subjectId: 'subject-web-programming',
        facultyId: 'faculty-anuj',
        batchId: 'batch-sy-it-a',
        roomId: 'room-cr-201',
        day: 1,
        startMinute: 600,
        endMinute: 650,
      ),
      const ManualSession(
        id: 'demo-wed-fya-web',
        subjectId: 'subject-web-programming',
        facultyId: 'faculty-sana',
        batchId: 'batch-fy-it-a',
        roomId: 'room-cr-101',
        day: 2,
        startMinute: 540,
        endMinute: 590,
      ),
      const ManualSession(
        id: 'demo-wed-fyb-dbms',
        subjectId: 'subject-database',
        facultyId: 'faculty-meera',
        batchId: 'batch-fy-it-b',
        roomId: 'room-cr-102',
        day: 2,
        startMinute: 600,
        endMinute: 650,
      ),
      const ManualSession(
        id: 'demo-wed-sya-software',
        subjectId: 'subject-software',
        facultyId: 'faculty-anuj',
        batchId: 'batch-sy-it-a',
        roomId: 'room-cr-201',
        day: 2,
        startMinute: 750,
        endMinute: 800,
      ),
      const ManualSession(
        id: 'demo-thu-fyb-net',
        subjectId: 'subject-networks',
        facultyId: 'faculty-meera',
        batchId: 'batch-fy-it-b',
        roomId: 'room-cr-102',
        day: 3,
        startMinute: 540,
        endMinute: 590,
      ),
      const ManualSession(
        id: 'demo-thu-fya-dbms-lab',
        subjectId: 'subject-database-lab',
        facultyId: 'faculty-rohan',
        batchId: 'batch-fy-it-a',
        roomId: 'room-it-lab-2',
        day: 3,
        startMinute: 600,
        endMinute: 710,
        type: ManualSessionType.practical,
      ),
      const ManualSession(
        id: 'demo-thu-sya-math',
        subjectId: 'subject-mathematics',
        facultyId: 'faculty-kavita',
        batchId: 'batch-sy-it-a',
        roomId: 'room-cr-201',
        day: 3,
        startMinute: 660,
        endMinute: 710,
      ),
      const ManualSession(
        id: 'demo-fri-fya-web',
        subjectId: 'subject-web-programming',
        facultyId: 'faculty-sana',
        batchId: 'batch-fy-it-a',
        roomId: 'room-cr-101',
        day: 4,
        startMinute: 540,
        endMinute: 590,
      ),
      const ManualSession(
        id: 'demo-fri-fyb-web-lab',
        subjectId: 'subject-web-lab',
        facultyId: 'faculty-rohan',
        batchId: 'batch-fy-it-b',
        roomId: 'room-it-lab-2',
        day: 4,
        startMinute: 600,
        endMinute: 710,
        type: ManualSessionType.practical,
      ),
      const ManualSession(
        id: 'demo-fri-sya-dbms',
        subjectId: 'subject-database',
        facultyId: 'faculty-anuj',
        batchId: 'batch-sy-it-a',
        roomId: 'room-cr-201',
        day: 4,
        startMinute: 750,
        endMinute: 800,
      ),
      const ManualSession(
        id: 'demo-sat-fya-project',
        subjectId: 'subject-project',
        facultyId: 'faculty-sana',
        batchId: 'batch-fy-it-a',
        roomId: 'room-auditorium',
        day: 5,
        startMinute: 540,
        endMinute: 650,
      ),
      const ManualSession(
        id: 'demo-sat-fyb-web',
        subjectId: 'subject-web-programming',
        facultyId: 'faculty-meera',
        batchId: 'batch-fy-it-b',
        roomId: 'room-cr-102',
        day: 5,
        startMinute: 660,
        endMinute: 710,
      ),
      const ManualSession(
        id: 'demo-sat-sya-net',
        subjectId: 'subject-networks',
        facultyId: 'faculty-anuj',
        batchId: 'batch-sy-it-a',
        roomId: 'room-cr-201',
        day: 5,
        startMinute: 750,
        endMinute: 800,
      ),
    ];

    // The seed literals above are const for readability, but all collections
    // become mutable setup state once the workspace opens. The timetable itself
    // starts empty; it is produced only after the coordinator presses Generate.
    _faculty = List<ManualFaculty>.from(_faculty);
    _rooms = List<ManualRoom>.from(_rooms);
    _batches = List<ManualBatch>.from(_batches);
    _subjects = List<ManualSubject>.from(_subjects);
    _workingDays = <int>{0, 1, 2, 3, 4, 5};
    _institutionName = defaultInstitution;
    _semesterLabel = defaultSemester;
    _breakStart = 720;
    _breakEnd = 750;
    _breakLabel = 'Lunch break';
    _teachingStart = 540;
    _teachingEnd = 920;
    _slotDurationMinutes = 50;
    _allowStaggeredStartTimes = true;
    _requirements = List<TimetableTeachingRequirement>.from(
      _demoRequirements(),
    );
    _sessions = <ManualSession>[];
    _rebuildTimeSlots();
  }

  List<TimetableTeachingRequirement> _demoRequirements() => const [
    TimetableTeachingRequirement(
      id: 'req-fya-math',
      subjectId: 'subject-mathematics',
      batchId: 'batch-fy-it-a',
      facultyId: 'faculty-kavita',
      lectureSessions: 2,
    ),
    TimetableTeachingRequirement(
      id: 'req-fyb-math',
      subjectId: 'subject-mathematics',
      batchId: 'batch-fy-it-b',
      facultyId: 'faculty-meera',
      lectureSessions: 2,
    ),
    TimetableTeachingRequirement(
      id: 'req-sya-math',
      subjectId: 'subject-mathematics',
      batchId: 'batch-sy-it-a',
      facultyId: 'faculty-kavita',
      lectureSessions: 2,
    ),
    TimetableTeachingRequirement(
      id: 'req-fya-ds',
      subjectId: 'subject-data-structures',
      batchId: 'batch-fy-it-a',
      facultyId: 'faculty-rohan',
      lectureSessions: 2,
    ),
    TimetableTeachingRequirement(
      id: 'req-fyb-ds',
      subjectId: 'subject-data-structures',
      batchId: 'batch-fy-it-b',
      facultyId: 'faculty-rohan',
      lectureSessions: 2,
    ),
    TimetableTeachingRequirement(
      id: 'req-fya-web',
      subjectId: 'subject-web-programming',
      batchId: 'batch-fy-it-a',
      facultyId: 'faculty-sana',
      lectureSessions: 2,
    ),
    TimetableTeachingRequirement(
      id: 'req-fyb-web',
      subjectId: 'subject-web-programming',
      batchId: 'batch-fy-it-b',
      facultyId: 'faculty-meera',
      lectureSessions: 2,
    ),
    TimetableTeachingRequirement(
      id: 'req-sya-web',
      subjectId: 'subject-web-programming',
      batchId: 'batch-sy-it-a',
      facultyId: 'faculty-anuj',
      lectureSessions: 1,
    ),
    TimetableTeachingRequirement(
      id: 'req-fya-web-lab',
      subjectId: 'subject-web-lab',
      batchId: 'batch-fy-it-a',
      facultyId: 'faculty-rohan',
      labSessions: 1,
      labDurationMinutes: 100,
      isPractical: true,
    ),
    TimetableTeachingRequirement(
      id: 'req-fyb-web-lab',
      subjectId: 'subject-web-lab',
      batchId: 'batch-fy-it-b',
      facultyId: 'faculty-anuj',
      labSessions: 1,
      labDurationMinutes: 100,
      isPractical: true,
    ),
    TimetableTeachingRequirement(
      id: 'req-fyb-dbms',
      subjectId: 'subject-database',
      batchId: 'batch-fy-it-b',
      facultyId: 'faculty-meera',
      lectureSessions: 2,
    ),
    TimetableTeachingRequirement(
      id: 'req-sya-dbms',
      subjectId: 'subject-database',
      batchId: 'batch-sy-it-a',
      facultyId: 'faculty-anuj',
      lectureSessions: 2,
    ),
    TimetableTeachingRequirement(
      id: 'req-fya-dbms-lab',
      subjectId: 'subject-database-lab',
      batchId: 'batch-fy-it-a',
      facultyId: 'faculty-rohan',
      labSessions: 1,
      labDurationMinutes: 100,
      isPractical: true,
    ),
    TimetableTeachingRequirement(
      id: 'req-fyb-networks',
      subjectId: 'subject-networks',
      batchId: 'batch-fy-it-b',
      facultyId: 'faculty-kavita',
      lectureSessions: 2,
    ),
    TimetableTeachingRequirement(
      id: 'req-sya-networks',
      subjectId: 'subject-networks',
      batchId: 'batch-sy-it-a',
      facultyId: 'faculty-sana',
      lectureSessions: 2,
    ),
    TimetableTeachingRequirement(
      id: 'req-sya-software',
      subjectId: 'subject-software',
      batchId: 'batch-sy-it-a',
      facultyId: 'faculty-sana',
      lectureSessions: 2,
    ),
    TimetableTeachingRequirement(
      id: 'req-fya-project',
      subjectId: 'subject-project',
      batchId: 'batch-fy-it-a',
      facultyId: 'faculty-kavita',
      lectureSessions: 2,
      sessionDurationMinutes: 50,
    ),
  ];
}
