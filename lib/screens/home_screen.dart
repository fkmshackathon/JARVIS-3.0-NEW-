import 'package:flutter/material.dart';

import '../brand/synchro_mark.dart';
import '../state/manual_timetable_controller.dart';
import '../theme/tokens.dart';
import '../widgets/ui.dart';

/// Calm entry point for the local timetable workspace. Every number here comes
/// from [ManualTimetableController]; the home screen never invents server
/// results or repeats solver metrics.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.manualController,
    this.onCreateTimetable,
    this.onRefineTimetable,
    this.onOpenWorkload,
    this.onOpenRooms,
    this.onOpenChanges,
    this.onOpenIssues,
  });

  final ManualTimetableController manualController;
  final VoidCallback? onCreateTimetable;
  final VoidCallback? onRefineTimetable;
  final VoidCallback? onOpenWorkload;
  final VoidCallback? onOpenRooms;
  final VoidCallback? onOpenChanges;
  final VoidCallback? onOpenIssues;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: ListenableBuilder(
      listenable: manualController,
      builder: (context, _) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            SynchroSpacing.gutter,
            SynchroSpacing.lg,
            SynchroSpacing.gutter,
            SynchroSpacing.xxl,
          ),
          children: [
            const _BrandHeader(),
            const SizedBox(height: SynchroSpacing.xl),
            Text(
              'Good morning',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: SynchroSpacing.xs),
            Text(
              'Demo campus · Semester 2026 · Timetable coordinator',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: SynchroSpacing.xs),
            Text(
              manualController.dataLabel,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: SynchroColors.orangeDeep,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: SynchroSpacing.xl),
            _PrimaryAction(
              label: manualController.hasUnsavedChanges
                  ? 'Continue editing'
                  : 'Create timetable',
              subtitle: manualController.hasUnsavedChanges
                  ? 'Return to your local draft.'
                  : 'Place classes into the week manually.',
              icon: manualController.hasUnsavedChanges
                  ? Icons.edit_calendar_outlined
                  : Icons.add_task,
              onPressed: onCreateTimetable,
            ),
            const SizedBox(height: SynchroSpacing.sm),
            OutlinedButton.icon(
              onPressed: onRefineTimetable,
              icon: const Icon(Icons.sync_alt_outlined),
              label: const Text('Handle a change'),
            ),
            const SizedBox(height: SynchroSpacing.xl),
            _DraftSummary(controller: manualController),
            const SizedBox(height: SynchroSpacing.lg),
            _IssueSummary(
              controller: manualController,
              onOpenIssues: onOpenIssues,
            ),
            const SizedBox(height: SynchroSpacing.lg),
            _SecondaryTools(
              onOpenWorkload: onOpenWorkload,
              onOpenRooms: onOpenRooms,
              onOpenChanges: onOpenChanges,
              onOpenIssues: onOpenIssues,
            ),
          ],
        ),
      ),
    ),
  );
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Expanded(
        child: FittedBox(
          alignment: Alignment.centerLeft,
          fit: BoxFit.scaleDown,
          child: SynchroWordmark(size: 34, onDark: false),
        ),
      ),
      const SizedBox(width: SynchroSpacing.sm),
      const StatusChip(
        label: 'Local demo',
        tone: Tone.neutral,
        icon: Icons.science_outlined,
      ),
    ],
  );
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    required this.label,
    required this.subtitle,
    required this.icon,
    this.onPressed,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: SynchroColors.orange,
    borderRadius: BorderRadius.circular(SynchroRadius.card),
    child: InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(SynchroRadius.card),
      child: Padding(
        padding: const EdgeInsets.all(SynchroSpacing.lg),
        child: Row(
          children: [
            Icon(icon, color: SynchroColors.navyDeep),
            const SizedBox(width: SynchroSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(color: SynchroColors.navyDeep),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: SynchroColors.navyDeep.withValues(alpha: 0.72),
                    ),
                  ),
                ],
              ),
            ),
            Icon(icon, color: SynchroColors.navyDeep),
          ],
        ),
      ),
    ),
  );
}

class _DraftSummary extends StatelessWidget {
  const _DraftSummary({required this.controller});

  final ManualTimetableController controller;

  @override
  Widget build(BuildContext context) => SectionCard(
    overline: 'Current draft',
    title: 'This week in progress',
    trailing: StatusChip(
      label: controller.hasLocalValidation
          ? controller.hardConflicts.isEmpty
                ? 'Locally checked'
                : 'Needs fixes'
          : controller.hasUnsavedChanges
          ? 'Unsaved'
          : 'Not checked',
      tone: controller.hasLocalValidation && controller.hardConflicts.isEmpty
          ? Tone.good
          : controller.hardConflicts.isNotEmpty
          ? Tone.bad
          : Tone.warn,
    ),
    child: Row(
      children: [
        Expanded(
          child: Stat(
            value: '${controller.sessions.length}',
            caption: 'classes',
          ),
        ),
        Expanded(
          child: Stat(
            value: '${controller.batches.length}',
            caption: 'batches',
          ),
        ),
        Expanded(
          child: Stat(value: '${controller.rooms.length}', caption: 'rooms'),
        ),
      ],
    ),
  );
}

class _IssueSummary extends StatelessWidget {
  const _IssueSummary({required this.controller, this.onOpenIssues});

  final ManualTimetableController controller;
  final VoidCallback? onOpenIssues;

  @override
  Widget build(BuildContext context) {
    final hard = controller.hardConflicts.length;
    final soft = controller.softWarnings.length;
    return SectionCard(
      overline: 'Needs attention',
      title: hard == 0 && soft == 0 ? 'No issues detected' : 'Review the draft',
      trailing: StatusChip(
        label: '${hard + soft}',
        tone: hard > 0
            ? Tone.bad
            : soft > 0
            ? Tone.warn
            : Tone.good,
        icon: hard > 0 ? Icons.error_outline : Icons.rule_folder_outlined,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              hard == 0 && soft == 0
                  ? 'The local checker has nothing to report yet.'
                  : '$hard hard conflict${hard == 1 ? '' : 's'} · $soft soft warning${soft == 1 ? '' : 's'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (onOpenIssues != null)
            TextButton(
              onPressed: onOpenIssues,
              child: const Text('Open issues'),
            ),
        ],
      ),
    );
  }
}

class _SecondaryTools extends StatelessWidget {
  const _SecondaryTools({
    this.onOpenWorkload,
    this.onOpenRooms,
    this.onOpenChanges,
    this.onOpenIssues,
  });

  final VoidCallback? onOpenWorkload;
  final VoidCallback? onOpenRooms;
  final VoidCallback? onOpenChanges;
  final VoidCallback? onOpenIssues;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Workspace tools', style: Theme.of(context).textTheme.labelSmall),
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
            onPressed: onOpenChanges,
            icon: const Icon(Icons.sync_alt_outlined, size: 18),
            label: const Text('Changes'),
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
