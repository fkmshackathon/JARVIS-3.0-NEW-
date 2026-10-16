import 'package:flutter/material.dart';

import '../brand/synchro_mark.dart';
import '../state/scheduling_controller.dart';
import '../theme/tokens.dart';
import '../widgets/ui.dart';

/// The first surface after launch. It is intentionally small: coordinators can
/// start a run or inspect the latest one without having to understand the whole
/// audit area first.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    this.onCreateTimetable,
    this.onRefineTimetable,
    this.onOpenAccount,
    this.onOpenAudit,
  });

  final SchedulingController controller;
  final VoidCallback? onCreateTimetable;
  final VoidCallback? onRefineTimetable;
  final VoidCallback? onOpenAccount;
  final VoidCallback? onOpenAudit;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => SafeArea(
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _Header(onOpenAccount: onOpenAccount)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  SynchroSpacing.gutter,
                  SynchroSpacing.md,
                  SynchroSpacing.gutter,
                  SynchroSpacing.xxl,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _WelcomeCard(controller: controller),
                    const SizedBox(height: SynchroSpacing.lg),
                    _PrimaryActions(
                      onCreateTimetable: onCreateTimetable,
                      onRefineTimetable: onRefineTimetable,
                    ),
                    const SizedBox(height: SynchroSpacing.xl),
                    _LiveSummary(controller: controller),
                    if (onOpenAudit != null) ...[
                      const SizedBox(height: SynchroSpacing.md),
                      OutlinedButton.icon(
                        onPressed: onOpenAudit,
                        icon: const Icon(Icons.tune_outlined),
                        label: const Text('Review workload and rooms'),
                      ),
                    ],
                    if (controller.result != null) ...[
                      const SizedBox(height: SynchroSpacing.lg),
                      _LatestRun(controller: controller),
                    ],
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({this.onOpenAccount});

  final VoidCallback? onOpenAccount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SynchroSpacing.gutter,
        SynchroSpacing.lg,
        SynchroSpacing.gutter,
        SynchroSpacing.sm,
      ),
      child: Row(
        children: [
          const SynchroWordmark(size: 38, onDark: false),
          const Spacer(),
          if (onOpenAccount != null)
            IconButton(
              tooltip: 'Open account',
              onPressed: onOpenAccount,
              icon: const Icon(Icons.person_outline),
            ),
        ],
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.controller});

  final SchedulingController controller;

  @override
  Widget build(BuildContext context) {
    final campus = controller.campus;
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SynchroSpacing.xl),
      decoration: BoxDecoration(
        color: SynchroColors.navyDeep,
        borderRadius: BorderRadius.circular(SynchroRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            campus?.name ?? 'Your next week, in sync.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: SynchroColors.onNavy,
            ),
          ),
          const SizedBox(height: SynchroSpacing.sm),
          Text(
            campus == null
                ? 'Review the connected campus, then ask the solver for a timetable you can check.'
                : 'Review ${campus.name} before the solver turns its real constraints into a week.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: SynchroColors.onNavyMuted,
            ),
          ),
          const SizedBox(height: SynchroSpacing.lg),
          Row(
            children: [
              Icon(
                _phaseIcon(controller.phase),
                size: 16,
                color: SynchroColors.orange,
              ),
              const SizedBox(width: SynchroSpacing.sm),
              Expanded(
                child: Text(
                  _phaseLabel(controller.phase),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: SynchroColors.onNavy,
                  ),
                ),
              ),
              if (controller.campus != null)
                StatusChip(
                  label: controller.result?.solved == true
                      ? 'timetable ready'
                      : 'review first',
                  tone: controller.result?.solved == true
                      ? Tone.good
                      : Tone.neutral,
                  icon: controller.result?.solved == true
                      ? Icons.check_circle_outline
                      : Icons.rate_review_outlined,
                ),
            ],
          ),
        ],
      ),
    );
  }

  static IconData _phaseIcon(LinkPhase phase) => switch (phase) {
    LinkPhase.ready => Icons.cloud_done_outlined,
    LinkPhase.connecting => Icons.sync,
    LinkPhase.offline => Icons.cloud_off_outlined,
    LinkPhase.idle => Icons.cloud_queue_outlined,
  };

  static String _phaseLabel(LinkPhase phase) => switch (phase) {
    LinkPhase.ready => 'Connected to the solver backend',
    LinkPhase.connecting => 'Connecting to the solver backend',
    LinkPhase.offline => 'Solver backend is offline',
    LinkPhase.idle => 'Backend connection not checked',
  };
}

