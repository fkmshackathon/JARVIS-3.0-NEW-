import 'package:flutter/material.dart';

import '../brand/synchro_mark.dart';
import '../state/manual_timetable_controller.dart';
import '../theme/theme_controller.dart';
import '../theme/tokens.dart';
import '../widgets/ui.dart';
import 'manual_changes_screen.dart';
import 'manual_issues_screen.dart';
import 'manual_rooms_screen.dart';
import 'manual_workload_screen.dart';
import 'generate_timetable_screen.dart';
import 'overview_screen.dart';
import 'setup_screen.dart';

/// The compact product shell for the local timetable workspace. Home is the
/// starting point; issues, workload, rooms, and change handling stay one tap
/// away without adding redundant primary tabs.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.controller,
    required this.onSignOut,
  });

  final ManualTimetableController controller;
  final VoidCallback onSignOut;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  ManualTimetableController get _manualController => widget.controller;

  static const List<_Destination> _destinations = [
    _Destination('Overview', Icons.home_outlined, Icons.home),
    _Destination('Setup', Icons.tune_outlined, Icons.tune),
    _Destination(
      'Generate & Timetable',
      Icons.calendar_view_day_outlined,
      Icons.calendar_view_day,
    ),
    _Destination('Issues', Icons.rule_folder_outlined, Icons.rule_folder),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: _manualController,
        builder: (context, _) => SafeArea(
          bottom: false,
          child: Column(
            children: [
              if (_index != 0)
                _ShellHeader(
                  index: _index,
                  manualController: _manualController,
                  onSignOut: widget.onSignOut,
                ),
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
        listenable: _manualController,
        builder: (context, _) {
          final violations = _manualController.hardConflicts.length;
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
    );
  }

  Widget _screenFor(int index) => switch (index) {
    0 => OverviewScreen(
      controller: _manualController,
      institutionName: _manualController.institutionName,
      semesterLabel: _manualController.semesterLabel,
      onOpenSetup: () => _selectDestination(1),
      onGenerate: _generateAndOpen,
      onReview: () => _selectDestination(2),
      onOpenWorkload: _openWorkload,
      onOpenRooms: _openRooms,
      onSignOut: widget.onSignOut,
      onReset: () {},
    ),
    1 => SetupScreen(
      controller: _manualController,
      institutionName: _manualController.institutionName,
      semesterLabel: _manualController.semesterLabel,
      onSetupComplete: () => _selectDestination(2),
      onGenerate: _generateAndOpen,
      onReview: () => _selectDestination(2),
      onOpenWorkload: _openWorkload,
      onOpenRooms: _openRooms,
      onReset: () {},
    ),
    2 => GenerateTimetableScreen(
      controller: _manualController,
      onOpenSetup: () => _selectDestination(1),
      onOpenWorkload: _openWorkload,
      onOpenRooms: _openRooms,
      onHandleChange: _openRefine,
      onOpenIssues: _openIssues,
    ),
    _ => _IssuesDestination(manualController: _manualController),
  };

  void _selectDestination(int index) {
    if (!mounted) return;
    setState(() => _index = index);
  }

  void _generateAndOpen() {
    final setupIssues = _manualController.validateSetup();
    if (setupIssues.isNotEmpty) {
      _selectDestination(1);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(setupIssues.first.message)));
      });
      return;
    }
    _selectDestination(2);
    if (!_manualController.canGenerate) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _manualController.generateTimetable();
    });
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
          child: _IssuesDestination(manualController: _manualController),
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
    if (index != 3) return plain;
    return Badge(
      label: Text('$violations'),
      isLabelVisible: violations > 0,
      backgroundColor: SynchroColors.danger,
      child: plain,
    );
  }
}

class _ShellHeader extends StatelessWidget {
  const _ShellHeader({
    required this.index,
    required this.manualController,
    required this.onSignOut,
  });

  final int index;
  final ManualTimetableController manualController;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final status = manualController.needsRegeneration
        ? const _ShellStatus(label: 'Needs regen', tone: Tone.warn)
        : manualController.setupIssues.isNotEmpty
        ? const _ShellStatus(label: 'Fix setup', tone: Tone.bad)
        : manualController.hasLocalValidation
        ? _ShellStatus(
            label: manualController.hardConflicts.isEmpty ? 'Checked' : 'Fixes',
            tone: manualController.hardConflicts.isEmpty ? Tone.good : Tone.bad,
          )
        : const _ShellStatus(label: 'Draft', tone: Tone.warn);

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
                  manualController.dataLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: SynchroColors.onNavyMuted),
                ),
              ],
            ),
          ),
          status,
          IconButton(
            tooltip: 'Sign out of local demo',
            onPressed: onSignOut,
            icon: const Icon(
              Icons.logout_outlined,
              size: 20,
              color: SynchroColors.onNavyMuted,
            ),
          ),
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

/// The Issues destination reads only the current local manual draft.
class _IssuesDestination extends StatelessWidget {
  const _IssuesDestination({required this.manualController});

  final ManualTimetableController manualController;

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: ManualIssuesScreen(controller: manualController));
}

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
