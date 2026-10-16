import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'manual_timetable_models.dart';

export 'manual_timetable_models.dart';

/// Owns the local, frontend-only draft used by the manual timetable editor.
///
/// This controller intentionally has no API client. It is a deterministic
/// product prototype: a coordinator can try edits, inspect local hard conflicts
/// and soft warnings, then save or discard a local draft. Persistence is limited
/// to the device/browser through shared_preferences; it is not institutional data.
class ManualTimetableController extends ChangeNotifier {
  static const String _storageKey = 'synchro.manual-draft.v1';

  ManualTimetableController({
    List<ManualSession>? sessions,
    List<ManualFaculty>? faculty,
    List<ManualRoom>? rooms,
    List<ManualSubject>? subjects,
    List<ManualBatch>? batches,
  }) {
    _seedDemoData();
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
    _refreshIssues();
  }

  static const String sampleDataLabel = 'DEMO SAMPLE · LOCAL DRAFT ONLY';
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
  List<ManualSwapRequest> _swapRequests = <ManualSwapRequest>[];

  List<ManualSession> _savedSessions = <ManualSession>[];
  List<ManualFaculty> _savedFaculty = <ManualFaculty>[];
  List<ManualRoom> _savedRooms = <ManualRoom>[];
  List<ManualSwapRequest> _savedSwapRequests = <ManualSwapRequest>[];

  String _selectedBatchId = '';
  int _selectedDay = 0;
  bool _showWeek = false;
  bool _hasUnsavedChanges = false;
  bool _hasLocalValidation = false;
  bool _isRestoring = false;
  String _scenarioLabel = sampleDataLabel;
  String _savedScenarioLabel = sampleDataLabel;
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
  List<ManualIssue> get issues => List<ManualIssue>.unmodifiable(<ManualIssue>[
    ..._hardConflicts,
    ..._softWarnings,
  ]);
  List<ManualSwapRequest> get swapRequests =>
      List<ManualSwapRequest>.unmodifiable(_swapRequests);

  ManualBatch? get selectedBatch => _findBatch(_selectedBatchId);

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
      final map = Map<String, dynamic>.from(decoded);
      final sessions = _decodeSessions(map['sessions']);
      final faculty = _decodeFaculty(map['faculty']);
      final rooms = _decodeRooms(map['rooms']);
      final swaps = _decodeSwaps(map['swaps']);
      if (sessions == null ||
          faculty == null ||
          rooms == null ||
          swaps == null) {
        return;
      }
      _sessions = sessions;
      _faculty = faculty;
      _rooms = rooms;
      _swapRequests = swaps;
      _savedSessions = List<ManualSession>.from(_sessions);
      _savedFaculty = List<ManualFaculty>.from(_faculty);
      _savedRooms = List<ManualRoom>.from(_rooms);
      _savedSwapRequests = List<ManualSwapRequest>.from(_swapRequests);
      _selectedBatchId =
          _batches.any((batch) => batch.id == map['selected_batch_id'])
          ? map['selected_batch_id'] as String
          : _selectedBatchId;
      _selectedDay = (map['selected_day'] as int? ?? 0).clamp(
        0,
        dayNames.length - 1,
      );
      _showWeek = map['show_week'] as bool? ?? false;
      _scenarioLabel = map['scenario_label'] as String? ?? sampleDataLabel;
      _savedScenarioLabel = _scenarioLabel;
      _hasUnsavedChanges = false;
      _hasLocalValidation = false;
      _refreshIssues();
    } catch (_) {
      // A broken local payload must never prevent the app from opening.
    } finally {
      _isRestoring = false;
      notifyListeners();
    }
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
    _touchDraft();
    return true;
  }

  /// Replaces a faculty record in the local draft without touching sessions.
  bool editFaculty(ManualFaculty teacher) {
    final index = _faculty.indexWhere((item) => item.id == teacher.id);
    if (index < 0) return false;
    _faculty[index] = teacher;
    _touchDraft();
    return true;
  }

  /// Adds a room or laboratory to the local draft.
  bool addRoom(ManualRoom room) {
    if (room.id.trim().isEmpty || _rooms.any((item) => item.id == room.id)) {
      return false;
    }
    _rooms.add(room);
    _touchDraft();
    return true;
  }

  /// Replaces a room or laboratory in the local draft without reassigning it.
  bool editRoom(ManualRoom room) {
    final index = _rooms.indexWhere((item) => item.id == room.id);
    if (index < 0) return false;
    _rooms[index] = room;
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
    _savedScenarioLabel = _scenarioLabel;
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
    _scenarioLabel = _savedScenarioLabel;
    _hasUnsavedChanges = false;
    _hasLocalValidation = false;
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
    _hasUnsavedChanges = false;
    _hasLocalValidation = false;
    _scenarioLabel = sampleDataLabel;
    _savedScenarioLabel = sampleDataLabel;
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
    final base = _sessions.first;
    _sessions.add(base.copyWith(id: 'demo-conflict-overlap'));
    _sessions.add(base.copyWith(id: 'demo-conflict-missing-room', roomId: ''));
    _selectedBatchId = _batches.first.id;
    _selectedDay = 0;
    _showWeek = false;
    _hasUnsavedChanges = true;
    _hasLocalValidation = false;
    _refreshIssues();
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
    _refreshIssues();
    notifyListeners();
  }

  Map<String, dynamic> _draftMap() => <String, dynamic>{
    'version': 1,
    'scenario_label': _scenarioLabel,
    'selected_batch_id': _selectedBatchId,
    'selected_day': _selectedDay,
    'show_week': _showWeek,
    'sessions': _sessions.map(_sessionMap).toList(),
    'faculty': _faculty.map(_facultyMap).toList(),
    'rooms': _rooms.map(_roomMap).toList(),
    'swaps': _swapRequests.map(_swapMap).toList(),
  };

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

    _hardConflicts = hard;
    _softWarnings = soft;
  }

  int _sessionIndex(Object sessionOrId) {
    final id = sessionOrId is ManualSession ? sessionOrId.id : '$sessionOrId';
    return _sessions.indexWhere((session) => session.id == id);
  }

  String _newSessionId() => 'manual-${_nextSessionNumber++}';

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
    // become mutable draft state once the editor opens.
    _faculty = List<ManualFaculty>.from(_faculty);
    _rooms = List<ManualRoom>.from(_rooms);
    _batches = List<ManualBatch>.from(_batches);
    _subjects = List<ManualSubject>.from(_subjects);
  }
}
