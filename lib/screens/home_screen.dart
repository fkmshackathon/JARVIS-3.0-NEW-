import 'package:flutter/material.dart';

import '../brand/synchro_mark.dart';
import '../data/models.dart';
import '../state/demo_auth.dart';
import '../state/scheduling_controller.dart';
import '../theme/tokens.dart';
import '../widgets/ui.dart';

/// The first surface after launch. It keeps the next action obvious while
/// showing only the campus and timetable data returned by the solver.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    this.onCreateTimetable,
    this.onRefineTimetable,
    this.onOpenAccount,
    this.onOpenAudit,
    this.onOpenWorkload,
    this.onOpenRooms,
    this.onOpenChanges,
    this.onOpenIssues,
    this.auth,
  });

  final SchedulingController controller;
  final VoidCallback? onCreateTimetable;
  final VoidCallback? onRefineTimetable;
  final VoidCallback? onOpenAccount;
  final VoidCallback? onOpenAudit;
  final VoidCallback? onOpenWorkload;
  final VoidCallback? onOpenRooms;
  final VoidCallback? onOpenChanges;
  final VoidCallback? onOpenIssues;
  final DemoAuth? auth;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => ListenableBuilder(
          listenable: auth ?? controller,
          builder: (context, _) => SafeArea(
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    SynchroSpacing.gutter,
                    SynchroSpacing.lg,
                    SynchroSpacing.gutter,
                    SynchroSpacing.xxl,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _Header(
                        controller: controller,
                        auth: auth,
                        onOpenAccount: onOpenAccount,
                      ),
                      const SizedBox(height: SynchroSpacing.xl),
                      _ShortcutRow(
                        onOpenAccount: onOpenAccount,
                        onOpenAudit: onOpenAudit,
                      ),
                      const SizedBox(height: SynchroSpacing.xl),
                      _StatusCard(controller: controller),
                      const SizedBox(height: SynchroSpacing.xl),
                      _PrimaryActions(
                        onCreateTimetable: onCreateTimetable,
                        onRefineTimetable: onRefineTimetable,
                      ),
                      const SizedBox(height: SynchroSpacing.xl),
                      _ManagementActions(
                        onOpenWorkload: onOpenWorkload,
                        onOpenRooms: onOpenRooms,
                        onOpenChanges: onOpenChanges,
                        onOpenIssues: onOpenIssues,
                      ),
                      const SizedBox(height: SynchroSpacing.xl),
                      _SchedulePreview(controller: controller),
                      const SizedBox(height: SynchroSpacing.lg),
                      _CampusSnapshot(controller: controller),
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
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.controller, this.auth, this.onOpenAccount});

  final SchedulingController controller;
  final DemoAuth? auth;
  final VoidCallback? onOpenAccount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: SynchroWordmark(size: 32, onDark: isDark),
              ),
            ),
            if (onOpenAccount != null)
              IconButton(
                tooltip: 'Open account',
                onPressed: onOpenAccount,
                icon: const Icon(Icons.person_outline),
              ),
          ],
        ),
        const SizedBox(height: SynchroSpacing.lg),
        Text(
          auth?.currentUser == null
              ? 'Good morning'
              : 'Good morning, ${auth!.currentUser!.name}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: SynchroSpacing.xs),
        Text(
          auth?.currentUser?.institution ??
              controller.campus?.name ??
              'Your campus dashboard',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({this.onOpenAccount, this.onOpenAudit});

  final VoidCallback? onOpenAccount;
  final VoidCallback? onOpenAudit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick access', style: theme.textTheme.labelSmall),
        const SizedBox(height: SynchroSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _ShortcutTile(
                icon: Icons.fact_check_outlined,
                label: 'Campus audit',
                onPressed: onOpenAudit,
              ),
            ),
            const SizedBox(width: SynchroSpacing.sm),
            Expanded(
              child: _ShortcutTile(
                icon: Icons.person_outline,
                label: 'Account',
                onPressed: onOpenAccount,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onPressed != null;
    final ink = enabled
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(SynchroRadius.card),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(SynchroRadius.card),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(SynchroRadius.card),
          child: SizedBox(
            height: 64,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SynchroSpacing.md,
              ),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: ink),
                  const SizedBox(width: SynchroSpacing.sm),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(color: ink),
                    ),
                  ),
                  const SizedBox(width: SynchroSpacing.xs),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 13,
                    color: ink.withValues(alpha: enabled ? 0.7 : 0.45),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.controller});

  final SchedulingController controller;

  @override
  Widget build(BuildContext context) {
    final result = controller.result;
    final statusColor = _statusColor(controller);
    final theme = Theme.of(context);

    return SectionCard(
      overline: 'Current timetable',
      title: _statusTitle(controller),
      trailing: _NavyStatusTag(
        label: _statusLabel(controller),
        color: statusColor,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                result?.publishable == true
                    ? Icons.verified_outlined
                    : controller.runPhase == RunPhase.running
                    ? Icons.sync
                    : Icons.edit_calendar_outlined,
                color: statusColor,
                size: 22,
              ),
              const SizedBox(width: SynchroSpacing.md),
              Expanded(
                child: Text(
                  _statusDetail(controller),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
          if (result != null && result.violations.isNotEmpty) ...[
            const SizedBox(height: SynchroSpacing.md),
            Text(
              '${result.violations.length} validator conflict${result.violations.length == 1 ? '' : 's'} need review.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NavyStatusTag extends StatelessWidget {
  const _NavyStatusTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SynchroSpacing.md,
        vertical: SynchroSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(SynchroRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.42)),
      ),
      child: Text(
        label.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: SynchroType.micro,
          fontWeight: FontWeight.w700,
          letterSpacing: SynchroType.overlineTracking * 0.55,
          color: color,
        ),
      ),
    );
  }
}

