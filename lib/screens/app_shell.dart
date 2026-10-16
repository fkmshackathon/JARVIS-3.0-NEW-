import 'package:flutter/material.dart';

import '../brand/synchro_mark.dart';
import '../data/models.dart';
import '../state/demo_auth.dart';
import '../state/manual_timetable_controller.dart';
import '../state/scheduling_controller.dart';
import '../theme/theme_controller.dart';
import '../theme/tokens.dart';
import '../widgets/ui.dart';
import 'account_screen.dart';
import 'audit_screen.dart';
import 'home_screen.dart';
import 'manual_changes_screen.dart';
import 'manual_issues_screen.dart';
import 'manual_rooms_screen.dart';
import 'manual_timetable_screen.dart';
import 'manual_workload_screen.dart';
import 'timetable_hub_screen.dart';

/// The compact product shell. Home is the starting point; the solver output and
/// validator remain one tap away, while the longer setup and refinement workflows
/// live behind contextual actions rather than permanent tabs.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.controller});

  final SchedulingController controller;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  final DemoAuth _auth = DemoAuth();
  final ManualTimetableController _manualController =
      ManualTimetableController();

  static const List<_Destination> _destinations = [
    _Destination('Home', Icons.home_outlined, Icons.home),
    _Destination(
      'Timetable',
      Icons.calendar_view_day_outlined,
      Icons.calendar_view_day,
    ),
    _Destination('Issues', Icons.rule_folder_outlined, Icons.rule_folder),
  ];

  SchedulingController get controller => widget.controller;

  @override
  void dispose() {
    _auth.dispose();
    _manualController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => SafeArea(
          bottom: false,
          child: Column(
            children: [
              if (_index != 0)
                _ShellHeader(index: _index, controller: controller),
              Expanded(
                child: AnimatedSwitcher(
                  duration: SynchroMotion.quick,
                  switchInCurve: SynchroMotion.entrance,
                  switchOutCurve: Curves.easeIn,
                  child: KeyedSubtree(
                    key: ValueKey(_index),
                    child: _screenFor(_index),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => ListenableBuilder(
          listenable: _manualController,
          builder: (context, _) {
            final violations =
                (controller.result?.violations.length ?? 0) +
                _manualController.hardConflicts.length;
            return NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (value) => setState(() => _index = value),
              destinations: [
                for (var i = 0; i < _destinations.length; i++)
                  NavigationDestination(
                    icon: _destinations[i].iconFor(violations, i),
                    selectedIcon: Icon(_destinations[i].activeIcon),
                    label: _destinations[i].label,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _screenFor(int index) => switch (index) {
    0 => HomeScreen(
      controller: controller,
      auth: _auth,
      onCreateTimetable: _openManualTimetable,
      onRefineTimetable: _openRefine,
      onOpenAccount: _openAccount,
      onOpenAudit: _openAudit,
      onOpenWorkload: _openWorkload,
      onOpenRooms: _openRooms,
      onOpenChanges: _openRefine,
      onOpenIssues: _openIssues,
    ),
    1 => TimetableHubScreen(
      controller: controller,
      manualController: _manualController,
      onOpenWorkload: _openWorkload,
      onOpenRooms: _openRooms,
      onHandleChange: _openRefine,
      onOpenIssues: _openIssues,
    ),
    _ => _IssuesDestination(
      controller: controller,
      manualController: _manualController,
    ),
  };

  void _openManualTimetable() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ManagementPage(
          title: 'Create timetable',
          child: ManualTimetableScreen(
            controller: _manualController,
            onOpenWorkload: _openWorkload,
            onOpenRooms: _openRooms,
            onHandleChange: _openRefine,
            onOpenIssues: _openIssues,
          ),
        ),
      ),
    );
  }

  void _openRefine() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ManagementPage(
          title: 'Handle a change',
          child: ManualChangesScreen(controller: _manualController),
        ),
      ),
    );
  }

  void _openWorkload() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ManagementPage(
          title: 'Faculty workload',
          child: ManualWorkloadScreen(controller: _manualController),
        ),
      ),
    );
  }

  void _openRooms() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ManagementPage(
          title: 'Rooms & labs',
          child: ManualRoomsScreen(controller: _manualController),
        ),
      ),
    );
  }

  void _openIssues() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ManagementPage(
          title: 'Issues',
          child: _IssuesDestination(
            controller: controller,
            manualController: _manualController,
          ),
        ),
      ),
    );
  }

  void _openAccount() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AccountScreen(
          auth: _auth,
          onBack: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  void _openAudit() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: const Text('Campus setup'),
            leading: IconButton(
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
            ),
          ),
          body: AuditScreen(controller: controller),
        ),
      ),
    );
  }
}

class _Destination {
  const _Destination(this.label, this.icon, this.activeIcon);

  final String label;
  final IconData icon;
  final IconData activeIcon;

