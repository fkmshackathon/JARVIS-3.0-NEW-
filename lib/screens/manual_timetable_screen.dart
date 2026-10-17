import 'package:flutter/material.dart';

import '../state/manual_timetable_controller.dart';
import '../state/timetable_view.dart';
import '../theme/tokens.dart';
import '../widgets/timetable_scope_controls.dart';
import '../widgets/ui.dart';

String _formatClock(int minutes) {
  final hour = minutes ~/ 60;
  final minute = minutes % 60;
  final suffix = hour >= 12 ? 'PM' : 'AM';
  final displayHour = hour % 12 == 0 ? 12 : hour % 12;
  return '$displayHour:${minute.toString().padLeft(2, '0')} $suffix';
}

/// Phone-first editor for the timetable produced by the deterministic local
/// generator. It remains useful for post-generation corrections and review.
///
/// It never calls the backend or stores credentials.
class ManualTimetableScreen extends StatefulWidget {
  const ManualTimetableScreen({
    super.key,
    required this.controller,
    this.onOpenWorkload,
    this.onOpenRooms,
    this.onHandleChange,
    this.onOpenIssues,
    this.onWorkload,
    this.onRooms,
    this.onIssues,
  });

  final ManualTimetableController controller;
  final VoidCallback? onOpenWorkload;
  final VoidCallback? onOpenRooms;
  final VoidCallback? onHandleChange;
  final VoidCallback? onOpenIssues;
  final VoidCallback? onWorkload;
  final VoidCallback? onRooms;
  final VoidCallback? onIssues;

  @override
  State<ManualTimetableScreen> createState() => _ManualTimetableScreenState();
}

class _ManualTimetableScreenState extends State<ManualTimetableScreen> {
  ManualTimetableController get controller => widget.controller;
  TimetableViewFilter _filter = const TimetableViewFilter();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: ListenableBuilder(
      listenable: controller,
      builder: (context, _) => SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => ListView(
            padding: const EdgeInsets.fromLTRB(
              SynchroSpacing.gutter,
              SynchroSpacing.lg,
              SynchroSpacing.gutter,
              SynchroSpacing.xxl,
            ),
            children: [
              _ManualHeader(controller: controller),
              const SizedBox(height: SynchroSpacing.lg),
              TimetableScopeControls(
                controller: controller,
                onChanged: (filter) => setState(() => _filter = filter),
              ),
              const SizedBox(height: SynchroSpacing.lg),
              if (_filter.kind == TimetableViewKind.classView)
                _ManualControls(
                  controller: controller,
                  onAdd: () => _openEditor(),
                ),
              const SizedBox(height: SynchroSpacing.md),
              _DraftActions(controller: controller, onReset: _resetDemo),
              const SizedBox(height: SynchroSpacing.lg),
              _ContextActions(
                onOpenWorkload: widget.onOpenWorkload ?? widget.onWorkload,
                onOpenRooms: widget.onOpenRooms ?? widget.onRooms,
                onHandleChange: widget.onHandleChange,
                onOpenIssues: widget.onOpenIssues ?? widget.onIssues,
              ),
              if (controller.hardConflicts.isNotEmpty ||
                  controller.softWarnings.isNotEmpty) ...[
                const SizedBox(height: SynchroSpacing.lg),
                _IssuesCard(controller: controller),
              ],
              const SizedBox(height: SynchroSpacing.lg),
              if (_filter.kind != TimetableViewKind.classView)
                _ScopeSchedule(
                  controller: controller,
                  filter: _filter,
                  onOpen: _openDetails,
                )
              else if (constraints.maxWidth >= 900)
                _DesktopWeekGrid(
                  controller: controller,
                  onAdd: (day, start, end) =>
                      _openEditor(day: day, start: start, end: end),
                  onOpen: _openDetails,
                )
              else if (controller.showWeek)
                _WeekTimeline(
                  controller: controller,
                  onAdd: (day, start, end) =>
                      _openEditor(day: day, start: start, end: end),
                  onOpen: _openDetails,
                )
              else
                _DayTimeline(
                  controller: controller,
                  onAdd: (day, start, end) =>
                      _openEditor(day: day, start: start, end: end),
                  onOpen: _openDetails,
                ),
              if (constraints.maxWidth > 600) ...[
                const SizedBox(height: SynchroSpacing.lg),
                Text(
                  'The manual editor is designed for a focused phone-width timeline; week view stacks days to keep each class readable.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _openEditor(),
      backgroundColor: SynchroColors.orange,
      foregroundColor: SynchroColors.navyDeep,
      icon: const Icon(Icons.add),
      label: const Text('Add class'),
    ),
  );

  Future<void> _openEditor({
    ManualSession? session,
    int? day,
    int? start,
    int? end,
    bool moveOnly = false,
  }) async {
    final result = await showModalBottomSheet<ManualSession>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(SynchroRadius.sheet),
        ),
      ),
      builder: (sheetContext) => _SessionEditorSheet(
        controller: controller,
        session: session,
        presetDay: day,
        presetStart: start,
        presetEnd: end,
        moveOnly: moveOnly,
      ),
    );
    if (!mounted || result == null) return;
    if (session == null) {
      controller.addSession(result);
    } else {
      controller.editSession(result);
    }
  }

