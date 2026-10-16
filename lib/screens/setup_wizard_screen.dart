import 'package:flutter/material.dart';

import '../data/models.dart';
import '../state/scheduling_controller.dart';
import '../theme/tokens.dart';
import '../widgets/ui.dart';

/// A read-only review of the loaded campus followed by one real solver call.
/// The wizard deliberately does not offer client-side editing: the backend owns
/// the campus definition used by both the solver and the validator.
class SetupWizardScreen extends StatefulWidget {
  const SetupWizardScreen({
    super.key,
    required this.controller,
    this.onBack,
    this.onOpenTimetable,
    this.onGenerated,
  });

  final SchedulingController controller;
  final VoidCallback? onBack;
  final VoidCallback? onOpenTimetable;
  final ValueChanged<GenerationResult>? onGenerated;

  @override
  State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends State<SetupWizardScreen> {
  static const int _stepCount = 6;

  int _step = 0;
  bool _generating = false;

  SchedulingController get controller => widget.controller;

  bool get _hasCampus => controller.campus != null;
  bool get _canGenerate => _hasCampus && controller.canGenerate && !_generating;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: _step == 0 ? 'Close setup' : 'Previous step',
          onPressed: _goBack,
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Create a New Timetable'),
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => SafeArea(
          top: false,
          child: Column(
            children: [
              _ProgressHeader(step: _step, stepTitle: _stepTitle(_step)),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    SynchroSpacing.gutter,
                    SynchroSpacing.md,
                    SynchroSpacing.gutter,
                    SynchroSpacing.xl,
                  ),
                  child: AnimatedSwitcher(
                    duration: SynchroMotion.standard,
                    switchInCurve: SynchroMotion.entrance,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, animation) {
                      final offset =
                          Tween<Offset>(
                            begin: const Offset(0.08, 0),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: SynchroMotion.entrance,
                            ),
                          );
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(position: offset, child: child),
                      );
                    },
                    child: KeyedSubtree(
                      key: ValueKey(_step),
                      child: _StepBody(step: _step, controller: controller),
                    ),
                  ),
                ),
              ),
              _WizardActions(
                step: _step,
                stepCount: _stepCount,
                canContinue: _hasCampus,
                canGenerate: _canGenerate,
                generating:
                    _generating || controller.runPhase == RunPhase.running,
                onBack: _goBack,
                onContinue: _goNext,
                onGenerate: _generate,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _generate() async {
    if (!_canGenerate) return;
    final previousResult = controller.result;
    setState(() => _generating = true);
    await controller.generate();
    if (!mounted) return;
    setState(() => _generating = false);
    final result = controller.result;
    if (controller.runPhase == RunPhase.done &&
        result != null &&
        !identical(result, previousResult)) {
      widget.onGenerated?.call(result);
    }
  }

  void _goNext() {
    if (_step >= _stepCount - 1 || !_hasCampus) return;
    setState(() => _step += 1);
  }

  void _goBack() {
    if (_step > 0) {
      setState(() => _step -= 1);
      return;
    }
    if (widget.onBack != null) {
      widget.onBack!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  static String _stepTitle(int step) => switch (step) {
    0 => 'Campus',
    1 => 'Demand',
    2 => 'Faculty',
    3 => 'Rooms and batches',
    4 => 'Review',
    5 => 'Generate',
    _ => 'Review',
  };
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.step, required this.stepTitle});

  final int step;
  final String stepTitle;

  @override
  Widget build(BuildContext context) {
    final progress = (step + 1) / 6;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SynchroSpacing.gutter,
        SynchroSpacing.sm,
        SynchroSpacing.gutter,
        SynchroSpacing.md,
      ),
      child: Semantics(
        label: 'Setup progress: step ${step + 1} of 6, $stepTitle',
        value: '${(progress * 100).round()} percent complete',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Step ${step + 1} of 6',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
                Text(stepTitle, style: Theme.of(context).textTheme.labelMedium),
              ],
            ),
            const SizedBox(height: SynchroSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(SynchroRadius.pill),
              child: LinearProgressIndicator(value: progress, minHeight: 6),
            ),
          ],
        ),
      ),
    );
  }
}