  Widget iconFor(int violations, int index) {
    final plain = Icon(icon);
    if (index != 2) return plain;
    return Badge(
      label: Text('$violations'),
      isLabelVisible: violations > 0,
      backgroundColor: SynchroColors.danger,
      child: plain,
    );
  }
}

class _ShellHeader extends StatelessWidget {
  const _ShellHeader({required this.index, required this.controller});

  final int index;
  final SchedulingController controller;

  @override
  Widget build(BuildContext context) {
    final result = controller.result;
    final status = result == null
        ? const _ShellStatus(label: 'Ready', tone: Tone.neutral)
        : _ShellStatus(
            label: result.publishable
                ? 'Validated'
                : result.solved
                ? 'Needs review'
                : 'No result',
            tone: result.publishable
                ? Tone.good
                : result.solved
                ? Tone.warn
                : Tone.bad,
          );

    return Container(
      color: SynchroColors.navy,
      padding: const EdgeInsets.fromLTRB(
        SynchroSpacing.gutter,
        SynchroSpacing.sm,
        SynchroSpacing.sm,
        SynchroSpacing.md,
      ),
      child: Row(
        children: [
          const SynchroMark(size: 34, badge: false),
          const SizedBox(width: SynchroSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _AppShellState._destinations[index].label,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(color: SynchroColors.onNavy),
                ),
                Text(
                  controller.campus?.name ?? 'SYNCHRO workspace',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: SynchroColors.onNavyMuted),
                ),
              ],
            ),
          ),
          status,
          ValueListenableBuilder<ThemeMode>(
            valueListenable: appThemeMode,
            builder: (context, mode, _) => IconButton(
              tooltip: mode == ThemeMode.light
                  ? 'Switch to dark'
                  : 'Switch to light',
              onPressed: () => appThemeMode.value = toggleTheme(mode),
              icon: Icon(
                mode == ThemeMode.light
                    ? Icons.dark_mode_outlined
                    : Icons.light_mode_outlined,
                size: 20,
                color: SynchroColors.onNavyMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShellStatus extends StatelessWidget {
  const _ShellStatus({required this.label, required this.tone});

  final String label;
  final Tone tone;

  @override
  Widget build(BuildContext context) => StatusChip(
    label: label,
    tone: tone,
    icon: tone == Tone.good ? Icons.verified_outlined : null,
  );
}

/// Adds the local issues destination while keeping the server validator visible
/// whenever a real solver result exists. The two sections deliberately retain
/// separate labels so a local draft is never presented as server-validated.
class _IssuesDestination extends StatelessWidget {
  const _IssuesDestination({
    required this.controller,
    required this.manualController,
  });

  final SchedulingController controller;
  final ManualTimetableController manualController;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: ListenableBuilder(
      listenable: controller,
      builder: (context, _) => ListenableBuilder(
        listenable: manualController,
        builder: (context, _) => Column(
          children: [
            if (controller.result != null)
              _ServerValidationSection(result: controller.result!),
            Expanded(child: ManualIssuesScreen(controller: manualController)),
          ],
        ),
      ),
    ),
  );
}

class _ServerValidationSection extends StatelessWidget {
  const _ServerValidationSection({required this.result});

  final GenerationResult result;

  @override
  Widget build(BuildContext context) {
    final violations = result.violations;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SynchroSpacing.gutter,
        SynchroSpacing.md,
        SynchroSpacing.gutter,
        0,
      ),
      child: SectionCard(
        overline: 'Server validation · run #${result.runId}',
        title: violations.isEmpty
            ? 'No hard violations returned'
            : '${violations.length} conflicts',
        trailing: StatusChip(
          label: result.publishable ? 'publishable' : 'not publishable',
          tone: result.publishable ? Tone.good : Tone.bad,
          icon: result.publishable ? Icons.verified : Icons.gpp_bad,
        ),
        padding: const EdgeInsets.all(SynchroSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result.publishable
                  ? 'The server validator found no hard conflicts.'
                  : 'Review the validator findings before publishing.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (violations.isNotEmpty) ...[
              const SizedBox(height: SynchroSpacing.sm),
              for (var index = 0; index < violations.length; index++) ...[
                if (index > 0) const Divider(height: SynchroSpacing.md),
                _ServerViolation(violation: violations[index]),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _ServerViolation extends StatelessWidget {
  const _ServerViolation({required this.violation});

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
              _serverRuleName(violation.code),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: SynchroSpacing.xs),
            Text(
              violation.message,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (violation.refs.isNotEmpty)
              Text(
                violation.refs.join(' · '),
                style: Theme.of(context).textTheme.labelSmall,
              ),
          ],
        ),
      ),
    ],
  );
}

String _serverRuleName(String code) => switch (code) {
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

class _ManagementPage extends StatelessWidget {
  const _ManagementPage({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(title),
      leading: IconButton(
        tooltip: 'Back',
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.arrow_back),
      ),
    ),
    body: child,
  );
}
