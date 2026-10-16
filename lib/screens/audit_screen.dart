import 'package:flutter/material.dart';

import '../state/scheduling_controller.dart';
import '../theme/tokens.dart';
import '../widgets/ui.dart';

/// FEATURE 1 (workload distribution) and FEATURE 2 (resource audit), read straight
/// from the server's summary so the numbers on screen are the numbers the solver
/// will be held to.
class AuditScreen extends StatelessWidget {
  const AuditScreen({super.key, required this.controller});

  final SchedulingController controller;

  @override
  Widget build(BuildContext context) {
    final summary = controller.summary;
    final campus = controller.campus;

    if (controller.phase == LinkPhase.connecting && summary == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (summary == null || campus == null) {
      return EmptyState(
        title: 'No campus loaded',
        body: controller.linkError ?? 'SYNCHRO needs the solver backend before it can audit a workload.',
        icon: Icons.cloud_off_outlined,
        action: FilledButton(onPressed: controller.loadDemoCampus, child: const Text('Load demo campus')),
      );
    }

    final labDemand = summary.labPeriods;
    final lectureDemand = summary.lecturePeriods;

    return ListView(
      padding: const EdgeInsets.fromLTRB(SynchroSpacing.gutter, SynchroSpacing.lg, SynchroSpacing.gutter, SynchroSpacing.xxl),
      children: [
        if (summary.blocker != null)
          Notice(
            tone: Tone.bad,
            icon: Icons.block_outlined,
            text: summary.blocker!,
          ),
        if (summary.blocker == null)
          const Notice(
            tone: Tone.good,
            icon: Icons.verified_outlined,
            text: 'Feasibility pre-check passed: demand, availability and room capacity are consistent. '
                'The solver can be asked for a timetable.',
          ),
        SectionCard(
          overline: 'Feature 1',
          title: 'Workload distribution',
          trailing: StatusChip(
            label: '${summary.sessions} sessions',
            tone: summary.canGenerate ? Tone.good : Tone.bad,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MeterRow(label: 'Lecture periods demanded', value: lectureDemand, limit: summary.classroomCapacity),
              MeterRow(label: 'Laboratory periods demanded', value: labDemand, limit: summary.laboratoryCapacity),
              const Divider(height: SynchroSpacing.xl),
              Text(
                '${summary.dayCount} teaching days, ${summary.usablePeriods} usable periods '
                '(${summary.totalPeriods - summary.usablePeriods} held for breaks)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: SynchroSpacing.lg),
        if (summary.warnings.isNotEmpty) ...[
          SectionCard(
            title: 'Consistency warnings',
            overline: 'Before solving',
            trailing: StatusChip(label: '${summary.warnings.length}', tone: Tone.warn, icon: Icons.warning_amber),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final warning in summary.warnings)
                  Padding(
                    padding: const EdgeInsets.only(bottom: SynchroSpacing.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 3),
                          child: Icon(Icons.circle, size: 6, color: SynchroColors.warn),
                        ),
                        const SizedBox(width: SynchroSpacing.md),
                        Expanded(child: Text(warning, style: Theme.of(context).textTheme.bodySmall)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: SynchroSpacing.lg),
        ],
        SectionCard(
          title: 'Faculty load',
          overline: 'Weekly hours assigned',
          child: Column(
            children: [
              for (final row in summary.faculty)
                MeterRow(
                  label: '${row['name']}',
                  value: (row['assigned_hours'] as int? ?? 0),
                  limit: (row['max_weekly_hours'] as int? ?? 0),
                  detail: '${row['sessions']} sessions · ${row['subjects'].length} subjects'
                      '${(row['no_capacity'] as bool? ?? false) ? ' · only ${row['available_periods']} periods available' : ''}',
                ),
            ],
          ),
        ),
        const SizedBox(height: SynchroSpacing.lg),
        SectionCard(
          title: 'Room inventory',
          overline: 'Feature 2',
          trailing: StatusChip(label: '${summary.rooms.length} rooms', icon: Icons.meeting_room_outlined),
          child: Column(
            children: [
              for (final row in summary.rooms) _RoomRow(row: row),
            ],
          ),
        ),
        const SizedBox(height: SynchroSpacing.lg),
        SectionCard(
          title: 'Batches',
          overline: 'Student groups',
          child: Column(
            children: [
              for (final row in summary.batches)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: SynchroSpacing.xs),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 78,
                        child: Text('${row['name']}', style: Theme.of(context).textTheme.titleSmall),
                      ),
                      Expanded(
                        child: Text(
                          'Year ${row['year']} · ${row['size']} students · '
                          '${row['lecture_hours']} lecture + ${row['lab_periods']} lab periods',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoomRow extends StatelessWidget {
  const _RoomRow({required this.row});

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final kind = row['kind'] as String? ?? 'classroom';
    final closed = row['closed_periods'] as int? ?? 0;
    final borrowable = row['borrowable'] as bool? ?? true;
    final department = (row['department'] as String? ?? '').isEmpty ? 'unassigned' : row['department'] as String;
    final Widget? chip = closed > 0
        ? StatusChip(label: '$closed closed', tone: Tone.warn)
        : (!borrowable ? const StatusChip(label: 'locked', tone: Tone.bad) : null);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SynchroSpacing.xs),
      child: Row(
        children: [
          Icon(
            kind == 'laboratory' ? Icons.computer_outlined : Icons.class_outlined,
            size: 16,
            color: kind == 'laboratory' ? SynchroColors.navySoft : SynchroColors.inkMuted,
          ),
          const SizedBox(width: SynchroSpacing.md),
          SizedBox(width: 74, child: Text('${row['name']}', style: Theme.of(context).textTheme.titleSmall)),
          Expanded(
            child: Text(
              '$department · ${row['capacity']} seats · ${row['usable_periods']} usable periods',
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ?chip,
        ],
      ),
    );
  }
}