class _WizardActions extends StatelessWidget {
  const _WizardActions({
    required this.step,
    required this.stepCount,
    required this.canContinue,
    required this.canGenerate,
    required this.generating,
    required this.onBack,
    required this.onContinue,
    required this.onGenerate,
  });

  final int step;
  final int stepCount;
  final bool canContinue;
  final bool canGenerate;
  final bool generating;
  final VoidCallback onBack;
  final VoidCallback onContinue;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          SynchroSpacing.gutter,
          SynchroSpacing.sm,
          SynchroSpacing.gutter,
          SynchroSpacing.md,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        child: Row(
          children: [
            TextButton(
              onPressed: onBack,
              child: Text(step == 0 ? 'Cancel' : 'Back'),
            ),
            const Spacer(),
            if (step < stepCount - 1)
              FilledButton.icon(
                onPressed: canContinue ? onContinue : null,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Continue'),
              )
            else
              FilledButton.icon(
                onPressed: canGenerate ? onGenerate : null,
                style: FilledButton.styleFrom(
                  backgroundColor: SynchroColors.orange,
                  foregroundColor: SynchroColors.navyDeep,
                ),
                icon: Icon(generating ? Icons.sync : Icons.bolt),
                label: Text(generating ? 'Generating…' : 'Generate timetable'),
              ),
          ],
        ),
      ),
    );
  }
}

class _StepBody extends StatelessWidget {
  const _StepBody({required this.step, required this.controller});

  final int step;
  final SchedulingController controller;

  @override
  Widget build(BuildContext context) => switch (step) {
    0 => _CampusStep(controller: controller),
    1 => _DemandStep(controller: controller),
    2 => _FacultyStep(controller: controller),
    3 => _RoomsAndBatchesStep(controller: controller),
    4 => _ReviewStep(controller: controller),
    5 => _GenerateStep(controller: controller),
    _ => const SizedBox.shrink(),
  };
}

class _CampusStep extends StatelessWidget {
  const _CampusStep({required this.controller});

  final SchedulingController controller;

  @override
  Widget build(BuildContext context) {
    final campus = controller.campus;
    if (campus == null) {
      return SectionCard(
        overline: 'Connected source',
        title: 'Load a campus to begin',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              controller.linkError ?? 'The solver backend has not supplied a campus definition yet. Setup cannot review or generate without it.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: SynchroSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: controller.phase == LinkPhase.connecting
                    ? null
                    : controller.loadDemoCampus,
                icon: const Icon(Icons.download_outlined),
                label: Text(
                  controller.phase == LinkPhase.connecting
                      ? 'Loading campus…'
                      : 'Load demo campus',
                ),
              ),
            ),
            const SizedBox(height: SynchroSpacing.md),
            const Notice(
              tone: Tone.neutral,
              icon: Icons.lock_outline,
              text: 'Campus editing is not supported in this client. The backend definition is reviewed as received.',
            ),
          ],
        ),
      );
    }

    return SectionCard(
      overline: 'Connected source',
      title: campus.name,
      trailing: const StatusChip(
        label: 'loaded',
        tone: Tone.good,
        icon: Icons.cloud_done_outlined,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This run will use the campus definition returned by the solver backend.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: SynchroSpacing.lg),
          Wrap(
            spacing: SynchroSpacing.xl,
            runSpacing: SynchroSpacing.lg,
            children: [
              Stat(value: '${campus.slots.length}', caption: 'slots'),
              Stat(value: '${campus.subjects.length}', caption: 'subjects'),
              Stat(value: '${campus.batches.length}', caption: 'batches'),
              Stat(value: '${campus.rooms.length}', caption: 'rooms'),
            ],
          ),
          const SizedBox(height: SynchroSpacing.lg),
          const Notice(
            tone: Tone.neutral,
            icon: Icons.info_outline,
            text: 'Review only: editing campus data, signing in, and publishing are not available here.',
          ),
        ],
      ),
    );
  }
}

