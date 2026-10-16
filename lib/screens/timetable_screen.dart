import 'package:flutter/material.dart';

import '../data/models.dart';
import '../state/scheduling_controller.dart';
import '../theme/tokens.dart';
import '../widgets/ui.dart';

/// FEATURE 3 (automatic timetable) and FEATURE 4 (view): every schedule shown
/// here is built from the assignment list returned by the solver. The client
/// never re-solves or locally declares a timetable valid; that verdict belongs
/// to the server-side validator.
class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key, required this.controller});

  final SchedulingController controller;

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  int? _selectedDay;
  bool _showWeek = false;

  SchedulingController get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    if (!controller.hasCampus) {
      return const EmptyState(
        title: 'No campus loaded',
        body:
            'Load the demo campus on the Workload tab first — the solver works from the definition, '
            'not from the app.',
        icon: Icons.table_view_outlined,
      );
    }

    final campus = controller.campus!;
    final result = controller.result;
    final running = controller.runPhase == RunPhase.running;
    final days = campus.dayNumbers;
    final selectedDay = days.contains(_selectedDay)
        ? _selectedDay!
        : (days.isEmpty ? 0 : days.first);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 390;
        final gutter = compact ? SynchroSpacing.lg : SynchroSpacing.gutter;

        return ListView(
          padding: EdgeInsets.fromLTRB(
            gutter,
            SynchroSpacing.lg,
            gutter,
            SynchroSpacing.xxl,
          ),
          children: [
            if (result == null || running)
              _ControlCard(controller: controller, running: running),
            if (controller.runError != null) ...[
              if (result == null || running)
                const SizedBox(height: SynchroSpacing.md),
              Notice(
                tone: Tone.bad,
                icon: Icons.error_outline,
                text: controller.runError!,
              ),
            ],
            if (result != null) ...[
              if (running) const SizedBox(height: SynchroSpacing.md),
              _ResultStrip(result: result),
              const SizedBox(height: SynchroSpacing.md),
            ],
            if (result != null && result.assignments.isNotEmpty) ...[
              _ScheduleToolbar(
                controller: controller,
                campus: campus,
                days: days,
                selectedDay: selectedDay,
                showWeek: _showWeek,
                onDaySelected: (day) => setState(() => _selectedDay = day),
                onViewChanged: (showWeek) =>
                    setState(() => _showWeek = showWeek),
              ),
              const SizedBox(height: SynchroSpacing.md),
              if (_showWeek)
                _WeekView(controller: controller, campus: campus)
              else
                _DayView(
                  controller: controller,
                  campus: campus,
                  selectedDay: selectedDay,
                ),
              const SizedBox(height: SynchroSpacing.md),
              const _Legend(),
            ] else if (running)
              const _GeneratingNotice()
            else if (result == null)
              const EmptyState(
                title: 'No timetable yet',
                body:
                    'Ask the solver for one. It returns only after an independent validator pass, so the '
                    'schedule shown here always comes from the server response.',
                icon: Icons.table_view_outlined,
              )
            else
              const EmptyState(
                title: 'No sessions returned',
                body:
                    'The solver completed without assignments to display. Check the run result and validator '
                    'response before publishing.',
                icon: Icons.event_busy_outlined,
              ),
            if (result != null && !running) ...[
              const SizedBox(height: SynchroSpacing.lg),
              _ControlCard(controller: controller, running: running),
            ],
          ],
        );
      },
    );
  }
}

class _ControlCard extends StatelessWidget {
  const _ControlCard({required this.controller, required this.running});

  final SchedulingController controller;
  final bool running;

  static const List<double> _budgets = [5, 10, 20, 40];

