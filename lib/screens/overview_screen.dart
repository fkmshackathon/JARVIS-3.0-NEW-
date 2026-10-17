import 'package:flutter/material.dart';

import '../brand/synchro_mark.dart';
import '../state/manual_timetable_controller.dart';
import '../state/timetable_library_controller.dart';
import '../theme/tokens.dart';
import '../widgets/ui.dart';
import 'synchro_flow_widgets.dart';

const String synchroDefaultInstitution = 'SHREE LR TIWARI COLLEGE OF ENGINEERING';
const String synchroDefaultSemester = 'Semester 2 · 2026';

/// The first surface in the focused SYNCHRO flow.
///
/// All collection counts and draft signals are derived from [controller].
/// Institution and semester are deliberately injectable display values until
/// the host flow supplies its own term configuration model.
class OverviewScreen extends StatelessWidget {
  const OverviewScreen({
    super.key,
    required this.controller,
    this.institutionName = synchroDefaultInstitution,
    this.semesterLabel = synchroDefaultSemester,
    this.onOpenSetup,
    this.onGenerate,
    this.onReview,
    this.onOpenWorkload,
    this.onOpenRooms,
    this.timetableLibrary,
    this.onOpenLibrary,
    this.onSignOut,
    this.onReset,
  });

  final ManualTimetableController controller;
  final String institutionName;
  final String semesterLabel;

  /// Moves the user into the editable setup surface.
  final VoidCallback? onOpenSetup;

  /// Hands off to the generator; this screen never creates a timetable itself.
  final VoidCallback? onGenerate;

  /// Opens the host's review/editor flow for the local draft.
  final VoidCallback? onReview;
  final VoidCallback? onOpenWorkload;
  final VoidCallback? onOpenRooms;
  final TimetableLibraryController? timetableLibrary;
  final VoidCallback? onOpenLibrary;
  final VoidCallback? onSignOut;

  /// Resets the complete local timetable library after confirmation.
  final Future<void> Function()? onReset;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final readiness = SynchroSetupReadiness.fromController(
            controller: controller,
            institution: institutionName,
            semester: semesterLabel,
          );
          return SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    SynchroSpacing.gutter,
                    SynchroSpacing.lg,
                    SynchroSpacing.gutter,
                    40,
                  ),
                  children: [
                    _OverviewTopbar(
                      onReset: () => _confirmReset(context),
                      onSignOut: onSignOut,
                    ),
                    const SizedBox(height: 30),
                    SynchroFlowHeading(
                      overline: 'OVERVIEW',
                      title: 'Your scheduling workspace',
                      subtitle: 'A calm view of the term details and local draft you are preparing.',
                      trailing: const SynchroMark(
                        size: 50,
                        badge: false,
                        onLight: true,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _TermSummaryCard(
                      controller: controller,
                      institutionName: institutionName,
                      semesterLabel: semesterLabel,
                    ),
                    if (timetableLibrary != null && onOpenLibrary != null) ...[
                      const SizedBox(height: 16),
                      _TimetableLibraryCard(
                        library: timetableLibrary!,
                        onOpenLibrary: onOpenLibrary!,
                      ),
                    ],
                    const SizedBox(height: 16),
                    _CollectionMetrics(
                      controller: controller,
                      onReview: onReview,
                      onOpenWorkload: onOpenWorkload,
                      onOpenRooms: onOpenRooms,
                    ),
                    const SizedBox(height: 16),
                    _ReadinessCard(
                      readiness: readiness,
                      onOpenSetup: onOpenSetup,
                    ),
                    const SizedBox(height: 16),
                    _DraftReviewCard(
                      controller: controller,
                      onReview: onReview,
                    ),
                    const SizedBox(height: 24),
                    _OverviewActions(
                      readiness: readiness,
                      hasGeneratedTimetable: controller.hasGeneratedTimetable,
                      needsRegeneration: controller.needsRegeneration,
                      onOpenSetup: onOpenSetup,
                      onGenerate: onGenerate,
                      onReview: onReview,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      controller.hasGeneratedTimetable &&
                              !controller.needsRegeneration
                          ? 'The timetable below is derived from the current local setup and can be edited and revalidated.'
                          : controller.needsRegeneration
                          ? 'Setup changed. Regenerate the timetable to apply the latest local inputs.'
                          : readiness.isComplete
                          ? 'Setup is ready. No timetable has been generated yet.'
                          : 'Complete the missing prerequisites before generation.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset local demo?'),
        content: const Text(
          'This restores the sample faculty, batches, subjects, rooms, and classes on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep draft'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Reset demo'),
          ),
        ],
      ),
    );
    if (shouldReset != true) return;
    if (onReset != null) {
      await onReset!();
    } else {
      await controller.resetDemo();
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Local demo restored.')));
  }
}

