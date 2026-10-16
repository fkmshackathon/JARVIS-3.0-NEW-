import 'package:flutter/material.dart';

import '../data/models.dart';
import '../state/manual_timetable_controller.dart';
import '../state/scheduling_controller.dart';
import '../theme/tokens.dart';
import 'manual_timetable_screen.dart';
import 'timetable_screen.dart';

/// The timetable destination has two honest sources of truth:
///
///  * the local manual draft, which is the default editing surface; and
///  * the server result, which is only available after [SchedulingController]
///    has received a real solver response.
///
/// The controllers are supplied by the shell so the manual draft remains alive
/// when the user visits another management view.
class TimetableHubScreen extends StatefulWidget {
  const TimetableHubScreen({
    super.key,
    required this.controller,
    required this.manualController,
    this.onOpenWorkload,
    this.onOpenRooms,
    this.onHandleChange,
    this.onOpenIssues,
  });

  final SchedulingController controller;
  final ManualTimetableController manualController;
  final VoidCallback? onOpenWorkload;
  final VoidCallback? onOpenRooms;
  final VoidCallback? onHandleChange;
  final VoidCallback? onOpenIssues;

  @override
  State<TimetableHubScreen> createState() => _TimetableHubScreenState();
}

class _TimetableHubScreenState extends State<TimetableHubScreen> {
  late GenerationResult? _lastResult = widget.controller.result;
  bool _showSolver = false;

  SchedulingController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant TimetableHubScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_onControllerChanged);
    _lastResult = controller.result;
    controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    final current = controller.result;
    final shouldInspect =
        !_showSolver && _lastResult == null && current != null;
    _lastResult = current;
    if (!mounted) return;
    setState(() {
      if (shouldInspect) _showSolver = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showSolver) {
      return Scaffold(
        body: TimetableScreen(controller: controller),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => setState(() => _showSolver = false),
          backgroundColor: SynchroColors.orange,
          foregroundColor: SynchroColors.navyDeep,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Manual draft'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manual timetable'),
        bottom: _SolverActionBar(
          controller: controller,
          showSolver: false,
          onInspectSolver: () => setState(() => _showSolver = true),
          onOpenManual: () => setState(() => _showSolver = false),
        ),
      ),
      body: ManualTimetableScreen(
        controller: widget.manualController,
        onOpenWorkload: widget.onOpenWorkload,
        onOpenRooms: widget.onOpenRooms,
        onHandleChange: widget.onHandleChange,
        onOpenIssues: widget.onOpenIssues,
      ),
    );
  }
}

/// A compact hand-off between the local editor and the real solver result.
/// Generation remains available from the manual destination for connected
/// campuses, but inspecting a server timetable is never offered without a
/// [SchedulingController.result].
class _SolverActionBar extends StatelessWidget implements PreferredSizeWidget {
  const _SolverActionBar({
    required this.controller,
    required this.showSolver,
    required this.onInspectSolver,
    required this.onOpenManual,
  });

  final SchedulingController controller;
  final bool showSolver;
  final VoidCallback onInspectSolver;
  final VoidCallback onOpenManual;

  String? get _blocker =>
      controller.summary?.blocker ?? controller.previewBlocker;

  bool get _canGenerate =>
      controller.hasCampus &&
      controller.canGenerate &&
      controller.runPhase != RunPhase.running;

  @override
  Size get preferredSize => Size.fromHeight(
    showSolver
        ? 58
        : _blocker == null
        ? 74
        : 108,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (showSolver) {
      return Container(
        color: theme.colorScheme.surfaceContainerLow,
        padding: const EdgeInsets.fromLTRB(
          SynchroSpacing.gutter,
          SynchroSpacing.xs,
          SynchroSpacing.gutter,
          SynchroSpacing.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Server result · validator response',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ),
            const SizedBox(width: SynchroSpacing.sm),
            OutlinedButton.icon(
              onPressed: onOpenManual,
              icon: const Icon(Icons.edit_outlined, size: 17),
              label: const Text('Manual draft'),
            ),
          ],
        ),
      );
    }

    final hasResult = controller.result != null;
    final loading = controller.runPhase == RunPhase.running;
    final message = hasResult
        ? 'A real solver result is available to inspect.'
        : controller.hasCampus
        ? 'Manual draft · backend solver stays server-side.'
        : 'Backend result unavailable while offline.';

    return Container(
      color: theme.colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.fromLTRB(
        SynchroSpacing.gutter,
        SynchroSpacing.xs,
        SynchroSpacing.gutter,
        SynchroSpacing.sm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              const SizedBox(width: SynchroSpacing.sm),
              if (hasResult)
                OutlinedButton.icon(
                  onPressed: onInspectSolver,
                  icon: const Icon(Icons.cloud_outlined, size: 17),
                  label: const Text('Inspect server timetable'),
                )
              else
                FilledButton.icon(
                  onPressed: _canGenerate ? controller.generate : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: SynchroColors.orange,
                    foregroundColor: SynchroColors.navyDeep,
                  ),
                  icon: Icon(loading ? Icons.sync : Icons.bolt, size: 17),
                  label: Text(loading ? 'Generating…' : 'Generate timetable'),
                ),
            ],
          ),
          if (_blocker != null) ...[
            const SizedBox(height: SynchroSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _blocker!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
