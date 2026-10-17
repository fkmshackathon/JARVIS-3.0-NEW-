import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'manual_timetable_controller.dart';

/// The review lifecycle shown for one locally stored timetable.
enum TimetableRecordStatus {
  notGenerated,
  draft,
  needsReview,
  validated;

  String get label => switch (this) {
    TimetableRecordStatus.notGenerated => 'Not generated',
    TimetableRecordStatus.draft => 'Draft',
    TimetableRecordStatus.needsReview => 'Needs review',
    TimetableRecordStatus.validated => 'Validated',
  };

  static TimetableRecordStatus fromString(String? value) {
    for (final status in values) {
      if (status.name == value || status.label == value) return status;
    }
    return TimetableRecordStatus.draft;
  }
}

/// Short alias for code that refers to the lifecycle as a timetable status.
typedef TimetableStatus = TimetableRecordStatus;

/// Metadata and serialized local workspace for one timetable in the library.
///
/// The snapshot is produced by [ManualTimetableController.exportSnapshot]. It
/// contains only timetable setup and local scheduling data; authentication and
/// passwords are not part of the manual workspace model.
class TimetableRecord {
  const TimetableRecord({
    required this.id,
    required this.userName,
    required this.term,
    required this.updatedAt,
    required this.status,
    required this.sessionCount,
    required this.snapshot,
  });

  final String id;
  final String userName;
  final String term;
  final DateTime updatedAt;
  final TimetableRecordStatus status;
  final int sessionCount;
  final String snapshot;

  /// Common UI-friendly aliases. [userName] remains the canonical field name.
  String get stableId => id;
  String get name => userName;
  String get title => userName;
  String get statusLabel => status.label;
  String get serializedSnapshot => snapshot;

  TimetableRecord copyWith({
    String? id,
    String? userName,
    String? term,
    DateTime? updatedAt,
    TimetableRecordStatus? status,
    int? sessionCount,
    String? snapshot,
  }) => TimetableRecord(
    id: id ?? this.id,
    userName: userName ?? this.userName,
    term: term ?? this.term,
    updatedAt: (updatedAt ?? this.updatedAt).toUtc(),
    status: status ?? this.status,
    sessionCount: sessionCount ?? this.sessionCount,
    snapshot: snapshot ?? this.snapshot,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'user_name': userName,
    'term': term,
    'updated_at': updatedAt.toUtc().toIso8601String(),
    'status': status.name,
    'session_count': sessionCount,
    'snapshot': snapshot,
  };

  Map<String, dynamic> toMap() => toJson();

  factory TimetableRecord.fromMap(Map<String, dynamic> value) =>
      TimetableRecord.fromJson(value);

  /// Parses persisted metadata. Invalid records throw [FormatException] so a
  /// library restore can reject a corrupt payload without a partial load.
  factory TimetableRecord.fromJson(Object? value) {
    if (value is! Map) {
      throw const FormatException('Timetable record must be an object.');
    }
    final map = Map<String, dynamic>.from(value);
    final id = map['id'] as String?;
    final userName = (map['user_name'] ?? map['name']) as String?;
    final term = map['term'] as String?;
    final snapshot = map['snapshot'] as String?;
    final updatedAtValue = map['updated_at'] ?? map['updatedAt'];
    if (id == null ||
        id.trim().isEmpty ||
        userName == null ||
        userName.trim().isEmpty ||
        term == null ||
        snapshot == null ||
        snapshot.trim().isEmpty) {
      throw const FormatException('Timetable record is missing metadata.');
    }

    DateTime updatedAt;
    if (updatedAtValue is num) {
      updatedAt = DateTime.fromMillisecondsSinceEpoch(
        updatedAtValue.toInt(),
        isUtc: true,
      );
    } else if (updatedAtValue is String) {
      updatedAt = DateTime.parse(updatedAtValue).toUtc();
    } else {
      throw const FormatException('Timetable record has no updated timestamp.');
    }

    return TimetableRecord(
      id: id,
      userName: userName,
      term: term,
      updatedAt: updatedAt,
      status: TimetableRecordStatus.fromString(map['status'] as String?),
      sessionCount: _intOr(map['session_count'] ?? map['sessionCount'], 0),
      snapshot: snapshot,
    );
  }

