import 'package:flutter/material.dart';

import '../state/manual_timetable_controller.dart';
import '../theme/tokens.dart';
import '../widgets/ui.dart';
import 'overview_screen.dart';
import 'synchro_flow_widgets.dart';

/// Editable setup surface for the four local scheduling collections.
///
/// Term fields and selected days are intentionally kept as screen state because
/// the existing manual controller owns draft records, not institution settings.
/// The host can persist or replace those values later through the callbacks.
class SetupScreen extends StatefulWidget {
  const SetupScreen({
    super.key,
    required this.controller,
    this.institutionName = synchroDefaultInstitution,
    this.semesterLabel = synchroDefaultSemester,
    this.onSetupComplete,
    this.onGenerate,
    this.onReview,
    this.onOpenWorkload,
    this.onOpenRooms,
    this.onReset,
  });

  final ManualTimetableController controller;
  final String institutionName;
  final String semesterLabel;

  /// Called when all prerequisites are present and the user confirms setup.
  final VoidCallback? onSetupComplete;

  /// Hands off to the future generator without claiming that output exists.
  final VoidCallback? onGenerate;

  /// Opens the host's collection editor/review flow.
  final VoidCallback? onReview;
  final VoidCallback? onOpenWorkload;
  final VoidCallback? onOpenRooms;

  /// Called after the local sample draft is restored.
  final VoidCallback? onReset;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  late final TextEditingController _institutionController;
  late final TextEditingController _semesterController;
  late Set<int> _selectedDays;
  late String _breakLabel;
  late int _breakStart;
  late int _breakEnd;