  Future<void> _openDetails(ManualSession session) async {
    final action = await showModalBottomSheet<_SessionAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(SynchroRadius.sheet),
        ),
      ),
      builder: (sheetContext) =>
          _SessionDetailsSheet(controller: controller, session: session),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _SessionAction.edit:
        await _openEditor(session: session);
      case _SessionAction.move:
        await _openEditor(session: session, moveOnly: true);
      case _SessionAction.delete:
        await _confirmDelete(session);
    }
  }

  Future<void> _confirmDelete(ManualSession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete class?'),
        content: Text(
          'Remove ${_subjectName(controller, session.subjectId)} from this local draft?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: SynchroColors.danger,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) controller.deleteSession(session.id);
  }

  Future<void> _resetDemo() async {
    if (!controller.hasUnsavedChanges) {
      await controller.resetDemo();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset demo data?'),
        content: const Text(
          'This clears the current local draft and restores the deterministic sample timetable.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep draft'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Reset demo'),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.resetDemo();
  }
}

class _ScopeSchedule extends StatelessWidget {
  const _ScopeSchedule({
    required this.controller,
    required this.filter,
    required this.onOpen,
  });
  final ManualTimetableController controller;
  final TimetableViewFilter filter;
  final ValueChanged<ManualSession> onOpen;

  @override
  Widget build(BuildContext context) {
    final sessions = filter.sessions(controller);
    return SectionCard(
      title: '${filter.kind.label} timetable · ${sessions.length} sessions',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (sessions.isEmpty)
            const Text(
              'No sessions match these filters. Generate a timetable or choose a different scope.',
            ),
          for (final day in controller.workingDays)
            if (filter.day == null || filter.day == day) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  controller.dayName(day),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                '${_formatClock(controller.breakStart)}–${_formatClock(controller.breakEnd)} · ${controller.breakLabel}',
              ),
              for (final session in sessions.where((s) => s.day == day))
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    isThreeLine: true,
                    title: Text(
                      '${_formatClock(session.startMinute)}–${_formatClock(session.endMinute)} · ${controller.subjectById(session.subjectId)?.name ?? session.subjectId}',
                    ),
                    subtitle: Text(
                      '${controller.batchById(session.batchId)?.name ?? session.batchId} · ${controller.facultyById(session.facultyId)?.name ?? session.facultyId}\n${controller.roomById(session.roomId)?.name ?? session.roomId} · ${session.type.label}',
                    ),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: () => onOpen(session),
                  ),
                ),
            ],
        ],
      ),
    );
  }
}

class _ManualHeader extends StatelessWidget {
  const _ManualHeader({required this.controller});

  final ManualTimetableController controller;

  @override
  Widget build(BuildContext context) => Column(
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
                  'Generated timetable',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: SynchroSpacing.xs),
                Text(
                  'Inspect, edit, and revalidate the local schedule.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          StatusChip(
            label: controller.isRestoring
                ? 'Restoring'
                : !controller.hasGeneratedTimetable
                ? 'Not generated'
                : controller.generationStatus ==
                      TimetableGenerationStatus.infeasible
                ? 'Partial result'
                : controller.hasLocalValidation
                ? (controller.hardConflicts.isEmpty
                      ? 'Locally checked'
                      : 'Needs fixes')
                : controller.hasUnsavedChanges
                ? 'Draft'
                : 'Not checked',
            tone:
                controller.isRestoring ||
                    (controller.hasUnsavedChanges &&
                        !controller.hasLocalValidation)
                ? Tone.warn
                : controller.generationStatus ==
                      TimetableGenerationStatus.infeasible
                ? Tone.bad
                : controller.hasLocalValidation &&
                      controller.hardConflicts.isEmpty
                ? Tone.good
                : Tone.neutral,
            icon:
                controller.hasLocalValidation &&
                    controller.hardConflicts.isEmpty
                ? Icons.check_circle_outline
                : Icons.edit_outlined,
          ),
        ],
      ),
      const SizedBox(height: SynchroSpacing.md),
      Container(
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
                controller.hasGeneratedTimetable
                    ? controller.dataLabel
                    : 'NO TIMETABLE GENERATED',
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: SynchroColors.navyDeep),
              ),
            ),
            Flexible(
              child: Text(
                'Local generator',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: SynchroColors.navyDeep),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _ManualControls extends StatelessWidget {
  const _ManualControls({required this.controller, required this.onAdd});

  final ManualTimetableController controller;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => SectionCard(
    overline: 'Timetable focus',
    title: controller.showWeek
        ? 'Weekly overview'
        : controller.dayName(controller.selectedDay),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          initialValue:
              controller.batches.any(
                (batch) => batch.id == controller.selectedBatchId,
              )
              ? controller.selectedBatchId
              : null,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Batch',
            prefixIcon: Icon(Icons.groups_outlined),
          ),
          items: [
            for (final batch in controller.batches)
              DropdownMenuItem<String>(
                value: batch.id,
                child: Text(batch.name),
              ),
          ],
          onChanged: (value) {
            if (value != null) controller.selectBatch(value);
          },
        ),
        const SizedBox(height: SynchroSpacing.md),
        if (!controller.showWeek) ...[
          Text('Day', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: SynchroSpacing.sm),
          _DaySelector(controller: controller),
          const SizedBox(height: SynchroSpacing.md),
        ],
        Row(
          children: [
            Expanded(
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment<bool>(
                    value: false,
                    label: Text('Day'),
                    icon: Icon(Icons.view_agenda_outlined),
                  ),
                  ButtonSegment<bool>(
                    value: true,
                    label: Text('Week'),
                    icon: Icon(Icons.view_list_outlined),
                  ),
                ],
                selected: {controller.showWeek},
                showSelectedIcon: false,
                onSelectionChanged: (selection) {
                  if (selection.isNotEmpty) {
                    controller.setShowWeek(selection.first);
                  }
                },
              ),
            ),
            const SizedBox(width: SynchroSpacing.sm),
            FilledButton.icon(
              onPressed: onAdd,
              style: FilledButton.styleFrom(
                backgroundColor: SynchroColors.orange,
                foregroundColor: SynchroColors.navyDeep,
                padding: const EdgeInsets.symmetric(
                  horizontal: SynchroSpacing.md,
                ),
              ),
              icon: const Icon(Icons.add, size: 19),
              label: const Text('Add class'),
            ),
          ],
        ),
      ],
    ),
  );
}