  static int _intOr(Object? value, int fallback) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? fallback;
}

/// Owns a collection of independent local timetable drafts and one active
/// [workspace]. All records are stored in device/browser shared preferences.
///
/// The controller deliberately keeps the existing manual workspace as the
/// source of truth for serialization and editing. Library operations only
/// coordinate snapshots and metadata, so the timetable generator algorithm is
/// not duplicated or changed here.
class TimetableLibraryController extends ChangeNotifier {
  static const String storageKey = 'synchro.timetables.v1';
  static const String legacyStorageKey = 'synchro.workspace.v2';

  static const String defaultRecordName = 'Untitled timetable';
  static const String demoRecordName = 'Demo timetable · local sample';
  static const String migratedRecordName = 'Migrated local timetable';

  TimetableLibraryController({ManualTimetableController? workspace})
    : workspace = workspace ?? ManualTimetableController.blank() {
    this.workspace.addListener(_handleWorkspaceChanged);
  }

  /// The one mutable workspace exposed to screens and editor actions.
  final ManualTimetableController workspace;

  /// Alias for callers that call the active workspace a controller.
  ManualTimetableController get controller => workspace;
  ManualTimetableController get activeWorkspace => workspace;
  ManualTimetableController get activeController => workspace;

  List<TimetableRecord> _records = <TimetableRecord>[];
  String? _activeId;
  bool _isRestoring = false;
  bool _suppressWorkspaceEvents = false;
  int _nextIdSuffix = 1;
  Future<void> _persistenceQueue = Future<void>.value();

  List<TimetableRecord> get records =>
      List<TimetableRecord>.unmodifiable(_records);
  List<TimetableRecord> get timetables => records;
  String? get activeId => _activeId;
  String? get activeTimetableId => _activeId;
  String? get activeRecordId => _activeId;
  bool get hasActiveTimetable => _activeId != null;
  bool get isRestoring => _isRestoring;

  TimetableRecord? get activeRecord {
    final id = _activeId;
    if (id == null) return null;
    for (final record in _records) {
      if (record.id == id) return record;
    }
    return null;
  }

  TimetableRecord? get activeTimetable => activeRecord;

