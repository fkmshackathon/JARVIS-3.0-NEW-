import 'package:flutter/material.dart';

import '../state/manual_timetable_controller.dart';
import '../state/scheduling_controller.dart';
import 'manual_timetable_screen.dart';

/// The primary timetable destination. It is intentionally local-first: the
/// current product prototype does not call a solver API or present a server
/// validation result as if it belonged to the editable draft.
class TimetableHubScreen extends StatelessWidget {
  const TimetableHubScreen({
    super.key,
    required this.controller,
    required this.manualController,
    this.onOpenWorkload,
    this.onOpenRooms,
    this.onHandleChange,
    this.onOpenIssues,
  });

  /// Kept at the shell boundary so existing app construction remains stable.
  /// The local editor deliberately does not read or call it.
  final SchedulingController controller;
  final ManualTimetableController manualController;
  final VoidCallback? onOpenWorkload;
  final VoidCallback? onOpenRooms;
  final VoidCallback? onHandleChange;
  final VoidCallback? onOpenIssues;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Timetable')),
    body: ManualTimetableScreen(
      controller: manualController,
      onOpenWorkload: onOpenWorkload,
      onOpenRooms: onOpenRooms,
      onHandleChange: onHandleChange,
      onOpenIssues: onOpenIssues,
    ),
  );
}
