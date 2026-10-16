import 'package:flutter/material.dart';

import '../state/manual_timetable_controller.dart';
import '../state/manual_timetable_models.dart' as manual_models;
import '../theme/tokens.dart';
import '../widgets/ui.dart';

/// Workload view for the in-memory manual timetable.
///
/// Every number on this screen is derived from [ManualTimetableController.sessions].
/// The controller currently exposes no faculty mutation API, so the editor
/// accepts optional integration callbacks and gracefully explains that limitation
/// when they are not supplied. If a future controller adds `addFaculty` or
/// `editFaculty`, the small dynamic bridge below uses it without changing this
/// view's public API.
class ManualWorkloadScreen extends StatelessWidget {
  const ManualWorkloadScreen({
    super.key,
    required this.controller,
    this.onAddFaculty,
    this.onEditFaculty,
  });

  final ManualTimetableController controller;
  final ValueChanged<manual_models.ManualFaculty>? onAddFaculty;
  final ValueChanged<manual_models.ManualFaculty>? onEditFaculty;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final workload = _buildWorkload(controller);
        final assignedMinutes = controller.sessions.fold<int>(
          0,
          (total, session) => total + session.durationMinutes,
        );
        final lectureMinutes = controller.sessions
            .where((session) => !_isPractical(controller, session))
            .fold<int>(0, (total, session) => total + session.durationMinutes);
        final practicalMinutes = assignedMinutes - lectureMinutes;
        final overloaded = workload.values.where(
          (entry) =>
              entry.targetMinutes > 0 &&
              entry.totalMinutes > entry.targetMinutes,
        );

        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              SynchroSpacing.gutter,
              SynchroSpacing.lg,
              SynchroSpacing.gutter,
              SynchroSpacing.xxl,
            ),
            children: [
              Text(
                'Faculty workload',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: SynchroSpacing.xs),
              Text(
                'Assigned hours from the current manual draft, split by teaching type.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: SynchroSpacing.md),
              const _WorkloadDemoBanner(),
              const SizedBox(height: SynchroSpacing.lg),
              SectionCard(
                overline: 'Draft totals · no chart projection',
                title: 'Assigned teaching hours',
                trailing: StatusChip(
                  label: '${workload.length}',
                  tone: Tone.neutral,
                  icon: Icons.people_outline,
                ),
                child: Wrap(
                  spacing: SynchroSpacing.lg,
                  runSpacing: SynchroSpacing.md,
                  children: [
                    Stat(
                      value: _hours(assignedMinutes),
                      caption: 'Assigned',
                      tone: Tone.neutral,
                    ),
                    Stat(
                      value: _hours(lectureMinutes),
                      caption: 'Lecture',
                      tone: Tone.good,
                    ),
                    Stat(
                      value: _hours(practicalMinutes),
                      caption: 'Practical',
                      tone: Tone.warn,
                    ),
                    Stat(
                      value: '${overloaded.length}',
                      caption: 'Over target',
                      tone: overloaded.isEmpty ? Tone.good : Tone.bad,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: SynchroSpacing.lg),
              SectionCard(
                overline: 'Targets are faculty max weekly hours',
                title: 'Faculty rows',
                trailing: FilledButton.icon(
                  onPressed: () => _openEditor(context),
                  icon: const Icon(Icons.person_add_alt_1_outlined, size: 17),
                  label: const Text('Add'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(
                      horizontal: SynchroSpacing.md,
                    ),
                    backgroundColor: SynchroColors.orange,
                    foregroundColor: SynchroColors.navyDeep,
                  ),
                ),
                child: workload.isEmpty
                    ? const Text(
                        'No faculty or assigned sessions in this draft.',
                      )
                    : Column(
                        children: [
                          for (
                            var index = 0;
                            index < workload.length;
                            index++
                          ) ...[
                            if (index > 0)
                              const Divider(height: SynchroSpacing.lg),
                            _FacultyWorkloadRow(
                              entry: workload.values.elementAt(index),
                              onEdit: () => _openEditor(
                                context,
                                faculty: workload.values
                                    .elementAt(index)
                                    .faculty,
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    ),
  );

  Future<void> _openEditor(
    BuildContext context, {
    ManualFaculty? faculty,
  }) async {
    final edited = await showModalBottomSheet<ManualFaculty>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(SynchroRadius.sheet),
        ),
      ),
      builder: (_) => _FacultyEditorSheet(faculty: faculty),
    );
    if (!context.mounted || edited == null) return;
    final editing = faculty != null;
    final applied = _callFacultyMethod(controller, edited, editing: editing);
    if (applied) {
      _showMessage(
        context,
        editing
            ? 'Faculty edit applied to the local draft.'
            : 'Faculty added to the local draft.',
      );
      return;
    }
    final callback = editing ? onEditFaculty : onAddFaculty;
    if (callback != null) {
      callback(edited);
      _showMessage(context, 'Faculty editor callback applied locally.');
    } else {
      _showMessage(
        context,
        'Faculty add/edit is not exposed by this controller yet; no data was changed.',
      );
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _WorkloadDemoBanner extends StatelessWidget {
  const _WorkloadDemoBanner();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(
      horizontal: SynchroSpacing.md,
      vertical: SynchroSpacing.sm,
    ),
    decoration: BoxDecoration(
      color: SynchroColors.cream,
      borderRadius: BorderRadius.circular(SynchroRadius.chip),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.science_outlined,
          size: 17,
          color: SynchroColors.navyDeep,
        ),
        const SizedBox(width: SynchroSpacing.sm),
        Expanded(
          child: Text(
            ManualTimetableController.sampleDataLabel,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: SynchroColors.navyDeep),
          ),
        ),
        Text(
          'In memory',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: SynchroColors.navyDeep),
        ),
      ],
    ),
  );
}

class _FacultyWorkloadRow extends StatelessWidget {
  const _FacultyWorkloadRow({required this.entry, required this.onEdit});

  final _WorkloadEntry entry;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final total = entry.totalMinutes;
    final target = entry.targetMinutes;
    final over = target > 0 && total > target;
    final under = target > 0 && total < target;
    final status = over
        ? 'Overloaded by ${_hours(total - target)}'
        : under
        ? 'Underallocated by ${_hours(target - total)}'
        : target == 0
        ? 'No target set'
        : 'At target';
    final tone = over
        ? Tone.bad
        : under
        ? Tone.warn
        : Tone.good;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.faculty.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: SynchroSpacing.xs),
                  Text(
                    entry.faculty.department,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: SynchroSpacing.sm),
            StatusChip(
              label: over
                  ? 'Over'
                  : under
                  ? 'Under'
                  : 'On target',
              tone: tone,
            ),
            IconButton(
              tooltip: 'Edit faculty',
              onPressed: onEdit,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.edit_outlined, size: 19),
            ),
          ],
        ),
        const SizedBox(height: SynchroSpacing.sm),
        Wrap(
          spacing: SynchroSpacing.sm,
          runSpacing: SynchroSpacing.xs,
          children: [
            _MetricTag(label: 'Assigned ${_hours(total)}'),
            _MetricTag(label: 'Target ${_hours(target)}'),
            _MetricTag(label: 'Lecture ${_hours(entry.lectureMinutes)}'),
            _MetricTag(label: 'Practical ${_hours(entry.practicalMinutes)}'),
          ],
        ),
        const SizedBox(height: SynchroSpacing.xs),
        Text(status, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _MetricTag extends StatelessWidget {
  const _MetricTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: SynchroSpacing.sm,
      vertical: SynchroSpacing.xs,
    ),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(SynchroRadius.chip),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Text(label, style: Theme.of(context).textTheme.labelSmall),
  );
}

