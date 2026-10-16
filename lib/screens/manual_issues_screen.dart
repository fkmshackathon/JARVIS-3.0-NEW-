import 'package:flutter/material.dart';

import '../state/manual_timetable_controller.dart';
import '../state/manual_timetable_models.dart' as manual_models;
import '../theme/tokens.dart';
import '../widgets/ui.dart';

/// Local issue triage for the manual timetable draft.
///
/// This screen deliberately reads only the in-memory controller. It does not
/// manufacture an issue when a collection is empty, and it never calls the
/// server-side validator. The optional callbacks let the shell open the
/// timetable editor or another contextual action without coupling this view to
/// a particular navigation structure.
class ManualIssuesScreen extends StatelessWidget {
  const ManualIssuesScreen({
    super.key,
    required this.controller,
    this.onInspectIssue,
    this.onActionIssue,
    this.onInspectSwap,
    this.onActionSwap,
    this.onInspectProxy,
    this.onActionProxy,
  });

  final ManualTimetableController controller;
  final ValueChanged<manual_models.ManualIssue>? onInspectIssue;
  final ValueChanged<manual_models.ManualIssue>? onActionIssue;
  final ValueChanged<manual_models.ManualSwapRequest>? onInspectSwap;
  final ValueChanged<manual_models.ManualSwapRequest>? onActionSwap;
  final ValueChanged<manual_models.ManualFaculty>? onInspectProxy;
  final ValueChanged<manual_models.ManualFaculty>? onActionProxy;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final roomIssues = _roomAvailabilityIssues(controller);
        final hard = controller.hardConflicts
            .where((issue) => issue.code != 'ROOM_UNAVAILABLE')
            .toList();
        final soft = controller.softWarnings;
        final proxies = controller.faculty.where((teacher) => teacher.isProxy);
        final swaps = controller.swapRequests;
        final hasIssues =
            hard.isNotEmpty ||
            soft.isNotEmpty ||
            roomIssues.isNotEmpty ||
            proxies.isNotEmpty ||
            swaps.isNotEmpty;

        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              SynchroSpacing.gutter,
              SynchroSpacing.lg,
              SynchroSpacing.gutter,
              SynchroSpacing.xxl,
            ),
            children: [
              const _IssuesHeader(),
              const SizedBox(height: SynchroSpacing.md),
              _LocalDraftBanner(controller: controller),
              const SizedBox(height: SynchroSpacing.lg),
              if (!hasIssues)
                const EmptyState(
                  title: 'No local issues',
                  body: 'The manual draft currently has no hard conflicts, soft warnings, room closures, or pending proxy/swap items.',
                  icon: Icons.rule_folder_outlined,
                )
              else ...[
                if (hard.isNotEmpty) ...[
                  _IssueSection(
                    title: 'Hard conflicts',
                    overline: 'Blocks a clean draft',
                    tone: Tone.bad,
                    icon: Icons.error_outline,
                    count: hard.length,
                    children: [
                      for (final issue in hard)
                        _IssueRow(
                          issue: issue,
                          controller: controller,
                          onInspect: () => _inspectIssue(context, issue),
                          onAction: () => _actionIssue(context, issue),
                        ),
                    ],
                  ),
                  if (soft.isNotEmpty || roomIssues.isNotEmpty)
                    const SizedBox(height: SynchroSpacing.lg),
                ],
                if (soft.isNotEmpty) ...[
                  _IssueSection(
                    title: 'Soft warnings',
                    overline: 'Review before saving the draft',
                    tone: Tone.warn,
                    icon: Icons.warning_amber_outlined,
                    count: soft.length,
                    children: [
                      for (final issue in soft)
                        _IssueRow(
                          issue: issue,
                          controller: controller,
                          onInspect: () => _inspectIssue(context, issue),
                          onAction: () => _actionIssue(context, issue),
                        ),
                    ],
                  ),
                  if (roomIssues.isNotEmpty)
                    const SizedBox(height: SynchroSpacing.lg),
                ],
                if (roomIssues.isNotEmpty) ...[
                  _IssueSection(
                    title: 'Room availability',
                    overline: 'Actual closures in this draft',
                    tone: Tone.bad,
                    icon: Icons.meeting_room_outlined,
                    count: roomIssues.length,
                    children: [
                      for (final issue in roomIssues)
                        _IssueRow(
                          issue: issue,
                          controller: controller,
                          onInspect: () => _inspectIssue(context, issue),
                          onAction: () => _actionIssue(context, issue),
                        ),
                    ],
                  ),
                  if (proxies.isNotEmpty || swaps.isNotEmpty)
                    const SizedBox(height: SynchroSpacing.lg),
                ],
                if (proxies.isNotEmpty || swaps.isNotEmpty)
                  _PendingSection(
                    controller: controller,
                    proxies: proxies.toList(),
                    swaps: swaps,
                    onInspectSwap: (request) => _inspectSwap(context, request),
                    onActionSwap: (request) => _actionSwap(context, request),
                    onInspectProxy: (proxy) => _inspectProxy(context, proxy),
                    onActionProxy: (proxy) => _actionProxy(context, proxy),
                  ),
              ],
            ],
          ),
        );
      },
    ),
  );

  void _inspectIssue(BuildContext context, ManualIssue issue) {
    final callback = onInspectIssue;
    if (callback != null) {
      callback(issue);
      return;
    }
    _showIssueSheet(context, issue, controller);
  }

  void _actionIssue(BuildContext context, ManualIssue issue) {
    final callback = onActionIssue;
    if (callback != null) {
      callback(issue);
      return;
    }
    _showIssueSheet(context, issue, controller, action: true);
  }

  void _inspectSwap(BuildContext context, ManualSwapRequest request) {
    final callback = onInspectSwap;
    if (callback != null) {
      callback(request);
      return;
    }
    _showSwapSheet(context, request, controller);
  }

  void _actionSwap(BuildContext context, ManualSwapRequest request) {
    final callback = onActionSwap;
    if (callback != null) {
      callback(request);
      return;
    }
    _showSwapSheet(context, request, controller, action: true);
  }

  void _inspectProxy(BuildContext context, ManualFaculty proxy) {
    final callback = onInspectProxy;
    if (callback != null) {
      callback(proxy);
      return;
    }
    _showProxySheet(context, proxy, controller);
  }

  void _actionProxy(BuildContext context, ManualFaculty proxy) {
    final callback = onActionProxy;
    if (callback != null) {
      callback(proxy);
      return;
    }
    _showProxySheet(context, proxy, controller, action: true);
  }
}