class _TimetableLibraryCard extends StatelessWidget {
  const _TimetableLibraryCard({
    required this.library,
    required this.onOpenLibrary,
  });

  final TimetableLibraryController library;
  final VoidCallback onOpenLibrary;

  @override
  Widget build(BuildContext context) {
    final active = library.activeRecord;
    final records = library.records;
    final status = active?.status ?? TimetableRecordStatus.notGenerated;
    final tone = switch (status) {
      TimetableRecordStatus.validated => Tone.good,
      TimetableRecordStatus.needsReview => Tone.warn,
      TimetableRecordStatus.draft => Tone.neutral,
      TimetableRecordStatus.notGenerated => Tone.neutral,
    };

    return SectionCard(
      overline: 'MY TIMETABLES',
      title: records.isEmpty
          ? 'No saved timetables'
          : '${records.length} saved timetable${records.length == 1 ? '' : 's'}',
      trailing: StatusChip(
        label: active == null ? 'None open' : '1 open',
        tone: tone,
        icon: Icons.calendar_today_outlined,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (active == null)
            const Text(
              'Create a timetable to start an independent local draft.',
            )
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.calendar_month_outlined, size: 21),
                const SizedBox(width: SynchroSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        active.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: SynchroSpacing.xs),
                      Text(
                        '${active.term} · ${active.sessionCount} session${active.sessionCount == 1 ? '' : 's'}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: SynchroSpacing.sm),
                StatusChip(label: active.statusLabel, tone: tone),
              ],
            ),
            const SizedBox(height: SynchroSpacing.xs),
            Text(
              'Updated ${_libraryTime(active.updatedAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (records.length > 1) ...[
              const SizedBox(height: SynchroSpacing.xs),
              Text(
                '${records.length - 1} other timetable${records.length == 2 ? '' : 's'} saved locally.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
          const SizedBox(height: SynchroSpacing.md),
          OutlinedButton.icon(
            key: const Key('open-timetable-library-button'),
            onPressed: onOpenLibrary,
            icon: const Icon(Icons.folder_open_outlined, size: 18),
            label: const Text('Open My timetables'),
          ),
        ],
      ),
    );
  }
}

String _libraryTime(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final meridiem = local.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $meridiem';
}

class _OverviewTopbar extends StatelessWidget {
  const _OverviewTopbar({required this.onReset, this.onSignOut});

  final VoidCallback onReset;
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Expanded(
        child: FittedBox(
          alignment: Alignment.centerLeft,
          fit: BoxFit.scaleDown,
          child: SynchroWordmark(size: 30, onDark: false),
        ),
      ),
      const SizedBox(width: SynchroSpacing.sm),
      const StatusChip(
        label: 'Local draft',
        tone: Tone.neutral,
        icon: Icons.edit_note_outlined,
      ),
      if (onSignOut != null)
        IconButton(
          onPressed: onSignOut,
          tooltip: 'Sign out of local demo',
          icon: const Icon(Icons.logout_outlined),
        ),
      const SizedBox(width: SynchroSpacing.xs),
      IconButton(
        onPressed: onReset,
        tooltip: 'Reset local demo',
        icon: const Icon(Icons.restart_alt),
      ),
    ],
  );
}

class _TermSummaryCard extends StatelessWidget {
  const _TermSummaryCard({
    required this.controller,
    required this.institutionName,
    required this.semesterLabel,
  });

  final ManualTimetableController controller;
  final String institutionName;
  final String semesterLabel;

