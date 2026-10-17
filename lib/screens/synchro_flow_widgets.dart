import 'package:flutter/material.dart';

import '../state/manual_timetable_controller.dart';

/// Small, reusable pieces of the setup flow that intentionally stay local to
/// the UI. The controller remains the source of truth for all draft records.
class SynchroPrerequisite {
  const SynchroPrerequisite({
    required this.label,
    required this.detail,
    required this.isComplete,
  });

  final String label;
  final String detail;
  final bool isComplete;
}

/// Computes setup readiness without introducing a second state model.
class SynchroSetupReadiness {
  const SynchroSetupReadiness({required this.prerequisites});

  factory SynchroSetupReadiness.fromController({
    required ManualTimetableController controller,
    required String institution,
    required String semester,
    Iterable<int>? workingDays,
  }) {
    final days = (workingDays ?? synchroWorkingDays(controller)).toSet();
    final hasInstitution = institution.trim().isNotEmpty;
    final hasSemester = semester.trim().isNotEmpty;
    final hasWorkingDays = days.isNotEmpty;
    final hasFaculty = controller.faculty.isNotEmpty;
    final hasBatches = controller.batches.isNotEmpty;
    final hasSubjects = controller.subjects.isNotEmpty;
    final hasRooms = controller.rooms.isNotEmpty;
    final hasRequirements = controller.requirements.isNotEmpty;
    final hasTeachingSlots = controller.timeSlots.any((slot) => !slot.isBreak);
    final hasBreak = controller.breaks.any(
      (slot) => slot.endMinute - slot.startMinute >= 30,
    );

    return SynchroSetupReadiness(
      prerequisites: <SynchroPrerequisite>[
        SynchroPrerequisite(
          label: 'Institution',
          detail: hasInstitution ? institution.trim() : 'Add an institution',
          isComplete: hasInstitution,
        ),
        SynchroPrerequisite(
          label: 'Semester',
          detail: hasSemester ? semester.trim() : 'Choose a semester',
          isComplete: hasSemester,
        ),
        SynchroPrerequisite(
          label: 'Working days',
          detail: hasWorkingDays
              ? '${days.length} day${days.length == 1 ? '' : 's'} selected'
              : 'Select at least one day',
          isComplete: hasWorkingDays,
        ),
        SynchroPrerequisite(
          label: 'Faculty',
          detail: hasFaculty
              ? '${controller.faculty.length} loaded'
              : 'Add faculty records',
          isComplete: hasFaculty,
        ),
        SynchroPrerequisite(
          label: 'Batches',
          detail: hasBatches
              ? '${controller.batches.length} loaded'
              : 'Add at least one batch',
          isComplete: hasBatches,
        ),
        SynchroPrerequisite(
          label: 'Subjects',
          detail: hasSubjects
              ? '${controller.subjects.length} loaded'
              : 'Add subject records',
          isComplete: hasSubjects,
        ),
        SynchroPrerequisite(
          label: 'Rooms',
          detail: hasRooms
              ? '${controller.rooms.length} available in the draft'
              : 'Add rooms or labs',
          isComplete: hasRooms,
        ),
        SynchroPrerequisite(
          label: 'Teaching requirements',
          detail: hasRequirements
              ? '${controller.requirements.length} mapped loads'
              : 'Map subjects to batches and faculty',
          isComplete: hasRequirements,
        ),
        SynchroPrerequisite(
          label: 'Available slots',
          detail: hasTeachingSlots
              ? '${controller.timeSlots.where((slot) => !slot.isBreak).length} teaching slots'
              : 'Define teaching time slots',
          isComplete: hasTeachingSlots,
        ),
        SynchroPrerequisite(
          label: 'Mandatory break',
          detail: hasBreak
              ? 'At least 30 minutes is reserved in the week'
              : 'Add a mandatory 30-minute break',
          isComplete: hasBreak,
        ),
      ],
    );
  }

  final List<SynchroPrerequisite> prerequisites;

  int get total => prerequisites.length;

  int get completed => prerequisites.where((item) => item.isComplete).length;

  bool get isComplete => completed == total && total > 0;

  double get progress => total == 0 ? 0 : completed / total;

  List<SynchroPrerequisite> get missing =>
      prerequisites.where((item) => !item.isComplete).toList(growable: false);
}

/// Returns the teaching days represented by the controller's local time grid.
List<int> synchroWorkingDays(ManualTimetableController controller) {
  final days =
      controller.timeSlots
          .map((slot) => slot.day)
          .where(
            (day) =>
                day >= 0 && day < ManualTimetableController.dayNames.length,
          )
          .toSet()
          .toList()
        ..sort();
  return days;
}

/// A distinct break range for use in compact summaries.
class SynchroBreakSummary {
  const SynchroBreakSummary({
    required this.label,
    required this.startMinute,
    required this.endMinute,
  });

  final String label;
  final int startMinute;
  final int endMinute;
}

SynchroBreakSummary? synchroBreakSummary(ManualTimetableController controller) {
  final breaks = controller.breaks;
  if (breaks.isEmpty) return null;
  final first = breaks.first;
  return SynchroBreakSummary(
    label: first.label?.trim().isNotEmpty == true
        ? first.label!.trim()
        : 'Break',
    startMinute: first.startMinute,
    endMinute: first.endMinute,
  );
}

String synchroTime(int minutes) {
  final hour = minutes ~/ 60;
  final minute = minutes % 60;
  final suffix = hour >= 12 ? 'PM' : 'AM';
  final displayHour = hour % 12 == 0 ? 12 : hour % 12;
  return '$displayHour:${minute.toString().padLeft(2, '0')} $suffix';
}

String synchroDayShort(int day) {
  if (day < 0 || day >= ManualTimetableController.dayNames.length) {
    return 'Day ${day + 1}';
  }
  return ManualTimetableController.dayNames[day].substring(0, 3);
}

/// A wide, quiet heading shared by the Overview and Setup surfaces.
class SynchroFlowHeading extends StatelessWidget {
  const SynchroFlowHeading({
    super.key,
    required this.title,
    required this.subtitle,
    this.overline = 'SYNCHRO',
    this.trailing,
  });

  final String overline;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(overline.toUpperCase(), style: theme.textTheme.labelSmall),
              const SizedBox(height: 6),
              Text(title, style: theme.textTheme.displaySmall),
              const SizedBox(height: 6),
              Text(subtitle, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
      ],
    );
  }
}

/// A compact metric tile for the four setup collections.
class SynchroMetricTile extends StatelessWidget {
  const SynchroMetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.onTap,
  });

  final String label;
  final int value;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Container(
      constraints: const BoxConstraints(minHeight: 104),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$value',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (onTap == null) return content;
    return Semantics(
      button: true,
      label: 'Review $label',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: content,
      ),
    );
  }
}