  ManualTimetableController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _institutionController = TextEditingController(
      text: widget.institutionName,
    );
    _semesterController = TextEditingController(text: widget.semesterLabel);
    _loadTermValuesFromController();
  }

  @override
  void dispose() {
    _institutionController.dispose();
    _semesterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final readiness = _readiness;
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
                    _SetupTopbar(onReset: () => _confirmReset(context)),
                    const SizedBox(height: 30),
                    SynchroFlowHeading(
                      overline: 'SETUP',
                      title: 'Make the term fit',
                      subtitle: 'Confirm the rhythm of the week, then review the records used for scheduling.',
                    ),
                    const SizedBox(height: 24),
                    _TermEditorCard(
                      institutionController: _institutionController,
                      semesterController: _semesterController,
                      selectedDays: _selectedDays,
                      breakLabel: _breakLabel,
                      breakStart: _breakStart,
                      breakEnd: _breakEnd,
                      onInstitutionChanged: (value) {
                        controller.updateSetup(institution: value);
                        setState(() {});
                      },
                      onSemesterChanged: (value) {
                        controller.updateSetup(semester: value);
                        setState(() {});
                      },
                      onDayToggled: _toggleDay,
                      onEditBreak: _editBreak,
                    ),
                    const SizedBox(height: 16),
                    _SetupReadinessCard(
                      readiness: readiness,
                      onReview: _review,
                    ),
                    const SizedBox(height: 16),
                    _ResourceReviewGrid(
                      controller: controller,
                      onReview: _review,
                      onOpenWorkload: widget.onOpenWorkload,
                      onOpenRooms: widget.onOpenRooms,
                    ),
                    const SizedBox(height: 16),
                    _EditableSetupRecords(
                      controller: controller,
                      onEditBatch: _editBatch,
                      onEditSubject: _editSubject,
                    ),
                    const SizedBox(height: 16),
                    _TeachingRequirementsCard(
                      controller: controller,
                      onEdit: _editRequirement,
                    ),
                    const SizedBox(height: 24),
                    _SetupActions(
                      readiness: readiness,
                      onSetupComplete: _completeSetup,
                      onGenerate: _generate,
                      onReview: _review,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'These records are local sample data until the host flow persists or replaces them.',
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

  SynchroSetupReadiness get _readiness => SynchroSetupReadiness.fromController(
    controller: controller,
    institution: _institutionController.text,
    semester: _semesterController.text,
    workingDays: _selectedDays,
  );

  void _loadTermValuesFromController() {
    _selectedDays = synchroWorkingDays(controller).toSet();
    final breakSummary = synchroBreakSummary(controller);
    _breakLabel = breakSummary?.label ?? 'Lunch break';
    _breakStart = breakSummary?.startMinute ?? 720;
    _breakEnd = breakSummary?.endMinute ?? 750;
  }

  void _toggleDay(int day, bool selected) {
    setState(() {
      if (selected) {
        _selectedDays.add(day);
      } else {
        _selectedDays.remove(day);
      }
    });
    controller.updateSetup(workingDays: _selectedDays);
  }

  Future<void> _editBreak() async {
    final labelController = TextEditingController(text: _breakLabel);
    var start = _breakStart;
    var end = _breakEnd;
    final result = await showModalBottomSheet<_BreakDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(SynchroRadius.sheet),
        ),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final endChoices = _breakTimes.where((time) => time > start).toList();
          if (!endChoices.contains(end)) end = endChoices.last;
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                SynchroSpacing.gutter,
                SynchroSpacing.lg,
                SynchroSpacing.gutter,
                MediaQuery.viewInsetsOf(context).bottom + SynchroSpacing.gutter,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Break details',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: SynchroSpacing.xs),
                  Text(
                    'Use a short label and a clear time range for each working day.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: SynchroSpacing.lg),
                  TextField(
                    controller: labelController,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(labelText: 'Break label'),
                  ),
                  const SizedBox(height: SynchroSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: start,
                          decoration: const InputDecoration(
                            labelText: 'Starts',
                          ),
                          items: [
                            for (final time in _breakTimes)
                              DropdownMenuItem(
                                value: time,
                                child: Text(synchroTime(time)),
                              ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setSheetState(() {
                              start = value;
                              if (end <= start) {
                                end = _breakTimes.firstWhere(
                                  (time) => time > start,
                                  orElse: () => start + 30,
                                );
                              }
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: SynchroSpacing.md),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: end,
                          decoration: const InputDecoration(labelText: 'Ends'),
                          items: [
                            for (final time in endChoices)
                              DropdownMenuItem(
                                value: time,
                                child: Text(synchroTime(time)),
                              ),
                          ],
                          onChanged: (value) {
                            if (value != null) setSheetState(() => end = value);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: SynchroSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(sheetContext).pop(
                        _BreakDraft(
                          label: labelController.text.trim().isEmpty
                              ? 'Break'
                              : labelController.text.trim(),
                          start: start,
                          end: end,
                        ),
                      ),
                      child: const Text('Save break details'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    labelController.dispose();
    if (!mounted || result == null) return;
    setState(() {
      _breakLabel = result.label;
      _breakStart = result.start;
      _breakEnd = result.end;
    });
    controller.updateSetup(
      breakLabel: result.label,
      breakStart: result.start,
      breakEnd: result.end,
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset local demo?'),
        content: const Text(
          'Restore the sample term and collection records for a clean review.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Reset demo'),
          ),
        ],
      ),
    );
    if (shouldReset != true) return;
    await controller.resetDemo();
    if (!mounted) return;
    _institutionController.text = widget.institutionName;
    _semesterController.text = widget.semesterLabel;
    setState(_loadTermValuesFromController);
    widget.onReset?.call();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Local demo restored.')));
  }

  void _review() {
    if (widget.onReview != null) {
      widget.onReview!();
      return;
    }
    _showMessage('Review callback is ready for the host flow.');
  }

  Future<void> _editRequirement(
    TimetableTeachingRequirement requirement,
  ) async {
    final lectureController = TextEditingController(
      text: '${requirement.lectureSessions ?? 0}',
    );
    final labController = TextEditingController(
      text: '${requirement.labSessions ?? 0}',
    );
    var facultyId = requirement.facultyId;
    final result = await showModalBottomSheet<_RequirementDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(SynchroRadius.sheet),
        ),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              SynchroSpacing.gutter,
              SynchroSpacing.lg,
              SynchroSpacing.gutter,
              MediaQuery.viewInsetsOf(context).bottom + SynchroSpacing.gutter,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Edit teaching requirement',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: SynchroSpacing.xs),
                Text(
                  '${controller.subjectById(requirement.subjectId)?.name ?? requirement.subjectId} · ${controller.batchById(requirement.batchId)?.name ?? requirement.batchId}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: SynchroSpacing.lg),
                DropdownButtonFormField<String>(
                  initialValue: facultyId,
                  decoration: const InputDecoration(
                    labelText: 'Assigned faculty',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  items: [
                    for (final teacher in controller.faculty)
                      DropdownMenuItem(
                        value: teacher.id,
                        child: Text(teacher.name),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) setSheetState(() => facultyId = value);
                  },
                ),
                const SizedBox(height: SynchroSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: lectureController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Lecture sessions',
                        ),
                      ),
                    ),
                    const SizedBox(width: SynchroSpacing.md),
                    Expanded(
                      child: TextField(
                        controller: labController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Lab sessions',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: SynchroSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(sheetContext).pop(
                      _RequirementDraft(
                        facultyId: facultyId,
                        lectureSessions: int.tryParse(lectureController.text),
                        labSessions: int.tryParse(labController.text),
                      ),
                    ),
                    child: const Text('Save requirement'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    lectureController.dispose();
    labController.dispose();
    if (!mounted || result == null) return;
    controller.editRequirement(
      requirement.copyWith(
        facultyId: result.facultyId,
        lectureSessions: result.lectureSessions,
        labSessions: result.labSessions,
      ),
    );
  }

  Future<void> _editBatch(ManualBatch batch) async {
    final nameController = TextEditingController(text: batch.name);
    final yearController = TextEditingController(text: '${batch.year}');
    final sizeController = TextEditingController(text: '${batch.size}');
    final result = await showDialog<ManualBatch>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit student batch'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Batch name'),
              ),
              TextField(
                controller: yearController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Academic year'),
              ),
              TextField(
                controller: sizeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Student count'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(
              batch.copyWith(
                name: nameController.text.trim().isEmpty
                    ? batch.name
                    : nameController.text.trim(),
                year: int.tryParse(yearController.text) ?? batch.year,
                size: int.tryParse(sizeController.text) ?? batch.size,
              ),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    nameController.dispose();
    yearController.dispose();
    sizeController.dispose();
    if (result != null) controller.editBatch(result);
  }

  Future<void> _editSubject(ManualSubject subject) async {
    final nameController = TextEditingController(text: subject.name);
    final codeController = TextEditingController(text: subject.code);
    final lectureController = TextEditingController(
      text: '${subject.lectureHours}',
    );
    final labController = TextEditingController(text: '${subject.labHours}');
    var practical = subject.isPractical;
    final result = await showDialog<ManualSubject>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit subject'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Subject name'),
                ),
                TextField(
                  controller: codeController,
                  decoration: const InputDecoration(labelText: 'Subject code'),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: lectureController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Lecture hours',
                        ),
                      ),
                    ),
                    const SizedBox(width: SynchroSpacing.md),
                    Expanded(
                      child: TextField(
                        controller: labController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Lab hours',
                        ),
                      ),
                    ),
                  ],
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: practical,
                  onChanged: (value) =>
                      setDialogState(() => practical = value ?? false),
                  title: const Text('Practical / laboratory subject'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(
                subject.copyWith(
                  name: nameController.text.trim().isEmpty
                      ? subject.name
                      : nameController.text.trim(),
                  code: codeController.text.trim().isEmpty
                      ? subject.code
                      : codeController.text.trim(),
                  isPractical: practical,
                  lectureHours:
                      int.tryParse(lectureController.text) ??
                      subject.lectureHours,
                  labHours:
                      int.tryParse(labController.text) ?? subject.labHours,
                ),
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
    codeController.dispose();
    lectureController.dispose();
    labController.dispose();
    if (result != null) controller.editSubject(result);
  }

  void _completeSetup() {
    final readiness = _readiness;
    if (!readiness.isComplete) {
      _showMissing(readiness);
      return;
    }
    if (widget.onSetupComplete != null) {
      widget.onSetupComplete!();
      return;
    }
    _showMessage('Setup is complete and ready for the next step.');
  }

  void _generate() {
    final readiness = _readiness;
    if (!readiness.isComplete) {
      _showMissing(readiness);
      return;
    }
    if (widget.onGenerate != null) {
      widget.onGenerate!();
      return;
    }
    _showMessage('Ready to hand off to the generator.');
  }

  void _showMissing(SynchroSetupReadiness readiness) {
    final labels = readiness.missing.map((item) => item.label).join(', ');
    _showMessage('Complete these first: $labels.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SetupTopbar extends StatelessWidget {
  const _SetupTopbar({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(
        onPressed: () => Navigator.of(context).maybePop(),
        tooltip: 'Back',
        icon: const Icon(Icons.arrow_back),
      ),
      const SizedBox(width: SynchroSpacing.xs),
      const Expanded(
        child: Text(
          'Term setup',
          style: TextStyle(
            fontSize: SynchroType.section,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      StatusChip(
        label: 'Local draft',
        tone: Tone.neutral,
        icon: Icons.edit_note_outlined,
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

class _TermEditorCard extends StatelessWidget {
  const _TermEditorCard({
    required this.institutionController,
    required this.semesterController,
    required this.selectedDays,
    required this.breakLabel,
    required this.breakStart,
    required this.breakEnd,
    required this.onInstitutionChanged,
    required this.onSemesterChanged,
    required this.onDayToggled,
    required this.onEditBreak,
  });

  final TextEditingController institutionController;
  final TextEditingController semesterController;
  final Set<int> selectedDays;
  final String breakLabel;
  final int breakStart;
  final int breakEnd;
  final ValueChanged<String> onInstitutionChanged;
  final ValueChanged<String> onSemesterChanged;
  final void Function(int day, bool selected) onDayToggled;
  final VoidCallback onEditBreak;

  @override
  Widget build(BuildContext context) => SectionCard(
    overline: 'Term details',
    title: 'Set the weekly rhythm',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: institutionController,
          onChanged: onInstitutionChanged,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Institution',
            prefixIcon: Icon(Icons.school_outlined),
          ),
        ),
        const SizedBox(height: SynchroSpacing.md),
        TextField(
          controller: semesterController,
          onChanged: onSemesterChanged,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Semester',
            prefixIcon: Icon(Icons.calendar_today_outlined),
          ),
        ),
        const SizedBox(height: SynchroSpacing.lg),
        Text('Working days', style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: SynchroSpacing.sm),
        Wrap(
          spacing: SynchroSpacing.sm,
          runSpacing: SynchroSpacing.sm,
          children: [
            for (
              var day = 0;
              day < ManualTimetableController.dayNames.length;
              day++
            )
              FilterChip(
                label: Text(synchroDayShort(day)),
                selected: selectedDays.contains(day),
                onSelected: (selected) => onDayToggled(day, selected),
              ),
          ],
        ),
        const SizedBox(height: SynchroSpacing.lg),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.free_breakfast_outlined,
              size: 19,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: SynchroSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Break', style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 3),
                  Text(
                    '$breakLabel · ${synchroTime(breakStart)}–${synchroTime(breakEnd)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: onEditBreak,
              icon: const Icon(Icons.edit_outlined, size: 17),
              label: const Text('Edit'),
            ),
          ],
        ),
      ],
    ),
  );
}

class _SetupReadinessCard extends StatelessWidget {
  const _SetupReadinessCard({required this.readiness, required this.onReview});

  final SynchroSetupReadiness readiness;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final isReady = readiness.isComplete;
    final tone = isReady ? Tone.good : Tone.warn;
    return SectionCard(
      overline: 'Readiness',
      title: '${readiness.completed} of ${readiness.total} ready',
      trailing: StatusChip(
        label: isReady ? 'Complete' : 'Missing items',
        tone: tone,
        icon: isReady ? Icons.check_circle_outline : Icons.info_outline,
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
          for (
            var index = 0;
            index < readiness.prerequisites.length;
            index++
          ) ...[
            if (index > 0) const Divider(height: SynchroSpacing.lg),
            _PrerequisiteRow(item: readiness.prerequisites[index]),
          ],
          const SizedBox(height: SynchroSpacing.md),
          TextButton.icon(
            onPressed: onReview,
            icon: const Icon(Icons.rule_outlined, size: 18),
            label: const Text('Review local draft'),
          ),
        ],
      ),
    );
  }
}

