import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synchro/data/timetable_export.dart';
import 'package:synchro/state/manual_timetable_controller.dart';
import 'package:synchro/state/timetable_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  ManualTimetableController fixture() => ManualTimetableController(
    batches: const [
      ManualBatch(id: 'a', name: 'IT A', year: 1, size: 20, department: 'IT'),
      ManualBatch(id: 'b', name: 'IT B', year: 2, size: 20, department: 'IT'),
      ManualBatch(id: 'c', name: 'CS A', year: 1, size: 20, department: 'CS'),
    ],
    sessions: [
      for (var index = 0; index < 3; index++)
        ManualSession(
          id: 's$index',
          subjectId: 'subject-mathematics',
          facultyId: 'faculty-kavita',
          batchId: ['a', 'b', 'c'][index],
          roomId: 'room-cr-101',
          day: index,
          startMinute: 540,
          endMinute: 590,
        ),
    ],
  );

  test(
    'department includes all batches; master, class and faculty share sessions',
    () {
      final workspace = fixture();
      const department = TimetableViewFilter(
        kind: TimetableViewKind.department,
        department: 'IT',
      );
      const master = TimetableViewFilter(kind: TimetableViewKind.master);
      const batch = TimetableViewFilter(batchId: 'b');
      const teacher = TimetableViewFilter(
        kind: TimetableViewKind.faculty,
        facultyId: 'faculty-kavita',
      );
      expect(department.sessions(workspace).map((s) => s.id), ['s0', 's1']);
      expect(master.sessions(workspace), hasLength(3));
      expect(batch.sessions(workspace).single.id, 's1');
      expect(teacher.sessions(workspace), hasLength(3));
      workspace.editSession('s1', roomId: 'room-cr-102');
      for (final filter in [department, master, batch, teacher]) {
        expect(
          filter.sessions(workspace).firstWhere((s) => s.id == 's1').roomId,
          'room-cr-102',
        );
      }
    },
  );

  test(
    'every scope exports valid filtered XLSX and multi-page-capable PDF',
    () async {
      final workspace = fixture();
      final output = Directory('build/export-validation')
        ..createSync(recursive: true);
      for (final filter in const [
        TimetableViewFilter(
          kind: TimetableViewKind.department,
          department: 'IT',
        ),
        TimetableViewFilter(kind: TimetableViewKind.master),
        TimetableViewFilter(batchId: 'b'),
        TimetableViewFilter(
          kind: TimetableViewKind.faculty,
          facultyId: 'faculty-kavita',
        ),
      ]) {
        final bytes = TimetableExport.excel(workspace, filter);
        expect(bytes.take(2), [0x50, 0x4b]);
        final workbook = Excel.decodeBytes(bytes);
        final sheet = workbook.tables['Schedule']!;
        expect(sheet.maxRows, filter.sessions(workspace).length + 1);
        expect(sheet.rows.first[0]?.value.toString(), 'Day');
        expect(sheet.rows[1][9]?.value.toString(), 'Kavita Nair');
        final pdf = await TimetableExport.pdf(workspace, filter);
        expect(ascii.decode(pdf.take(5).toList()), '%PDF-');
        expect(ascii.decode(pdf.skip(pdf.length - 6).toList()).trim(), '%%EOF');
        final name = TimetableExport.filename(workspace, filter);
        File('${output.path}/$name.xlsx').writeAsBytesSync(bytes);
        File('${output.path}/$name.pdf').writeAsBytesSync(pdf);
      }
    },
  );
}