class _DemandStep extends StatelessWidget {
  const _DemandStep({required this.controller});

  final SchedulingController controller;

  @override
  Widget build(BuildContext context) {
    final summary = controller.summary;
    if (summary == null) return const _MissingSummary();

    return SectionCard(
      overline: 'Demand review',
      title: 'What the week needs',
      trailing: StatusChip(
        label: summary.canGenerate ? 'preflight passed' : 'needs review',
        tone: summary.canGenerate ? Tone.good : Tone.bad,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MeterRow(
            label: 'Lecture periods demanded',
            value: summary.lecturePeriods,
            limit: summary.classroomCapacity,
          ),
          MeterRow(
            label: 'Laboratory periods demanded',
            value: summary.labPeriods,
            limit: summary.laboratoryCapacity,
          ),
          const Divider(height: SynchroSpacing.xl),
          Text(
            '${summary.sessions} sessions across ${summary.dayCount} teaching days and '
            '${summary.usablePeriods} usable periods.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (summary.blocker != null) ...[
            const SizedBox(height: SynchroSpacing.md),
            Notice(
              tone: Tone.bad,
              icon: Icons.block_outlined,
              text: summary.blocker!,
            ),
          ] else if (summary.warnings.isNotEmpty) ...[
            const SizedBox(height: SynchroSpacing.md),
            Notice(
              tone: Tone.warn,
              icon: Icons.warning_amber_outlined,
              text:
                  '${summary.warnings.length} consistency warning${summary.warnings.length == 1 ? '' : 's'} '
                  'came from the backend preflight.',
            ),
          ],
        ],
      ),
    );
  }
}

class _FacultyStep extends StatelessWidget {
  const _FacultyStep({required this.controller});

  final SchedulingController controller;

  @override
  Widget build(BuildContext context) {
    final campus = controller.campus;
    final summary = controller.summary;
    if (campus == null) return const _MissingCampus();

    final loadByName = <String, Map<String, dynamic>>{
      for (final row in summary?.faculty ?? const <Map<String, dynamic>>[])
        '${row['name']}': row,
    };

    return SectionCard(
      overline: 'Faculty review',
      title: 'Who can teach the sessions',
      trailing: StatusChip(label: '${campus.faculty.length} faculty'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Qualifications, availability and weekly caps remain server-side constraints.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: SynchroSpacing.md),
          if (campus.faculty.isEmpty)
            Text(
              'No faculty records were returned.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            for (final faculty in campus.faculty)
              _FacultyRow(faculty: faculty, summary: loadByName[faculty.name]),
        ],
      ),
    );
  }
}

class _FacultyRow extends StatelessWidget {
  const _FacultyRow({required this.faculty, this.summary});

  final Faculty faculty;
  final Map<String, dynamic>? summary;