class _PrerequisiteRow extends StatelessWidget {
  const _PrerequisiteRow({required this.item});

  final SynchroPrerequisite item;

  @override
  Widget build(BuildContext context) {
    final tone = item.isComplete ? Tone.good : Tone.warn;
    final color = StatusChip.color(tone, Theme.of(context).brightness);
    return Row(
      children: [
        Icon(
          item.isComplete ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 19,
          color: color,
        ),
        const SizedBox(width: SynchroSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.label, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 2),
              Text(item.detail, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _ResourceReviewGrid extends StatelessWidget {
  const _ResourceReviewGrid({
    required this.controller,
    required this.onReview,
    this.onOpenWorkload,
    this.onOpenRooms,
  });

  final ManualTimetableController controller;
  final VoidCallback onReview;
  final VoidCallback? onOpenWorkload;
  final VoidCallback? onOpenRooms;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Scheduling collections',
        style: Theme.of(context).textTheme.labelSmall,
      ),
      const SizedBox(height: SynchroSpacing.sm),
      LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 560 ? 2 : 1;
          final width =
              (constraints.maxWidth - SynchroSpacing.sm * (columns - 1)) /
              columns;
          return Wrap(
            spacing: SynchroSpacing.sm,
            runSpacing: SynchroSpacing.sm,
            children: [
              SizedBox(
                width: width,
                child: _ResourceCard(
                  title: 'Faculty',
                  icon: Icons.people_outline,
                  count: controller.faculty.length,
                  preview: controller.faculty
                      .take(3)
                      .map((person) => person.name)
                      .toList(),
                  onReview: onOpenWorkload ?? onReview,
                ),
              ),
              SizedBox(
                width: width,
                child: _ResourceCard(
                  title: 'Batches',
                  icon: Icons.groups_outlined,
                  count: controller.batches.length,
                  preview: controller.batches
                      .take(3)
                      .map((batch) => '${batch.name} · ${batch.size} students')
                      .toList(),
                  onReview: onReview,
                ),
              ),
              SizedBox(
                width: width,
                child: _ResourceCard(
                  title: 'Subjects',
                  icon: Icons.menu_book_outlined,
                  count: controller.subjects.length,
                  preview: controller.subjects
                      .take(3)
                      .map((subject) => '${subject.code} · ${subject.name}')
                      .toList(),
                  onReview: onReview,
                ),
              ),
              SizedBox(
                width: width,
                child: _ResourceCard(
                  title: 'Rooms & labs',
                  icon: Icons.meeting_room_outlined,
                  count: controller.rooms.length,
                  preview: controller.rooms
                      .take(3)
                      .map((room) => '${room.name} · ${room.capacity} seats')
                      .toList(),
                  onReview: onOpenRooms ?? onReview,
                ),
              ),
            ],
          );
        },
      ),
    ],
  );
}

