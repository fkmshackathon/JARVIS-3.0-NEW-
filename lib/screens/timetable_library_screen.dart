import 'package:flutter/material.dart';

import '../state/timetable_library_controller.dart';
import '../theme/tokens.dart';
import '../widgets/ui.dart';

/// The result returned when the library route should move the user into setup.
enum TimetableLibraryNext { none, setup }

/// Compact local library for independent timetable drafts.
class TimetableLibraryScreen extends StatelessWidget {
  const TimetableLibraryScreen({super.key, required this.library});

  final TimetableLibraryController library;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('My timetables'),
      actions: [
        IconButton(
          tooltip: 'Create timetable',
          onPressed: () => _create(context),
          icon: const Icon(Icons.add),
        ),
      ],
    ),
    body: ListenableBuilder(
      listenable: library,
      builder: (context, _) {
        final records = library.records;
        return SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  SynchroSpacing.gutter,
                  SynchroSpacing.md,
                  SynchroSpacing.gutter,
                  SynchroSpacing.xxl,
                ),
                children: [
                  Text(
                    'Keep each academic schedule independent.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: SynchroSpacing.md),
                  FilledButton.icon(
                    key: const Key('create-timetable-button'),
                    onPressed: () => _create(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Create timetable'),
                    style: FilledButton.styleFrom(
                      backgroundColor: SynchroColors.orange,
                      foregroundColor: SynchroColors.navyDeep,
                    ),
                  ),
                  const SizedBox(height: SynchroSpacing.lg),
                  if (records.isEmpty)
                    const EmptyState(
                      title: 'No timetables saved',
                      body: 'Create a blank timetable or restore the demo data to begin.',
                      icon: Icons.calendar_view_day_outlined,
                    )
                  else
                    for (var index = 0; index < records.length; index++) ...[
                      if (index > 0) const SizedBox(height: SynchroSpacing.sm),
                      _TimetableRecordRow(
                        key: ValueKey('timetable-row-${records[index].id}'),
                        record: records[index],
                        isActive: records[index].id == library.activeId,
                        onOpen: () => _open(context, records[index].id),
                        onRename: () => _rename(context, records[index]),
                        onDuplicate: () => _duplicate(context, records[index]),
                        onDelete: () => _delete(context, records[index]),
                      ),
                    ],
                ],
              ),
            ),
          ),
        );
      },
    ),
  );

  Future<void> _create(BuildContext context) async {
    final draft = await _showCreateDialog(context);
    if (!context.mounted || draft == null) return;

    final created = draft.sourceId == null
        ? library.createBlank(userName: draft.name, term: draft.term)
        : library.duplicate(
            draft.sourceId!,
            userName: draft.name,
            term: draft.term,
          );
    if (created == null || !context.mounted) return;
    _close(context, TimetableLibraryNext.setup);
  }

  void _open(BuildContext context, String id) {
    if (!library.switchTo(id)) return;
    _close(context, TimetableLibraryNext.none);
  }

  Future<void> _rename(BuildContext context, TimetableRecord record) async {
    final name = await _showNameDialog(
      context,
      title: 'Rename timetable',
      initialValue: record.name,
      confirmLabel: 'Rename',
    );
    if (!context.mounted || name == null) return;
    library.rename(record.id, name);
  }

  void _duplicate(BuildContext context, TimetableRecord record) {
    final copy = library.duplicate(record.id);
    if (copy == null) return;
    _close(context, TimetableLibraryNext.setup);
  }

  Future<void> _delete(BuildContext context, TimetableRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete “${record.name}”?'),
        content: Text(
          'The saved draft and its ${record.sessionCount} generated session${record.sessionCount == 1 ? '' : 's'} will be removed. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: SynchroColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete timetable'),
          ),
        ],
      ),
    );
    if (confirmed == true) library.delete(record.id);
  }

  Future<_TimetableCreateDraft?> _showCreateDialog(BuildContext context) =>
      showDialog<_TimetableCreateDraft>(
        context: context,
        builder: (_) => _CreateTimetableDialog(
          records: library.records,
          initialTerm:
              library.activeRecord?.term ?? library.workspace.semesterLabel,
        ),
      );

  Future<String?> _showNameDialog(
    BuildContext context, {
    required String title,
    required String initialValue,
    required String confirmLabel,
  }) => showDialog<String>(
    context: context,
    builder: (_) => _TimetableNameDialog(
      title: title,
      initialValue: initialValue,
      confirmLabel: confirmLabel,
    ),
  );

  void _close(BuildContext context, TimetableLibraryNext next) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(next);
    }
  }
}

class _TimetableNameDialog extends StatefulWidget {
  const _TimetableNameDialog({
    required this.title,
    required this.initialValue,
    required this.confirmLabel,
  });

  final String title;
  final String initialValue;
  final String confirmLabel;

  @override
  State<_TimetableNameDialog> createState() => _TimetableNameDialogState();
}