class _WorkloadEntry {
  _WorkloadEntry({required this.faculty, required this.targetMinutes});

  final manual_models.ManualFaculty faculty;
  final int targetMinutes;
  int lectureMinutes = 0;
  int practicalMinutes = 0;

  int get totalMinutes => lectureMinutes + practicalMinutes;
}

Map<String, _WorkloadEntry> _buildWorkload(
  ManualTimetableController controller,
) {
  final rows = <String, _WorkloadEntry>{
    for (final teacher in controller.faculty)
      teacher.id: _WorkloadEntry(
        faculty: teacher,
        targetMinutes: teacher.maxWeeklyHours * 60,
      ),
  };
  for (final session in controller.sessions) {
    final row = rows.putIfAbsent(
      session.facultyId,
      () => _WorkloadEntry(
        faculty: ManualFaculty(
          id: session.facultyId,
          name: session.facultyId.trim().isEmpty
              ? 'Unassigned faculty'
              : 'Unknown · ${session.facultyId}',
          department: 'Not in faculty list',
          maxWeeklyHours: 0,
        ),
        targetMinutes: 0,
      ),
    );
    if (_isPractical(controller, session)) {
      row.practicalMinutes += session.durationMinutes;
    } else {
      row.lectureMinutes += session.durationMinutes;
    }
  }
  return rows;
}