class _ResourceCard extends StatelessWidget {
  const _ResourceCard({
    required this.title,
    required this.icon,
    required this.count,
    required this.preview,
    required this.onReview,
  });

  final String title;
  final IconData icon;
  final int count;
  final List<String> preview;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) => SectionCard(
    padding: const EdgeInsets.all(SynchroSpacing.lg),
    title: title,
    trailing: StatusChip(label: '$count', tone: Tone.neutral),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: SynchroSpacing.sm),
            Expanded(
              child: Text(
                preview.isEmpty ? 'No records yet' : preview.first,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        if (preview.length > 1) ...[
          const SizedBox(height: SynchroSpacing.xs),
          Text(
            '+${preview.length - 1} more in this draft',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: SynchroSpacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(onPressed: onReview, child: const Text('Review')),
        ),
      ],
    ),
  );
}

class _SetupActions extends StatelessWidget {
  const _SetupActions({
    required this.readiness,
    required this.onSetupComplete,
    required this.onGenerate,
    required this.onReview,
  });

  final SynchroSetupReadiness readiness;
  final VoidCallback onSetupComplete;
  final VoidCallback onGenerate;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FilledButton.icon(
        onPressed: onSetupComplete,
        icon: Icon(
          readiness.isComplete
              ? Icons.arrow_forward_outlined
              : Icons.info_outline,
        ),
        label: Text(
          readiness.isComplete ? 'Complete setup' : 'Complete missing items',
        ),
      ),
      const SizedBox(height: SynchroSpacing.sm),
      OutlinedButton.icon(
        onPressed: readiness.isComplete ? onGenerate : null,
        icon: const Icon(Icons.auto_awesome_outlined, size: 18),
        label: const Text('Generate timetable'),
      ),
      const SizedBox(height: SynchroSpacing.sm),
      TextButton.icon(
        onPressed: onReview,
        icon: const Icon(Icons.rule_outlined, size: 18),
        label: const Text('Review local draft'),
      ),
    ],
  );
}

