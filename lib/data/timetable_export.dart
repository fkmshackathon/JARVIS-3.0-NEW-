import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../state/manual_timetable_controller.dart';
import '../state/timetable_view.dart';

enum TimetableExportFormat { excel, pdf }

/// Real OOXML / PDF generation from the selected *current draft*. No backend,
/// hidden saved copy, CSV masquerading as Excel, or external fonts are used.
class TimetableExport {
  static const headers = [
    'Day',
    'Start',
    'End',
    'Department',
    'Term',
    'Year',
    'Batch',
    'Subject code',
    'Subject',
    'Faculty',
    'Room / lab',
    'Type',
  ];

  static List<List<String>> rows(
    ManualTimetableController workspace,
    TimetableViewFilter filter,
  ) => filter
      .sessions(workspace)
      .map((session) {
        final batch = workspace.batchById(session.batchId);
        final subject = workspace.subjectById(session.subjectId);
        return <String>[
          workspace.dayName(session.day),
          timetableClock(session.startMinute),
          timetableClock(session.endMinute),
          batch?.department ?? '',
          workspace.semesterLabel,
          '${batch?.year ?? ''}',
          batch?.name ?? session.batchId,
          subject?.code ?? '',
          subject?.name ?? session.subjectId,
          workspace.facultyById(session.facultyId)?.name ?? session.facultyId,
          workspace.roomById(session.roomId)?.name ?? session.roomId,
          session.type.label,
        ];
      })
      .toList(growable: false);

  static String filename(
    ManualTimetableController workspace,
    TimetableViewFilter filter,
  ) => 'SYNCHRO_${filter.describe(workspace)}'
      .replaceAll(RegExp(r'[^a-zA-Z0-9\u0900-\u097F_-]+'), '_')
      .replaceAll(RegExp('_+'), '_').characters.take(150).toString();

  static Uint8List excel(
    ManualTimetableController workspace,
    TimetableViewFilter filter,
  ) {
    final workbook = Excel.createExcel();
    final schedule = workbook['Schedule'];
    workbook.delete('Sheet1');
    schedule.appendRow(headers.map(TextCellValue.new).toList());
    for (final row in rows(workspace, filter)) {
      schedule.appendRow([
        for (var index = 0; index < row.length; index++)
          if (index == 1 || index == 2)
            TimeCellValue(
              hour: int.parse(row[index].split(':')[0]),
              minute: int.parse(row[index].split(':')[1]),
            )
          else
            TextCellValue(row[index]),
      ]);
    }
    for (var row = 1; row < schedule.maxRows; row++) {
      for (final column in [1, 2]) {
        schedule
            .cell(
              CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row),
            )
            .cellStyle = CellStyle(
          numberFormat: NumFormat.defaultTime,
        );
      }
    }
    for (var column = 0; column < headers.length; column++) {
      schedule.setColumnWidth(column, column == 8 ? 34 : 23);
      schedule
          .cell(CellIndex.indexByColumnRow(columnIndex: column, rowIndex: 0))
          .cellStyle = CellStyle(
        bold: true,
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        backgroundColorHex: ExcelColor.fromHexString('#176B45'),
      );
    }
    final details = workbook['Read me'];
    for (final row in <List<String>>[
      ['SYNCHRO', filter.describe(workspace)],
      ['Institution', workspace.institutionName],
      ['Exported state', 'Current selected draft, including unsaved edits'],
      [
        'Validation',
        '${workspace.hardConflicts.length} hard conflicts; '
            '${workspace.softWarnings.length} warnings',
      ],
      [
        'Break',
        '${timetableClock(workspace.breakStart)}–'
            '${timetableClock(workspace.breakEnd)} ${workspace.breakLabel}',
      ],
      [
        'Scope',
        'All sessions matching the selected filters, not screen pixels',
      ],
    ]) {
      details.appendRow(row.map(TextCellValue.new).toList());
    }
    details.setColumnWidth(0, 24);
    details.setColumnWidth(1, 85);
    final weekly = workbook['Weekly timetable'];
    final selected = filter.sessions(workspace);
    final days = workspace.workingDays
        .where((d) => filter.day == null || filter.day == d)
        .toList();
    weekly.appendRow(
      ['Time', ...days.map(workspace.dayName)].map(TextCellValue.new).toList(),
    );
    final boundaries = {
      workspace.teachingStart,
      workspace.teachingEnd,
      workspace.breakStart,
      workspace.breakEnd,
      for (final s in workspace.timeSlots) ...[s.startMinute, s.endMinute],
      for (final s in selected) ...[s.startMinute, s.endMinute],
    }.toList()..sort();
    String gridCell(int day, int start, int end) {
      if (start < workspace.breakEnd && workspace.breakStart < end) {
        return workspace.breakLabel;
      }
      final classes = selected.where(
        (s) => s.day == day && s.startMinute < end && start < s.endMinute,
      );
      if (classes.isEmpty) return 'Free / no selected sessions';
      return classes
          .map(
            (s) =>
                '${workspace.subjectById(s.subjectId)?.code ?? s.subjectId} · ${workspace.batchById(s.batchId)?.name ?? s.batchId}\n'
                '${workspace.facultyById(s.facultyId)?.name ?? s.facultyId}\n${workspace.roomById(s.roomId)?.name ?? s.roomId} / ${s.type.label}',
          )
          .join('\n\n');
    }

