import 'package:flutter/material.dart';

import '../brand/synchro_mark.dart';
import '../state/scheduling_controller.dart';
import '../theme/theme_controller.dart';
import '../theme/tokens.dart';
import '../widgets/ui.dart';
import 'audit_screen.dart';
import 'conflicts_screen.dart';
import 'timetable_screen.dart';

/// Three destinations, in the order a coordinator actually works: read the
/// workload, generate, then check what the validator said.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.controller});

  final SchedulingController controller;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const List<_Destination> _destinations = [
    _Destination('Workload', Icons.assignment_outlined, Icons.assignment),
    _Destination('Timetable', Icons.grid_view_outlined, Icons.grid_view),
    _Destination('Conflicts', Icons.rule_folder_outlined, Icons.rule_folder),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final screens = [
            AuditScreen(controller: widget.controller),
            TimetableScreen(controller: widget.controller),
            ConflictsScreen(controller: widget.controller),
          ];
          return SafeArea(
            bottom: false,
            child: Column(
              children: [
                _Header(controller: widget.controller),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: SynchroMotion.quick,
                    switchInCurve: SynchroMotion.entrance,
                    child: KeyedSubtree(
                      key: ValueKey(_index),
                      child: screens[_index],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          // Only the conflicts tab earns a badge, because a badge there is a warning.
          final violations = widget.controller.result?.violations.length ?? 0;
          return NavigationBar(
            selectedIndex: _index,
            height: 68,
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

class _Header extends StatelessWidget {
  const _Header({required this.controller});

  final SchedulingController controller;

  @override
  Widget build(BuildContext context) {
    final campus = controller.campus;
    final solved = controller.result != null && controller.result!.solved;
    final publishable = controller.result?.publishable ?? false;

    return Container(
      color: SynchroColors.navy,
      padding: const EdgeInsets.fromLTRB(SynchroSpacing.gutter, SynchroSpacing.md, SynchroSpacing.gutter, SynchroSpacing.lg),
      child: Row(
        children: [
          const SynchroMark(size: 40, badge: false),
          const SizedBox(width: SynchroSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  campus?.name ?? 'SYNCHRO',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: SynchroColors.onNavy),
                ),
                Text(
                  controller.backendUrl.replaceFirst('http://', ''),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: SynchroColors.onNavyMuted),
                ),
              ],
            ),
          ),
          _Pulse(
            label: publishable
                ? 'PUBLISHABLE'
                : solved
                    ? 'SOLVED'
                    : 'NO TIMETABLE',
            tone: publishable ? Tone.good : solved ? Tone.warn : Tone.neutral,
          ),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: appThemeMode,
            builder: (context, mode, _) => IconButton(
              tooltip: mode == ThemeMode.light ? 'Switch to dark' : 'Switch to light',
              onPressed: () => appThemeMode.value = toggleTheme(mode),
              icon: Icon(
                mode == ThemeMode.light ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
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

/// On-navy status pill: the light tones in [StatusChip] are tuned for cream.
class _Pulse extends StatelessWidget {
  const _Pulse({required this.label, required this.tone});

  final String label;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final ink = switch (tone) {
      Tone.good => SynchroColors.cream,
      Tone.warn => SynchroColors.orange,
      _ => SynchroColors.onNavyMuted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: SynchroSpacing.md, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(SynchroRadius.pill),
        border: Border.all(color: ink.withValues(alpha: 0.55)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: SynchroType.micro,
          fontWeight: FontWeight.w700,
          letterSpacing: SynchroType.overlineTracking * 0.6,
          color: ink,
        ),
      ),
    );
  }
}