class _EditableSetupRecords extends StatelessWidget {
  const _EditableSetupRecords({
    required this.controller,
    required this.onEditBatch,
    required this.onEditSubject,
  });

  final ManualTimetableController controller;
  final ValueChanged<ManualBatch> onEditBatch;
  final ValueChanged<ManualSubject> onEditSubject;

  @override
  Widget build(BuildContext context) => SectionCard(
    overline: 'Review and edit',
    title: 'Batches and subjects',
    child: Column(
      children: [
        for (final batch in controller.batches)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.groups_outlined),
            title: Text(batch.name),
            subtitle: Text('${batch.year} year · ${batch.size} students'),
            trailing: IconButton(
              onPressed: () => onEditBatch(batch),
              tooltip: 'Edit batch',
              icon: const Icon(Icons.edit_outlined, size: 18),
            ),
          ),
        if (controller.batches.isNotEmpty && controller.subjects.isNotEmpty)
          const Divider(height: SynchroSpacing.lg),
        for (final subject in controller.subjects)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              subject.isPractical
                  ? Icons.science_outlined
                  : Icons.menu_book_outlined,
            ),
            title: Text('${subject.code} · ${subject.name}'),
            subtitle: Text(
              '${subject.lectureHours} lecture h · ${subject.labHours} lab h',
            ),
            trailing: IconButton(
              onPressed: () => onEditSubject(subject),
              tooltip: 'Edit subject',
              icon: const Icon(Icons.edit_outlined, size: 18),
            ),
          ),
      ],
    ),
  );
}

