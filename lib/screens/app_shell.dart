import 'package:flutter/material.dart';

import '../brand/synchro_mark.dart';
import '../state/demo_auth.dart';
import '../state/scheduling_controller.dart';
import '../theme/theme_controller.dart';
import '../theme/tokens.dart';
import '../widgets/ui.dart';
import 'account_screen.dart';
import 'audit_screen.dart';
import 'conflicts_screen.dart';
import 'home_screen.dart';
import 'refine_screen.dart';
import 'setup_wizard_screen.dart';
import 'timetable_screen.dart';

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

  static const List<_Destination> _destinations = [
    _Destination('Home', Icons.home_outlined, Icons.home),
    _Destination(
      'Timetable',
      Icons.calendar_view_day_outlined,
      Icons.calendar_view_day,
    ),
    _Destination('Conflicts', Icons.rule_folder_outlined, Icons.rule_folder),
  ];

  SchedulingController get controller => widget.controller;

  @override
  void dispose() {
    _auth.dispose();
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
        builder: (context, _) {
          final violations = controller.result?.violations.length ?? 0;
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
    0 => HomeScreen(
      controller: controller,
      onCreateTimetable: _openSetup,
      onRefineTimetable: _openRefine,
      onOpenAccount: _openAccount,
      onOpenAudit: _openAudit,
    ),
    1 => TimetableScreen(controller: controller),
    _ => ConflictsScreen(controller: controller),
  };

  void _openSetup() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SetupWizardScreen(
          controller: controller,
          onBack: () => Navigator.of(context).pop(),
          onOpenTimetable: _returnToTimetable,
          onGenerated: (result) {
            if (result.solved) _returnToTimetable();
          },
        ),
      ),
    );
  }

  void _openRefine() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RefineScreen(
          controller: controller,
          onBack: () => Navigator.of(context).pop(),
          onOpenTimetable: _returnToTimetable,
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

  void _returnToTimetable() {
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
    setState(() => _index = 1);
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