class _DaySelector extends StatelessWidget {
  const _DaySelector({required this.controller});

  final ManualTimetableController controller;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (
          var day = 0;
          day < ManualTimetableController.dayNames.length;
          day++
        )
          Padding(
            padding: EdgeInsets.only(
              right: day == ManualTimetableController.dayNames.length - 1
                  ? 0
                  : SynchroSpacing.sm,
            ),
            child: ChoiceChip(
              label: Text(_shortDay(controller.dayName(day))),
              selected: controller.selectedDay == day,
              onSelected: (_) => controller.selectDay(day),
            ),
          ),
      ],
    ),
  );
}

class _DraftActions extends StatelessWidget {
  const _DraftActions({required this.controller, required this.onReset});

  final ManualTimetableController controller;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: SynchroSpacing.sm,
    runSpacing: SynchroSpacing.sm,
    children: [
      FilledButton.icon(
        onPressed: controller.hasUnsavedChanges
            ? () => controller.saveDraft()
            : null,
        icon: const Icon(Icons.save_outlined, size: 18),
        label: const Text('Save draft'),
      ),
      OutlinedButton.icon(
        onPressed: controller.hasUnsavedChanges
            ? controller.discardDraft
            : null,
        icon: const Icon(Icons.undo_outlined, size: 18),
        label: const Text('Discard'),
      ),
      OutlinedButton.icon(
        onPressed: controller.validate,
        icon: const Icon(Icons.fact_check_outlined, size: 18),
        label: const Text('Check draft'),
      ),
      OutlinedButton.icon(
        onPressed: controller.loadConflictDemo,
        icon: const Icon(Icons.warning_amber_outlined, size: 18),
        label: const Text('Load conflict sample'),
      ),
      OutlinedButton.icon(
        onPressed: onReset,
        icon: const Icon(Icons.restart_alt, size: 18),
        label: const Text('Reset demo'),
      ),
    ],
  );
}

class _ContextActions extends StatelessWidget {
  const _ContextActions({
    this.onOpenWorkload,
    this.onOpenRooms,
    this.onHandleChange,
    this.onOpenIssues,
  });

  final VoidCallback? onOpenWorkload;
  final VoidCallback? onOpenRooms;
  final VoidCallback? onHandleChange;
  final VoidCallback? onOpenIssues;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Quick actions', style: Theme.of(context).textTheme.labelSmall),
      const SizedBox(height: SynchroSpacing.sm),
      Wrap(
        spacing: SynchroSpacing.sm,
        runSpacing: SynchroSpacing.sm,
        children: [
          OutlinedButton.icon(
            onPressed: onOpenWorkload,
            icon: const Icon(Icons.bar_chart_outlined, size: 18),
            label: const Text('Workload'),
          ),
          OutlinedButton.icon(
            onPressed: onOpenRooms,
            icon: const Icon(Icons.meeting_room_outlined, size: 18),
            label: const Text('Rooms'),
          ),
          OutlinedButton.icon(
            onPressed: onHandleChange,
            icon: const Icon(Icons.sync_alt_outlined, size: 18),
            label: const Text('Handle a change'),
          ),
          OutlinedButton.icon(
            onPressed: onOpenIssues,
            icon: const Icon(Icons.rule_folder_outlined, size: 18),
            label: const Text('Issues'),
          ),
        ],
      ),
    ],
  );
}

class _IssuesCard extends StatelessWidget {
  const _IssuesCard({required this.controller});

  final ManualTimetableController controller;