class _PrimaryActions extends StatelessWidget {
  const _PrimaryActions({this.onCreateTimetable, this.onRefineTimetable});

  final VoidCallback? onCreateTimetable;
  final VoidCallback? onRefineTimetable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Plan your week', style: theme.textTheme.titleMedium),
        const SizedBox(height: SynchroSpacing.xs),
        Text(
          'Choose a starting point for the next schedule.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: SynchroSpacing.md),
        FilledButton.icon(
          onPressed: onCreateTimetable,
          style: FilledButton.styleFrom(
            backgroundColor: SynchroColors.orange,
            foregroundColor: SynchroColors.navyDeep,
            minimumSize: const Size.fromHeight(54),
            padding: const EdgeInsets.symmetric(horizontal: SynchroSpacing.lg),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(SynchroRadius.card),
            ),
          ),
          icon: const Icon(Icons.add_task),
          label: const Text('Create a New Timetable'),
        ),
        const SizedBox(height: SynchroSpacing.sm),
        FilledButton.icon(
          onPressed: onRefineTimetable,
          style: FilledButton.styleFrom(
            backgroundColor: SynchroColors.navy,
            foregroundColor: SynchroColors.onNavy,
            minimumSize: const Size.fromHeight(54),
            padding: const EdgeInsets.symmetric(horizontal: SynchroSpacing.lg),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(SynchroRadius.card),
            ),
          ),
          icon: const Icon(Icons.tune),
          label: const Text('Refine Existing Timetable'),
        ),
        if (onCreateTimetable == null || onRefineTimetable == null) ...[
          const SizedBox(height: SynchroSpacing.sm),
          Text(
            'Navigation actions are provided by the app shell.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _ManagementActions extends StatelessWidget {
  const _ManagementActions({
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
      Text('Manage the draft', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: SynchroSpacing.xs),
      Text(
        'Keep workload, rooms, changes and issues close to the timetable editor.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: SynchroSpacing.md),
      Wrap(
        spacing: SynchroSpacing.sm,
        runSpacing: SynchroSpacing.sm,
        children: [
          _ManagementButton(
            icon: Icons.bar_chart_outlined,
            label: 'Workload',
            onPressed: onOpenWorkload,
          ),
          _ManagementButton(
            icon: Icons.meeting_room_outlined,
            label: 'Rooms',
            onPressed: onOpenRooms,
          ),
          _ManagementButton(
            icon: Icons.sync_alt_outlined,
            label: 'Handle a change',
            onPressed: onOpenChanges,
          ),
          _ManagementButton(
            icon: Icons.rule_folder_outlined,
            label: 'Issues',
            onPressed: onOpenIssues,
          ),
        ],
      ),
    ],
  );
}

class _ManagementButton extends StatelessWidget {
  const _ManagementButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: Icon(icon, size: 18),
    label: Text(label),
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(horizontal: SynchroSpacing.md),
    ),
  );
}

