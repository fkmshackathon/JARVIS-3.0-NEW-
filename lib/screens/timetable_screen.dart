import 'dart:math' as math;

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
        final isWide = constraints.maxWidth >= 760;
        return ListView(
          padding: const EdgeInsets.fromLTRB(
            SynchroSpacing.gutter,
            SynchroSpacing.lg,
            SynchroSpacing.gutter,
            SynchroSpacing.xxl,
          ),
          children: [
            if (result == null || running)
              _ControlCard(controller: controller, running: running),
            const SizedBox(height: SynchroSpacing.lg),
            if (controller.runError != null)
              Notice(
                tone: Tone.bad,
                icon: Icons.error_outline,
                text: controller.runError!,
              ),
            if (result != null) ...[
              _ResultStrip(result: result),
              const SizedBox(height: SynchroSpacing.lg),
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
                _WeekGrid(
                  controller: controller,
                  campus: campus,
                  isWide: isWide,
                )
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

    return SectionCard(
      overline: 'Solver controls',
      title: 'Generate timetable',
      trailing: running
          ? const StatusChip(
              label: 'running',
              tone: Tone.warn,
              icon: Icons.autorenew,
            )
          : controller.result == null
          ? const StatusChip(label: 'not run', icon: Icons.schedule)
          : StatusChip(
              label: controller.result!.solved
                  ? controller.result!.solverStatus.toLowerCase()
                  : 'no solution',
              tone: controller.result!.solved ? Tone.good : Tone.bad,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
    return SectionCard(
      overline: 'Run #${result.runId}',
      title: result.solved ? 'Timetable produced' : 'No timetable',
      trailing: StatusChip(
        label: result.publishable ? 'validator clean' : 'validator blocked',
        tone: result.publishable ? Tone.good : Tone.bad,
        icon: result.publishable
            ? Icons.verified_outlined
            : Icons.gpp_bad_outlined,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
              style: Theme.of(context).textTheme.bodySmall,
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
      trailing: StatusChip(
        label: campus.batchName(controller.batchId ?? ''),
        icon: Icons.groups_outlined,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BatchPicker(controller: controller, campus: campus),
          const SizedBox(height: SynchroSpacing.lg),
          Row(
            children: [
              Text('View', style: Theme.of(context).textTheme.labelSmall),
              const Spacer(),
              ChoiceChip(
                label: const Text('Day'),
                selected: !showWeek,
                onSelected: (_) => onViewChanged(false),
                avatar: const Icon(Icons.view_agenda_outlined, size: 16),
              ),
              const SizedBox(width: SynchroSpacing.sm),
              ChoiceChip(
                label: const Text('Week'),
                selected: showWeek,
                onSelected: (_) => onViewChanged(true),
                avatar: const Icon(Icons.grid_view_outlined, size: 16),
              ),
            ],
          ),
          if (!showWeek) ...[
            const SizedBox(height: SynchroSpacing.md),
            Text('Day', style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: SynchroSpacing.sm),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: days.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: SynchroSpacing.sm),
                itemBuilder: (context, index) {
                  final day = days[index];
                  return ChoiceChip(
                    label: Text(dayName(day)),
                    selected: selectedDay == day,
                    onSelected: (_) => onDaySelected(day),
                  );
                },
              ),
            ),
          ] else ...[
            const SizedBox(height: SynchroSpacing.md),
            Text(
              'Select Day for the readable timeline. Week keeps every period visible together.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _BatchPicker extends StatelessWidget {
  const _BatchPicker({required this.controller, required this.campus});

  final SchedulingController controller;
  final Campus campus;

  @override
  Widget build(BuildContext context) {
    final batches = campus.batches;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Batch', style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: SynchroSpacing.sm),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: batches.length,
            separatorBuilder: (_, _) =>
                const SizedBox(width: SynchroSpacing.sm),
            itemBuilder: (context, i) {
              final batch = batches[i];
              final selected = batch.id == controller.batchId;
              return ChoiceChip(
                selected: selected,
                onSelected: (_) => controller.selectBatch(batch.id),
                label: Text(batch.name.replaceFirst('SEIT-', '')),
              );
            },
          ),
        ),
      ],
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
    final assignments =
        controller.visibleAssignments
            .where((a) => a.day == selectedDay)
            .toList()
          ..sort((a, b) => a.index.compareTo(b.index));
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

    final slots = campus.slots.where((slot) => slot.day == selectedDay).toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    return SectionCard(
      overline: 'Readable day view',
      title: dayName(selectedDay),
      trailing: Text(
        '${assignments.length} ${assignments.length == 1 ? 'session' : 'sessions'}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      child: slots.isEmpty
          ? Text(
              'No campus periods are defined for this day.',
              style: Theme.of(context).textTheme.bodySmall,
            )
          : Column(
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
            ),
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
            width: 68,
            child: Padding(
              padding: const EdgeInsets.only(top: SynchroSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'P${slot.index + 1}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatMinutes(slot.start),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: assignment != null
                ? _SessionCard(
                    assignment: assignment!,
                    campus: campus,
                    controller: controller,
                  )
                : isBreak
                ? const _BreakRow()
                : _OpenSlot(slot: slot),
          ),
        ],
      ),
    );
  }
}

class _OpenSlot extends StatelessWidget {
  const _OpenSlot({required this.slot});

  final Slot slot;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 66),
    padding: const EdgeInsets.all(SynchroSpacing.md),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(SynchroRadius.chip),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Row(
      children: [
        Icon(
          Icons.more_time_outlined,
          size: 18,
          color: Theme.of(context).colorScheme.outline,
        ),
        const SizedBox(width: SynchroSpacing.sm),
        Text(
          '${formatMinutes(slot.start)}–${formatMinutes(slot.end)} · Available',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}

class _BreakRow extends StatelessWidget {
  const _BreakRow();

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 66),
    padding: const EdgeInsets.symmetric(horizontal: SynchroSpacing.md),
    decoration: BoxDecoration(
      color: SynchroColors.cream,
      borderRadius: BorderRadius.circular(SynchroRadius.chip),
      border: Border.all(color: SynchroColors.warn.withValues(alpha: 0.28)),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.free_breakfast_outlined,
          size: 18,
          color: SynchroColors.warn,
        ),
        const SizedBox(width: SynchroSpacing.sm),
        Text(
          'BREAK',
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: SynchroColors.warn, letterSpacing: 1.2),
        ),
        const Spacer(),
        Text(
          'No session',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: SynchroColors.warn),
        ),
      ],
    ),
  );
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

    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(SynchroRadius.chip),
        child: InkWell(
          borderRadius: BorderRadius.circular(SynchroRadius.chip),
          onTap: () => _openDetails(context, assignment, campus, controller),
          child: Container(
            constraints: const BoxConstraints(minHeight: 78),
            padding: const EdgeInsets.all(SynchroSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(SynchroRadius.chip),
              border: Border.all(color: theme.colorScheme.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: SynchroColors.navy.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
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
                    Icon(
                      lab ? Icons.science_outlined : Icons.menu_book_outlined,
                      size: 18,
                      color: lab
                          ? SynchroColors.orangeDeep
                          : theme.colorScheme.primary,
                    ),
                  ],
                ),
                const SizedBox(height: SynchroSpacing.sm),
                Wrap(
                  spacing: SynchroSpacing.md,
                  runSpacing: SynchroSpacing.xs,
                  children: [
                    _Meta(
                      icon: Icons.schedule_outlined,
                      text:
                          '${formatMinutes(assignment.start)}–${formatMinutes(assignment.end)}',
                    ),
                    _Meta(icon: Icons.meeting_room_outlined, text: room),
                    _Meta(icon: Icons.person_outline, text: faculty),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        icon,
        size: 14,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      const SizedBox(width: 4),
      Text(text, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

int _spanFor(Assignment assignment, Campus campus) => assignment.isLab
    ? (campus.subjectsById[assignment.subjectId]?.labDurationSlots ?? 1)
    : 1;

class _Cell {
  const _Cell({required this.assignment, required this.offset});

  final Assignment assignment;
  final int offset;

  bool get isStart => offset == 0;
}

class _WeekGrid extends StatelessWidget {
  const _WeekGrid({
    required this.controller,
    required this.campus,
    required this.isWide,
  });

  final SchedulingController controller;
  final Campus campus;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final assignments = controller.visibleAssignments;
    final cells = <String, _Cell>{};
    for (final assignment in assignments) {
      final spans = _spanFor(assignment, campus);
      for (var offset = 0; offset < spans; offset++) {
        cells['${assignment.day}:${assignment.index + offset}'] = _Cell(
          assignment: assignment,
          offset: offset,
        );
      }
    }

    final days = campus.dayNumbers;
    final periods = campus.periodIndexes;
    final minWidth = math.max<double>(
      520.0,
      (56 + days.length * (isWide ? 112 : 124)).toDouble(),
    );

    return SectionCard(
      padding: const EdgeInsets.all(SynchroSpacing.md),
      overline: campus.batchName(controller.batchId ?? ''),
      title: 'Weekly grid',
      trailing: Text(
        '${assignments.length} sessions',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: minWidth,
          child: Column(
            children: [
              _GridRow(
                height: 34,
                days: days,
                builder: (context, day) => day == null
                    ? const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'PERIOD',
                            style: TextStyle(fontSize: 9, letterSpacing: 1),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          dayName(day)
                              .substring(0, math.min(3, dayName(day).length))
                              .toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
              ),
              for (final index in periods)
                _GridRow(
                  height: 62,
                  days: days,
                  builder: (context, day) {
                    if (day == null) {
                      return Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'P${index + 1}',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            Text(
                              campus.periodStart.containsKey(index)
                                  ? formatMinutes(campus.periodStart[index]!)
                                  : '',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(fontSize: 9),
                            ),
                          ],
                        ),
                      );
                    }
                    if (campus.isBreak(day, index)) return const _BreakCell();
                    final cell = cells['$day:$index'];
                    if (cell == null) return const _EmptyCell();
                    return _SessionCell(
                      cell: cell,
                      campus: campus,
                      onTap: () => _openDetails(
                        context,
                        cell.assignment,
                        campus,
                        controller,
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GridRow extends StatelessWidget {
  const _GridRow({
    required this.height,
    required this.days,
    required this.builder,
  });

  final double height;
  final List<int> days;
  final Widget Function(BuildContext context, int? day) builder;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: 52, child: builder(context, null)),
        for (final day in days) Expanded(child: builder(context, day)),
      ],
    ),
  );
}

class _BreakCell extends StatelessWidget {
  const _BreakCell();

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.all(2),
    decoration: BoxDecoration(
      color: SynchroColors.cream,
      borderRadius: BorderRadius.circular(6),
    ),
    child: const Center(
      child: Text(
        'BREAK',
        style: TextStyle(
          fontSize: 9,
          letterSpacing: 1.2,
          color: SynchroColors.warn,
        ),
      ),
    ),
  );
}

class _EmptyCell extends StatelessWidget {
  const _EmptyCell();

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.all(2),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
  );
}

class _SessionCell extends StatelessWidget {
  const _SessionCell({
    required this.cell,
    required this.campus,
    required this.onTap,
  });

  final _Cell cell;
  final Campus campus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final assignment = cell.assignment;
    final lab = assignment.isLab || assignment.roomKind == 'laboratory';
    final background = cell.isStart
        ? (lab ? SynchroColors.navySoft : SynchroColors.navy)
        : SynchroColors.navy.withValues(alpha: 0.35);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (cell.isStart) ...[
              Text(
                campus.subjectName(assignment.subjectId),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                  color: SynchroColors.onNavy,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                campus.roomName(assignment.roomId),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9,
                  color: lab ? SynchroColors.orange : SynchroColors.onNavyMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ] else
              const Padding(
                padding: EdgeInsets.only(left: 2),
                child: Text(
                  '· · ·',
                  style: TextStyle(fontSize: 9, color: SynchroColors.navySoft),
                ),
              ),
          ],
        ),
      ),
    );
  }
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
                '${campus.roomName(assignment.roomId)} · ${assignment.isLab ? 'laboratory' : 'classroom'}',
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
    Widget swatch(Color color, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );

    return Wrap(
      spacing: SynchroSpacing.lg,
      runSpacing: SynchroSpacing.sm,
      children: [
        swatch(SynchroColors.navy, 'Lecture'),
        swatch(SynchroColors.navySoft, 'Lab'),
        swatch(SynchroColors.cream, 'Break'),
      ],
    );
  }
}
