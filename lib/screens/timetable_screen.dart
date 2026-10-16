import 'package:flutter/material.dart';

import '../data/models.dart';
import '../state/scheduling_controller.dart';
import '../theme/tokens.dart';
import '../widgets/ui.dart';

/// FEATURE 3 (automatic timetable) and FEATURE 4 (view): the grid is built only
/// from the assignment list the solver returned, and every verdict on it comes from
/// the server-side validator rather than a local check.
class TimetableScreen extends StatelessWidget {
  const TimetableScreen({super.key, required this.controller});

  final SchedulingController controller;

  @override
  Widget build(BuildContext context) {
    if (!controller.hasCampus) {
      return const EmptyState(
        title: 'No campus loaded',
        body: 'Load the demo campus on the Workload tab first — the solver works from the definition, '
            'not from the app.',
        icon: Icons.table_view_outlined,
      );
    }

    final campus = controller.campus!;
    final result = controller.result;
    final running = controller.runPhase == RunPhase.running;

    return ListView(
      padding: const EdgeInsets.fromLTRB(SynchroSpacing.gutter, SynchroSpacing.lg, SynchroSpacing.gutter, SynchroSpacing.xxl),
      children: [
        _ControlCard(controller: controller, running: running),
        const SizedBox(height: SynchroSpacing.lg),
        if (controller.runError != null)
          Notice(tone: Tone.bad, icon: Icons.error_outline, text: controller.runError!),
        if (result != null) ...[
          _ResultStrip(controller: controller, result: result),
          const SizedBox(height: SynchroSpacing.lg),
        ],
        if (result != null && result.assignments.isNotEmpty) ...[
          _BatchPicker(controller: controller, campus: campus),
          const SizedBox(height: SynchroSpacing.md),
          _Grid(controller: controller, campus: campus),
          const SizedBox(height: SynchroSpacing.md),
          const _Legend(),
        ] else if (!running)
          const EmptyState(
            title: 'No timetable yet',
            body: 'Ask the solver for one. It returns only after an independent validator pass, so a '
                'grid on this screen is a grid with no clashes.',
            icon: Icons.table_view_outlined,
          ),
      ],
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
      overline: 'Solver',
      title: 'Generate timetable',
      trailing: running
          ? const StatusChip(label: 'running', tone: Tone.warn, icon: Icons.autorenew)
          : controller.result == null
              ? const StatusChip(label: 'not run', icon: Icons.schedule)
              : StatusChip(
                  label: controller.result!.solved ? controller.result!.solverStatus.toLowerCase() : 'no solution',
                  tone: controller.result!.solved ? Tone.good : Tone.bad,
                ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (blocker != null)
            Notice(tone: Tone.bad, icon: Icons.block_outlined, text: blocker)
          else
            Text(
              'Time budget',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          Wrap(
            spacing: SynchroSpacing.sm,
            runSpacing: SynchroSpacing.sm,
            children: [
              for (final budget in _budgets)
                ChoiceChip(
                  label: Text('${budget.toInt()}s'),
                  selected: controller.timeLimitSeconds == budget,
                  onSelected: enabled ? (_) => controller.setTimeLimit(budget) : null,
                ),
            ],
          ),
          const SizedBox(height: SynchroSpacing.md),
          Row(
            children: [
              Text('Seed', style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(width: SynchroSpacing.md),
              IconButton.outlined(
                tooltip: 'Earlier seed',
                onPressed: enabled ? () => controller.setSeed(controller.randomSeed - 1) : null,
                icon: const Icon(Icons.remove),
              ),
              SizedBox(
                width: 44,
                child: Text('${controller.randomSeed}', textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              IconButton.outlined(
                tooltip: 'New seed',
                onPressed: enabled ? () => controller.setSeed(controller.randomSeed + 1) : null,
                icon: const Icon(Icons.add),
              ),
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
              label: Text(running ? 'Solving…' : controller.result == null ? 'Generate timetable' : 'Re-solve'),
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

class _ResultStrip extends StatelessWidget {
  const _ResultStrip({required this.controller, required this.result});

  final SchedulingController controller;
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
        icon: result.publishable ? Icons.verified_outlined : Icons.gpp_bad_outlined,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Stat(value: '${result.assignments.length}', caption: 'sessions')),
                Expanded(
                  child: Stat(
                    value: '${(result.wallTimeMs / 1000).toStringAsFixed(1)}s',
                    caption: 'solved in',
                  ),
                ),
                Expanded(child: Stat(value: '${result.softCost ?? 0}', caption: 'soft cost')),
                Expanded(
                  child: Stat(
                    value: '$violations',
                    caption: 'violations',
                    tone: violations == 0 ? Tone.good : Tone.bad,
                  ),
                ),
              ],
            ),
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
            Notice(tone: Tone.bad, icon: Icons.help_outline, text: result.message),
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
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: batches.length,
        separatorBuilder: (_, _) => const SizedBox(width: SynchroSpacing.sm),
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
    );
  }
}

class _Cell {
  const _Cell({required this.assignment, required this.offset});

  final Assignment assignment;
  final int offset;

  bool get isStart => offset == 0;
}

class _Grid extends StatelessWidget {
  const _Grid({required this.controller, required this.campus});

  final SchedulingController controller;
  final Campus campus;

  @override
  Widget build(BuildContext context) {
    final assignments = controller.visibleAssignments;
    final cells = <String, _Cell>{};
    for (final assignment in assignments) {
      final spans = assignment.isLab
          ? (campus.subjectsById[assignment.subjectId]?.labDurationSlots ?? 1)
          : 1;
      for (var offset = 0; offset < spans; offset++) {
        cells['${assignment.day}:${assignment.index + offset}'] = _Cell(assignment: assignment, offset: offset);
      }
    }

    final days = campus.dayNumbers;
    final periods = campus.periodIndexes;

    return SectionCard(
      padding: const EdgeInsets.all(SynchroSpacing.md),
      overline: campus.batchName(controller.batchId ?? ''),
      title: 'Weekly grid',
      trailing: Text(
        '${assignments.length} sessions',
        style: Theme.of(context).textTheme.bodySmall,
      ),
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
                      child: Text('PERIOD', style: TextStyle(fontSize: 9, letterSpacing: 1)),
                    ),
                  )
                : Center(
                    child: Text(
                      dayName(day).substring(0, 3).toUpperCase(),
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1),
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
                        Text('P${index + 1}', style: Theme.of(context).textTheme.titleSmall),
                        Text(
                          campus.periodStart.containsKey(index) ? formatMinutes(campus.periodStart[index]!) : '',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 9),
                        ),
                      ],
                    ),
                  );
                }
                if (campus.isBreak(day, index)) {
                  return const _BreakCell();
                }
                final cell = cells['$day:$index'];
                if (cell == null) return const _EmptyCell();
                return _SessionCell(
                  cell: cell,
                  campus: campus,
                  onTap: cell.isStart
                      ? () => _openDetails(context, cell.assignment, campus, controller)
                      : null,
                );
              },
            ),
        ],
      ),
    );
  }
}