class _SchedulePreview extends StatelessWidget {
  const _SchedulePreview({required this.controller});

  final SchedulingController controller;

  @override
  Widget build(BuildContext context) {
    final result = controller.result;
    final assignments = _sortedAssignments(result?.assignments ?? const []);

    if (assignments.isEmpty) {
      return SectionCard(
        overline: result == null
            ? 'Timetable preview'
            : 'Latest timetable · run #${result.runId}',
        title: 'Today & recent',
        child: _EmptySchedule(controller: controller),
      );
    }

    final todayIndex = DateTime.now().weekday - 1;
    final today = assignments.where((item) => item.day == todayIndex).toList();
    final recent = assignments.take(3).toList();

    return SectionCard(
      overline: 'Latest timetable · run #${result?.runId ?? 0}',
      title: 'Today & recent',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ScheduleGroup(
            title: 'Today',
            assignments: today,
            campus: controller.campus,
            emptyLabel: 'No sessions scheduled today',
            includeDay: false,
          ),
          const SizedBox(height: SynchroSpacing.lg),
          const Divider(height: 1),
          const SizedBox(height: SynchroSpacing.lg),
          _ScheduleGroup(
            title: 'Recent sessions',
            assignments: recent,
            campus: controller.campus,
            emptyLabel: 'No recent sessions to show',
            includeDay: true,
            totalCount: assignments.length,
          ),
        ],
      ),
    );
  }
}

class _EmptySchedule extends StatelessWidget {
  const _EmptySchedule({required this.controller});

