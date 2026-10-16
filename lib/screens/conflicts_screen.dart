import 'package:flutter/material.dart';

import '../data/models.dart';
import '../state/scheduling_controller.dart';
import '../theme/tokens.dart';
import '../widgets/ui.dart';

/// FEATURE 5: the conflict panel. It reports only what the server's independent
/// validator returned — never a local guess about whether the grid is safe.
class ConflictsScreen extends StatefulWidget {
  const ConflictsScreen({super.key, required this.controller});

  final SchedulingController controller;

  @override
  State<ConflictsScreen> createState() => _ConflictsScreenState();
}

class _ConflictsScreenState extends State<ConflictsScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.controller.hasCampus) WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await widget.controller.loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final result = controller.result;

    if (result == null) {
      return EmptyState(
        title: 'Nothing to check yet',
        body: 'Generate a timetable and the validator\'s verdict for it lands here, '
            'grouped by the rule each conflict breaks.',
        icon: Icons.rule_folder_outlined,
        action: FilledButton(onPressed: controller.generate, child: const Text('Generate timetable')),
      );
    }

    final violations = result.violations;
    final byCode = <String, List<Violation>>{};
    for (final violation in violations) {
      (byCode[violation.code] ??= <Violation>[]).add(violation);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(SynchroSpacing.gutter, SynchroSpacing.lg, SynchroSpacing.gutter, SynchroSpacing.xxl),
      children: [
        SectionCard(
          overline: 'Independent validation',
          title: violations.isEmpty ? 'No conflicts found' : '${violations.length} conflicts',
          trailing: StatusChip(
            label: result.publishable ? 'safe to publish' : 'not publishable',
            tone: result.publishable ? Tone.good : Tone.bad,
            icon: result.publishable ? Icons.verified : Icons.gpp_bad,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                violations.isEmpty
                    ? 'The validator re-derived every rule from the campus definition — faculty, batch and '
                        'room clashes, room kind and capacity, department policy, breaks, availability, '
                        'required hours and workload caps — and found nothing to report.'
                    : 'Each item below names the sessions that break the rule. They are the solver\'s own '
                        'session ids, so the same set can be sent back for re-checking.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: SynchroSpacing.lg),
              OutlinedButton.icon(
                onPressed: controller.revalidate,
                icon: const Icon(Icons.refresh),
                label: Text('Re-check ${result.assignments.length} sessions with the server'),
              ),
              if (controller.runError != null) ...[
                const SizedBox(height: SynchroSpacing.md),
                Notice(tone: Tone.bad, icon: Icons.error_outline, text: controller.runError!),
              ],
            ],
          ),
        ),
        if (violations.isNotEmpty) ...[
          const SizedBox(height: SynchroSpacing.lg),
          for (final entry in byCode.entries) ...[
            SectionCard(
              title: _ruleName(entry.key),
              overline: entry.key,
              trailing: StatusChip(label: '${entry.value.length}', tone: Tone.bad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final violation in entry.value)
                    Padding(
                      padding: const EdgeInsets.only(bottom: SynchroSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(violation.message, style: Theme.of(context).textTheme.bodyMedium),
                          const SizedBox(height: 2),
                          Text(violation.refs.join(' · '), style: Theme.of(context).textTheme.labelSmall),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: SynchroSpacing.lg),
          ],
        ],
        SectionCard(
          title: 'Generation log',
          overline: 'Audit trail',
          child: controller.history.isEmpty
              ? Text('No runs recorded yet.', style: Theme.of(context).textTheme.bodySmall)
              : Column(
                  children: [
                    for (final run in controller.history)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 46,
                              child: Text('#${run.id}', style: Theme.of(context).textTheme.titleSmall),
                            ),
                            Expanded(
                              child: Text(
                                '${run.status} · ${run.sessionCount} sessions · '
                                '${(run.wallTimeMs / 1000).toStringAsFixed(1)}s · cost ${run.softCost ?? 0}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                            StatusChip(
                              label: run.status,
                              tone: run.status == 'solved' ? Tone.good : Tone.bad,
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