class _GridRow extends StatelessWidget {
  const _GridRow({required this.height, required this.days, required this.builder});

  final double height;
  final List<int> days;
  final Widget Function(BuildContext context, int? day) builder;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
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
          child: Text('BREAK', style: TextStyle(fontSize: 9, letterSpacing: 1.2, color: SynchroColors.warn)),
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
  const _SessionCell({required this.cell, required this.campus, this.onTap});

  final _Cell cell;
  final Campus campus;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final assignment = cell.assignment;
    final lab = assignment.isLab;
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
                child: Text('· · ·', style: TextStyle(fontSize: 9, color: SynchroColors.navySoft)),
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
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(SynchroRadius.sheet)),
    ),
    builder: (sheetContext) {
      final violations = (controller.result?.violations ?? const <Violation>[])
          .where((v) => v.refs.contains(assignment.sessionId))
          .toList();
      final room = campus.roomsById[assignment.roomId];
      final batch = campus.batchesById[assignment.batchId];

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(SynchroSpacing.gutter),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                campus.subjectName(assignment.subjectId),
                style: Theme.of(sheetContext).textTheme.headlineSmall,
              ),
              const SizedBox(height: SynchroSpacing.xs),
              Text(
                '${dayName(assignment.day)} · period ${assignment.index + 1} · '
                '${formatMinutes(assignment.start)}–${formatMinutes(assignment.end)}',
                style: Theme.of(sheetContext).textTheme.bodySmall,
              ),
              const SizedBox(height: SynchroSpacing.lg),
              _Detail('Batch', campus.batchName(assignment.batchId)),
              _Detail('Faculty', campus.facultyName(assignment.facultyId)),
              _Detail('Room', '${campus.roomName(assignment.roomId)} · ${assignment.isLab ? 'laboratory' : 'classroom'}'),
              if (room != null && batch != null)
                _Detail('Capacity', '${room.capacity} seats for ${batch.size} students'),
              _Detail('Department', assignment.department.isEmpty ? 'unassigned' : assignment.department),
              const SizedBox(height: SynchroSpacing.lg),
              if (violations.isEmpty)
                const Notice(
                  tone: Tone.good,
                  icon: Icons.verified_outlined,
                  text: 'The validator found no problem in this session.',
                )
              else
                for (final violation in violations)
                  Notice(tone: Tone.bad, icon: Icons.error_outline, text: violation.message),
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
            SizedBox(width: 92, child: Text(label.toUpperCase(), style: Theme.of(context).textTheme.labelSmall)),
            Expanded(child: Text(value, style: Theme.of(context).textTheme.bodyMedium)),
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
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
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
        swatch(SynchroColors.navySoft, 'Lab (2 periods)'),
        swatch(SynchroColors.cream, 'Break'),
      ],
    );
  }
}