class _IssuesHeader extends StatelessWidget {
  const _IssuesHeader();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Manual issues', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: SynchroSpacing.xs),
      Text(
        'Triage only what is present in the local timetable draft.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );
}

class _LocalDraftBanner extends StatelessWidget {
  const _LocalDraftBanner({required this.controller});

  final ManualTimetableController controller;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(
      horizontal: SynchroSpacing.md,
      vertical: SynchroSpacing.sm,
    ),
    decoration: BoxDecoration(
      color: SynchroColors.cream,
      borderRadius: BorderRadius.circular(SynchroRadius.chip),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.science_outlined,
          size: 17,
          color: SynchroColors.navyDeep,
        ),
        const SizedBox(width: SynchroSpacing.sm),
        Expanded(
          child: Text(
            ManualTimetableController.sampleDataLabel,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: SynchroColors.navyDeep),
          ),
        ),
        Text(
          controller.hasUnsavedChanges ? 'Draft' : 'Saved',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: SynchroColors.navyDeep),
        ),
      ],
    ),
  );
}

class _IssueSection extends StatelessWidget {
  const _IssueSection({
    required this.title,
    required this.overline,
    required this.tone,
    required this.icon,
    required this.count,
    required this.children,
  });

  final String title;
  final String overline;
  final Tone tone;
  final IconData icon;
  final int count;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SectionCard(
    overline: overline,
    title: title,
    trailing: StatusChip(label: '$count', tone: tone, icon: icon),
    child: Column(
      children: [
        for (var index = 0; index < children.length; index++) ...[
          if (index > 0) const Divider(height: SynchroSpacing.lg),
          children[index],
        ],
      ],
    ),
  );
}

class _IssueRow extends StatelessWidget {
  const _IssueRow({
    required this.issue,
    required this.controller,
    required this.onInspect,
    required this.onAction,
  });