class _PrimaryActions extends StatelessWidget {
  const _PrimaryActions({this.onCreateTimetable, this.onRefineTimetable});

  final VoidCallback? onCreateTimetable;
  final VoidCallback? onRefineTimetable;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: onCreateTimetable,
          style: FilledButton.styleFrom(
            backgroundColor: SynchroColors.orange,
            foregroundColor: SynchroColors.navyDeep,
          ),
          icon: const Icon(Icons.add_task),
          label: const Text('Create a New Timetable'),
        ),
        const SizedBox(height: SynchroSpacing.md),
        FilledButton.icon(
          onPressed: onRefineTimetable,
          style: FilledButton.styleFrom(
            backgroundColor: SynchroColors.navy,
            foregroundColor: SynchroColors.onNavy,
          ),
          icon: const Icon(Icons.tune),
          label: const Text('Refine Existing Timetable'),
        ),
        if (onCreateTimetable == null || onRefineTimetable == null) ...[
          const SizedBox(height: SynchroSpacing.sm),
          Text(
            'Navigation actions are provided by the app shell.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _LiveSummary extends StatelessWidget {
  const _LiveSummary({required this.controller});

  final SchedulingController controller;

  @override
  Widget build(BuildContext context) {
    final campus = controller.campus;
    final summary = controller.summary;

    if (campus == null || summary == null) {
      return SectionCard(
        overline: 'Live campus data',
        title: 'No campus summary yet',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              controller.linkError ?? 'Load a campus from the solver backend to see real demand, people and room counts here.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (campus == null) ...[
              const SizedBox(height: SynchroSpacing.md),
              Text(
                'The summary stays empty until the backend responds.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      );
    }

    return SectionCard(
      overline: 'Live campus data',
      title: 'At a glance',
      trailing: StatusChip(
        label: summary.canGenerate ? 'ready to solve' : 'needs review',
        tone: summary.canGenerate ? Tone.good : Tone.bad,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: SynchroSpacing.xl,
            runSpacing: SynchroSpacing.lg,
            children: [
              Stat(value: '${summary.sessions}', caption: 'sessions'),
              Stat(value: '${campus.batches.length}', caption: 'batches'),
              Stat(value: '${campus.faculty.length}', caption: 'faculty'),
              Stat(value: '${campus.rooms.length}', caption: 'rooms'),
            ],
          ),
          const SizedBox(height: SynchroSpacing.lg),
          Text(
            '${summary.dayCount} teaching days · ${summary.usablePeriods} usable periods · '
            '${summary.lecturePeriods} lecture + ${summary.labPeriods} lab periods',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (summary.blocker != null) ...[
            const SizedBox(height: SynchroSpacing.md),
            Notice(
              tone: Tone.bad,
              icon: Icons.block_outlined,
              text: summary.blocker!,
            ),
          ],
        ],
      ),
    );
  }
}

class _LatestRun extends StatelessWidget {
  const _LatestRun({required this.controller});

  final SchedulingController controller;

  @override
  Widget build(BuildContext context) {
    final result = controller.result!;
    final violations = result.violations.length;

    return SectionCard(
      overline: 'Latest run #${result.runId}',
      title: result.solved ? 'Timetable produced' : 'No timetable produced',
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
            spacing: SynchroSpacing.xl,
            runSpacing: SynchroSpacing.lg,
            children: [
              Stat(value: '${result.assignments.length}', caption: 'sessions'),
              Stat(value: '${result.wallTimeMs} ms', caption: 'solver time'),
              Stat(
                value: '$violations',
                caption: 'violations',
                tone: violations == 0 ? Tone.good : Tone.bad,
              ),
            ],
          ),
          if (!result.solved && result.message.isNotEmpty) ...[
            const SizedBox(height: SynchroSpacing.md),
            Notice(
              tone: Tone.bad,
              icon: Icons.info_outline,
              text: result.message,
            ),
          ],
        ],
      ),
    );
  }
}