  @override
  Widget build(BuildContext context) {
    final blocker = controller.summary?.blocker ?? controller.previewBlocker;
    final enabled = !running && blocker == null;
    final result = controller.result;

    return SectionCard(
      overline: 'Solver controls',
      title: 'Generate timetable',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: running
                ? const StatusChip(
                    label: 'running',
                    tone: Tone.warn,
                    icon: Icons.autorenew,
                  )
                : result == null
                ? const StatusChip(label: 'not run', icon: Icons.schedule)
                : StatusChip(
                    label: result.solved
                        ? result.solverStatus.toLowerCase()
                        : 'no solution',
                    tone: result.solved ? Tone.good : Tone.bad,
                  ),
          ),
          const SizedBox(height: SynchroSpacing.lg),
          if (blocker != null)
            Notice(tone: Tone.bad, icon: Icons.block_outlined, text: blocker)
          else ...[
            Text('Time budget', style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: SynchroSpacing.sm),
            Wrap(
              spacing: SynchroSpacing.sm,
              runSpacing: SynchroSpacing.sm,
              children: [
                for (final budget in _budgets)
                  ChoiceChip(
                    label: Text('${budget.toInt()}s'),
                    selected: controller.timeLimitSeconds == budget,
                    onSelected: enabled
                        ? (_) => controller.setTimeLimit(budget)
                        : null,
                  ),
              ],
            ),
          ],
          const SizedBox(height: SynchroSpacing.md),
          Row(
            children: [
              Text('Seed', style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(width: SynchroSpacing.md),
              IconButton.outlined(
                tooltip: 'Earlier seed',
                onPressed: enabled
                    ? () => controller.setSeed(controller.randomSeed - 1)
                    : null,
                icon: const Icon(Icons.remove),
              ),
              SizedBox(
                width: 44,
                child: Text(
                  '${controller.randomSeed}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton.outlined(
                tooltip: 'New seed',
                onPressed: enabled
                    ? () => controller.setSeed(controller.randomSeed + 1)
                    : null,
                icon: const Icon(Icons.add),
              ),
              const SizedBox(width: SynchroSpacing.sm),
              Expanded(
                child: Text(
                  'Same seed, same timetable.',
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: SynchroSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: enabled ? controller.generate : null,
              style: FilledButton.styleFrom(
                backgroundColor: blocker != null ? null : SynchroColors.orange,
                foregroundColor: SynchroColors.navyDeep,
              ),
              icon: Icon(running ? Icons.autorenew : Icons.bolt),
              label: Text(
                running
                    ? 'Solving…'
                    : controller.result == null
                    ? 'Generate timetable'
                    : 'Re-solve',
              ),
            ),
          ),
          if (running) ...[
            const SizedBox(height: SynchroSpacing.md),
            const LinearProgressIndicator(minHeight: 3),
            const SizedBox(height: SynchroSpacing.sm),
            Text(
              'Assigning periods, then rooms, then re-checking with the validator.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _GeneratingNotice extends StatelessWidget {
  const _GeneratingNotice();

  @override
  Widget build(BuildContext context) => SectionCard(
    overline: 'Solver',
    title: 'Building the schedule',
    child: Row(
      children: [
        const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: SynchroSpacing.md),
        Expanded(
          child: Text(
            'The timetable will appear after the server returns its assignments and validator verdict.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    ),
  );
}

class _ResultStrip extends StatelessWidget {
  const _ResultStrip({required this.result});

  final GenerationResult result;

  @override
  Widget build(BuildContext context) {
    final violations = result.violations.length;
    final theme = Theme.of(context);

    return SectionCard(
      overline: 'Run #${result.runId}',
      title: result.solved ? 'Timetable produced' : 'No timetable',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  result.publishable
                      ? 'The server validator found no hard conflicts.'
                      : 'Review the validator findings before publishing.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              const SizedBox(width: SynchroSpacing.sm),
              StatusChip(
                label: result.publishable
                    ? 'validator clean'
                    : 'validator blocked',
                tone: result.publishable ? Tone.good : Tone.bad,
                icon: result.publishable
                    ? Icons.verified_outlined
                    : Icons.gpp_bad_outlined,
              ),
            ],
          ),
          const SizedBox(height: SynchroSpacing.md),
          StatusChip(
            label: result.publishable ? 'PUBLISHABLE' : 'NOT PUBLISHABLE',
            tone: result.publishable ? Tone.good : Tone.bad,
            icon: result.publishable
                ? Icons.verified_outlined
                : Icons.gpp_bad_outlined,
          ),
          const SizedBox(height: SynchroSpacing.lg),
          Wrap(
            spacing: SynchroSpacing.lg,
            runSpacing: SynchroSpacing.md,
            children: [
              Stat(value: '${result.assignments.length}', caption: 'sessions'),
              Stat(
                value: '${(result.wallTimeMs / 1000).toStringAsFixed(1)}s',
                caption: 'solved in',
              ),
              Stat(value: '${result.softCost ?? 0}', caption: 'soft cost'),
              Stat(
                value: '$violations',
                caption: 'hard violations',
                tone: violations == 0 ? Tone.good : Tone.bad,
              ),
            ],
          ),
          if (result.utilisation != null) ...[
            const SizedBox(height: SynchroSpacing.md),
            Text(
              '${result.utilisation!.roomsInUse}/${result.utilisation!.roomsOnCampus} rooms used'
              ' · ${result.utilisation!.borrowedPeriods} borrowed periods',
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (!result.solved && result.message.isNotEmpty) ...[
            const SizedBox(height: SynchroSpacing.md),
            Notice(
              tone: Tone.bad,
              icon: Icons.help_outline,
              text: result.message,
            ),
          ],
        ],
      ),
    );
  }
}

class _ScheduleToolbar extends StatelessWidget {
  const _ScheduleToolbar({
    required this.controller,
    required this.campus,
    required this.days,
    required this.selectedDay,
    required this.showWeek,
    required this.onDaySelected,
    required this.onViewChanged,
  });

  final SchedulingController controller;
  final Campus campus;
  final List<int> days;
  final int selectedDay;
  final bool showWeek;
  final ValueChanged<int> onDaySelected;
  final ValueChanged<bool> onViewChanged;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      overline: 'Schedule focus',
      title: showWeek ? 'Weekly overview' : dayName(selectedDay),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BatchPicker(controller: controller, campus: campus),
          const SizedBox(height: SynchroSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 470;
              final view = _ViewSwitcher(
                showWeek: showWeek,
                onViewChanged: onViewChanged,
              );

              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('View', style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: SynchroSpacing.sm),
                    view,
                  ],
                );
              }

              return Row(
                children: [
                  Text('View', style: Theme.of(context).textTheme.labelSmall),
                  const Spacer(),
                  view,
                ],
              );
            },
          ),
          if (!showWeek) ...[
            const SizedBox(height: SynchroSpacing.lg),
            Text('Day', style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: SynchroSpacing.sm),
            _DaySelector(
              days: days,
              selectedDay: selectedDay,
              onSelected: onDaySelected,
            ),
          ] else ...[
            const SizedBox(height: SynchroSpacing.md),
            Text(
              'A stacked week view keeps every day readable on a phone. Select Day for the focused timeline.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _ViewSwitcher extends StatelessWidget {
  const _ViewSwitcher({required this.showWeek, required this.onViewChanged});

  final bool showWeek;
  final ValueChanged<bool> onViewChanged;

  @override
  Widget build(BuildContext context) => SegmentedButton<bool>(
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
    selected: {showWeek},
    showSelectedIcon: false,
    onSelectionChanged: (selection) {
      if (selection.isNotEmpty) onViewChanged(selection.first);
    },
  );
}

class _BatchPicker extends StatelessWidget {
  const _BatchPicker({required this.controller, required this.campus});

  final SchedulingController controller;
  final Campus campus;

  @override
  Widget build(BuildContext context) {
    final batches = campus.batches;
    if (batches.isEmpty) {
      return Text(
        'No batches are available in the campus definition.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    final selected = batches.any((batch) => batch.id == controller.batchId)
        ? controller.batchId
        : batches.first.id;

    return DropdownButtonFormField<String>(
      initialValue: selected,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Batch',
        prefixIcon: Icon(Icons.groups_outlined),
      ),
      items: [
        for (final batch in batches)
          DropdownMenuItem<String>(
            value: batch.id,
            child: Text(
              batch.name.replaceFirst('SEIT-', ''),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (id) {
        if (id != null) controller.selectBatch(id);
      },
    );
  }
}

class _DaySelector extends StatelessWidget {
  const _DaySelector({
    required this.days,
    required this.selectedDay,
    required this.onSelected,
  });

  final List<int> days;
  final int selectedDay;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: SynchroSpacing.sm,
    runSpacing: SynchroSpacing.sm,
    children: [
      for (final day in days)
        _DayPill(
          day: day,
          selected: selectedDay == day,
          onTap: () => onSelected(day),
        ),
    ],
  );
}

class _DayPill extends StatelessWidget {
  const _DayPill({
    required this.day,
    required this.selected,
    required this.onTap,
  });

  final int day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = selected
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;
    final background = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceContainerLow;

    return Semantics(
      button: true,
      selected: selected,
      label: '${dayName(day)}, day ${day + 1}',
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(SynchroRadius.chip),
        child: InkWell(
          borderRadius: BorderRadius.circular(SynchroRadius.chip),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minWidth: 56, minHeight: 48),
            padding: const EdgeInsets.symmetric(
              horizontal: SynchroSpacing.md,
              vertical: SynchroSpacing.sm,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(SynchroRadius.chip),
              border: Border.all(
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _shortDay(day),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: foreground,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${day + 1}'.padLeft(2, '0'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: foreground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DayView extends StatelessWidget {
  const _DayView({
    required this.controller,
    required this.campus,
    required this.selectedDay,
  });

  final SchedulingController controller;
  final Campus campus;
  final int selectedDay;

  @override
  Widget build(BuildContext context) {
    final assignments = _assignmentsForDay(controller, selectedDay);

    return SectionCard(
      overline: 'Readable day view',
      title: dayName(selectedDay),
      trailing: Text(
        '${assignments.length} ${assignments.length == 1 ? 'session' : 'sessions'}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      child: _TimelineRows(
        controller: controller,
        campus: campus,
        day: selectedDay,
      ),
    );
  }
}

class _WeekView extends StatelessWidget {
  const _WeekView({required this.controller, required this.campus});

  final SchedulingController controller;
  final Campus campus;

  @override
  Widget build(BuildContext context) {
    final days = campus.dayNumbers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < days.length; index++) ...[
          if (index > 0) const SizedBox(height: SynchroSpacing.md),
          _WeekDayCard(
            controller: controller,
            campus: campus,
            day: days[index],
          ),
        ],
      ],
    );
  }
}

class _WeekDayCard extends StatelessWidget {
  const _WeekDayCard({
    required this.controller,
    required this.campus,
    required this.day,
  });

  final SchedulingController controller;
  final Campus campus;
  final int day;

  @override
  Widget build(BuildContext context) {
    final assignments = _assignmentsForDay(controller, day);

    return SectionCard(
      overline: 'Weekly grid · day ${day + 1}',
      title: dayName(day),
      trailing: Text(
        '${assignments.length} ${assignments.length == 1 ? 'session' : 'sessions'}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      child: _TimelineRows(controller: controller, campus: campus, day: day),
    );
  }
}

class _TimelineRows extends StatelessWidget {
  const _TimelineRows({
    required this.controller,
    required this.campus,
    required this.day,
  });

  final SchedulingController controller;
  final Campus campus;
  final int day;

  @override
  Widget build(BuildContext context) {
    final assignments = _assignmentsForDay(controller, day);
    final starts = <String, Assignment>{
      for (final assignment in assignments)
        '${assignment.day}:${assignment.index}': assignment,
    };
    final covered = <String>{};
    for (final assignment in assignments) {
      final spans = _spanFor(assignment, campus);
      for (var offset = 1; offset < spans; offset++) {
        covered.add('${assignment.day}:${assignment.index + offset}');
      }
    }

    final slots = campus.slots.where((slot) => slot.day == day).toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    if (slots.isEmpty) {
      return Text(
        'No campus periods are defined for this day.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    return Column(
      children: [
        for (final slot in slots)
          if (campus.isBreak(slot.day, slot.index) ||
              !covered.contains('${slot.day}:${slot.index}'))
            _DaySlot(
              slot: slot,
              assignment: starts['${slot.day}:${slot.index}'],
              isBreak: campus.isBreak(slot.day, slot.index),
              campus: campus,
              controller: controller,
            ),
      ],
    );
  }
}

class _DaySlot extends StatelessWidget {
  const _DaySlot({
    required this.slot,
    required this.assignment,
    required this.isBreak,
    required this.campus,
    required this.controller,
  });

  final Slot slot;
  final Assignment? assignment;
  final bool isBreak;
  final Campus campus;
  final SchedulingController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SynchroSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 58,
            child: Padding(
              padding: const EdgeInsets.only(top: SynchroSpacing.sm),
              child: _TimeRail(slot: slot),
            ),
          ),
          const SizedBox(width: SynchroSpacing.sm),
          Expanded(
            child: assignment != null
                ? _SessionCard(
                    assignment: assignment!,
                    campus: campus,
                    controller: controller,
                  )
                : isBreak
                ? _BreakRow(slot: slot)
                : _OpenSlot(slot: slot),
          ),
        ],
      ),
    );
  }
}

class _TimeRail extends StatelessWidget {
  const _TimeRail({required this.slot});

  final Slot slot;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('P${slot.index + 1}', style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 2),
      Text(
        formatMinutes(slot.start),
        style: Theme.of(context).textTheme.labelSmall,
      ),
      Text(
        formatMinutes(slot.end),
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(fontWeight: FontWeight.w400),
      ),
    ],
  );
}

class _OpenSlot extends StatelessWidget {
  const _OpenSlot({required this.slot});

  final Slot slot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 74),
      padding: const EdgeInsets.all(SynchroSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(SynchroRadius.chip),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(
            Icons.more_time_outlined,
            size: 20,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(width: SynchroSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('FREE', style: theme.textTheme.labelMedium),
                const SizedBox(height: 2),
                Text(
                  '${formatMinutes(slot.start)}–${formatMinutes(slot.end)} · Available',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakRow extends StatelessWidget {
  const _BreakRow({required this.slot});

  final Slot slot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = StatusChip.color(Tone.warn, theme.brightness);
    final background = theme.brightness == Brightness.dark
        ? ink.withValues(alpha: 0.12)
        : SynchroColors.cream;

    return Container(
      constraints: const BoxConstraints(minHeight: 74),
      padding: const EdgeInsets.all(SynchroSpacing.md),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(SynchroRadius.chip),
        border: Border.all(color: ink.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Icon(Icons.free_breakfast_outlined, size: 20, color: ink),
          const SizedBox(width: SynchroSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BREAK',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: ink,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatMinutes(slot.start)}–${formatMinutes(slot.end)} · No session',
                  style: theme.textTheme.bodySmall?.copyWith(color: ink),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.assignment,
    required this.campus,
    required this.controller,
  });

  final Assignment assignment;
  final Campus campus;
  final SchedulingController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lab = assignment.isLab || assignment.roomKind == 'laboratory';
    final room = campus.roomName(assignment.roomId);
    final faculty = campus.facultyName(assignment.facultyId);
    final subject = campus.subjectName(assignment.subjectId);
    final label =
        '$subject, ${formatMinutes(assignment.start)} to ${formatMinutes(assignment.end)}, $room';
    final accent = lab
        ? (theme.brightness == Brightness.dark
              ? SynchroColors.warnOnNavy
              : SynchroColors.orangeDeep)
        : theme.colorScheme.primary;

    return Semantics(
      button: true,
      label: '$label · ${lab ? 'lab' : 'lecture'}',
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(SynchroRadius.chip),
        child: InkWell(
          borderRadius: BorderRadius.circular(SynchroRadius.chip),
          onTap: () => _openDetails(context, assignment, campus, controller),
          child: Container(
            constraints: const BoxConstraints(minHeight: 104),
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
                                  subject,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall,
                                ),
                              ),
                              const SizedBox(width: SynchroSpacing.sm),
                              _TypeBadge(
                                label: lab ? 'LAB' : 'LECTURE',
                                color: accent,
                              ),
                            ],
                          ),
                          const SizedBox(height: SynchroSpacing.sm),
                          _Meta(
                            icon: Icons.schedule_outlined,
                            text:
                                '${formatMinutes(assignment.start)}–${formatMinutes(assignment.end)}',
                          ),
                          const SizedBox(height: SynchroSpacing.xs),
                          Row(
                            children: [
                              Expanded(
                                child: _Meta(
                                  icon: Icons.meeting_room_outlined,
                                  text: room,
                                ),
                              ),
                              const SizedBox(width: SynchroSpacing.md),
                              Expanded(
                                child: _Meta(
                                  icon: Icons.person_outline,
                                  text: faculty,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
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

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.label, required this.color});

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
      border: Border.all(color: color.withValues(alpha: 0.30)),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: SynchroType.micro,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    ),
  );
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(
        icon,
        size: 14,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      const SizedBox(width: SynchroSpacing.xs),
      Expanded(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    ],
  );
}

List<Assignment> _assignmentsForDay(SchedulingController controller, int day) =>
    controller.visibleAssignments.where((a) => a.day == day).toList()
      ..sort((a, b) => a.index.compareTo(b.index));

int _spanFor(Assignment assignment, Campus campus) => assignment.isLab
    ? (campus.subjectsById[assignment.subjectId]?.labDurationSlots ?? 1)
    : 1;

String _shortDay(int day) {
  final name = dayName(day);
  return name.length <= 3
      ? name.toUpperCase()
      : name.substring(0, 3).toUpperCase();
}

void _openDetails(
  BuildContext context,
  Assignment assignment,
  Campus campus,
  SchedulingController controller,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(SynchroRadius.sheet),
      ),
    ),
    builder: (sheetContext) {
      final allViolations =
          controller.result?.violations ?? const <Violation>[];
      final violations = allViolations
          .where((v) => v.refs.contains(assignment.sessionId))
          .toList();
      final room = campus.roomsById[assignment.roomId];
      final batch = campus.batchesById[assignment.batchId];
      final capacity = room != null && batch != null
          ? '${room.capacity} seats for ${batch.size} students'
          : 'Not available from campus data';
      final lab = assignment.isLab || assignment.roomKind == 'laboratory';

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
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(sheetContext).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: SynchroSpacing.lg),
              Text(
                campus.subjectName(assignment.subjectId),
                style: Theme.of(sheetContext).textTheme.headlineSmall,
              ),
              const SizedBox(height: SynchroSpacing.xs),
              Text(
                'Session ${assignment.sessionId}',
                style: Theme.of(sheetContext).textTheme.labelSmall,
              ),
              const SizedBox(height: SynchroSpacing.lg),
              _Detail(
                'Timing',
                '${dayName(assignment.day)} · period ${assignment.index + 1} · '
                    '${formatMinutes(assignment.start)}–${formatMinutes(assignment.end)}',
              ),
              _Detail(
                'Room',
                '${campus.roomName(assignment.roomId)} · ${lab ? 'laboratory' : 'classroom'}',
              ),
              _Detail('Faculty', campus.facultyName(assignment.facultyId)),
              _Detail('Batch', campus.batchName(assignment.batchId)),
              _Detail('Capacity', capacity),
              _Detail(
                'Department',
                assignment.department.isEmpty
                    ? 'unassigned'
                    : assignment.department,
              ),
              const SizedBox(height: SynchroSpacing.lg),
              Text(
                'Validator',
                style: Theme.of(sheetContext).textTheme.titleSmall,
              ),
              const SizedBox(height: SynchroSpacing.sm),
              if (violations.isNotEmpty)
                for (final violation in violations)
                  Notice(
                    tone: Tone.bad,
                    icon: Icons.error_outline,
                    text: violation.message,
                  )
              else if (allViolations.isEmpty)
                const Notice(
                  tone: Tone.good,
                  icon: Icons.verified_outlined,
                  text: 'The validator found no problem in this session.',
                )
              else
                Notice(
                  tone: Tone.warn,
                  icon: Icons.info_outline,
                  text:
                      'No hard violation was linked to this session; ${allViolations.length} known hard '
                      'violation${allViolations.length == 1 ? '' : 's'} exist elsewhere in the timetable.',
                ),
              Text(
                'Soft-preference warnings are not exposed by the current validator response.',
                style: Theme.of(sheetContext).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _Detail extends StatelessWidget {
  const _Detail(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
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

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget swatch(Color color, String label, {IconData? icon}) => Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SynchroSpacing.sm,
        vertical: SynchroSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(SynchroRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: 14, color: color)
          else
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );

    final theme = Theme.of(context);
    final lecture = theme.colorScheme.primary;
    final lab = theme.brightness == Brightness.dark
        ? SynchroColors.warnOnNavy
        : SynchroColors.orangeDeep;
    final breakColor = StatusChip.color(Tone.warn, theme.brightness);
    final free = theme.colorScheme.outline;

    return Wrap(
      spacing: SynchroSpacing.sm,
      runSpacing: SynchroSpacing.sm,
      children: [
        swatch(lecture, 'Lecture'),
        swatch(lab, 'Lab'),
        swatch(breakColor, 'Break', icon: Icons.free_breakfast_outlined),
        swatch(free, 'Free', icon: Icons.more_time_outlined),
      ],
    );
  }
}
