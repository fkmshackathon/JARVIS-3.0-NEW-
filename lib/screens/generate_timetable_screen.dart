import 'package:flutter/material.dart';

import '../state/manual_timetable_controller.dart';
import '../theme/tokens.dart';
import '../widgets/ui.dart';
import 'manual_timetable_screen.dart';

/// The main product surface: a truthful pre-generation hand-off followed by
/// the timetable produced from the current setup input.
class GenerateTimetableScreen extends StatelessWidget {
  const GenerateTimetableScreen({
    super.key,
    required this.controller,
    this.onOpenSetup,
    this.onOpenWorkload,
    this.onOpenRooms,
    this.onHandleChange,
    this.onOpenIssues,
  });

  final ManualTimetableController controller;
  final VoidCallback? onOpenSetup;
  final VoidCallback? onOpenWorkload;
  final VoidCallback? onOpenRooms;
  final VoidCallback? onHandleChange;
  final VoidCallback? onOpenIssues;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      if (!controller.hasGeneratedTimetable) {
        return _GenerationLanding(
          controller: controller,
          onOpenSetup: onOpenSetup,
          onGenerate: () => _generate(context),
        );
      }

      return Scaffold(
        body: Column(
          children: [
            _GenerationOutcome(
              controller: controller,
              onGenerate: () => _generate(context),
              onOpenIssues: onOpenIssues,
            ),
            Expanded(
              child: controller.sessions.isEmpty
                  ? _NoGeneratedSessions(
                      controller: controller,
                      onGenerate: () => _generate(context),
                      onOpenSetup: onOpenSetup,
                    )
                  : ManualTimetableScreen(
                      controller: controller,
                      onOpenWorkload: onOpenWorkload,
                      onOpenRooms: onOpenRooms,
                      onHandleChange: onHandleChange,
                      onOpenIssues: onOpenIssues,
                    ),
            ),
          ],
        ),
      );
    },
  );

  void _generate(BuildContext context) {
    final setupIssues = controller.validateSetup();
    if (setupIssues.isNotEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(setupIssues.first.message)));
      onOpenSetup?.call();
      return;
    }
    if (!controller.canGenerate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complete setup before generating a timetable.'),
        ),
      );
      onOpenSetup?.call();
      return;
    }
    final result = controller.generateTimetable();
    final label = result.isSuccess
        ? 'Timetable generated locally.'
        : result.message;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(label)));
  }
}

class _GenerationLanding extends StatelessWidget {
  const _GenerationLanding({
    required this.controller,
    this.onOpenSetup,
    required this.onGenerate,
  });

