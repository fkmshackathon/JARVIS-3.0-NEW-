import 'package:flutter/material.dart';

import '../data/models.dart';
import '../state/scheduling_controller.dart';
import '../theme/tokens.dart';
import '../widgets/ui.dart';

/// FEATURE 5: this screen reports the server validator response. It does not
/// infer a clean schedule from an empty local list, and it keeps the validator's
/// known hard violations separate from soft preferences that the API does not
/// currently expose.
class ConflictsScreen extends StatefulWidget {
  const ConflictsScreen({super.key, required this.controller});

  final SchedulingController controller;

  @override
  State<ConflictsScreen> createState() => _ConflictsScreenState();
}

class _ConflictsScreenState extends State<ConflictsScreen> {
  bool _historyLoading = false;
  bool _revalidating = false;

  SchedulingController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    if (controller.hasCampus) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadHistory());
    }
  }

  Future<void> _loadHistory() async {
    if (_historyLoading || !mounted) return;
    setState(() => _historyLoading = true);
    try {
      await controller.loadHistory();
    } finally {
      if (mounted) setState(() => _historyLoading = false);
    }
  }

  Future<void> _revalidate() async {
    if (_revalidating) return;
    setState(() => _revalidating = true);
    try {
      await controller.revalidate();
    } finally {
      if (mounted) setState(() => _revalidating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!controller.hasCampus) {
      return const EmptyState(
        title: 'No campus loaded',
        body: 'Load a campus on the Workload tab before asking the server to validate a timetable.',
        icon: Icons.rule_folder_outlined,
      );
    }

    final result = controller.result;
    final violations = result?.violations ?? const <Violation>[];
    final byCode = <String, List<Violation>>{};
    for (final violation in violations) {
      (byCode[violation.code] ??= <Violation>[]).add(violation);
    }

    return LayoutBuilder(
      builder: (context, constraints) => ListView(
        padding: const EdgeInsets.fromLTRB(
          SynchroSpacing.gutter,
          SynchroSpacing.lg,
          SynchroSpacing.gutter,
          SynchroSpacing.xxl,
        ),
        children: [
          if (result == null) ...[
            if (_historyLoading) const _HistoryLoadingCard(),
            if (controller.runError != null)
              Notice(
                tone: Tone.bad,
                icon: Icons.error_outline,
                text: controller.runError!,
              ),
            EmptyState(
              title: 'Nothing to check yet',
              body:
                  'Generate a timetable first. This panel will show the validator response and will not '
                  'guess whether an unseen schedule is clean.',
              icon: Icons.rule_folder_outlined,
              action: _GenerateButton(controller: controller),
            ),
          ] else ...[
            _VerdictCard(
              result: result,
              revalidating: _revalidating,
              onRevalidate: _revalidate,
              error: controller.runError,
            ),
            if (violations.isNotEmpty) ...[
              const SizedBox(height: SynchroSpacing.lg),
              _ViolationGroups(
                byCode: byCode,
                maxWidth: constraints.maxWidth - (SynchroSpacing.gutter * 2),
              ),
            ],
            const SizedBox(height: SynchroSpacing.lg),
            const _SoftPreferenceCard(),
          ],
          const SizedBox(height: SynchroSpacing.lg),
          _HistoryCard(history: controller.history, loading: _historyLoading),
        ],
      ),
    );
  }

  static String _ruleName(String code) => switch (code) {
    'FACULTY_CLASH' => 'A professor is in two places at once',
    'BATCH_CLASH' => 'A batch has two sessions in one period',
    'ROOM_CLASH' => 'A room is double-booked',
    'ROOM_KIND' => 'A lab is sitting in a plain classroom',
    'ROOM_CAPACITY' => 'The room is too small for the batch',
    'ROOM_POLICY' => "Another department's room is not borrowable",
    'BREAK_USED' => 'A session falls inside a break',
    'FACULTY_UNAVAILABLE' => 'The professor is marked unavailable',
    'ROOM_CLOSED' => 'The room is closed at that period',
    'NOT_QUALIFIED' => 'The professor is not qualified for the subject',
    'MISSING_LECTURES' => 'Required lecture hours are missing',
    'MISSING_LABS' => 'Required lab sessions are missing',
    'WORKLOAD_EXCEEDED' => 'A professor is over their weekly hours',
    'SESSION_RUN_OFF' => 'A lab block runs past the end of the day',
    'UNKNOWN_SLOT' => 'The session uses a period this campus does not have',
    _ => 'Validation rule',
  };
}

class _GenerateButton extends StatelessWidget {
  const _GenerateButton({required this.controller});

  final SchedulingController controller;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: controller.generate,
    icon: const Icon(Icons.bolt),
    label: const Text('Generate timetable'),
  );
}

class _VerdictCard extends StatelessWidget {
  const _VerdictCard({
    required this.result,
    required this.revalidating,
    required this.onRevalidate,
    required this.error,
  });

