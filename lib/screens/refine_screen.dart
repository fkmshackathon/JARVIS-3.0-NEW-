import 'package:flutter/material.dart';

import '../data/models.dart';
import '../state/scheduling_controller.dart';
import '../theme/tokens.dart';
import '../widgets/ui.dart';

/// A truthful follow-up surface for a generated timetable. The current API only
/// supports revalidation and reading runs, so this screen does not invent edit,
/// alternative-generation, or publishing controls.
class RefineScreen extends StatefulWidget {
  const RefineScreen({
    super.key,
    required this.controller,
    this.onBack,
    this.onOpenTimetable,
  });

  final SchedulingController controller;
  final VoidCallback? onBack;
  final VoidCallback? onOpenTimetable;

  @override
  State<RefineScreen> createState() => _RefineScreenState();
}

class _RefineScreenState extends State<RefineScreen> {
  bool _revalidating = false;
  bool _historyLoading = false;

  SchedulingController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    if (controller.hasCampus && controller.history.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadHistory());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: _goBack,
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Refine Existing Timetable'),
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              SynchroSpacing.gutter,
              SynchroSpacing.lg,
              SynchroSpacing.gutter,
              SynchroSpacing.xxl,
            ),
            children: [
              _Intro(controller: controller),
              const SizedBox(height: SynchroSpacing.lg),
              if (controller.result == null)
                _NoCurrentResult(onOpenTimetable: widget.onOpenTimetable)
              else
                _CurrentResult(
                  controller: controller,
                  revalidating: _revalidating,
                  onRevalidate: _revalidate,
                  onOpenTimetable: widget.onOpenTimetable,
                ),
              const SizedBox(height: SynchroSpacing.lg),
              const Notice(
                tone: Tone.neutral,
                icon: Icons.info_outline,
                text:
                    'Alternative timetable and publishing endpoints are not available in this client. '
                    'The supported actions here are revalidation and opening the current timetable.',
              ),
              const SizedBox(height: SynchroSpacing.lg),
              _History(controller: controller, loading: _historyLoading),
              if (controller.runError != null) ...[
                const SizedBox(height: SynchroSpacing.lg),
                Notice(
                  tone: Tone.bad,
                  icon: Icons.error_outline,
                  text: controller.runError!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadHistory() async {
    if (_historyLoading) return;
    setState(() => _historyLoading = true);
    await controller.loadHistory();
    if (mounted) setState(() => _historyLoading = false);
  }

  Future<void> _revalidate() async {
    if (_revalidating ||
        controller.result == null ||
        controller.result!.assignments.isEmpty) {
      return;
    }
    setState(() => _revalidating = true);
    await controller.revalidate();
    if (mounted) setState(() => _revalidating = false);
  }

  void _goBack() {
    if (widget.onBack != null) {
      widget.onBack!();
    } else {
      Navigator.of(context).maybePop();
    }
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.controller});

  final SchedulingController controller;

  @override
  Widget build(BuildContext context) {
    final campus = controller.campus;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Check what the server returned.',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: SynchroSpacing.sm),
        Text(
          campus == null
              ? 'A campus is not loaded, so there is no current timetable to refine.'
              : 'The current result and generation history for ${campus.name} stay tied to the backend validator.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _NoCurrentResult extends StatelessWidget {
  const _NoCurrentResult({this.onOpenTimetable});

  final VoidCallback? onOpenTimetable;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      overline: 'Current timetable',
      title: 'Nothing to revalidate yet',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Generate a timetable first. This screen will show the real result once the solver returns one.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (onOpenTimetable != null) ...[
            const SizedBox(height: SynchroSpacing.lg),
            OutlinedButton.icon(
              onPressed: onOpenTimetable,
              icon: const Icon(Icons.grid_view_outlined),
              label: const Text('Open timetable'),
            ),
          ],
        ],
      ),
    );
  }
}