  @override
  Widget build(BuildContext context) {
    final assigned = summary?['assigned_hours'] as int?;
    final sessions = summary?['sessions'] as int?;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SynchroSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: SynchroColors.cream,
            foregroundColor: SynchroColors.navy,
            child: Text(
              faculty.name.isEmpty
                  ? '?'
                  : faculty.name.characters.first.toUpperCase(),
            ),
          ),
          const SizedBox(width: SynchroSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  faculty.name,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  faculty.department.isEmpty
                      ? 'Department not specified'
                      : faculty.department,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (assigned != null)
            Text(
              '$assigned h${sessions == null ? '' : ' · $sessions sessions'}',
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}

class _RoomsAndBatchesStep extends StatelessWidget {
  const _RoomsAndBatchesStep({required this.controller});

  final SchedulingController controller;

  @override
  Widget build(BuildContext context) {
    final campus = controller.campus;
    if (campus == null) return const _MissingCampus();

    return Column(
      children: [
        SectionCard(
          overline: 'Resource review',
          title: 'Rooms and capacity',
          trailing: StatusChip(
            label: '${campus.rooms.length} rooms',
            icon: Icons.meeting_room_outlined,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (campus.rooms.isEmpty)
                Text(
                  'No rooms were returned.',
                  style: Theme.of(context).textTheme.bodyMedium,
                )
              else
                for (final room in campus.rooms)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: SynchroSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          room.isLab
                              ? Icons.computer_outlined
                              : Icons.class_outlined,
                          size: 18,
                          color: room.isLab
                              ? SynchroColors.navySoft
                              : SynchroColors.inkMuted,
                        ),
                        const SizedBox(width: SynchroSpacing.md),
                        Expanded(
                          child: Text(
                            room.name,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        Text(
                          '${room.capacity} seats',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
        const SizedBox(height: SynchroSpacing.lg),
        SectionCard(
          overline: 'Student groups',
          title: 'Batches in scope',
          trailing: StatusChip(label: '${campus.batches.length} batches'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (campus.batches.isEmpty)
                Text(
                  'No batches were returned.',
                  style: Theme.of(context).textTheme.bodyMedium,
                )
              else
                for (final batch in campus.batches)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: SynchroSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            batch.name,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        Text(
                          'Year ${batch.year} · ${batch.size} students',
                          style: Theme.of(context).textTheme.bodySmall,
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

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({required this.controller});

  final SchedulingController controller;

  @override
  Widget build(BuildContext context) {
    final campus = controller.campus;
    final summary = controller.summary;

    return Column(
      children: [
        SectionCard(
          overline: 'Final review',
          title: 'Ready to ask the solver?',
          trailing: StatusChip(
            label: controller.canGenerate ? 'ready' : 'blocked',
            tone: controller.canGenerate ? Tone.good : Tone.bad,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ReviewLine('Campus', campus?.name ?? 'Not loaded'),
              _ReviewLine('Backend', controller.backendUrl),
              _ReviewLine(
                'Demand',
                summary == null
                    ? 'Not available'
                    : '${summary.sessions} sessions',
              ),
              _ReviewLine(
                'Solver budget',
                '${controller.timeLimitSeconds.toInt()} seconds',
              ),
              _ReviewLine('Seed', '${controller.randomSeed}'),
              if (summary?.blocker != null) ...[
                const SizedBox(height: SynchroSpacing.md),
                Notice(
                  tone: Tone.bad,
                  icon: Icons.block_outlined,
                  text: summary!.blocker!,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: SynchroSpacing.lg),
        const Notice(
          tone: Tone.neutral,
          icon: Icons.info_outline,
          text: 'This review does not edit the campus. Authentication and publishing are not configured in this client.',
        ),
      ],
    );
  }
}

class _GenerateStep extends StatelessWidget {
  const _GenerateStep({required this.controller});

  final SchedulingController controller;

  @override
  Widget build(BuildContext context) {
    final summary = controller.summary;
    final result = controller.result;
    final running = controller.runPhase == RunPhase.running;

    return Column(
      children: [
        SectionCard(
          overline: 'Solver hand-off',
          title: running ? 'Generating timetable…' : 'Generate timetable',
          trailing: running
              ? const StatusChip(
                  label: 'running',
                  tone: Tone.warn,
                  icon: Icons.sync,
                )
              : result == null
              ? const StatusChip(label: 'not run', icon: Icons.schedule)
              : StatusChip(
                  label: result.solved ? 'solved' : 'no solution',
                  tone: result.solved ? Tone.good : Tone.bad,
                ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (summary?.blocker != null)
                Notice(
                  tone: Tone.bad,
                  icon: Icons.block_outlined,
                  text: summary!.blocker!,
                )
              else if (!controller.canGenerate)
                const Notice(
                  tone: Tone.warn,
                  icon: Icons.hourglass_empty,
                  text: 'The backend has not confirmed that this campus can generate a timetable yet.',
                )
              else
                const Text(
                  'The server will assign periods and rooms, then return its validator verdict.',
                ),
              if (controller.runError != null) ...[
                const SizedBox(height: SynchroSpacing.md),
                Notice(
                  tone: Tone.bad,
                  icon: Icons.error_outline,
                  text: controller.runError!,
                ),
              ],
              if (running) ...[
                const SizedBox(height: SynchroSpacing.lg),
                const LinearProgressIndicator(minHeight: 3),
                const SizedBox(height: SynchroSpacing.sm),
                Text(
                  'Assigning periods, then rooms, then re-checking with the validator.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (result != null && !running) ...[
                const SizedBox(height: SynchroSpacing.lg),
                _ResultSummary(result: result),
                if (result.solved) ...[
                  const SizedBox(height: SynchroSpacing.md),
                  const Notice(
                    tone: Tone.neutral,
                    icon: Icons.open_in_new,
                    text: 'The timetable is available from the real result. Publishing is not supported here.',
                  ),
                ],
              ],
            ],
          ),
        ),
        const SizedBox(height: SynchroSpacing.lg),
        _SolverOptions(controller: controller),
      ],
    );
  }
}

class _SolverOptions extends StatelessWidget {
  const _SolverOptions({required this.controller});

  final SchedulingController controller;

  static const List<double> _budgets = [5, 10, 20, 40];

  @override
  Widget build(BuildContext context) {
    final enabled = controller.runPhase != RunPhase.running;
    return SectionCard(
      overline: 'Solver options',
      title: 'Time budget and seed',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'These values are sent to the backend with the generate request.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: SynchroSpacing.md),
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
          const SizedBox(height: SynchroSpacing.md),
          Row(
            children: [
              Text('Seed', style: Theme.of(context).textTheme.labelMedium),
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
            ],
          ),
        ],
      ),
    );
  }
}

class _ResultSummary extends StatelessWidget {
  const _ResultSummary({required this.result});

  final GenerationResult result;

  @override
  Widget build(BuildContext context) {
    final violations = result.violations.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Stat(
                value: '${result.assignments.length}',
                caption: 'sessions',
              ),
            ),
            Expanded(
              child: Stat(
                value: '${result.wallTimeMs} ms',
                caption: 'solver time',
              ),
            ),
            Expanded(
              child: Stat(
                value: '$violations',
                caption: 'violations',
                tone: violations == 0 ? Tone.good : Tone.bad,
              ),
            ),
          ],
        ),
        const SizedBox(height: SynchroSpacing.md),
        Text(
          result.publishable
              ? 'The server marked this result publishable.'
              : 'The server did not mark this result publishable.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (!result.solved && result.message.isNotEmpty) ...[
          const SizedBox(height: SynchroSpacing.md),
          Notice(
            tone: Tone.bad,
            icon: Icons.help_outline,
            text: result.message,
          ),
        ],
      ],
    );
  }
}

class _ReviewLine extends StatelessWidget {
  const _ReviewLine(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: SynchroSpacing.sm),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 104,
          child: Text(label, style: Theme.of(context).textTheme.labelSmall),
        ),
        Expanded(
          child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    ),
  );
}

class _MissingCampus extends StatelessWidget {
  const _MissingCampus();

  @override
  Widget build(BuildContext context) => const SectionCard(
    overline: 'Campus data',
    title: 'Campus not loaded',
    child: Notice(
      tone: Tone.warn,
      icon: Icons.cloud_off_outlined,
      text: 'Return to the Campus step and load a real campus from the backend before continuing.',
    ),
  );
}

class _MissingSummary extends StatelessWidget {
  const _MissingSummary();

  @override
  Widget build(BuildContext context) => const SectionCard(
    overline: 'Demand review',
    title: 'Summary not available',
    child: Notice(
      tone: Tone.warn,
      icon: Icons.info_outline,
      text: 'The backend did not return a summary, so the wizard cannot make a feasibility claim.',
    ),
  );
}
