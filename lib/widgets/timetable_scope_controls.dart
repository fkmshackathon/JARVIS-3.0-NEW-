import 'package:flutter/material.dart';

import '../data/timetable_export.dart';
import '../state/manual_timetable_controller.dart';
import '../state/timetable_view.dart';
import 'ui.dart';

class TimetableScopeControls extends StatefulWidget {
  const TimetableScopeControls({
    super.key,
    required this.controller,
    required this.onChanged,
  });
  final ManualTimetableController controller;
  final ValueChanged<TimetableViewFilter> onChanged;

  @override
  State<TimetableScopeControls> createState() => _TimetableScopeControlsState();
}

class _TimetableScopeControlsState extends State<TimetableScopeControls> {
  TimetableViewKind _kind = TimetableViewKind.classView;
  String? _department;
  String? _faculty;
  String? _room;
  int? _year;
  int? _day;
  bool _exporting = false;

  TimetableViewFilter get _filter => TimetableViewFilter(
    kind: _kind,
    department: _department,
    batchId: _kind == TimetableViewKind.classView
        ? widget.controller.selectedBatchId
        : null,
    facultyId: _faculty,
    roomId: _room,
    year: _year,
    day: _day,
  );

  void _change(VoidCallback action) {
    setState(action);
    widget.onChanged(_filter);
  }

  @override
  Widget build(BuildContext context) => SectionCard(
    title: 'One schedule · connected views',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final kind in TimetableViewKind.values)
              ChoiceChip(
                label: Text(kind.label),
                selected: kind == _kind,
                onSelected: (_) => _change(() {
                  _kind = kind;
                  _department = null;
                  _faculty = null;
                  _room = null;
                  _year = null;
                  _day = null;
                }),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          widget.controller.semesterLabel,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const Text(
          'Semester belongs to this draft. Switch semesters in My timetables.',
        ),
        const SizedBox(height: 12),
        if (_kind != TimetableViewKind.classView)
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _select<String>('Department', _department, {
                for (final d in TimetableViewFilter.departments(
                  widget.controller,
                ))
                  d: d,
              }, (v) => _change(() => _department = v)),
              _select<String>('Faculty', _faculty, {
                for (final t in widget.controller.faculty) t.id: t.name,
              }, (v) => _change(() => _faculty = v)),
              _select<String>('Room / laboratory', _room, {
                for (final r in widget.controller.rooms) r.id: r.name,
              }, (v) => _change(() => _room = v)),
              _select<int>('Academic year', _year, {
                for (final b in widget.controller.batches)
                  b.year: 'Year ${b.year}',
              }, (v) => _change(() => _year = v)),
              _select<int>('Day', _day, {
                for (final d in widget.controller.workingDays)
                  d: widget.controller.dayName(d),
              }, (v) => _change(() => _day = v)),
            ],
          ),
        const SizedBox(height: 12),
        const Text(
          'Export includes all matching sessions from the current draft, including unsaved edits. Breaks and validation status are included.',
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _exporting
                  ? null
                  : () => _export(TimetableExportFormat.excel),
              icon: const Icon(Icons.table_view_outlined),
              label: const Text('Excel (.xlsx)'),
            ),
            OutlinedButton.icon(
              onPressed: _exporting
                  ? null
                  : () => _export(TimetableExportFormat.pdf),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('PDF (.pdf)'),
            ),
            if (_exporting)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ],
    ),
  );

  Widget _select<T>(
    String label,
    T? value,
    Map<T, String> options,
    ValueChanged<T?> onChanged,
  ) => SizedBox(
    width: 235,
    child: DropdownButtonFormField<T>(
      key: ValueKey('$label:$value:${options.length}'),
      initialValue: options.containsKey(value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        DropdownMenuItem<T>(value: null, child: const Text('All')),
        for (final e in options.entries)
          DropdownMenuItem(
            value: e.key,
            child: Text(e.value, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
    ),
  );

  Future<void> _export(TimetableExportFormat format) async {
    if (_kind == TimetableViewKind.faculty && _faculty == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select one faculty member for a personal timetable.'),
        ),
      );
      return;
    }
    setState(() => _exporting = true);
    try {
      await TimetableExport.download(widget.controller, _filter, format);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Export prepared from the current draft. Your browser or device handles the download.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Export failed. Your timetable is unchanged. Try again or check download permissions.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}