  final ManualIssue issue;
  final ManualTimetableController controller;
  final VoidCallback onInspect;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final ink = StatusChip.color(
      issue.isHard ? Tone.bad : Tone.warn,
      Theme.of(context).brightness,
    );
    final affected = _affectedSessions(controller, issue.sessionIds);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                issue.isHard
                    ? Icons.error_outline
                    : Icons.warning_amber_outlined,
                color: ink,
                size: 19,
              ),
            ),
            const SizedBox(width: SynchroSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    issue.message,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (affected.isNotEmpty) ...[
                    const SizedBox(height: SynchroSpacing.xs),
                    for (final line in affected)
                      Text(
                        line,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                  const SizedBox(height: SynchroSpacing.sm),
                  Wrap(
                    spacing: SynchroSpacing.sm,
                    runSpacing: SynchroSpacing.xs,
                    children: [
                      OutlinedButton.icon(
                        onPressed: onInspect,
                        icon: const Icon(Icons.visibility_outlined, size: 16),
                        label: const Text('Inspect'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 38),
                          padding: const EdgeInsets.symmetric(
                            horizontal: SynchroSpacing.md,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: onAction,
                        icon: const Icon(
                          Icons.arrow_forward_outlined,
                          size: 16,
                        ),
                        label: const Text('Action'),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 38),
                          padding: const EdgeInsets.symmetric(
                            horizontal: SynchroSpacing.sm,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PendingSection extends StatelessWidget {
  const _PendingSection({
    required this.controller,
    required this.proxies,
    required this.swaps,
    required this.onInspectSwap,
    required this.onActionSwap,
    required this.onInspectProxy,
    required this.onActionProxy,
  });

  final ManualTimetableController controller;
  final List<ManualFaculty> proxies;
  final List<ManualSwapRequest> swaps;
  final ValueChanged<ManualSwapRequest> onInspectSwap;
  final ValueChanged<ManualSwapRequest> onActionSwap;
  final ValueChanged<ManualFaculty> onInspectProxy;
  final ValueChanged<ManualFaculty> onActionProxy;

  @override
  Widget build(BuildContext context) => SectionCard(
    overline: 'Local workflow · not sent',
    title: 'Pending proxy / swap state',
    trailing: StatusChip(
      label: '${proxies.length + swaps.length}',
      tone: Tone.warn,
      icon: Icons.sync_alt_outlined,
    ),
    child: Column(
      children: [
        for (var index = 0; index < proxies.length; index++) ...[
          if (index > 0) const Divider(height: SynchroSpacing.lg),
          _ProxyRow(
            proxy: proxies[index],
            controller: controller,
            onInspect: () => onInspectProxy(proxies[index]),
            onAction: () => onActionProxy(proxies[index]),
          ),
        ],
        if (proxies.isNotEmpty && swaps.isNotEmpty)
          const Divider(height: SynchroSpacing.lg),
        for (var index = 0; index < swaps.length; index++) ...[
          if (index > 0) const Divider(height: SynchroSpacing.lg),
          _SwapRow(
            request: swaps[index],
            controller: controller,
            onInspect: () => onInspectSwap(swaps[index]),
            onAction: () => onActionSwap(swaps[index]),
          ),
        ],
      ],
    ),
  );
}

class _ProxyRow extends StatelessWidget {
  const _ProxyRow({
    required this.proxy,
    required this.controller,
    required this.onInspect,
    required this.onAction,
  });

  final ManualFaculty proxy;
  final ManualTimetableController controller;
  final VoidCallback onInspect;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final assigned = controller.sessions
        .where((session) => session.facultyId == proxy.id)
        .toList();
    final detail = assigned.isEmpty
        ? 'Created proxy · not assigned to a class yet'
        : 'Assigned to ${assigned.length} local class${assigned.length == 1 ? '' : 'es'}';
    return _PendingRow(
      icon: Icons.person_add_alt_1_outlined,
      title: proxy.name,
      detail: '$detail · ${proxy.department}',
      status: 'proxy',
      onInspect: onInspect,
      onAction: onAction,
    );
  }
}

class _SwapRow extends StatelessWidget {
  const _SwapRow({
    required this.request,
    required this.controller,
    required this.onInspect,
    required this.onAction,
  });

  final ManualSwapRequest request;
  final ManualTimetableController controller;
  final VoidCallback onInspect;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final session = controller.sessionById(request.sessionId);
    final target = request.targetFacultyId == null
        ? 'no target teacher'
        : controller.facultyById(request.targetFacultyId!)?.name ??
              request.targetFacultyId!;
    final subject = session == null
        ? 'Session ${request.sessionId}'
        : controller.subjectById(session.subjectId)?.name ?? request.sessionId;
    return _PendingRow(
      icon: Icons.swap_horiz_outlined,
      title: subject,
      detail:
          '${session == null ? 'Session unavailable' : _sessionLine(controller, session)} · target $target',
      status: request.status,
      onInspect: onInspect,
      onAction: onAction,
    );
  }
}

class _PendingRow extends StatelessWidget {
  const _PendingRow({
    required this.icon,
    required this.title,
    required this.detail,
    required this.status,
    required this.onInspect,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String detail;
  final String status;
  final VoidCallback onInspect;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: SynchroColors.orangeDeep, size: 19),
      const SizedBox(width: SynchroSpacing.sm),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: SynchroSpacing.sm),
                StatusChip(label: status, tone: Tone.warn),
              ],
            ),
            const SizedBox(height: SynchroSpacing.xs),
            Text(detail, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: SynchroSpacing.sm),
            Wrap(
              spacing: SynchroSpacing.sm,
              children: [
                OutlinedButton.icon(
                  onPressed: onInspect,
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('Inspect'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(
                      horizontal: SynchroSpacing.md,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.arrow_forward_outlined, size: 16),
                  label: const Text('Action'),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(
                      horizontal: SynchroSpacing.sm,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}

List<String> _affectedSessions(
  ManualTimetableController controller,
  List<String> sessionIds,
) => [
  for (final id in sessionIds)
    if (controller.sessionById(id) case final session?)
      _sessionLine(controller, session),
];

String _sessionLine(
  ManualTimetableController controller,
  ManualSession session,
) {
  final subject =
      controller.subjectById(session.subjectId)?.name ?? 'Missing subject';
  final faculty =
      controller.facultyById(session.facultyId)?.name ?? 'Missing faculty';
  final room = controller.roomById(session.roomId)?.name ?? 'Missing room';
  return '$subject · ${controller.dayName(session.day)} ${_time(session.startMinute)}–${_time(session.endMinute)} · $faculty · $room';
}

/// The validator records a room issue when a session is affected. A closure on
/// an otherwise empty room is still a real availability issue, so include that
/// resource state here without inventing a timetable conflict for it.
List<ManualIssue> _roomAvailabilityIssues(
  ManualTimetableController controller,
) {
  final issues = controller.hardConflicts
      .where((issue) => issue.code == 'ROOM_UNAVAILABLE')
      .toList();
  for (final room in controller.rooms) {
    if (!room.isAvailable) {
      final affected = controller.sessions
          .where((session) => session.roomId == room.id)
          .map((session) => session.id)
          .toList();
      if (!_hasRoomIssueFor(issues, affected, room.name)) {
        issues.add(
          ManualIssue(
            code: 'ROOM_UNAVAILABLE',
            message: '${room.name} is unavailable all day.',
            sessionIds: affected,
          ),
        );
      }
    }
    for (final closure in room.unavailableSlots) {
      final affected = controller.sessions
          .where(
            (session) =>
                session.roomId == room.id &&
                session.day == closure.day &&
                _overlaps(
                  session.startMinute,
                  session.endMinute,
                  closure.startMinute,
                  closure.endMinute,
                ),
          )
          .map((session) => session.id)
          .toList();
      final closureLabel =
          '${controller.dayName(closure.day)} ${_time(closure.startMinute)}–${_time(closure.endMinute)}';
      if (_hasRoomIssueFor(
        issues,
        affected,
        room.name,
        timeLabel: affected.isEmpty ? closureLabel : null,
      )) {
        continue;
      }
      issues.add(
        ManualIssue(
          code: 'ROOM_UNAVAILABLE',
          message:
              '${room.name} is closed for $closureLabel${closure.reason.isEmpty ? '' : ': ${closure.reason}'}.',
          sessionIds: affected,
        ),
      );
    }
  }
  return issues;
}

bool _hasRoomIssueFor(
  List<ManualIssue> issues,
  List<String> affected,
  String roomName, {
  String? timeLabel,
}) {
  for (final issue in issues) {
    if (!issue.message.contains(roomName)) continue;
    if (timeLabel != null && !issue.message.contains(timeLabel)) continue;
    if (affected.isEmpty || issue.sessionIds.any(affected.contains)) {
      return true;
    }
  }
  return false;
}

bool _overlaps(int startA, int endA, int startB, int endB) =>
    startA < endB && startB < endA;

Future<void> _showIssueSheet(
  BuildContext context,
  ManualIssue issue,
  ManualTimetableController controller, {
  bool action = false,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Theme.of(context).colorScheme.surface,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(
      top: Radius.circular(SynchroRadius.sheet),
    ),
  ),
  builder: (sheetContext) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        SynchroSpacing.gutter,
        SynchroSpacing.lg,
        SynchroSpacing.gutter,
        SynchroSpacing.gutter,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            action ? 'Review action' : 'Inspect issue',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: SynchroSpacing.sm),
          Text(issue.message, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: SynchroSpacing.lg),
          for (final line in _affectedSessions(controller, issue.sessionIds))
            Padding(
              padding: const EdgeInsets.only(bottom: SynchroSpacing.sm),
              child: Notice(
                tone: issue.isHard ? Tone.bad : Tone.warn,
                icon: issue.isHard
                    ? Icons.error_outline
                    : Icons.warning_amber_outlined,
                text: line,
              ),
            ),
          Text(
            action
                ? 'Open the local timetable editor to change the affected session or resource.'
                : 'This detail is derived from the current local controller state.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: SynchroSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(sheetContext).pop(),
              child: const Text('Close'),
            ),
          ),
        ],
      ),
    ),
  ),
);

Future<void> _showSwapSheet(
  BuildContext context,
  ManualSwapRequest request,
  ManualTimetableController controller, {
  bool action = false,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Theme.of(context).colorScheme.surface,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(
      top: Radius.circular(SynchroRadius.sheet),
    ),
  ),
  builder: (sheetContext) {
    final session = controller.sessionById(request.sessionId);
    final target = request.targetFacultyId == null
        ? 'No target teacher selected'
        : controller.facultyById(request.targetFacultyId!)?.name ??
              request.targetFacultyId!;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          SynchroSpacing.gutter,
          SynchroSpacing.lg,
          SynchroSpacing.gutter,
          SynchroSpacing.gutter,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              action ? 'Review swap request' : 'Inspect swap request',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: SynchroSpacing.sm),
            Text(
              '${session == null ? request.sessionId : _sessionLine(controller, session)}\nTarget: $target\nStatus: ${request.status}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (request.note.isNotEmpty) ...[
              const SizedBox(height: SynchroSpacing.sm),
              Text(
                'Note: ${request.note}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: SynchroSpacing.lg),
            const Notice(
              tone: Tone.warn,
              icon: Icons.science_outlined,
              text: 'This request is a local draft. It does not notify a teacher or publish a timetable.',
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  },
);

Future<void> _showProxySheet(
  BuildContext context,
  ManualFaculty proxy,
  ManualTimetableController controller, {
  bool action = false,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Theme.of(context).colorScheme.surface,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(
      top: Radius.circular(SynchroRadius.sheet),
    ),
  ),
  builder: (sheetContext) {
    final sessions = controller.sessions
        .where((session) => session.facultyId == proxy.id)
        .toList();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          SynchroSpacing.gutter,
          SynchroSpacing.lg,
          SynchroSpacing.gutter,
          SynchroSpacing.gutter,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              action ? 'Review proxy' : 'Inspect proxy',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: SynchroSpacing.sm),
            Text(
              '${proxy.name}\n${proxy.department} · target ${proxy.maxWeeklyHours}h',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: SynchroSpacing.sm),
            Text(
              sessions.isEmpty
                  ? 'No session is assigned to this proxy yet.'
                  : 'Assigned sessions: ${sessions.length}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: SynchroSpacing.lg),
            const Notice(
              tone: Tone.warn,
              icon: Icons.science_outlined,
              text: 'Proxy records are local sample state. No absence message or approval is sent.',
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  },
);

String _time(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