bool _isPractical(
  ManualTimetableController controller,
  ManualSession session,
) =>
    session.isPractical ||
    controller.subjectById(session.subjectId)?.isPractical == true;

String _hours(int minutes) {
  if (minutes <= 0) return '0h';
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  if (remainder == 0) return '${hours}h';
  return '${hours}h ${remainder}m';
}

bool _callFacultyMethod(
  ManualTimetableController controller,
  ManualFaculty faculty, {
  required bool editing,
}) {
  // The current T1 controller intentionally has no faculty mutation method.
  // Keep the call optional so this view can use one when a host supplies it.
  final dynamic target = controller;
  try {
    // ignore: avoid_dynamic_calls
    final result = editing
        ? target.editFaculty(faculty)
        : target.addFaculty(faculty);
    return result is bool ? result : true;
  } on NoSuchMethodError {
    return false;
  }
}

class _FacultyEditorSheet extends StatefulWidget {
  const _FacultyEditorSheet({this.faculty});

  final ManualFaculty? faculty;

  @override
  State<_FacultyEditorSheet> createState() => _FacultyEditorSheetState();
}

class _FacultyEditorSheetState extends State<_FacultyEditorSheet> {
  late final TextEditingController _name;
  late final TextEditingController _department;
  late final TextEditingController _target;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final faculty = widget.faculty;
    _name = TextEditingController(text: faculty?.name ?? '');
    _department = TextEditingController(
      text: faculty?.department ?? 'Information Technology',
    );
    _target = TextEditingController(text: '${faculty?.maxWeeklyHours ?? 18}');
  }

  @override
  void dispose() {
    _name.dispose();
    _department.dispose();
    _target.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        SynchroSpacing.gutter,
        SynchroSpacing.lg,
        SynchroSpacing.gutter,
        MediaQuery.viewInsetsOf(context).bottom + SynchroSpacing.gutter,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.faculty == null ? 'Add faculty' : 'Edit faculty',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: SynchroSpacing.xs),
            Text(
              'Target hours are used for local workload comparison.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: SynchroSpacing.lg),
            TextFormField(
              controller: _name,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Faculty name',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Enter a name' : null,
            ),
            const SizedBox(height: SynchroSpacing.md),
            TextFormField(
              controller: _department,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Department',
                prefixIcon: Icon(Icons.account_tree_outlined),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a department'
                  : null,
            ),
            const SizedBox(height: SynchroSpacing.md),
            TextFormField(
              controller: _target,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Target weekly hours',
                prefixIcon: Icon(Icons.schedule_outlined),
              ),
              validator: (value) {
                final parsed = int.tryParse(value?.trim() ?? '');
                return parsed == null || parsed < 0
                    ? 'Use zero or a positive whole number'
                    : null;
              },
            ),
            const SizedBox(height: SynchroSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.check),
                label: Text(
                  widget.faculty == null ? 'Add to draft' : 'Apply edit',
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final name = _name.text.trim();
    final existing = widget.faculty;
    Navigator.of(context).pop(
      ManualFaculty(
        id: existing?.id ?? _slug(name),
        name: name,
        department: _department.text.trim(),
        maxWeeklyHours: int.parse(_target.text.trim()),
        absences: existing?.absences ?? const <ManualAbsence>[],
        isProxy: existing?.isProxy ?? false,
      ),
    );
  }
}

String _slug(String value) {
  final slug = value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  return 'faculty-${slug.replaceAll(RegExp(r'^-+|-+$'), '')}';
}