class _CurrentResult extends StatelessWidget {
  const _CurrentResult({
    required this.controller,
    required this.revalidating,
    required this.onRevalidate,
    this.onOpenTimetable,
  });

  final SchedulingController controller;
  final bool revalidating;
  final VoidCallback onRevalidate;
  final VoidCallback? onOpenTimetable;

  @override
  Widget build(BuildContext context) {
    final result = controller.result!;
    final violations = result.violations;
    final canRevalidate = !revalidating && result.assignments.isNotEmpty;

    return SectionCard(
      overline: 'Current result · run #${result.runId}',
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
                  value: '${violations.length}',
                  caption: 'violations',
                  tone: violations.isEmpty ? Tone.good : Tone.bad,
                ),
              ),
              Expanded(
                child: Stat(
                  value: '${result.wallTimeMs} ms',
                  caption: 'solver time',
                ),
              ),
            ],
          ),
          if (violations.isNotEmpty) ...[
            const SizedBox(height: SynchroSpacing.lg),
            Text(
              'Validator findings',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: SynchroSpacing.sm),
            for (final violation in violations)
              Padding(
                padding: const EdgeInsets.only(bottom: SynchroSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 5),
                      child: Icon(
                        Icons.circle,
                        size: 6,
                        color: SynchroColors.danger,
                      ),
                    ),
                    const SizedBox(width: SynchroSpacing.md),
                    Expanded(
                      child: Text(
                        '${violation.message}${violation.refs.isEmpty ? '' : ' · ${violation.refs.join(' · ')}'}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
          ] else ...[
            const SizedBox(height: SynchroSpacing.lg),
            const Notice(
              tone: Tone.good,
              icon: Icons.verified_outlined,
              text:
                  'The latest server result contains no validator violations.',
            ),
          ],
          if (!result.solved && result.message.isNotEmpty) ...[
            const SizedBox(height: SynchroSpacing.sm),
            Notice(
              tone: Tone.bad,
              icon: Icons.help_outline,
              text: result.message,
            ),
          ],
          const SizedBox(height: SynchroSpacing.md),
          Wrap(
            spacing: SynchroSpacing.sm,
            runSpacing: SynchroSpacing.sm,
            children: [
              OutlinedButton.icon(
                onPressed: canRevalidate ? onRevalidate : null,
                icon: Icon(revalidating ? Icons.sync : Icons.refresh),
                label: Text(
                  revalidating
                      ? 'Revalidating…'
                      : 'Revalidate current timetable',
                ),
              ),
              OutlinedButton.icon(
                onPressed: onOpenTimetable,
                icon: const Icon(Icons.grid_view_outlined),
                label: const Text('Open timetable'),
              ),
            ],
          ),
          if (onOpenTimetable == null) ...[
            const SizedBox(height: SynchroSpacing.sm),
            Text(
              'Open timetable is enabled by the surrounding app navigation.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _History extends StatelessWidget {
  const _History({required this.controller, required this.loading});

  final SchedulingController controller;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final history = controller.history;
    return SectionCard(
      overline: 'Backend history',
      title: 'Generation log',
      trailing: loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : StatusChip(label: '${history.length} runs'),
      child: history.isEmpty
          ? Text(
              loading
                  ? 'Loading runs from the backend…'
                  : 'No runs recorded yet.',
              style: Theme.of(context).textTheme.bodySmall,
            )
          : Column(
              children: [for (final run in history) _HistoryRow(run: run)],
            ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.run});

  final RunRecord run;

  @override
  Widget build(BuildContext context) {
    final solved = run.status == 'solved';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SynchroSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 42,
            child: Text(
              '#${run.id}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          Expanded(
            child: Text(
              '${run.status} · ${run.sessionCount} sessions · ${(run.wallTimeMs / 1000).toStringAsFixed(1)}s',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          StatusChip(label: run.status, tone: solved ? Tone.good : Tone.bad),
        ],
      ),
    );
  }
}