  final GenerationResult result;
  final bool revalidating;
  final VoidCallback onRevalidate;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final violations = result.violations;
    final hasHardViolations = violations.isNotEmpty;
    return SectionCard(
      overline: 'Independent validation · run #${result.runId}',
      title: hasHardViolations
          ? '${violations.length} conflicts'
          : 'No hard violations returned',
      trailing: StatusChip(
        label: result.publishable ? 'publishable' : 'not publishable',
        tone: result.publishable ? Tone.good : Tone.bad,
        icon: result.publishable ? Icons.verified : Icons.gpp_bad,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasHardViolations
                ? 'The validator returned ${violations.length} known hard-constraint violation${violations.length == 1 ? '' : 's'}. '
                      'Each item below names the server session ids involved.'
                : 'The validator returned no known hard-constraint violations for this run. This is not a '
                      'soft-preference score: the current validator does not expose soft-preference warnings.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: SynchroSpacing.lg),
          OutlinedButton.icon(
            onPressed: revalidating ? null : onRevalidate,
            icon: revalidating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            label: Text(
              revalidating
                  ? 'Checking…'
                  : 'Re-check ${result.assignments.length} sessions with the server',
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: SynchroSpacing.md),
            Notice(tone: Tone.bad, icon: Icons.error_outline, text: error!),
          ],
        ],
      ),
    );
  }
}

class _ViolationGroups extends StatelessWidget {
  const _ViolationGroups({required this.byCode, required this.maxWidth});

  final Map<String, List<Violation>> byCode;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final width = maxWidth >= 760
        ? (maxWidth - SynchroSpacing.lg) / 2
        : maxWidth;
    return Wrap(
      spacing: SynchroSpacing.lg,
      runSpacing: SynchroSpacing.lg,
      children: [
        for (final entry in byCode.entries)
          SizedBox(
            width: width,
            child: _ViolationGroup(code: entry.key, violations: entry.value),
          ),
      ],
    );
  }
}

class _ViolationGroup extends StatelessWidget {
  const _ViolationGroup({required this.code, required this.violations});

  final String code;
  final List<Violation> violations;

  @override
  Widget build(BuildContext context) => SectionCard(
    overline: code,
    title: _ConflictsScreenState._ruleName(code),
    trailing: StatusChip(label: '${violations.length}', tone: Tone.bad),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < violations.length; index++) ...[
          if (index > 0) const Divider(height: SynchroSpacing.lg),
          _ViolationItem(violation: violations[index]),
        ],
      ],
    ),
  );
}

class _ViolationItem extends StatelessWidget {
  const _ViolationItem({required this.violation});

  final Violation violation;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Padding(
        padding: EdgeInsets.only(top: 2),
        child: Icon(Icons.error_outline, size: 17, color: SynchroColors.danger),
      ),
      const SizedBox(width: SynchroSpacing.sm),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              violation.message,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (violation.refs.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                violation.refs.join(' · '),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ],
        ),
      ),
    ],
  );
}

class _SoftPreferenceCard extends StatelessWidget {
  const _SoftPreferenceCard();

  @override
  Widget build(BuildContext context) => SectionCard(
    overline: 'Validator scope',
    title: 'Soft preferences',
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, size: 19, color: SynchroColors.warn),
        const SizedBox(width: SynchroSpacing.md),
        Expanded(
          child: Text(
            'Soft-preference warnings are not exposed by the current validator response. This screen '
            'reports known hard violations only and does not infer a clean soft-preference result.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    ),
  );
}

class _HistoryLoadingCard extends StatelessWidget {
  const _HistoryLoadingCard();

  @override
  Widget build(BuildContext context) => SectionCard(
    overline: 'Audit trail',
    title: 'Loading validation history',
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
            'Reading recorded solver runs from the server.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    ),
  );
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.history, required this.loading});

  final List<RunRecord> history;
  final bool loading;

  @override
  Widget build(BuildContext context) => SectionCard(
    title: 'Generation log',
    overline: 'Audit trail',
    child: loading
        ? const Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        : history.isEmpty
        ? Text(
            'No runs recorded yet.',
            style: Theme.of(context).textTheme.bodySmall,
          )
        : Column(children: [for (final run in history) _HistoryRow(run: run)]),
  );
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.run});

  final RunRecord run;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: SynchroSpacing.xs),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 44,
          child: Text(
            '#${run.id}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${run.status.toUpperCase()} · ${run.sessionCount} sessions',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 2),
              Text(
                '${_historyDate(run.createdAt)} · ${(run.wallTimeMs / 1000).toStringAsFixed(1)}s · '
                'cost ${run.softCost ?? 0}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(width: SynchroSpacing.sm),
        StatusChip(
          label: run.status,
          tone: run.status == 'solved' ? Tone.good : Tone.bad,
        ),
      ],
    ),
  );

  static String _historyDate(String value) {
    if (value.isEmpty) return 'time unavailable';
    return value.replaceFirst('T', ' ');
  }
}
