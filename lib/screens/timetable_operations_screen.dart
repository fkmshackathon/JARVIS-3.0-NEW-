import 'package:flutter/material.dart';

import '../data/assistant_service.dart';
import '../state/manual_timetable_controller.dart';
import '../state/timetable_operations.dart';
import '../state/timetable_view.dart';
import '../widgets/ui.dart';

class TimetableOperationsScreen extends StatefulWidget {
  const TimetableOperationsScreen({
    super.key,
    required this.controller,
    this.activeTimetableId,
  });
  final ManualTimetableController controller;
  final String? Function()? activeTimetableId;

  @override
  State<TimetableOperationsScreen> createState() =>
      _TimetableOperationsScreenState();
}

class _TimetableOperationsScreenState extends State<TimetableOperationsScreen> {
  String _kind = 'absence';
  String? _facultyId,
      _roomId,
      _batchId,
      _subjectId,
      _firstSession,
      _secondSession;
  Set<int> _days = {0};
  final _start = TextEditingController(text: '09:00');
  final _end = TextEditingController(text: '10:00');
  final _reason = TextEditingController();
  final _duration = TextEditingController(text: '50');
  final _capacity = TextEditingController(text: '0');
  final _equipment = TextEditingController();
  bool _fullDay = true,
      _fixed = false,
      _laboratory = false,
      _explaining = false;
  String? _error, _explanation;
  List<TimetableProposal> _proposals = [];

  ManualTimetableController get workspace => widget.controller;
  TimetableOperations get operations => TimetableOperations(
    workspace,
    activeTimetableId: widget.activeTimetableId,
  );

  @override
  void initState() {
    super.initState();
    _facultyId = workspace.faculty.firstOrNull?.id;
    _roomId = workspace.rooms.firstOrNull?.id;
    _batchId = workspace.batches.firstOrNull?.id;
    _subjectId = workspace.subjects.firstOrNull?.id;
    _firstSession = workspace.sessions.firstOrNull?.id;
    _secondSession = workspace.sessions.length > 1
        ? workspace.sessions[1].id
        : null;
    _days = {workspace.workingDays.firstOrNull ?? 0};
  }