  final ManualTimetableController controller;
  final VoidCallback? onOpenSetup;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              SynchroSpacing.gutter,
              SynchroSpacing.lg,
              SynchroSpacing.gutter,
              SynchroSpacing.xxl,
            ),
            children: [
              Text(
                'Generate & Timetable',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: SynchroSpacing.xs),
              Text(
                'The schedule is created from the configured teaching requirements. Nothing is shown until you run the generator.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: SynchroSpacing.lg),
              SectionCard(
                overline: 'Before generation',
                title: 'Review the inputs',
                child: Column(
                  children: [
                    _SummaryRow(
                      icon: Icons.people_outline,
                      label: 'Faculty workload records',
                      value: '${controller.faculty.length}',
                    ),
                    _SummaryRow(
                      icon: Icons.groups_outlined,
                      label: 'Batches / divisions',
                      value: '${controller.batches.length}',
                    ),
                    _SummaryRow(
                      icon: Icons.menu_book_outlined,
                      label: 'Subjects',
                      value: '${controller.subjects.length}',
                    ),
                    _SummaryRow(
                      icon: Icons.meeting_room_outlined,
                      label: 'Rooms and labs',
                      value: '${controller.rooms.length}',
                    ),
                    _SummaryRow(
                      icon: Icons.assignment_outlined,
                      label: 'Required teaching blocks',
                      value: '${controller.requirements.length}',
                    ),
                    _SummaryRow(
                      icon: Icons.calendar_view_week_outlined,
                      label: 'Working days',
                      value: '${controller.workingDays.length}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: SynchroSpacing.md),
              Notice(
                tone: controller.canGenerate ? Tone.neutral : Tone.warn,
                icon: controller.canGenerate
                    ? Icons.info_outline
                    : Icons.warning_amber_outlined,
                text: controller.canGenerate
                    ? 'The local scheduler will prioritise scarce labs and faculty, enforce hard constraints, and explain any unassigned sessions.'
                    : 'Setup is incomplete. Add faculty, batches, subjects, rooms, working days, and teaching requirements before generating.',
              ),
              const SizedBox(height: SynchroSpacing.lg),
              FilledButton.icon(
                onPressed: controller.canGenerate ? onGenerate : onOpenSetup,
                icon: Icon(
                  controller.canGenerate
                      ? Icons.play_arrow_outlined
                      : Icons.tune_outlined,
                ),
                label: Text(
                  controller.canGenerate
                      ? 'Generate timetable'
                      : 'Complete setup first',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: controller.canGenerate
                      ? SynchroColors.orange
                      : SynchroColors.navy,
                  foregroundColor: controller.canGenerate
                      ? SynchroColors.navyDeep
                      : SynchroColors.onNavy,
                ),
              ),
              const SizedBox(height: SynchroSpacing.sm),
              Text(
                'Status: not generated',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _GenerationOutcome extends StatelessWidget {
  const _GenerationOutcome({
    required this.controller,
    required this.onGenerate,
    this.onOpenIssues,
  });

  final ManualTimetableController controller;
  final VoidCallback onGenerate;
  final VoidCallback? onOpenIssues;

  @override
  Widget build(BuildContext context) {
    final result = controller.generationResult;
    final needsRegeneration = controller.needsRegeneration;
    final success = result?.isSuccess == true && !needsRegeneration;
    final tone = success ? Tone.good : Tone.warn;
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.fromLTRB(
        SynchroSpacing.gutter,
        SynchroSpacing.sm,
        SynchroSpacing.gutter,
        SynchroSpacing.sm,
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Icon(
              success
                  ? Icons.check_circle_outline
                  : Icons.warning_amber_outlined,
              color: StatusChip.color(tone, Theme.of(context).brightness),
            ),
            const SizedBox(width: SynchroSpacing.sm),
            Expanded(
              child: Text(
                needsRegeneration
                    ? 'Setup changed. Regenerate to apply the latest local inputs.'
                    : result?.message ?? 'Generation completed.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            if (onOpenIssues != null && controller.issues.isNotEmpty)
              TextButton(onPressed: onOpenIssues, child: const Text('Issues')),
            IconButton(
              tooltip: needsRegeneration
                  ? 'Regenerate timetable'
                  : 'Generate again',
              onPressed: onGenerate,
              icon: const Icon(Icons.refresh_outlined),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoGeneratedSessions extends StatelessWidget {
  const _NoGeneratedSessions({
    required this.controller,
    required this.onGenerate,
    this.onOpenSetup,
  });

  final ManualTimetableController controller;
  final VoidCallback onGenerate;
  final VoidCallback? onOpenSetup;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(SynchroSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.event_busy_outlined, size: 42),
          const SizedBox(height: SynchroSpacing.md),
          Text(
            controller.generationStatus == TimetableGenerationStatus.infeasible
                ? 'No sessions could be placed.'
                : 'No timetable sessions yet.',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: SynchroSpacing.sm),
          Text(
            'Open Issues for the exact unassigned requirements and constraints.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: SynchroSpacing.lg),
          Wrap(
            spacing: SynchroSpacing.sm,
            children: [
              OutlinedButton(
                onPressed: onOpenSetup,
                child: const Text('Edit setup'),
              ),
              FilledButton(
                onPressed: onGenerate,
                child: const Text('Try again'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: SynchroSpacing.sm),
    child: Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: SynchroSpacing.md),
        Expanded(child: Text(label)),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}
