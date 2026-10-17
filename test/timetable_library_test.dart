import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synchro/state/manual_timetable_controller.dart';
import 'package:synchro/state/timetable_library_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('creates independent blank timetables and switches without leakage', () {
    final library = TimetableLibraryController();

    final first = library.createBlank(userName: 'First timetable');
    library.workspace.updateSetup(institution: 'First Institute');
    final second = library.createBlank(userName: 'Second timetable');
    library.workspace.updateSetup(institution: 'Second Institute');

    expect(library.switchTo(first.id), isTrue);
    expect(library.workspace.institutionName, 'First Institute');
    expect(library.switchTo(second.id), isTrue);
    expect(library.workspace.institutionName, 'Second Institute');
    expect(library.records.map((record) => record.id).toSet(), hasLength(2));
  });

  test('manual workspace snapshots round-trip through the public API', () {
    final source = ManualTimetableController.blank();
    source.updateSetup(institution: 'Snapshot Institute');
    final snapshot = source.exportSnapshot();

    final restored = ManualTimetableController.blank();
    expect(restored.importSnapshot(snapshot), isTrue);
    expect(restored.institutionName, 'Snapshot Institute');
    expect(restored.dataLabel, ManualTimetableController.blankDataLabel);
    expect(restored.importSnapshot('{bad json'), isFalse);
    expect(restored.institutionName, 'Snapshot Institute');
  });

  test('duplicates a complete snapshot into an independent record', () {
    final library = TimetableLibraryController();
    final source = library.createBlank(userName: 'Source');
    library.workspace.updateSetup(
      institution: 'Source Institute',
      semester: 'Term One',
    );

    final copy = library.duplicate(source.id);
    expect(copy, isNotNull);
    expect(copy!.id, isNot(source.id));
    expect(copy.userName, 'Source copy');
    expect(library.workspace.institutionName, 'Source Institute');

    library.workspace.updateSetup(institution: 'Copy Institute');
    expect(library.switchTo(source.id), isTrue);
    expect(library.workspace.institutionName, 'Source Institute');
    expect(library.switchTo(copy.id), isTrue);
    expect(library.workspace.institutionName, 'Copy Institute');
  });

  test('renames and deletes only the requested record', () {
    final library = TimetableLibraryController();
    final first = library.createBlank(userName: 'First');
    final second = library.createBlank(userName: 'Second');

    expect(library.rename(first.id, 'Renamed first'), isTrue);
    expect(
      library.records.firstWhere((record) => record.id == first.id).name,
      'Renamed first',
    );
    expect(library.delete(first.id), isTrue);
    expect(library.records.any((record) => record.id == first.id), isFalse);
    expect(library.activeId, second.id);
    expect(library.workspace, isNotNull);
  });

  test(
    'persists records, active id, and workspace edits across reload',
    () async {
      final library = TimetableLibraryController();
      final record = library.createBlank(userName: 'Persisted timetable');
      library.workspace.updateSetup(
        institution: 'Persisted Institute',
        semester: 'Spring 2027',
      );
      await library.flush();

      final reloaded = TimetableLibraryController();
      await reloaded.restore();

      expect(reloaded.activeId, record.id);
      final restored = reloaded.records.firstWhere(
        (item) => item.id == record.id,
      );
      expect(restored.userName, 'Persisted timetable');
      expect(restored.term, 'Spring 2027');
      expect(reloaded.workspace.institutionName, 'Persisted Institute');
    },
  );

  test('derives status and session count from the active workspace', () {
    final library = TimetableLibraryController();
    final demo = library.createBlank(userName: 'Status test');
    expect(library.activeRecord?.status, TimetableRecordStatus.notGenerated);
    expect(library.activeRecord?.sessionCount, 0);

    library.workspace.updateSetup(institution: 'Edited setup');
    expect(library.activeRecord?.status, TimetableRecordStatus.draft);

    expect(library.switchTo(library.records.first.id), isTrue);
    expect(library.activeRecord?.status, isNotNull);
    expect(demo.id, isNotEmpty);
  });

  test('updates record metadata after generation and manual edits', () async {
    final library = TimetableLibraryController();
    await library.restore();
    expect(library.activeRecord?.status, TimetableRecordStatus.notGenerated);

    final result = library.workspace.generateTimetable();
    expect(result.isSuccess, isTrue, reason: result.message);
    expect(
      library.activeRecord?.sessionCount,
      library.workspace.sessions.length,
    );
    expect(
      library.activeRecord?.status,
      anyOf(TimetableRecordStatus.validated, TimetableRecordStatus.needsReview),
    );

    final session = library.workspace.sessions.first;
    expect(
      library.workspace.editSession(session.copyWith(note: 'local edit')),
      isTrue,
    );
    expect(
      library.activeRecord?.sessionCount,
      library.workspace.sessions.length,
    );
    expect(
      library.activeRecord?.status,
      anyOf(TimetableRecordStatus.draft, TimetableRecordStatus.needsReview),
    );
  });

  test(
    'migrates the legacy single workspace into one library record',
    () async {
      final legacy = ManualTimetableController();
      legacy.generateTimetable();
      await legacy.saveDraft();

      final library = TimetableLibraryController();
      await library.restore();

      expect(library.records, hasLength(1));
      expect(library.records.single.userName, 'Migrated local timetable');
      expect(library.records.single.sessionCount, legacy.sessions.length);
      expect(library.workspace.sessions.length, legacy.sessions.length);
    },
  );

  test('deleting the last record leaves an explicit blank workspace', () {
    final library = TimetableLibraryController();
    final record = library.createBlank();

    expect(library.delete(record.id), isTrue);
    expect(library.records, isEmpty);
    expect(library.activeId, isNull);
    expect(library.workspace.sessions, isEmpty);
    expect(library.workspace.faculty, isEmpty);
  });

  test(
    'resetDemo replaces an empty library with a labelled demo record',
    () async {
      final library = TimetableLibraryController();
      final record = library.createBlank(userName: 'Temporary');
      expect(library.delete(record.id), isTrue);
      expect(library.records, isEmpty);

      await library.resetDemo();

      expect(library.records, hasLength(1));
      expect(library.records.single.userName, contains('Demo'));
      expect(library.activeId, library.records.single.id);
      expect(
        library.workspace.dataLabel,
        ManualTimetableController.sampleDataLabel,
      );
    },
  );
}