    for (var index = 0; index + 1 < boundaries.length; index++) {
      final start = boundaries[index], end = boundaries[index + 1];
      if (start < workspace.teachingStart || end > workspace.teachingEnd) {
        continue;
      }
      weekly.appendRow([
        TextCellValue('${timetableClock(start)}–${timetableClock(end)}'),
        for (final day in days) TextCellValue(gridCell(day, start, end)),
      ]);
      weekly.setRowHeight(weekly.maxRows - 1, 84);
    }
    for (var column = 0; column <= days.length; column++) {
      weekly.setColumnWidth(column, column == 0 ? 18 : 42);
      for (var row = 0; row < weekly.maxRows; row++) {
        weekly
            .cell(
              CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row),
            )
            .cellStyle = CellStyle(
          textWrapping: TextWrapping.WrapText,
          verticalAlign: VerticalAlign.Top,
          bold: row == 0,
          backgroundColorHex: ExcelColor.fromHexString(
            row == 0 ? '#E7F5E9' : '#FFFFFF',
          ),
        );
      }
    }
    // excel's public API does not expose frozen panes or filters. Add these
    // standard OOXML elements to the generated archive, without changing data.
    final original = ZipDecoder().decodeBytes(workbook.encode()!);
    final output = Archive();
    for (final file in original.files) {
      if (file.name == 'xl/worksheets/sheet1.xml') {
        var xml = utf8.decode(file.content as List<int>);
        xml = xml.replaceFirst(
          RegExp(r'<sheetViews>.*?</sheetViews>', dotAll: true),
          '<sheetViews><sheetView workbookViewId="0"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>',
        );
        xml = xml.replaceFirst(
          '</sheetData>',
          '</sheetData><autoFilter ref="A1:L${schedule.maxRows}"/>',
        );
        final bytes = utf8.encode(xml);
        output.addFile(ArchiveFile(file.name, bytes.length, bytes));
      } else {
        output.addFile(file);
      }
    }
    return Uint8List.fromList(ZipEncoder().encode(output)!);
  }

  static Future<Uint8List> pdf(
    ManualTimetableController workspace,
    TimetableViewFilter filter,
  ) async {
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Bold.ttf'),
    );
    final devanagari = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSansDevanagari-Regular.ttf'),
    );
    final document = pw.Document(
      title: 'SYNCHRO ${filter.kind.label} timetable',
      theme: pw.ThemeData.withFont(
        base: regular,
        bold: bold,
        fontFallback: [devanagari],
      ),
    );
    final data = rows(workspace, filter);
    // Bundled fonts keep names and Devanagari intact without a network fetch.
    String printable(String value) => value;
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        header: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              printable(workspace.institutionName),
              style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(printable(filter.describe(workspace))),
            pw.SizedBox(height: 8),
          ],
        ),
        footer: (context) => pw.Text(
          'Current draft, including unsaved edits | '
          '${workspace.hardConflicts.length} hard conflicts | Page ${context.pageNumber} of ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 8),
        ),
        build: (_) => [
          pw.Text(
            'Mandatory break: ${timetableClock(workspace.breakStart)} - '
            '${timetableClock(workspace.breakEnd)} ${printable(workspace.breakLabel)}',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.SizedBox(height: 8),
          if (data.isEmpty)
            pw.Text('No sessions match these filters.')
          else
            pw.TableHelper.fromTextArray(
              headers: const [
                'Day',
                'Time',
                'Department / class',
                'Subject',
                'Faculty',
                'Room',
                'Type',
              ],
              data: data
                  .map(
                    (r) => [
                      r[0],
                      '${r[1]} - ${r[2]}',
                      '${r[3]}\n${r[6]} / Y${r[5]}',
                      '${r[7]}\n${r[8]}',
                      r[9],
                      r[10],
                      r[11],
                    ].map(printable).toList(),
                  )
                  .toList(),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFF176B45),
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellPadding: const pw.EdgeInsets.all(5),
              columnWidths: {
                0: const pw.FixedColumnWidth(56),
                1: const pw.FixedColumnWidth(68),
              },
            ),
        ],
      ),
    );
    return document.save();
  }

  static Future<void> download(
    ManualTimetableController workspace,
    TimetableViewFilter filter,
    TimetableExportFormat format,
  ) async {
    // Capture the selected draft before fonts/download APIs yield. A later
    // library switch must not mix another timetable into a pending export.
    final captured = ManualTimetableController.blank();
    if (!captured.importSnapshot(workspace.exportSnapshot())) {
      throw const FormatException('Cannot export this draft snapshot.');
    }
    final isPdf = format == TimetableExportFormat.pdf;
    try {
      final bytes = isPdf ? await pdf(captured, filter) : excel(captured, filter);
      await FileSaver.instance.saveFile(
        name: filename(captured, filter), bytes: bytes,
        fileExtension: isPdf ? 'pdf' : 'xlsx',
        mimeType: isPdf ? MimeType.pdf : MimeType.microsoftExcel,
      );
    } finally { captured.dispose(); }
  }
}