  final SchedulingController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message =
        controller.runError ??
        (controller.campus == null
            ? 'Connect campus data to see real sessions here.'
            : 'Generate a timetable to see real sessions here.');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SynchroSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(SynchroRadius.chip),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: SynchroSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No timetable to preview',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: SynchroSpacing.xs),
                Text(message, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleGroup extends StatelessWidget {
  const _ScheduleGroup({
    required this.title,
    required this.assignments,
    required this.campus,
    required this.emptyLabel,
    required this.includeDay,
    this.totalCount,
  });

  final String title;
  final List<Assignment> assignments;
  final Campus? campus;
  final String emptyLabel;
  final bool includeDay;
  final int? totalCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = totalCount ?? assignments.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
            Text(
              count == 0
                  ? 'No sessions'
                  : '$count ${count == 1 ? 'session' : 'sessions'}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: SynchroSpacing.sm),
        if (assignments.isEmpty)
          Text(emptyLabel, style: theme.textTheme.bodySmall)
        else
          for (var index = 0; index < assignments.length; index++) ...[
            _ScheduleRow(
              assignment: assignments[index],
              campus: campus,
              includeDay: includeDay,
            ),
            if (index < assignments.length - 1) const Divider(height: 1),
          ],
      ],
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({
    required this.assignment,
    required this.campus,
    required this.includeDay,
  });

  final Assignment assignment;
  final Campus? campus;
  final bool includeDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subject =
        campus?.subjectName(assignment.subjectId) ?? assignment.subjectId;
    final batch = campus?.batchName(assignment.batchId) ?? assignment.batchId;
    final room = campus?.roomName(assignment.roomId) ?? assignment.roomId;
    final contextLabel = includeDay
        ? '${dayName(assignment.day)} · $room'
        : room;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SynchroSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 54,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatMinutes(assignment.start),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatMinutes(assignment.end),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: SynchroSpacing.sm),
          Container(
            width: 3,
            height: 45,
            decoration: BoxDecoration(
              color: assignment.isLab
                  ? SynchroColors.orange
                  : SynchroColors.navySoft,
              borderRadius: BorderRadius.circular(SynchroRadius.pill),
            ),
          ),
          const SizedBox(width: SynchroSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        subject,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    if (assignment.isLab) ...[
                      const SizedBox(width: SynchroSpacing.sm),
                      _SessionTypeTag(label: 'Lab'),
                    ],
                  ],
                ),
                const SizedBox(height: SynchroSpacing.xs),
                Text(
                  '$batch · $contextLabel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionTypeTag extends StatelessWidget {
  const _SessionTypeTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SynchroSpacing.sm,
        vertical: SynchroSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: SynchroColors.orange.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(SynchroRadius.chip),
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: SynchroColors.orangeDeep,
          fontSize: SynchroType.micro,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _CampusSnapshot extends StatelessWidget {
  const _CampusSnapshot({required this.controller});

  final SchedulingController controller;

  @override
  Widget build(BuildContext context) {
    final campus = controller.campus;
    final summary = controller.summary;
    final theme = Theme.of(context);

    if (campus == null || summary == null) {
      return SectionCard(
        overline: 'Live campus data',
        title: 'Waiting for campus data',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              controller.linkError ?? 'Load a campus from the solver backend to see real demand, people and room counts here.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: SynchroSpacing.sm),
            Text(
              'This summary stays empty until the backend responds.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    final blocker = controller.previewBlocker ?? summary.blocker;

    return SectionCard(
      overline: 'Live campus data',
      title: 'Campus at a glance',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: StatusChip(
              label: summary.canGenerate ? 'Ready to solve' : 'Needs review',
              tone: summary.canGenerate ? Tone.good : Tone.bad,
            ),
          ),
          const SizedBox(height: SynchroSpacing.lg),
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
            style: theme.textTheme.bodySmall,
          ),
          if (blocker != null) ...[
            const SizedBox(height: SynchroSpacing.md),
            Notice(tone: Tone.bad, icon: Icons.block_outlined, text: blocker),
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
    final theme = Theme.of(context);

    return SectionCard(
      overline: 'Latest run #${result.runId}',
      title: result.solved ? 'Timetable produced' : 'No timetable produced',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatusChip(
            label: result.publishable ? 'Validator clean' : 'Validator blocked',
            tone: result.publishable ? Tone.good : Tone.bad,
            icon: result.publishable
                ? Icons.verified_outlined
                : Icons.gpp_bad_outlined,
          ),
          const SizedBox(height: SynchroSpacing.lg),
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
          if (controller.runError != null) ...[
            const SizedBox(height: SynchroSpacing.md),
            Text(
              controller.runError!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _statusTitle(SchedulingController controller) {
  final result = controller.result;
  final summary = controller.summary;

  if (controller.runPhase == RunPhase.running) return 'Building your timetable';
  if (result?.publishable == true) return 'Schedule is ready';
  if (result?.solved == true) return 'Review your timetable';
  if (controller.campus == null) return 'Connect your campus';
  if (summary?.canGenerate == false) return 'Campus needs attention';
  return 'Ready to build your week';
}

String _statusDetail(SchedulingController controller) {
  final result = controller.result;
  final summary = controller.summary;

  if (controller.runPhase == RunPhase.running) {
    return 'The solver is working through the connected campus constraints.';
  }
  if (controller.runError != null) return controller.runError!;
  if (result != null && result.message.isNotEmpty) return result.message;
  if (controller.campus == null) {
    return controller.linkError ?? 'Load campus data to start scheduling.';
  }
  if (controller.previewBlocker != null) return controller.previewBlocker!;
  if (summary?.blocker != null) return summary!.blocker!;
  if (summary != null) {
    return '${controller.campus!.name} · ${summary.sessions} sessions ready to place.';
  }
  return controller.campus!.name;
}

String _statusLabel(SchedulingController controller) {
  final result = controller.result;
  if (controller.runPhase == RunPhase.running) return 'Solving';
  if (result?.publishable == true) return 'Validated';
  if (result?.solved == true) return 'Review';

  return switch (controller.phase) {
    LinkPhase.ready =>
      controller.summary?.canGenerate == false ? 'Needs review' : 'Ready',
    LinkPhase.connecting => 'Connecting',
    LinkPhase.offline => 'Offline',
    LinkPhase.idle => 'Not connected',
  };
}

Color _statusColor(SchedulingController controller) {
  final result = controller.result;
  if (controller.runPhase == RunPhase.running) return SynchroColors.orange;
  if (result?.publishable == true) return SynchroColors.okOnNavy;
  if (result?.solved == true) return SynchroColors.warnOnNavy;
  if (controller.phase == LinkPhase.offline) return SynchroColors.dangerOnNavy;
  if (controller.summary?.canGenerate == false) return SynchroColors.warnOnNavy;
  return SynchroColors.onNavyMuted;
}

List<Assignment> _sortedAssignments(List<Assignment> assignments) {
  final sorted = [...assignments];
  sorted.sort((a, b) {
    final day = a.day.compareTo(b.day);
    if (day != 0) return day;
    final start = a.start.compareTo(b.start);
    if (start != 0) return start;
    return a.index.compareTo(b.index);
  });
  return sorted;
}