  @override
  Widget build(BuildContext context) {
    final days = synchroWorkingDays(controller);
    final breakSummary = synchroBreakSummary(controller);
    return SectionCard(
      overline: 'Term at a glance',
      title: institutionName,
      trailing: StatusChip(
        label: semesterLabel,
        tone: Tone.neutral,
        icon: Icons.calendar_today_outlined,
      ),
      child: Wrap(
        spacing: 22,
        runSpacing: 14,
        children: [
          _TermValue(
            icon: Icons.school_outlined,
            label: 'Semester',
            value: semesterLabel,
          ),
          _TermValue(
            icon: Icons.view_week_outlined,
            label: 'Working days',
            value: days.isEmpty
                ? 'Not set'
                : days.map(synchroDayShort).join(' · '),
          ),
          _TermValue(
            icon: Icons.free_breakfast_outlined,
            label: 'Break',
            value: breakSummary == null
                ? 'Not set'
                : '${breakSummary.label} · ${synchroTime(breakSummary.startMinute)}–${synchroTime(breakSummary.endMinute)}',
          ),
        ],
      ),
    );
  }
}

class _TermValue extends StatelessWidget {
  const _TermValue({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 205,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: 3),
              Text(value, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    ),
  );
}

class _CollectionMetrics extends StatelessWidget {
  const _CollectionMetrics({
    required this.controller,
    this.onReview,
    this.onOpenWorkload,
    this.onOpenRooms,
  });

  final ManualTimetableController controller;
  final VoidCallback? onReview;
  final VoidCallback? onOpenWorkload;
  final VoidCallback? onOpenRooms;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 560 ? 4 : 2;
      final width =
          (constraints.maxWidth - SynchroSpacing.sm * (columns - 1)) / columns;
      return Wrap(
        spacing: SynchroSpacing.sm,
        runSpacing: SynchroSpacing.sm,
        children: [
          SizedBox(
            width: width,
            child: SynchroMetricTile(
              label: 'Faculty',
              value: controller.faculty.length,
              icon: Icons.people_outline,
              onTap: onOpenWorkload ?? onReview,
            ),
          ),
          SizedBox(
            width: width,
            child: SynchroMetricTile(
              label: 'Batches',
              value: controller.batches.length,
              icon: Icons.groups_outlined,
              onTap: onReview,
            ),
          ),
          SizedBox(
            width: width,
            child: SynchroMetricTile(
              label: 'Subjects',
              value: controller.subjects.length,
              icon: Icons.menu_book_outlined,
              onTap: onReview,
            ),
          ),
          SizedBox(
            width: width,
            child: SynchroMetricTile(
              label: 'Rooms',
              value: controller.rooms.length,
              icon: Icons.meeting_room_outlined,
              onTap: onOpenRooms ?? onReview,
            ),
          ),
        ],
      );
    },
  );
}

class _ReadinessCard extends StatelessWidget {
  const _ReadinessCard({required this.readiness, this.onOpenSetup});

  final SynchroSetupReadiness readiness;
  final VoidCallback? onOpenSetup;