  @override
  void dispose() {
    for (final input in [
      _start,
      _end,
      _reason,
      _duration,
      _capacity,
      _equipment,
    ]) {
      input.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: workspace,
    builder: (context, _) => ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
      children: [
        Text(
          'Handle a change',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Notice(
          tone: Tone.neutral,
          text:
              'Describe → Review affected sessions → Validate → Confirm → Apply. '
              'Only the active local timetable changes. This version edits the recurring weekly draft, not date-specific calendar exceptions. No faculty notifications are sent.',
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Describe the scheduling issue',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _kind,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Change type'),
                items: const [
                  DropdownMenuItem(
                    value: 'absence',
                    child: Text('Teacher absence / proxy'),
                  ),
                  DropdownMenuItem(
                    value: 'closure',
                    child: Text('Room closure'),
                  ),
                  DropdownMenuItem(
                    value: 'seminar',
                    child: Text('Seminar / workshop'),
                  ),
                  DropdownMenuItem(
                    value: 'extra',
                    child: Text('Extra lecture'),
                  ),
                  DropdownMenuItem(value: 'swap', child: Text('Teacher swap')),
                ],
                onChanged: (v) => setState(() {
                  _kind = v!;
                  _proposals = [];
                  _error = null;
                  _explanation = null;
                }),
              ),
              const SizedBox(height: 12),
              if (_kind == 'absence' || _kind == 'extra')
                _selection('Faculty', _facultyId, {
                  for (final f in workspace.faculty) f.id: f.name,
                }, (v) => _facultyId = v),
              if (_kind == 'closure' ||
                  _kind == 'seminar' ||
                  (_kind == 'extra' && _fixed))
                _selection('Room / laboratory', _roomId, {
                  for (final r in workspace.rooms)
                    r.id: '${r.name} · ${r.capacity} seats',
                }, (v) => _roomId = v),
              if (_kind == 'extra') ...[
                _selection('Subject', _subjectId, {
                  for (final s in workspace.subjects)
                    s.id: '${s.code} · ${s.name}',
                }, (v) => _subjectId = v),
                _selection('Batch', _batchId, {
                  for (final b in workspace.batches) b.id: b.name,
                }, (v) => _batchId = v),
                TextField(
                  controller: _duration,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Duration (minutes)',
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('This day/time/room is mandatory'),
                  value: _fixed,
                  onChanged: (v) => setState(() => _fixed = v),
                ),
              ],
              if (_kind == 'swap') ...[
                _selection('First session', _firstSession, {
                  for (final s in workspace.sessions) s.id: _sessionLabel(s),
                }, (v) => _firstSession = v),
                _selection('Second session', _secondSession, {
                  for (final s in workspace.sessions) s.id: _sessionLabel(s),
                }, (v) => _secondSession = v),
              ] else ...[
                const Text(
                  'Affected weekdays (recurring)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final d in workspace.workingDays)
                      FilterChip(
                        label: Text(workspace.dayName(d).substring(0, 3)),
                        selected: _days.contains(d),
                        onSelected: (selected) => setState(() {
                          _days = {..._days};
                          if (selected) {
                            _days.add(d);
                          } else {
                            _days.remove(d);
                          }
                        }),
                      ),
                  ],
                ),
                if (_kind == 'absence' || _kind == 'closure')
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Full day'),
                    value: _fullDay,
                    onChanged: (v) => setState(() => _fullDay = v),
                  ),
                if (!(_fullDay && (_kind == 'absence' || _kind == 'closure')))
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _start,
                          decoration: const InputDecoration(
                            labelText: 'Start (HH:mm)',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _end,
                          decoration: const InputDecoration(
                            labelText: 'End (HH:mm)',
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
              if (_kind == 'seminar') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _capacity,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Required seats',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _equipment,
                  decoration: const InputDecoration(
                    labelText: 'Required equipment (comma-separated)',
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Laboratory required'),
                  value: _laboratory,
                  onChanged: (v) => setState(() => _laboratory = v),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _reason,
                decoration: InputDecoration(
                  labelText: _kind == 'seminar'
                      ? 'Event name / reason'
                      : 'Reason (optional)',
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _recommend,
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Find and validate recommendations'),
              ),
              TextButton.icon(
                onPressed: _configureEligibility,
                icon: const Icon(Icons.school_outlined),
                label: const Text(
                  'Configure subject eligibility & room equipment',
                ),
              ),
              if (_error != null) Notice(tone: Tone.bad, text: _error!),
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (final proposal in _proposals)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _proposalCard(proposal),
          ),
        if (_proposals.isNotEmpty)
          OutlinedButton.icon(
            onPressed: _explaining ? null : _explain,
            icon: const Icon(Icons.eco_outlined),
            label: Text(
              _explaining
                  ? 'Asking assistant…'
                  : 'Ask Groq to explain these checked options',
            ),
          ),
        if (_explanation != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: SelectableText(_explanation!),
          ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Local audit trail',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (workspace.changeAudit.isEmpty)
                const Text('No confirmed local changes yet.'),
              for (final entry in workspace.changeAudit.reversed)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    '${entry['kind']} · ${entry['status']} · ${entry['timestamp']}\n${entry['reason']}\nSessions: ${(entry['session_ids'] as List).join(', ')}',
                  ),
                ),
              OutlinedButton.icon(
                onPressed: workspace.changeAudit.isEmpty ? null : _undo,
                icon: const Icon(Icons.undo),
                label: const Text('Undo last applied change safely'),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _selection(
    String label,
    String? value,
    Map<String, String> items,
    ValueChanged<String?> change,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DropdownButtonFormField<String>(
      key: ValueKey('$label:$value'),
      initialValue: items.containsKey(value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final e in items.entries)
          DropdownMenuItem(
            value: e.key,
            child: Text(e.value, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (v) => setState(() => change(v)),
    ),
  );

  String _sessionLabel(ManualSession s) =>
      '${s.id} · ${workspace.dayName(s.day)} ${timetableClock(s.startMinute)} · '
      '${workspace.subjectById(s.subjectId)?.code ?? s.subjectId} / ${workspace.batchById(s.batchId)?.name ?? s.batchId}';

  int? _minutes(String text) {
    final parts = text.trim().split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]), m = int.tryParse(parts[1]);
    return h != null && m != null && h >= 0 && h <= 23 && m >= 0 && m <= 59
        ? h * 60 + m
        : null;
  }

  void _recommend() {
    setState(() {
      _error = null;
      _proposals = [];
      _explanation = null;
    });
    final start = _fullDay && (_kind == 'absence' || _kind == 'closure')
        ? 0
        : _minutes(_start.text);
    final end = _fullDay && (_kind == 'absence' || _kind == 'closure')
        ? 1440
        : _minutes(_end.text);
    if (_kind != 'swap' &&
        (_days.isEmpty || start == null || end == null || end <= start)) {
      setState(
        () => _error = 'Select a weekday and enter a valid time window.',
      );
      return;
    }
    final reason = _reason.text.trim().isEmpty ? _kind : _reason.text.trim();
    List<TimetableProposal> proposals;
    switch (_kind) {
      case 'absence':
        proposals = operations.absence(
          facultyId: _facultyId ?? '',
          days: _days,
          start: start!,
          end: end!,
          reason: reason,
        );
      case 'closure':
        proposals = operations.closeRoom(
          roomId: _roomId ?? '',
          days: _days,
          start: start!,
          end: end!,
          reason: reason,
        );
      case 'seminar':
        proposals = operations.seminar(
          name: reason,
          days: _days,
          start: start!,
          end: end!,
          preferredRoomId: _roomId,
          capacity: int.tryParse(_capacity.text) ?? 0,
          laboratory: _laboratory,
          equipment: _equipment.text
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList(),
        );
      case 'extra':
        final duration = int.tryParse(_duration.text);
        if (duration == null || duration <= 0 || duration > 480) {
          setState(() => _error = 'Enter a duration from 1 to 480 minutes.');
          return;
        }
        proposals = operations.extraLecture(
          ManualSession(
            id: 'extra-${DateTime.now().microsecondsSinceEpoch}',
            subjectId: _subjectId ?? '',
            facultyId: _facultyId ?? '',
            batchId: _batchId ?? '',
            roomId: _roomId ?? '',
            day: _days.first,
            startMinute: start!,
            endMinute: start + duration,
            type: workspace.subjectById(_subjectId ?? '')?.isPractical == true
                ? ManualSessionType.practical
                : ManualSessionType.lecture,
          ),
          fixedTime: _fixed,
        );
      default:
        proposals = [
          operations.swapTeachers(_firstSession ?? '', _secondSession ?? ''),
        ];
    }
    setState(() {
      _proposals = proposals;
      if (proposals.isEmpty) _error = 'Required faculty, rooms or sessions are missing. Complete Setup first.';
    });
  }

  Widget _proposalCard(TimetableProposal proposal) => SectionCard(
    title: proposal.title,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Status: ${proposal.status.name}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        Text(proposal.reason),
        if (proposal.explanation.isNotEmpty) Text(proposal.explanation),
        for (final session in proposal.replacements)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '${_sessionLabel(session)}\nBefore: ${_assignment(workspace.sessionById(session.id))}\nAfter: ${_assignment(session)}',
            ),
          ),
        if (proposal.replacements.isEmpty)
          const Text(
            'No class assignments are changed; only the specified availability restriction may be recorded.',
          ),
        for (final error in proposal.errors)
          Text(
            error,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton(
              onPressed: proposal.status == TimetableProposalStatus.validated
                  ? () => _confirm(proposal)
                  : null,
              child: const Text('Review & confirm'),
            ),
            OutlinedButton(
              onPressed: proposal.status == TimetableProposalStatus.validated
                  ? () => setState(() => operations.reject(proposal))
                  : null,
              child: const Text('Reject'),
            ),
          ],
        ),
      ],
    ),
  );

  String _assignment(ManualSession? session) => session == null
      ? 'New session'
      : '${workspace.dayName(session.day)} ${timetableClock(session.startMinute)}–${timetableClock(session.endMinute)} · '
            '${workspace.facultyById(session.facultyId)?.name ?? session.facultyId} · ${workspace.roomById(session.roomId)?.name ?? session.roomId}';

  Future<void> _confirm(TimetableProposal proposal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Apply this validated local change?'),
        content: Text(
          '${proposal.title}\n${proposal.reason}\n\nThis modifies only the active recurring weekly draft. '
          'It is revalidated against the latest schedule before applying. Unaffected classes remain unchanged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Confirm & apply'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    final applied = operations.apply(proposal, confirmed: true);
    if (applied) await workspace.saveDraft();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          applied
              ? 'Validated change applied to the active local draft. All timetable views now use these assignments.'
              : 'Nothing applied. ${proposal.errors.join(' ')}',
        ),
      ),
    );
  }

  Future<void> _undo() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Undo the latest local change?'),
        content: const Text(
          'Undo is refused if another edit has happened since that change, so newer work cannot be overwritten.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Undo change'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    final success = workspace.undoLastLocalChange();
    if (success) await workspace.saveDraft();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Local change undone.'
              : 'Cannot undo safely because a later edit changed this draft.',
        ),
      ),
    );
    setState(() => _proposals = []);
  }

  Future<void> _explain() async {
    setState(() => _explaining = true);
    final service = AssistantService();
    final response = await service.respond(
      'Explain these validated timetable operation tool results. Compare trade-offs without inventing options or applying anything.',
      'en',
      context: AssistantService.contextFor(
        workspace,
        page: 'Handle a change',
        tools: [
          for (final p in _proposals.take(4))
            {
              'id': p.id,
              'status': p.status.name,
              'reason': p.reason,
              'errors': p.errors,
              'changes': [
                for (final s in p.replacements)
                  {
                    'session_id': s.id,
                    'faculty_id': s.facultyId,
                    'room_id': s.roomId,
                    'day': s.day,
                    'start': s.startMinute,
                    'end': s.endMinute,
                  },
              ],
            },
        ],
      ),
    );
    service.close();
    if (mounted) {
      setState(() {
        _explaining = false;
        _explanation =
            '${response.live ? 'Groq · live explanation' : 'Offline demo · deterministic guidance'}\n'
            '${response.warning ?? ''}\n${response.text}';
      });
    }
  }

  Future<void> _configureEligibility() async {
    if (workspace.faculty.isEmpty) {
      setState(() => _error = 'Add faculty in Setup first.');
      return;
    }
    var teacher =
        workspace.facultyById(_facultyId ?? '') ?? workspace.faculty.first;
    var subjects = {...teacher.qualifiedSubjectIds};
    var room = workspace.roomById(_roomId ?? '') ?? workspace.rooms.firstOrNull;
    final equipment = TextEditingController(
      text: room?.equipment.join(', ') ?? '',
    );
    final cap = TextEditingController(
      text: teacher.hardWeeklyHourLimit?.toString() ?? '',
    );
    await showDialog<void>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (dialog, update) => AlertDialog(
          title: const Text('Actual eligibility & equipment'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: teacher.id,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Faculty'),
                    items: [
                      for (final f in workspace.faculty)
                        DropdownMenuItem(value: f.id, child: Text(f.name)),
                    ],
                    onChanged: (id) => update(() {
                      teacher = workspace.facultyById(id!)!;
                      subjects = {...teacher.qualifiedSubjectIds};
                      cap.text = teacher.hardWeeklyHourLimit?.toString() ?? '';
                    }),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Authorised subjects (teaching-load mappings also count):',
                  ),
                  for (final subject in workspace.subjects)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${subject.code} · ${subject.name}'),
                      value: subjects.contains(subject.id),
                      onChanged: (v) => update(() {
                        if (v == true) {
                          subjects.add(subject.id);
                        } else {
                          subjects.remove(subject.id);
                        }
                      }),
                    ),
                  TextField(
                    controller: cap,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Hard weekly hour cap (optional)',
                      helperText:
                          'Weekly workload target remains a soft preference.',
                    ),
                  ),
                  if (room != null) ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: room!.id,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Room inventory',
                      ),
                      items: [
                        for (final r in workspace.rooms)
                          DropdownMenuItem(value: r.id, child: Text(r.name)),
                      ],
                      onChanged: (id) => update(() {
                        room = workspace.roomById(id!);
                        equipment.text = room!.equipment.join(', ');
                      }),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: equipment,
                      decoration: const InputDecoration(
                        labelText: 'Installed equipment (comma-separated)',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final limit = cap.text.trim().isEmpty
                    ? null
                    : int.tryParse(cap.text);
                if (cap.text.trim().isNotEmpty &&
                    (limit == null || limit <= 0)) {
                  return;
                }
                workspace.editFaculty(
                  ManualFaculty(
                    id: teacher.id,
                    name: teacher.name,
                    department: teacher.department,
                    maxWeeklyHours: teacher.maxWeeklyHours,
                    absences: teacher.absences,
                    isProxy: teacher.isProxy,
                    qualifiedSubjectIds: subjects.toList(),
                    hardWeeklyHourLimit: limit,
                  ),
                );
                if (room != null) {
                  workspace.editRoom(
                    room!.copyWith(
                      equipment: equipment.text
                          .split(',')
                          .map((s) => s.trim())
                          .where((s) => s.isNotEmpty)
                          .toList(),
                    ),
                  );
                }
                Navigator.pop(dialog);
                setState(() => _proposals = []);
              },
              child: const Text('Save actual configuration'),
            ),
          ],
        ),
      ),
    );
    equipment.dispose();
    cap.dispose();
  }
}