  /// Loads the versioned library, migrating the old single-workspace draft
  /// when present. A missing library and missing legacy draft seed one clearly
  /// labelled demo record; a valid empty library remains empty.
  Future<void> restore() async {
    _isRestoring = true;
    _suppressWorkspaceEvents = true;
    try {
      await _persistenceQueue;
      final preferences = await SharedPreferences.getInstance();
      final rawLibrary = preferences.getString(storageKey);
      var loaded = false;

      if (rawLibrary != null && rawLibrary.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(rawLibrary);
          loaded = _loadLibraryMap(decoded);
        } catch (_) {
          loaded = false;
        }
      }

      if (!loaded) {
        final legacySnapshot = preferences.getString(legacyStorageKey);
        if (legacySnapshot != null && legacySnapshot.trim().isNotEmpty) {
          final migrated = _recordFromLegacySnapshot(legacySnapshot);
          if (migrated != null) {
            _records = <TimetableRecord>[migrated];
            _activeId = migrated.id;
            loaded = true;
          }
        }
      }

      if (!loaded) {
        _seedDemoInMemory();
      }

      _loadActiveWorkspace();
      await _persistNow();
    } catch (_) {
      // Opening the app must remain possible when local storage is unavailable.
      if (_records.isEmpty) _seedDemoInMemory();
      _loadActiveWorkspace();
    } finally {
      _suppressWorkspaceEvents = false;
      _isRestoring = false;
      notifyListeners();
    }
  }

  /// Creates and selects a blank timetable with no demo entities or sessions.
  /// The operation is synchronous for immediate UI updates; call [flush] when
  /// a caller needs to await the queued local persistence write.
  TimetableRecord createBlank({String? userName, String? name, String? term}) {
    _captureActiveWorkspace();
    final blank = ManualTimetableController.blank();
    final requestedTerm = term?.trim();
    if (requestedTerm != null && requestedTerm.isNotEmpty) {
      blank.updateSetup(semester: requestedTerm);
    }
    final record = _recordFromWorkspace(
      id: _newRecordId(),
      userName: _normaliseName(userName ?? name, defaultRecordName),
      source: blank,
      updatedAt: DateTime.now().toUtc(),
    );
    _records = <TimetableRecord>[..._records, record];
    _activeId = record.id;
    _loadWorkspaceSnapshot(record.snapshot);
    notifyListeners();
    _schedulePersist();
    return record;
  }

  /// Alias used by UI code that prefers the full operation name.
  TimetableRecord createTimetable({
    String? userName,
    String? name,
    String? term,
  }) => createBlank(userName: userName, name: name, term: term);

  /// Alias for [createBlank] that makes the blank nature explicit at call
  /// sites that also expose duplicate actions.
  TimetableRecord createBlankTimetable({
    String? userName,
    String? name,
    String? term,
  }) => createBlank(userName: userName, name: name, term: term);

  /// Duplicates [sourceId]'s complete snapshot into a new independent record
  /// and selects it. Entity objects are reconstructed by the workspace import,
  /// so later edits cannot mutate the source record.
  TimetableRecord? duplicate(
    String sourceId, {
    String? userName,
    String? name,
    String? term,
  }) {
    final source = _recordById(sourceId);
    if (source == null) return null;
    _captureActiveWorkspace();

    final copiedWorkspace = ManualTimetableController.blank();
    if (!copiedWorkspace.importSnapshot(source.snapshot)) return null;
    final requestedTerm = term?.trim();
    if (requestedTerm != null && requestedTerm.isNotEmpty) {
      copiedWorkspace.updateSetup(semester: requestedTerm);
    }
    final copy = _recordFromWorkspace(
      id: _newRecordId(),
      userName: _normaliseName(userName ?? name, '${source.userName} copy'),
      source: copiedWorkspace,
      updatedAt: DateTime.now().toUtc(),
    );
    _records = <TimetableRecord>[..._records, copy];
    _activeId = copy.id;
    _loadWorkspaceSnapshot(copy.snapshot);
    notifyListeners();
    _schedulePersist();
    return copy;
  }

  /// Full-name alias for [duplicate].
  TimetableRecord? duplicateTimetable(
    String sourceId, {
    String? userName,
    String? name,
    String? term,
  }) => duplicate(sourceId, userName: userName, name: name, term: term);

  /// Alias for [duplicate] that names the source as a record ID.
  TimetableRecord? duplicateRecord(
    String sourceId, {
    String? userName,
    String? name,
    String? term,
  }) => duplicate(sourceId, userName: userName, name: name, term: term);

  /// Selects a saved timetable by stable record ID.
  bool switchTo(String id) {
    final record = _recordById(id);
    if (record == null) return false;
    _captureActiveWorkspace();
    if (record.id == _activeId) return true;
    if (!_loadWorkspaceSnapshot(record.snapshot)) return false;
    _activeId = record.id;
    notifyListeners();
    _schedulePersist();
    return true;
  }

  /// Full-name alias for [switchTo].
  bool switchTimetable(String id) => switchTo(id);

  /// Alias for [switchTo].
  bool switchRecord(String id) => switchTo(id);

  /// Renames one record without changing its serialized workspace.
  bool rename(String id, String userName) {
    final name = userName.trim();
    if (name.isEmpty) return false;
    final index = _records.indexWhere((record) => record.id == id);
    if (index < 0) return false;
    final record = _records[index];
    _records[index] = record.copyWith(
      userName: name,
      updatedAt: DateTime.now().toUtc(),
    );
    notifyListeners();
    _schedulePersist();
    return true;
  }

  /// Full-name alias for [rename].
  bool renameTimetable(String id, String userName) => rename(id, userName);

  /// Alias for [rename].
  bool renameRecord(String id, String userName) => rename(id, userName);

  /// Deletes one record. If it was active, another saved record is selected;
  /// deleting the final record leaves an explicit blank, inactive workspace.
  bool delete(String id) {
    final index = _records.indexWhere((record) => record.id == id);
    if (index < 0) return false;
    _captureActiveWorkspace();
    final wasActive = id == _activeId;
    _records = <TimetableRecord>[..._records]..removeAt(index);

    if (wasActive) {
      if (_records.isEmpty) {
        _activeId = null;
        _loadWorkspaceSnapshot(
          ManualTimetableController.blank().exportSnapshot(),
        );
      } else {
        final replacement = _records.first;
        _activeId = replacement.id;
        _loadWorkspaceSnapshot(replacement.snapshot);
      }
    }
    notifyListeners();
    _schedulePersist();
    return true;
  }

  /// Full-name alias for [delete].
  bool deleteTimetable(String id) => delete(id);

  /// Alias for [delete].
  bool deleteRecord(String id) => delete(id);

  /// Clears the library and installs one clearly labelled demo record.
  /// This is intentionally separate from [restore], which preserves a valid
  /// empty library and migrates existing local work.
  Future<void> resetDemo() async {
    _suppressWorkspaceEvents = true;
    try {
      _seedDemoInMemory();
      _loadActiveWorkspace();
      await _persistenceQueue;
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(storageKey);
      await preferences.remove(legacyStorageKey);
      await _persistNow();
    } catch (_) {
      // The in-memory demo still provides a usable reset when storage fails.
    } finally {
      _suppressWorkspaceEvents = false;
      notifyListeners();
    }
  }

  /// Waits until all queued library writes have completed.
  Future<void> flush() => _persistenceQueue;

  /// Explicit persistence entry point for callers that want a named save.
  Future<void> save() async {
    _captureActiveWorkspace();
    await _persistNow();
  }

  @override
  void dispose() {
    workspace.removeListener(_handleWorkspaceChanged);
    workspace.dispose();
    super.dispose();
  }

  void _handleWorkspaceChanged() {
    if (_suppressWorkspaceEvents || _isRestoring || _activeId == null) return;
    final id = _activeId;
    final index = _records.indexWhere((record) => record.id == id);
    if (index < 0) return;
    final current = _records[index];
    _records[index] = _recordFromWorkspace(
      id: current.id,
      userName: current.userName,
      source: workspace,
      updatedAt: DateTime.now().toUtc(),
    );
    notifyListeners();
    _schedulePersist();
  }

  void _captureActiveWorkspace() {
    final id = _activeId;
    if (id == null) return;
    final index = _records.indexWhere((record) => record.id == id);
    if (index < 0) return;
    final current = _records[index];
    _records[index] = _recordFromWorkspace(
      id: current.id,
      userName: current.userName,
      source: workspace,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  TimetableRecord? _recordFromLegacySnapshot(String snapshot) {
    final migratedWorkspace = ManualTimetableController.blank();
    if (!migratedWorkspace.importSnapshot(snapshot)) return null;
    return _recordFromWorkspace(
      id: _newRecordId(),
      userName: migratedRecordName,
      source: migratedWorkspace,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  void _seedDemoInMemory() {
    final demo = ManualTimetableController();
    final record = _recordFromWorkspace(
      id: _newRecordId(),
      userName: demoRecordName,
      source: demo,
      updatedAt: DateTime.now().toUtc(),
    );
    _records = <TimetableRecord>[record];
    _activeId = record.id;
  }

  bool _loadLibraryMap(Object? decoded) {
    if (decoded is! Map) return false;
    final map = Map<String, dynamic>.from(decoded);
    if (_intOr(map['version'], 0) != 1 || map['records'] is! List) {
      return false;
    }

    try {
      final parsed = <TimetableRecord>[];
      final ids = <String>{};
      for (final value in map['records'] as List) {
        final record = TimetableRecord.fromJson(value);
        if (!ids.add(record.id)) return false;
        final probe = ManualTimetableController.blank();
        if (!probe.importSnapshot(record.snapshot)) return false;
        parsed.add(
          record.copyWith(
            sessionCount: probe.sessions.length,
            term: probe.semesterLabel,
            status: _statusFor(probe),
          ),
        );
      }
      final requestedActive =
          map['active_id'] as String? ?? map['activeId'] as String?;
      _records = parsed;
      _activeId =
          requestedActive != null &&
              parsed.any((record) => record.id == requestedActive)
          ? requestedActive
          : (parsed.isEmpty ? null : parsed.first.id);
      return true;
    } catch (_) {
      return false;
    }
  }

  void _loadActiveWorkspace() {
    final active = activeRecord;
    if (active == null) {
      _loadWorkspaceSnapshot(
        ManualTimetableController.blank().exportSnapshot(),
      );
      return;
    }
    if (_loadWorkspaceSnapshot(active.snapshot)) return;
    _activeId = null;
    _loadWorkspaceSnapshot(ManualTimetableController.blank().exportSnapshot());
  }

  bool _loadWorkspaceSnapshot(String snapshot) {
    final wasSuppressed = _suppressWorkspaceEvents;
    _suppressWorkspaceEvents = true;
    try {
      return workspace.importSnapshot(snapshot);
    } finally {
      _suppressWorkspaceEvents = wasSuppressed;
    }
  }

  TimetableRecord _recordFromWorkspace({
    required String id,
    required String userName,
    required ManualTimetableController source,
    required DateTime updatedAt,
  }) => TimetableRecord(
    id: id,
    userName: userName,
    term: source.semesterLabel,
    updatedAt: updatedAt.toUtc(),
    status: _statusFor(source),
    sessionCount: source.sessions.length,
    snapshot: source.exportSnapshot(),
  );

  static TimetableRecordStatus _statusFor(ManualTimetableController source) {
    final hasSessions = source.sessions.isNotEmpty;
    final hasGenerated = source.hasGeneratedTimetable;
    if (!hasSessions && !hasGenerated && !source.hasUnsavedChanges) {
      return TimetableRecordStatus.notGenerated;
    }
    if (source.needsRegeneration ||
        (source.generationStatus != null &&
            source.generationStatus != TimetableGenerationStatus.generated) ||
        (source.setupIssues.isNotEmpty && (hasSessions || hasGenerated)) ||
        source.hardConflicts.isNotEmpty ||
        source.softWarnings.isNotEmpty) {
      return TimetableRecordStatus.needsReview;
    }
    if (source.hasLocalValidation && (hasSessions || hasGenerated)) {
      return TimetableRecordStatus.validated;
    }
    return TimetableRecordStatus.draft;
  }

  TimetableRecord? _recordById(String id) {
    for (final record in _records) {
      if (record.id == id) return record;
    }
    return null;
  }

  String _newRecordId() {
    final stamp = DateTime.now().toUtc().microsecondsSinceEpoch;
    var candidate = 'timetable-$stamp';
    while (_records.any((record) => record.id == candidate)) {
      candidate = 'timetable-$stamp-${_nextIdSuffix++}';
    }
    return candidate;
  }

  static String _normaliseName(String? value, String fallback) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? fallback : trimmed;
  }

  Map<String, dynamic> _libraryMap() => <String, dynamic>{
    'version': 1,
    'active_id': _activeId,
    'records': _records.map((record) => record.toJson()).toList(),
  };

  void _schedulePersist() {
    if (_suppressWorkspaceEvents || _isRestoring) return;
    _persistenceQueue = _persistenceQueue.then((_) => _persistNow());
  }

  Future<void> _persistNow() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(storageKey, jsonEncode(_libraryMap()));
    } catch (_) {
      // The in-memory library remains usable when local storage is unavailable.
    }
  }

  static int _intOr(Object? value, int fallback) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? fallback;
}