class _TeachingRequirementsCard extends StatelessWidget {
  const _TeachingRequirementsCard({
    required this.controller,
    required this.onEdit,
  });

  final ManualTimetableController controller;
  final ValueChanged<TimetableTeachingRequirement> onEdit;

  @override
  Widget build(BuildContext context) => SectionCard(
    overline: 'Teaching load',
    title: 'Requirements used by generation',
    child: Column(
      children: [
        for (
          var index = 0;
          index < controller.requirements.length;
          index++
        ) ...[
          if (index > 0) const Divider(height: SynchroSpacing.lg),
          _RequirementRow(
            controller: controller,
            requirement: controller.requirements[index],
            onEdit: onEdit,
          ),
        ],
      ],
    ),
  );
}

class _RequirementRow extends StatelessWidget {
  const _RequirementRow({
    required this.controller,
    required this.requirement,
    required this.onEdit,
  });

  final ManualTimetableController controller;
  final TimetableTeachingRequirement requirement;
  final ValueChanged<TimetableTeachingRequirement> onEdit;

  @override
  Widget build(BuildContext context) {
    final subject = controller.subjectById(requirement.subjectId);
    final batch = controller.batchById(requirement.batchId);
    final faculty = controller.facultyById(requirement.facultyId);
    final count = [
      if ((requirement.lectureSessions ?? 0) > 0)
        '${requirement.lectureSessions} lectures',
      if ((requirement.labSessions ?? 0) > 0)
        '${requirement.labSessions} lab${requirement.labSessions == 1 ? '' : 's'}',
    ].join(' · ');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          requirement.practicalOnly
              ? Icons.science_outlined
              : Icons.menu_book_outlined,
          size: 19,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: SynchroSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${subject?.code ?? requirement.subjectId} · ${batch?.name ?? requirement.batchId}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 2),
              Text(
                '${faculty?.name ?? requirement.facultyId} · ${count.isEmpty ? 'No sessions configured' : count}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => onEdit(requirement),
          tooltip: 'Edit requirement',
          icon: const Icon(Icons.edit_outlined, size: 18),
        ),
      ],
    );
  }
}

class _RequirementDraft {
  const _RequirementDraft({
    required this.facultyId,
    required this.lectureSessions,
    required this.labSessions,
  });

  final String facultyId;
  final int? lectureSessions;
  final int? labSessions;
}

class _BreakDraft {
  const _BreakDraft({
    required this.label,
    required this.start,
    required this.end,
  });

  final String label;
  final int start;
  final int end;
}

const List<int> _breakTimes = <int>[
  540,
  570,
  600,
  630,
  660,
  690,
  720,
  750,
  780,
  810,
  840,
  870,
  900,
];