class _TimetableNameDialogState extends State<_TimetableNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      autofocus: true,
      textInputAction: TextInputAction.done,
      decoration: const InputDecoration(labelText: 'Timetable name'),
      onSubmitted: (_) => _submit(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
    ],
  );

  void _submit() {
    final value = _controller.text.trim();
    if (value.isNotEmpty) Navigator.of(context).pop(value);
  }
}

class _TimetableRecordRow extends StatelessWidget {
  const _TimetableRecordRow({
    super.key,
    required this.record,
    required this.isActive,
    required this.onOpen,
    required this.onRename,
    required this.onDuplicate,
    required this.onDelete,
  });

  final TimetableRecord record;
  final bool isActive;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final tone = switch (record.status) {
      TimetableRecordStatus.validated => Tone.good,
      TimetableRecordStatus.needsReview => Tone.warn,
      TimetableRecordStatus.draft => Tone.neutral,
      TimetableRecordStatus.notGenerated => Tone.neutral,
    };
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(SynchroRadius.card),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(SynchroRadius.card),
        child: Container(
          padding: const EdgeInsets.all(SynchroSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SynchroRadius.card),
            border: Border.all(
              color: isActive
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outlineVariant,
              width: isActive ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isActive
                    ? Icons.radio_button_checked
                    : Icons.calendar_month_outlined,
                color: isActive
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: SynchroSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: SynchroSpacing.xs),
                    Text(
                      '${record.term} · ${record.sessionCount} session${record.sessionCount == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: SynchroSpacing.xs),
                    Text(
                      'Updated ${_formatUpdatedAt(record.updatedAt)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: SynchroSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusChip(label: record.statusLabel, tone: tone),
                  PopupMenuButton<String>(
                    tooltip: 'Timetable actions for ${record.name}',
                    onSelected: (action) {
                      switch (action) {
                        case 'rename':
                          onRename();
                        case 'duplicate':
                          onDuplicate();
                        case 'delete':
                          onDelete();
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'rename', child: Text('Rename')),
                      PopupMenuItem(
                        value: 'duplicate',
                        child: Text('Duplicate'),
                      ),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                    icon: const Icon(Icons.more_vert),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatUpdatedAt(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final meridiem = local.hour >= 12 ? 'PM' : 'AM';
  return '${local.day}/${local.month}/${local.year} · $hour:$minute $meridiem';
}

class _TimetableCreateDraft {
  const _TimetableCreateDraft({
    required this.name,
    required this.term,
    required this.sourceId,
  });

  final String name;
  final String term;
  final String? sourceId;
}

class _CreateTimetableDialog extends StatefulWidget {
  const _CreateTimetableDialog({
    required this.records,
    required this.initialTerm,
  });

  final List<TimetableRecord> records;
  final String initialTerm;

  @override
  State<_CreateTimetableDialog> createState() => _CreateTimetableDialogState();
}

class _CreateTimetableDialogState extends State<_CreateTimetableDialog> {
  static const String _blankSource = '__blank__';

  late final TextEditingController _name;
  late final TextEditingController _term;
  String _sourceId = _blankSource;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _term = TextEditingController(text: widget.initialTerm);
  }

  @override
  void dispose() {
    _name.dispose();
    _term.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Create timetable'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const Key('new-timetable-name-field'),
            controller: _name,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'FY IT — Semester 2',
            ),
          ),
          const SizedBox(height: SynchroSpacing.md),
          TextField(
            key: const Key('new-timetable-term-field'),
            controller: _term,
            decoration: const InputDecoration(
              labelText: 'Academic year / semester / term',
            ),
          ),
          const SizedBox(height: SynchroSpacing.md),
          DropdownButtonFormField<String>(
            key: const Key('new-timetable-source-field'),
            initialValue: _sourceId,
            decoration: const InputDecoration(labelText: 'Start with'),
            items: [
              const DropdownMenuItem<String>(
                value: _blankSource,
                child: Text('Blank configuration'),
              ),
              for (final record in widget.records)
                DropdownMenuItem<String>(
                  value: record.id,
                  child: Text(
                    'Duplicate · ${record.name}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _sourceId = value);
            },
          ),
          const SizedBox(height: SynchroSpacing.sm),
          Text(
            _sourceId == _blankSource
                ? 'Start with an empty setup and add the collections before generating.'
                : 'The selected timetable is copied into an independent draft.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const Key('confirm-create-timetable-button'),
        onPressed: _submit,
        child: const Text('Create'),
      ),
    ],
  );

  void _submit() {
    final name = _name.text.trim();
    final term = _term.text.trim();
    if (name.isEmpty || term.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a timetable name and term first.')),
      );
      return;
    }
    Navigator.of(context).pop(
      _TimetableCreateDraft(
        name: name,
        term: term,
        sourceId: _sourceId == _blankSource ? null : _sourceId,
      ),
    );
  }
}
