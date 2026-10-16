import 'package:flutter/foundation.dart' show ChangeNotifier;

import '../data/models.dart';
import '../data/synchro_api.dart';

/// One screen's worth of state: is the backend up, is the campus loaded, has a
/// timetable been produced, and what did the independent validator say about it.
enum LinkPhase { idle, connecting, ready, offline }

enum RunPhase { none, running, done }

/// Owns the campus, the generated timetable and the calls to the solver API.
///
/// The client never computes a schedule and never decides whether one is valid:
/// `publishable` is read straight off the server's validator response.
class SchedulingController extends ChangeNotifier {
  SchedulingController({SynchroApi? api}) : api = api ?? SynchroApi();

  final SynchroApi api;

  LinkPhase phase = LinkPhase.idle;
  String? linkError;

  Campus? campus;
  Summary? summary;
  String? previewBlocker;

  RunPhase runPhase = RunPhase.none;
  String? runError;
  GenerationResult? result;
  List<RunRecord> history = const [];

  /// Which batch the grid is showing.
  String? batchId;

  double timeLimitSeconds = 10;
  int randomSeed = 1;

  bool get hasCampus => campus != null;
  bool get canGenerate => summary?.canGenerate ?? false;

  String get backendUrl => api.baseUrl;

  /// The timetable the grid draws, filtered to the batch in focus.
  List<Assignment> get visibleAssignments {
    final all = result?.assignments ?? const <Assignment>[];
    if (batchId == null || all.isEmpty) return const [];
    return all.where((a) => a.batchId == batchId).toList();
  }

  Future<void> connect() async {
    phase = LinkPhase.connecting;
    linkError = null;
    notifyListeners();
    try {
      await api.health();
      phase = LinkPhase.ready;
    } on ApiException catch (e) {
      phase = LinkPhase.offline;
      linkError = e.message;
    }
    notifyListeners();
  }

  /// Loads the seeded campus and immediately registers it server-side, so the
  /// solver and the validator are both working from the same definition.
  Future<void> loadDemoCampus() async {
    phase = LinkPhase.connecting;
    linkError = null;
    notifyListeners();
    try {
      final sample = await api.sampleCampus();
      final saved = await api.saveCampus(SynchroApi.demoCampusId, sample.name, sample.campus);
      campus = Campus.fromPayload(sample.name, jsonMap(saved['campus']));
      summary = Summary(jsonMap(saved['summary']));
      batchId = campus!.batches.isEmpty ? null : campus!.batches.first.id;
      phase = LinkPhase.ready;
      await _preview();
    } on ApiException catch (e) {
      phase = LinkPhase.offline;
      linkError = e.message;
    }
    notifyListeners();
  }

  Future<void> _preview() async {
    final id = SynchroApi.demoCampusId;
    try {
      final body = await api.preview(id);
      previewBlocker = body['blocker'] as String?;
      final s = body['summary'];
      if (s is Map) summary = Summary(jsonMap(s));
    } on ApiException catch (e) {
      runError = e.message;
    }
  }

  Future<void> generate() async {
    if (campus == null) return;
    runPhase = RunPhase.running;
    runError = null;
    notifyListeners();
    try {
      final body = await api.generate(
        SynchroApi.demoCampusId,
        timeLimitSeconds: timeLimitSeconds,
        randomSeed: randomSeed,
      );
      result = GenerationResult.fromMap(body);
      if (batchId == null && result!.assignments.isNotEmpty) {
        batchId = result!.assignments.first.batchId;
      }
      runPhase = RunPhase.done;
    } on ApiException catch (e) {
      runError = e.message;
      runPhase = RunPhase.none;
      phase = e.isTransport ? LinkPhase.offline : phase;
    }
    notifyListeners();
  }

  /// Hands the current timetable back to the validator. A coordinator editing a
  /// slot locally must get the server's answer, not a local optimistic one.
  Future<void> revalidate() async {
    final current = result;
    if (current == null || current.assignments.isEmpty) return;
    runError = null;
    notifyListeners();
    try {
      final body = await api.validate(
        SynchroApi.demoCampusId,
        current.assignments.map((a) => a.toMap()).toList(),
      );
      result = GenerationResult(
        runId: current.runId,
        status: current.status,
        solverStatus: current.solverStatus,
        softCost: current.softCost,
        wallTimeMs: current.wallTimeMs,
        message: current.message,
        assignments: current.assignments,
        violations: jsonMapList(body['violations']).map(Violation.fromMap).toList(),
        publishable: body['publishable'] as bool? ?? false,
        utilisation: Utilisation.fromMap(body['utilisation']),
      );
      runPhase = RunPhase.done;
    } on ApiException catch (e) {
      runError = e.message;
    }
    notifyListeners();
  }

  Future<void> loadHistory() async {
    try {
      final rows = await api.runs(SynchroApi.demoCampusId);
      history = rows.map(RunRecord.fromMap).toList();
    } on ApiException catch (e) {
      runError = e.message;
    }
    notifyListeners();
  }

  void selectBatch(String id) {
    batchId = id;
    notifyListeners();
  }

  void setTimeLimit(double seconds) {
    timeLimitSeconds = seconds;
    notifyListeners();
  }

  void setSeed(int seed) {
    randomSeed = seed.clamp(1, 10000);
    notifyListeners();
  }

  @override
  void dispose() {
    api.close();
    super.dispose();
  }
}