  @override
  Widget build(BuildContext context) {
    final missing = readiness.missing;
    final tone = readiness.isComplete ? Tone.good : Tone.warn;
    return SectionCard(
      overline: 'Setup progress',
      title: '${readiness.completed} of ${readiness.total} prerequisites ready',
      trailing: StatusChip(
        label: readiness.isComplete ? 'Ready to review' : 'Needs setup',
        tone: tone,
        icon: readiness.isComplete
            ? Icons.check_circle_outline
            : Icons.circle_outlined,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: readiness.progress,
              minHeight: 7,
              backgroundColor: Theme.of(context).colorScheme.outlineVariant,
              valueColor: AlwaysStoppedAnimation(
                StatusChip.color(tone, Theme.of(context).brightness),
              ),
            ),
          ),
          const SizedBox(height: SynchroSpacing.md),
          if (missing.isEmpty)
            Text(
              'Term details and the four scheduling collections are present.',
              style: Theme.of(context).textTheme.bodySmall,
            )
          else ...[
            Text('Still needed', style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: SynchroSpacing.sm),
            Wrap(
              spacing: SynchroSpacing.sm,
              runSpacing: SynchroSpacing.sm,
              children: [
                for (final prerequisite in missing)
                  Chip(
                    avatar: const Icon(Icons.add_circle_outline, size: 16),
                    label: Text(prerequisite.label),
                  ),
              ],
            ),
          ],
          if (onOpenSetup != null) ...[
            const SizedBox(height: SynchroSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onOpenSetup,
                icon: const Icon(Icons.tune_outlined, size: 18),
                label: Text(missing.isEmpty ? 'Edit setup' : 'Finish setup'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DraftReviewCard extends StatelessWidget {
  const _DraftReviewCard({required this.controller, this.onReview});

  final ManualTimetableController controller;
  final VoidCallback? onReview;

  @override
  Widget build(BuildContext context) {
    final hard = controller.hardConflicts.length;
    final soft = controller.softWarnings.length;
    final hasIssues = hard > 0 || soft > 0;
    final isChecked = controller.hasLocalValidation;
    final tone = hard > 0
        ? Tone.bad
        : soft > 0
        ? Tone.warn
        : isChecked
        ? Tone.good
        : Tone.neutral;
    final title = controller.needsRegeneration
        ? 'Setup changed — regenerate before review'
        : !controller.hasGeneratedTimetable
        ? 'No timetable generated yet'
        : hard > 0
        ? 'Resolve local conflicts before hand-off'
        : soft > 0
        ? 'Draft has a few warnings to review'
        : isChecked
        ? 'Local draft reviewed'
        : 'Draft is ready for a review pass';
    final detail = controller.needsRegeneration
        ? 'A saved timetable exists, but the current setup has changed. Generate again to use the latest inputs.'
        : !controller.hasGeneratedTimetable
        ? 'Configure the term and run the deterministic local generator to create the first schedule.'
        : hasIssues
        ? '$hard hard conflict${hard == 1 ? '' : 's'} · $soft soft warning${soft == 1 ? '' : 's'}'
        : isChecked
        ? 'The local checker has no issues to report.'
        : 'Review the sample placements before handing off to generation.';

    return SectionCard(
      overline: 'Local draft',
      title: title,
      trailing: StatusChip(
        label: controller.needsRegeneration
            ? 'Needs regeneration'
            : !controller.hasGeneratedTimetable
            ? 'Not generated'
            : isChecked
            ? 'Checked locally'
            : 'Review needed',
        tone: tone,
        icon: hasIssues ? Icons.error_outline : Icons.rule_outlined,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(detail, style: Theme.of(context).textTheme.bodySmall),
          ),
          if (onReview != null) ...[
            const SizedBox(width: SynchroSpacing.sm),
            TextButton(onPressed: onReview, child: const Text('Review')),
          ],
        ],
      ),
    );
  }
}

class _OverviewActions extends StatelessWidget {
  const _OverviewActions({
    required this.readiness,
    required this.hasGeneratedTimetable,
    required this.needsRegeneration,
    this.onOpenSetup,
    this.onGenerate,
    this.onReview,
  });

  final SynchroSetupReadiness readiness;
  final bool hasGeneratedTimetable;
  final bool needsRegeneration;
  final VoidCallback? onOpenSetup;
  final VoidCallback? onGenerate;
  final VoidCallback? onReview;

  @override
  Widget build(BuildContext context) {
    final canGenerate = readiness.isComplete && onGenerate != null;
    final primary = hasGeneratedTimetable && !needsRegeneration
        ? onReview
        : canGenerate
        ? onGenerate
        : onOpenSetup;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: primary,
          icon: Icon(
            hasGeneratedTimetable && !needsRegeneration
                ? Icons.visibility_outlined
                : readiness.isComplete
                ? Icons.auto_awesome_outlined
                : Icons.arrow_forward_outlined,
          ),
          label: Text(
            hasGeneratedTimetable && !needsRegeneration
                ? 'Review generated timetable'
                : readiness.isComplete
                ? 'Generate timetable'
                : 'Complete setup',
          ),
          style: FilledButton.styleFrom(
            backgroundColor: hasGeneratedTimetable || readiness.isComplete
                ? SynchroColors.orange
                : SynchroColors.navy,
            foregroundColor: SynchroColors.navyDeep,
          ),
        ),
        if (onOpenSetup != null) ...[
          const SizedBox(height: SynchroSpacing.sm),
          OutlinedButton.icon(
            onPressed: onOpenSetup,
            icon: const Icon(Icons.tune_outlined, size: 18),
            label: const Text('Edit setup details'),
          ),
        ],
      ],
    );
  }
}