  @override
  Widget build(BuildContext context) {
    final hard = controller.hardConflicts;
    final soft = controller.softWarnings;
    return SectionCard(
      overline: 'Local checks · after every edit',
      title: hard.isEmpty
          ? '${soft.length} soft warning${soft.length == 1 ? '' : 's'}'
          : '${hard.length} hard conflict${hard.length == 1 ? '' : 's'}',
      trailing: StatusChip(
        label: hard.isEmpty ? 'Review' : 'Fix',
        tone: hard.isEmpty ? Tone.warn : Tone.bad,
        icon: hard.isEmpty ? Icons.info_outline : Icons.error_outline,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final issue in [...hard, ...soft])
            Padding(
              padding: const EdgeInsets.only(bottom: SynchroSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    issue.isHard
                        ? Icons.error_outline
                        : Icons.warning_amber_outlined,
                    size: 18,
                    color: issue.isHard
                        ? StatusChip.color(
                            Tone.bad,
                            Theme.of(context).brightness,
                          )
                        : StatusChip.color(
                            Tone.warn,
                            Theme.of(context).brightness,
                          ),
                  ),
                  const SizedBox(width: SynchroSpacing.sm),
                  Expanded(
                    child: Text(
                      issue.message,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          if (hard.isEmpty && soft.isNotEmpty)
            Text(
              'Soft warnings are suggestions; they do not block this local draft.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}

class _DayTimeline extends StatelessWidget {
  const _DayTimeline({
    required this.controller,
    required this.onAdd,
    required this.onOpen,
  });

  final ManualTimetableController controller;
  final void Function(int day, int start, int end) onAdd;
  final ValueChanged<ManualSession> onOpen;

  @override
  Widget build(BuildContext context) {
    final sessions = controller.selectedDaySessions;
    return SectionCard(
      overline: 'Readable day view',
      title: controller.dayName(controller.selectedDay),
      trailing: Text(
        '${sessions.length} ${sessions.length == 1 ? 'class' : 'classes'}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      child: _TimelineRows(
        controller: controller,
        day: controller.selectedDay,
        batchId: controller.selectedBatchId,
        onAdd: onAdd,
        onOpen: onOpen,
      ),
    );
  }
}

class _DesktopWeekGrid extends StatelessWidget {
  const _DesktopWeekGrid({
    required this.controller,
    required this.onAdd,
    required this.onOpen,
  });

  final ManualTimetableController controller;
  final void Function(int day, int start, int end) onAdd;
  final ValueChanged<ManualSession> onOpen;

  @override
  Widget build(BuildContext context) {
    final days = controller.workingDays;
    final starts = {
      for (final slot in controller.timeSlots) slot.startMinute,
      for (final session in controller.sessionsFor(
        batchId: controller.selectedBatchId,
      ))
        session.startMinute,
    }.toList()..sort();
    final sessions = <String, ManualSession>{
      for (final session in controller.sessionsFor(
        batchId: controller.selectedBatchId,
      ))
        for (final start in starts)
          if (session.startMinute <= start && start < session.endMinute)
            '${session.day}:$start': session,
    };

    return SectionCard(
      overline: 'Desktop weekly grid',
      title: '${controller.selectedBatch?.name ?? 'Selected batch'} · Week',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          defaultColumnWidth: const FixedColumnWidth(150),
          columnWidths: const <int, TableColumnWidth>{0: FixedColumnWidth(82)},
          border: TableBorder.all(
            color: SynchroColors.hairline,
            borderRadius: BorderRadius.all(Radius.circular(SynchroRadius.chip)),
          ),
          children: [
            TableRow(
              decoration: const BoxDecoration(color: SynchroColors.cream),
              children: [
                const _GridHeaderCell('Time'),
                for (final day in days)
                  _GridHeaderCell(controller.dayName(day)),
              ],
            ),
            for (final start in starts)
              TableRow(
                children: [
                  _GridTimeCell(start),
                  for (final day in days)
                    _DesktopGridCell(
                      slot: _slotAt(controller, day, start),
                      session: sessions['$day:$start'],
                      controller: controller,
                      onAdd: onAdd,
                      onOpen: onOpen,
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

ManualTimeSlot? _slotAt(
  ManualTimetableController controller,
  int day,
  int start,
) {
  for (final slot in controller.timeSlots) {
    if (slot.day == day && slot.startMinute == start) return slot;
  }
  return null;
}

class _GridHeaderCell extends StatelessWidget {
  const _GridHeaderCell(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(SynchroSpacing.sm),
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelSmall
          ?.copyWith(fontWeight: FontWeight.w700),
    ),
  );
}

class _GridTimeCell extends StatelessWidget {
  const _GridTimeCell(this.start);

  final int start;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 86,
    child: Padding(
      padding: const EdgeInsets.all(SynchroSpacing.sm),
      child: Text(
        _formatClock(start),
        style: Theme.of(context).textTheme.labelSmall,
      ),
    ),
  );
}

class _DesktopGridCell extends StatelessWidget {
  const _DesktopGridCell({
    required this.slot,
    required this.session,
    required this.controller,
    required this.onAdd,
    required this.onOpen,
  });

  final ManualTimeSlot? slot;
  final ManualSession? session;
  final ManualTimetableController controller;
  final void Function(int day, int start, int end) onAdd;
  final ValueChanged<ManualSession> onOpen;

  @override
  Widget build(BuildContext context) {
    if (slot == null && session == null) return const SizedBox(height: 140);
    if (slot?.isBreak == true) {
      return Container(
        height: 140,
        color: SynchroColors.cream,
        alignment: Alignment.center,
        child: Text(
          slot!.label ?? 'Break',
          style: Theme.of(context).textTheme.labelSmall,
        ),
      );
    }
    if (session == null) {
      return SizedBox(
        height: 140,
        child: InkWell(
          onTap: () => onAdd(slot!.day, slot!.startMinute, slot!.endMinute),
          child: Center(
            child: Text('Open', style: Theme.of(context).textTheme.labelSmall),
          ),
        ),
      );
    }
    final current = session!;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: InkWell(
        onTap: () => onOpen(current),
        child: Container(
          constraints: const BoxConstraints(minHeight: 140),
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                controller.subjectById(current.subjectId)?.code ??
                    current.subjectId,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              Text(
                controller.facultyById(current.facultyId)?.name ??
                    current.facultyId,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                controller.roomById(current.roomId)?.name ?? current.roomId,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                current.type.label,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeekTimeline extends StatelessWidget {
  const _WeekTimeline({
    required this.controller,
    required this.onAdd,
    required this.onOpen,
  });

  final ManualTimetableController controller;
  final void Function(int day, int start, int end) onAdd;
  final ValueChanged<ManualSession> onOpen;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Stacked week · one day at a time',
        style: Theme.of(context).textTheme.labelSmall,
      ),
      const SizedBox(height: SynchroSpacing.sm),
      for (
        var day = 0;
        day < ManualTimetableController.dayNames.length;
        day++
      ) ...[
        if (day > 0) const SizedBox(height: SynchroSpacing.md),
        SectionCard(
          overline: 'Day ${day + 1}',
          title: controller.dayName(day),
          trailing: Text(
            '${controller.sessionsFor(batchId: controller.selectedBatchId, day: day).length} classes',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          child: _TimelineRows(
            controller: controller,
            day: day,
            batchId: controller.selectedBatchId,
            onAdd: onAdd,
            onOpen: onOpen,
            compact: true,
          ),
        ),
      ],
    ],
  );
}

class _TimelineRows extends StatelessWidget {
  const _TimelineRows({
    required this.controller,
    required this.day,
    required this.batchId,
    required this.onAdd,
    required this.onOpen,
    this.compact = false,
  });

  final ManualTimetableController controller;
  final int day;
  final String batchId;
  final void Function(int day, int start, int end) onAdd;
  final ValueChanged<ManualSession> onOpen;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final sessions = controller.sessionsFor(batchId: batchId, day: day);
    final starts = <int, ManualSession>{
      for (final session in sessions) session.startMinute: session,
    };
    final covered = <int>{};
    for (final session in sessions) {
      for (final slot in controller.timeSlots.where(
        (slot) =>
            slot.day == day &&
            !slot.isBreak &&
            slot.startMinute >= session.startMinute &&
            slot.startMinute < session.endMinute,
      )) {
        if (slot.startMinute != session.startMinute) {
          covered.add(slot.startMinute);
        }
      }
    }
    final slots = controller.timeSlots
        .where((slot) => slot.day == day)
        .toList();
    if (slots.isEmpty) {
      return Text(
        'No teaching slots are defined for this day.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    return Column(
      children: [
        for (final slot in slots)
          if (slot.isBreak)
            _BreakSlot(slot: slot, compact: compact)
          else if (!covered.contains(slot.startMinute))
            _ManualSlotRow(
              slot: slot,
              session: starts[slot.startMinute],
              controller: controller,
              onAdd: () => onAdd(day, slot.startMinute, slot.endMinute),
              onOpen: onOpen,
              compact: compact,
            ),
        ...[
          for (final session in sessions)
            if (!slots.any((slot) => slot.startMinute == session.startMinute))
              Padding(
                padding: const EdgeInsets.only(top: SynchroSpacing.sm),
                child: _ManualSessionCard(
                  session: session,
                  controller: controller,
                  onTap: () => onOpen(session),
                  compact: compact,
                ),
              ),
        ],
      ],
    );
  }
}

class _ManualSlotRow extends StatelessWidget {
  const _ManualSlotRow({
    required this.slot,
    required this.session,
    required this.controller,
    required this.onAdd,
    required this.onOpen,
    required this.compact,
  });

  final ManualTimeSlot slot;
  final ManualSession? session;
  final ManualTimetableController controller;
  final VoidCallback onAdd;
  final ValueChanged<ManualSession> onOpen;
  final bool compact;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: SynchroSpacing.sm),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: compact ? 54 : 58,
          child: Padding(
            padding: const EdgeInsets.only(top: SynchroSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${slot.startMinute ~/ 60}:${(slot.startMinute % 60).toString().padLeft(2, '0')}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  '${slot.endMinute ~/ 60}:${(slot.endMinute % 60).toString().padLeft(2, '0')}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: SynchroSpacing.sm),
        Expanded(
          child: session == null
              ? _FreeSlot(slot: slot, onTap: onAdd)
              : _ManualSessionCard(
                  session: session!,
                  controller: controller,
                  onTap: () => onOpen(session!),
                  compact: compact,
                ),
        ),
      ],
    ),
  );
}

class _FreeSlot extends StatelessWidget {
  const _FreeSlot({required this.slot, required this.onTap});

  final ManualTimeSlot slot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(SynchroRadius.chip),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SynchroRadius.chip),
        child: Container(
          constraints: const BoxConstraints(minHeight: 68),
          padding: const EdgeInsets.all(SynchroSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SynchroRadius.chip),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(Icons.add_circle_outline, color: theme.colorScheme.primary),
              const SizedBox(width: SynchroSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('FREE SLOT', style: theme.textTheme.labelMedium),
                    Text(
                      'Tap to add a class',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _BreakSlot extends StatelessWidget {
  const _BreakSlot({required this.slot, required this.compact});

  final ManualTimeSlot slot;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = StatusChip.color(Tone.warn, theme.brightness);
    return Padding(
      padding: const EdgeInsets.only(bottom: SynchroSpacing.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: SynchroSpacing.md,
          vertical: SynchroSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: tone.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(SynchroRadius.chip),
          border: Border.all(color: tone.withValues(alpha: 0.24)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.free_breakfast_outlined,
              size: compact ? 17 : 19,
              color: tone,
            ),
            const SizedBox(width: SynchroSpacing.sm),
            Expanded(
              child: Text(
                '${slot.label ?? 'Break'} · ${_time(slot.startMinute)}–${_time(slot.endMinute)}',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: tone),
              ),
            ),
            Text(
              'BREAK',
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: tone),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManualSessionCard extends StatelessWidget {
  const _ManualSessionCard({
    required this.session,
    required this.controller,
    required this.onTap,
    required this.compact,
  });

  final ManualSession session;
  final ManualTimetableController controller;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subject = controller.subjectById(session.subjectId);
    final faculty = controller.facultyById(session.facultyId);
    final room = controller.roomById(session.roomId);
    final practical = session.isPractical || subject?.isPractical == true;
    final accent = practical
        ? SynchroColors.orangeDeep
        : theme.colorScheme.primary;
    return Semantics(
      button: true,
      label:
          '${subject?.name ?? 'Missing subject'} · ${_time(session.startMinute)}',
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(SynchroRadius.chip),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(SynchroRadius.chip),
          child: Container(
            constraints: BoxConstraints(minHeight: compact ? 82 : 98),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(SynchroRadius.chip),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(SynchroRadius.chip),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(SynchroSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  subject?.name ?? 'Missing subject',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall,
                                ),
                              ),
                              const SizedBox(width: SynchroSpacing.sm),
                              _TypePill(
                                label: practical ? 'LAB' : 'LECTURE',
                                color: accent,
                              ),
                            ],
                          ),
                          const SizedBox(height: SynchroSpacing.xs),
                          Text(
                            '${_time(session.startMinute)}–${_time(session.endMinute)} · ${room?.name ?? 'Missing room'}',
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: SynchroSpacing.xs),
                          Text(
                            faculty?.name ?? 'Missing faculty',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(right: SynchroSpacing.sm),
                    child: Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TypePill extends StatelessWidget {
  const _TypePill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: SynchroSpacing.sm,
      vertical: SynchroSpacing.xs,
    ),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(SynchroRadius.pill),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: SynchroType.micro,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.7,
      ),
    ),
  );
}

enum _SessionAction { edit, move, delete }

class _SessionDetailsSheet extends StatelessWidget {
  const _SessionDetailsSheet({required this.controller, required this.session});

  final ManualTimetableController controller;
  final ManualSession session;

  @override
  Widget build(BuildContext context) {
    final subject = controller.subjectById(session.subjectId);
    final faculty = controller.facultyById(session.facultyId);
    final room = controller.roomById(session.roomId);
    final batch = controller.batchById(session.batchId);
    final hard = controller.hardConflicts
        .where((issue) => issue.sessionIds.contains(session.id))
        .toList();
    final soft = controller.softWarnings
        .where((issue) => issue.sessionIds.contains(session.id))
        .toList();
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          SynchroSpacing.gutter,
          SynchroSpacing.md,
          SynchroSpacing.gutter,
          SynchroSpacing.gutter,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SheetHandle(),
            const SizedBox(height: SynchroSpacing.lg),
            Text(
              subject?.name ?? 'Missing subject',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: SynchroSpacing.xs),
            Text(
              '${controller.dayName(session.day)} · ${_time(session.startMinute)}–${_time(session.endMinute)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: SynchroSpacing.lg),
            _DetailLine('Batch', batch?.name ?? 'Missing batch'),
            _DetailLine('Faculty', faculty?.name ?? 'Missing faculty'),
            _DetailLine('Room', room?.name ?? 'Missing room'),
            _DetailLine('Type', session.type.label),
            if (session.note.isNotEmpty) _DetailLine('Note', session.note),
            const SizedBox(height: SynchroSpacing.lg),
            if (hard.isNotEmpty || soft.isNotEmpty) ...[
              Text(
                'Local checks',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: SynchroSpacing.sm),
              for (final issue in [...hard, ...soft])
                Padding(
                  padding: const EdgeInsets.only(bottom: SynchroSpacing.sm),
                  child: Notice(
                    tone: issue.isHard ? Tone.bad : Tone.warn,
                    icon: issue.isHard
                        ? Icons.error_outline
                        : Icons.warning_amber_outlined,
                    text: issue.message,
                  ),
                ),
            ] else
              const Notice(
                tone: Tone.good,
                icon: Icons.check_circle_outline,
                text: 'No local issue detected for this class.',
              ),
            const SizedBox(height: SynchroSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        Navigator.of(context).pop(_SessionAction.edit),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
                  ),
                ),
                const SizedBox(width: SynchroSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        Navigator.of(context).pop(_SessionAction.move),
                    icon: const Icon(Icons.open_with_outlined),
                    label: const Text('Move'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: SynchroSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () =>
                    Navigator.of(context).pop(_SessionAction.delete),
                style: TextButton.styleFrom(
                  foregroundColor: SynchroColors.danger,
                ),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete class'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionEditorSheet extends StatefulWidget {
  const _SessionEditorSheet({
    required this.controller,
    this.session,
    this.presetDay,
    this.presetStart,
    this.presetEnd,
    this.moveOnly = false,
  });

  final ManualTimetableController controller;
  final ManualSession? session;
  final int? presetDay;
  final int? presetStart;
  final int? presetEnd;
  final bool moveOnly;

  @override
  State<_SessionEditorSheet> createState() => _SessionEditorSheetState();
}

class _SessionEditorSheetState extends State<_SessionEditorSheet> {
  String? _subjectId;
  String? _facultyId;
  String? _batchId;
  String? _roomId;
  late int _day;
  late int _start;
  late int _end;
  late ManualSessionType _type;

  ManualTimetableController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    final session = widget.session;
    _subjectId = session?.subjectId ?? _firstId(controller.subjects);
    _facultyId = session?.facultyId ?? _firstId(controller.faculty);
    _batchId = session?.batchId ?? controller.selectedBatchId;
    _roomId = session?.roomId;
    _day = session?.day ?? widget.presetDay ?? controller.selectedDay;
    _start =
        session?.startMinute ??
        widget.presetStart ??
        _firstStart(controller, _day);
    _end =
        session?.endMinute ?? widget.presetEnd ?? _nextEnd(controller, _start);
    _type = session?.type ?? ManualSessionType.lecture;
  }

  @override
  Widget build(BuildContext context) {
    final slots = controller.timeSlots
        .where((slot) => slot.day == _day && !slot.isBreak)
        .toList();
    final starts = <int>{
      for (final slot in slots) slot.startMinute,
      _start,
    }.toList()..sort();
    final ends = <int>{for (final slot in slots) slot.endMinute, _end}.toList()
      ..sort();
    final subject = controller.subjectById(_subjectId ?? '');
    final batch = controller.batchById(_batchId ?? '');
    final rooms = controller.availableRoomsFor(
      day: _day,
      startMinute: _start,
      endMinute: _end,
      excludeSessionId: widget.session?.id,
      practical: _type.isPractical || subject?.isPractical == true,
      capacity: batch?.size,
    );
    final roomOptions = _withCurrentRoom(rooms, _roomId, controller.rooms);

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          SynchroSpacing.gutter,
          SynchroSpacing.md,
          SynchroSpacing.gutter,
          MediaQuery.viewInsetsOf(context).bottom + SynchroSpacing.gutter,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SheetHandle(),
            const SizedBox(height: SynchroSpacing.lg),
            Text(
              widget.session == null
                  ? 'Add class'
                  : widget.moveOnly
                  ? 'Move class'
                  : 'Edit class',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: SynchroSpacing.xs),
            Text(
              'Changes update this local draft immediately. Conflicts remain visible for review.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: SynchroSpacing.lg),
            if (!widget.moveOnly) ...[
              _StringDropdown(
                label: 'Subject',
                icon: Icons.menu_book_outlined,
                value: _subjectId,
                items: [
                  for (final item in controller.subjects)
                    DropdownMenuItem(
                      value: item.id,
                      child: Text('${item.code} · ${item.name}'),
                    ),
                ],
                onChanged: (value) => setState(() => _subjectId = value),
              ),
              const SizedBox(height: SynchroSpacing.md),
              _StringDropdown(
                label: 'Faculty',
                icon: Icons.person_outline,
                value: _facultyId,
                items: [
                  for (final item in controller.faculty)
                    DropdownMenuItem(value: item.id, child: Text(item.name)),
                ],
                onChanged: (value) => setState(() => _facultyId = value),
              ),
              const SizedBox(height: SynchroSpacing.md),
              _StringDropdown(
                label: 'Batch',
                icon: Icons.groups_outlined,
                value: _batchId,
                items: [
                  for (final item in controller.batches)
                    DropdownMenuItem(value: item.id, child: Text(item.name)),
                ],
                onChanged: (value) => setState(() => _batchId = value),
              ),
              const SizedBox(height: SynchroSpacing.md),
              _StringDropdown(
                label: 'Room',
                icon: Icons.meeting_room_outlined,
                value: _roomId,
                items: [
                  for (final item in roomOptions)
                    DropdownMenuItem(
                      value: item.id,
                      child: Text('${item.name} · ${item.department}'),
                    ),
                ],
                onChanged: (value) => setState(() => _roomId = value),
              ),
              const SizedBox(height: SynchroSpacing.md),
              _TypeDropdown(
                value: _type,
                onChanged: (value) => setState(() => _type = value),
              ),
              const SizedBox(height: SynchroSpacing.md),
            ],
            Row(
              children: [
                Expanded(
                  child: _IntDropdown(
                    label: 'Day',
                    value: _day,
                    items: [
                      for (
                        var day = 0;
                        day < ManualTimetableController.dayNames.length;
                        day++
                      )
                        day,
                    ],
                    text: (value) => controller.dayName(value),
                    onChanged: (value) => setState(() => _day = value),
                  ),
                ),
                const SizedBox(width: SynchroSpacing.sm),
                Expanded(
                  child: _IntDropdown(
                    label: 'Start',
                    value: _start,
                    items: starts,
                    text: _time,
                    onChanged: (value) => setState(() {
                      _start = value;
                      if (_end <= _start) _end = _nextEnd(controller, _start);
                    }),
                  ),
                ),
                const SizedBox(width: SynchroSpacing.sm),
                Expanded(
                  child: _IntDropdown(
                    label: 'End',
                    value: _end,
                    items: ends,
                    text: _time,
                    onChanged: (value) => setState(() => _end = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: SynchroSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(
                  ManualSession(
                    id: widget.session?.id ?? '',
                    subjectId: _subjectId ?? '',
                    facultyId: _facultyId ?? '',
                    batchId: _batchId ?? '',
                    roomId: _roomId ?? '',
                    day: _day,
                    startMinute: _start,
                    endMinute: _end,
                    type: _type,
                  ),
                ),
                icon: Icon(widget.session == null ? Icons.add : Icons.check),
                label: Text(
                  widget.session == null ? 'Add to draft' : 'Apply changes',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StringDropdown extends StatelessWidget {
  const _StringDropdown({
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final String? value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final itemValues = items.map((item) => item.value).toSet();
    return DropdownButtonFormField<String>(
      initialValue: itemValues.contains(value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      items: items,
      onChanged: onChanged,
    );
  }
}

class _IntDropdown extends StatelessWidget {
  const _IntDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.text,
    required this.onChanged,
  });

  final String label;
  final int value;
  final List<int> items;
  final String Function(int) text;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<int>(
    initialValue: items.contains(value) ? value : null,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: [
      for (final item in items)
        DropdownMenuItem<int>(value: item, child: Text(text(item))),
    ],
    onChanged: (item) {
      if (item != null) onChanged(item);
    },
  );
}

class _TypeDropdown extends StatelessWidget {
  const _TypeDropdown({required this.value, required this.onChanged});

  final ManualSessionType value;
  final ValueChanged<ManualSessionType> onChanged;

  @override
  Widget build(BuildContext context) =>
      DropdownButtonFormField<ManualSessionType>(
        initialValue: value,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Type',
          prefixIcon: Icon(Icons.category_outlined),
        ),
        items: [
          for (final type in ManualSessionType.values)
            DropdownMenuItem(value: type, child: Text(type.label)),
        ],
        onChanged: (item) {
          if (item != null) onChanged(item);
        },
      );
}

class _DetailLine extends StatelessWidget {
  const _DetailLine(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: SynchroSpacing.xs),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 78,
          child: Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
        Expanded(
          child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    ),
  );
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.outlineVariant,
        borderRadius: BorderRadius.circular(4),
      ),
    ),
  );
}

String? _firstId<T>(List<T> items) {
  if (items.isEmpty) return null;
  final item = items.first;
  if (item is ManualSubject) return item.id;
  if (item is ManualFaculty) return item.id;
  return null;
}

int _firstStart(ManualTimetableController controller, int day) {
  for (final slot in controller.timeSlots) {
    if (slot.day == day && !slot.isBreak) return slot.startMinute;
  }
  return 540;
}

int _nextEnd(ManualTimetableController controller, int start) {
  for (final slot in controller.timeSlots) {
    if (!slot.isBreak && slot.startMinute == start) return slot.endMinute;
  }
  return start + 50;
}

List<ManualRoom> _withCurrentRoom(
  List<ManualRoom> available,
  String? currentId,
  List<ManualRoom> all,
) {
  if (currentId == null || available.any((room) => room.id == currentId)) {
    return available;
  }
  final current = all.where((room) => room.id == currentId);
  return [...available, ...current];
}

String _subjectName(ManualTimetableController controller, String subjectId) =>
    controller.subjectById(subjectId)?.name ?? 'this class';

String _shortDay(String value) =>
    value.length <= 3 ? value : value.substring(0, 3);

String _time(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
