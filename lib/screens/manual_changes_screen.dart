import 'package:flutter/material.dart';

import '../state/manual_timetable_controller.dart';
import '../state/manual_timetable_models.dart' as manual_models;
import '../theme/tokens.dart';
import '../widgets/ui.dart';

/// Local change-management flows for the manual timetable prototype.
///
/// Each action below calls a real [ManualTimetableController] method and then
/// explicitly re-runs local validation. The banner and copy make the demo
/// boundary visible: there are no notifications, backend writes, or publish
/// operations behind these forms.
class ManualChangesScreen extends StatelessWidget {
  const ManualChangesScreen({super.key, required this.controller});

  final ManualTimetableController controller;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final absences = controller.faculty.fold<int>(
          0,
          (total, teacher) => total + teacher.absences.length,
        );
        final closures = controller.rooms.fold<int>(
          0,
          (total, room) => total + room.unavailableSlots.length,
        );
        final proxies = controller.faculty
            .where((teacher) => teacher.isProxy)
            .length;
        final swaps = controller.swapRequests.length;

        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              SynchroSpacing.gutter,
              SynchroSpacing.lg,
              SynchroSpacing.gutter,
              SynchroSpacing.xxl,
            ),
            children: [
              Text(
                'Handle a change',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: SynchroSpacing.xs),
              Text(
                'Apply a local demo change, then inspect the recalculated draft issues.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: SynchroSpacing.md),
              const _ChangesBanner(),
              const SizedBox(height: SynchroSpacing.lg),
              SectionCard(
                overline: 'Current local change state',
                title: 'Draft signals',
                child: Wrap(
                  spacing: SynchroSpacing.lg,
                  runSpacing: SynchroSpacing.md,
                  children: [
                    Stat(
                      value: '$absences',
                      caption: 'Absence slots',
                      tone: absences == 0 ? Tone.neutral : Tone.warn,
                    ),
                    Stat(
                      value: '$closures',
                      caption: 'Room closures',
                      tone: closures == 0 ? Tone.neutral : Tone.bad,
                    ),
                    Stat(
                      value: '$proxies',
                      caption: 'Proxy records',
                      tone: proxies == 0 ? Tone.neutral : Tone.warn,
                    ),
                    Stat(
                      value: '$swaps',
                      caption: 'Swap requests',
                      tone: swaps == 0 ? Tone.neutral : Tone.warn,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: SynchroSpacing.lg),
              SectionCard(
                overline: 'Choose a local workflow',
                title: 'Change actions',
                child: Wrap(
                  spacing: SynchroSpacing.sm,
                  runSpacing: SynchroSpacing.sm,
                  children: [
                    _ChangeActionButton(
                      icon: Icons.person_off_outlined,
                      label: 'Teacher absence',
                      onPressed: () => _openAbsence(context),
                    ),
                    _ChangeActionButton(
                      icon: Icons.meeting_room_outlined,
                      label: 'Room closure',
                      onPressed: () => _openClosure(context),
                    ),
                    _ChangeActionButton(
                      icon: Icons.person_add_alt_1_outlined,
                      label: 'Assign proxy',
                      onPressed: () => _openProxy(context),
                    ),
                    _ChangeActionButton(
                      icon: Icons.swap_horiz_outlined,
                      label: 'Teacher swap',
                      onPressed: () => _openSwap(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: SynchroSpacing.lg),
              _ExistingChanges(controller: controller),
            ],
          ),
        );
      },
    ),
  );

  Future<void> _openAbsence(BuildContext context) async {
    if (controller.faculty.isEmpty) {
      _showMessage(context, 'No faculty is available in this local draft.');
      return;
    }
    final form = await showModalBottomSheet<_AbsenceForm>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(SynchroRadius.sheet),
        ),
      ),
      builder: (_) => _AbsenceSheet(controller: controller),
    );
    if (!context.mounted || form == null) return;
    controller.handleAbsence(
      form.facultyId,
      day: form.day,
      startMinute: form.start,
      endMinute: form.end,
      reason: form.reason,
    );
    controller.validate();
    _showMessage(
      context,
      'Teacher absence added; affected sessions were rechecked.',
    );
  }

  Future<void> _openClosure(BuildContext context) async {
    if (controller.rooms.isEmpty) {
      _showMessage(context, 'No room is available in this local draft.');
      return;
    }
    final form = await showModalBottomSheet<_ClosureForm>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(SynchroRadius.sheet),
        ),
      ),
      builder: (_) => _ClosureSheet(controller: controller),
    );
    if (!context.mounted || form == null) return;
    controller.markRoomUnavailable(
      form.roomId,
      day: form.day,
      startMinute: form.start,
      endMinute: form.end,
      unavailable: true,
      reason: form.reason,
    );
    controller.validate();
    _showMessage(
      context,
      'Room closure added; affected sessions were rechecked.',
    );
  }

  Future<void> _openProxy(BuildContext context) async {
    if (controller.sessions.isEmpty || controller.faculty.isEmpty) {
      _showMessage(
        context,
        'A session and faculty are required for a proxy assignment.',
      );
      return;
    }
    final form = await showModalBottomSheet<_ProxyForm>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(SynchroRadius.sheet),
        ),
      ),
      builder: (_) => _ProxySheet(controller: controller),
    );
    if (!context.mounted || form == null) return;
    final session = controller.sessionById(form.sessionId);
    if (session == null || session.facultyId.trim().isEmpty) {
      _showMessage(
        context,
        'The selected session has no assignable source teacher.',
      );
      return;
    }
    ManualFaculty? proxy;
    if (form.existingProxyId != null) {
      proxy = controller.facultyById(form.existingProxyId!);
    } else {
      final name = form.proxyName.trim();
      if (name.isEmpty) {
        _showMessage(context, 'Enter a name for the local proxy.');
        return;
      }
      proxy = controller.createProxy(session.facultyId, name: name);
    }
    if (proxy == null) {
      _showMessage(
        context,
        'The selected proxy is no longer in the local draft.',
      );
      return;
    }
    controller.editSession(session.id, facultyId: proxy.id);
    controller.validate();
    _showMessage(
      context,
      '${proxy.name} assigned to the selected session locally.',
    );
  }

  Future<void> _openSwap(BuildContext context) async {
    if (controller.sessions.isEmpty || controller.faculty.length < 2) {
      _showMessage(
        context,
        'A session and at least two faculty records are required for a swap.',
      );
      return;
    }
    final form = await showModalBottomSheet<_SwapForm>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(SynchroRadius.sheet),
        ),
      ),
      builder: (_) => _SwapSheet(controller: controller),
    );
    if (!context.mounted || form == null) return;
    final request = controller.requestSwap(
      form.sessionId,
      targetFacultyId: form.targetFacultyId,
      note: form.note,
    );
    controller.validate();
    _showMessage(
      context,
      request == null
          ? 'The swap could not be created for that session.'
          : 'Swap request added to local pending state.',
    );
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ChangesBanner extends StatelessWidget {
  const _ChangesBanner();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(SynchroSpacing.md),
    decoration: BoxDecoration(
      color: SynchroColors.cream,
      borderRadius: BorderRadius.circular(SynchroRadius.chip),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.science_outlined,
          size: 18,
          color: SynchroColors.navyDeep,
        ),
        const SizedBox(width: SynchroSpacing.sm),
        Expanded(
          child: Text(
            '${ManualTimetableController.sampleDataLabel}\nForms change only this in-memory draft. No backend calls, notifications, or publishing.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: SynchroColors.navyDeep),
          ),
        ),
      ],
    ),
  );
}

class _ChangeActionButton extends StatelessWidget {
  const _ChangeActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: Icon(icon, size: 18),
    label: Text(label),
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(horizontal: SynchroSpacing.md),
    ),
  );
}

class _ExistingChanges extends StatelessWidget {
  const _ExistingChanges({required this.controller});

  final ManualTimetableController controller;

  @override
  Widget build(BuildContext context) {
    final lines = <String>[
      for (final teacher in controller.faculty)
        for (final absence in teacher.absences)
          '${teacher.name} · absent ${controller.dayName(absence.day)} ${_time(absence.startMinute)}–${_time(absence.endMinute)} · ${absence.reason}',
      for (final room in controller.rooms)
        for (final closure in room.unavailableSlots)
          '${room.name} · closed ${controller.dayName(closure.day)} ${_time(closure.startMinute)}–${_time(closure.endMinute)} · ${closure.reason}',
      for (final request in controller.swapRequests)
        'Swap ${request.id} · ${request.sessionId} · ${request.status}',
      for (final proxy in controller.faculty.where(
        (teacher) => teacher.isProxy,
      ))
        '${proxy.name} · local proxy record',
    ];
    return SectionCard(
      overline: 'Controller state',
      title: 'Existing local changes',
      child: lines.isEmpty
          ? Text(
              'No local change has been applied yet. Start with one of the four workflows above.',
              style: Theme.of(context).textTheme.bodySmall,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < lines.length; index++) ...[
                  if (index > 0) const Divider(height: SynchroSpacing.lg),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.check_circle_outline,
                          size: 18,
                          color: SynchroColors.ok,
                        ),
                      ),
                      const SizedBox(width: SynchroSpacing.sm),
                      Expanded(
                        child: Text(
                          lines[index],
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }
}

class _AbsenceForm {
  const _AbsenceForm({
    required this.facultyId,
    required this.day,
    required this.start,
    required this.end,
    required this.reason,
  });

  final String facultyId;
  final int day;
  final int start;
  final int end;
  final String reason;
}

class _ClosureForm {
  const _ClosureForm({
    required this.roomId,
    required this.day,
    required this.start,
    required this.end,
    required this.reason,
  });

  final String roomId;
  final int day;
  final int start;
  final int end;
  final String reason;
}

class _ProxyForm {
  const _ProxyForm({
    required this.sessionId,
    required this.existingProxyId,
    required this.proxyName,
  });

  final String sessionId;
  final String? existingProxyId;
  final String proxyName;
}

class _SwapForm {
  const _SwapForm({
    required this.sessionId,
    required this.targetFacultyId,
    required this.note,
  });

  final String sessionId;
  final String targetFacultyId;
  final String note;
}

class _AbsenceSheet extends StatefulWidget {
  const _AbsenceSheet({required this.controller});

  final ManualTimetableController controller;

  @override
  State<_AbsenceSheet> createState() => _AbsenceSheetState();
}

class _AbsenceSheetState extends State<_AbsenceSheet> {
  late String _facultyId;
  late int _day;
  late int _start;
  late int _end;
  late final TextEditingController _reason;

  @override
  void initState() {
    super.initState();
    _facultyId = widget.controller.faculty.first.id;
    _day = widget.controller.selectedDay;
    final slot = _firstSlot(widget.controller, _day);
    _start = slot.startMinute;
    _end = slot.endMinute;
    _reason = TextEditingController(text: 'Faculty unavailable');
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _ChangeSheetScaffold(
    title: 'Teacher absence',
    subtitle: 'Mark an actual local unavailability window; affected sessions become hard conflicts.',
    children: [
      _FacultyDropdown(
        controller: widget.controller,
        value: _facultyId,
        onChanged: (value) => setState(() => _facultyId = value),
      ),
      const SizedBox(height: SynchroSpacing.md),
      _DayTimeFields(
        controller: widget.controller,
        day: _day,
        start: _start,
        end: _end,
        onDayChanged: (value) => setState(() {
          _day = value;
          final slot = _firstSlot(widget.controller, value);
          _start = slot.startMinute;
          _end = slot.endMinute;
        }),
        onStartChanged: (value) => setState(() {
          _start = value;
          if (_end <= value) _end = _nextEnd(widget.controller, _day, value);
        }),
        onEndChanged: (value) => setState(() => _end = value),
      ),
      const SizedBox(height: SynchroSpacing.md),
      TextField(
        controller: _reason,
        decoration: const InputDecoration(
          labelText: 'Reason',
          prefixIcon: Icon(Icons.notes_outlined),
        ),
      ),
      const SizedBox(height: SynchroSpacing.lg),
      _submitButton(
        context,
        'Add absence',
        () => Navigator.of(context).pop(
          _AbsenceForm(
            facultyId: _facultyId,
            day: _day,
            start: _start,
            end: _end,
            reason: _reason.text.trim().isEmpty
                ? 'Faculty unavailable'
                : _reason.text.trim(),
          ),
        ),
      ),
    ],
  );
}

class _ClosureSheet extends StatefulWidget {
  const _ClosureSheet({required this.controller});

  final ManualTimetableController controller;

  @override
  State<_ClosureSheet> createState() => _ClosureSheetState();
}

class _ClosureSheetState extends State<_ClosureSheet> {
  late String _roomId;
  late int _day;
  late int _start;
  late int _end;
  late final TextEditingController _reason;

  @override
  void initState() {
    super.initState();
    _roomId = widget.controller.rooms.first.id;
    _day = widget.controller.selectedDay;
    final slot = _firstSlot(widget.controller, _day);
    _start = slot.startMinute;
    _end = slot.endMinute;
    _reason = TextEditingController(text: 'Room closure');
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _ChangeSheetScaffold(
    title: 'Room closure',
    subtitle: 'Close a selected room slot in the local draft and recheck room conflicts.',
    children: [
      DropdownButtonFormField<String>(
        initialValue: _roomId,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Room',
          prefixIcon: Icon(Icons.meeting_room_outlined),
        ),
        items: [
          for (final room in widget.controller.rooms)
            DropdownMenuItem(
              value: room.id,
              child: Text('${room.name} · ${room.kind}'),
            ),
        ],
        onChanged: (value) {
          if (value != null) setState(() => _roomId = value);
        },
      ),
      const SizedBox(height: SynchroSpacing.md),
      _DayTimeFields(
        controller: widget.controller,
        day: _day,
        start: _start,
        end: _end,
        onDayChanged: (value) => setState(() {
          _day = value;
          final slot = _firstSlot(widget.controller, value);
          _start = slot.startMinute;
          _end = slot.endMinute;
        }),
        onStartChanged: (value) => setState(() {
          _start = value;
          if (_end <= value) _end = _nextEnd(widget.controller, _day, value);
        }),
        onEndChanged: (value) => setState(() => _end = value),
      ),
      const SizedBox(height: SynchroSpacing.md),
      TextField(
        controller: _reason,
        decoration: const InputDecoration(
          labelText: 'Reason',
          prefixIcon: Icon(Icons.notes_outlined),
        ),
      ),
      const SizedBox(height: SynchroSpacing.lg),
      _submitButton(
        context,
        'Close room slot',
        () => Navigator.of(context).pop(
          _ClosureForm(
            roomId: _roomId,
            day: _day,
            start: _start,
            end: _end,
            reason: _reason.text.trim().isEmpty
                ? 'Room closure'
                : _reason.text.trim(),
          ),
        ),
      ),
    ],
  );
}

class _ProxySheet extends StatefulWidget {
  const _ProxySheet({required this.controller});

  final ManualTimetableController controller;

  @override
  State<_ProxySheet> createState() => _ProxySheetState();
}

class _ProxySheetState extends State<_ProxySheet> {
  late String _sessionId;
  String? _existingProxyId;
  late final TextEditingController _proxyName;

  List<ManualFaculty> get _proxies =>
      widget.controller.faculty.where((teacher) => teacher.isProxy).toList();

  @override
  void initState() {
    super.initState();
    _sessionId = widget.controller.sessions.first.id;
    _proxyName = TextEditingController(text: 'Local proxy');
  }

  @override
  void dispose() {
    _proxyName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.controller.sessionById(_sessionId);
    final source = session == null
        ? 'No source teacher'
        : widget.controller.facultyById(session.facultyId)?.name ??
              'Missing faculty';
    return _ChangeSheetScaffold(
      title: 'Assign proxy',
      subtitle: 'Create or reuse a local proxy record, then assign it to one session.',
      children: [
        DropdownButtonFormField<String>(
          initialValue: _sessionId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Session',
            prefixIcon: Icon(Icons.calendar_view_day_outlined),
          ),
          items: [
            for (final item in widget.controller.sessions)
              DropdownMenuItem(
                value: item.id,
                child: Text(
                  '${widget.controller.subjectById(item.subjectId)?.name ?? item.id} · ${widget.controller.dayName(item.day)} ${_time(item.startMinute)}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _sessionId = value);
          },
        ),
        const SizedBox(height: SynchroSpacing.sm),
        Text(
          'Source teacher: $source',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: SynchroSpacing.md),
        if (_proxies.isNotEmpty) ...[
          DropdownButtonFormField<String?>(
            initialValue: _existingProxyId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Existing local proxy',
              prefixIcon: Icon(Icons.person_add_alt_1_outlined),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Create a new proxy'),
              ),
              for (final proxy in _proxies)
                DropdownMenuItem<String?>(
                  value: proxy.id,
                  child: Text(proxy.name),
                ),
            ],
            onChanged: (value) => setState(() => _existingProxyId = value),
          ),
          const SizedBox(height: SynchroSpacing.md),
        ],
        if (_existingProxyId == null)
          TextField(
            controller: _proxyName,
            decoration: const InputDecoration(
              labelText: 'New proxy name',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
        const SizedBox(height: SynchroSpacing.lg),
        _submitButton(
          context,
          'Assign in local draft',
          () => Navigator.of(context).pop(
            _ProxyForm(
              sessionId: _sessionId,
              existingProxyId: _existingProxyId,
              proxyName: _proxyName.text,
            ),
          ),
        ),
      ],
    );
  }
}

class _SwapSheet extends StatefulWidget {
  const _SwapSheet({required this.controller});

  final ManualTimetableController controller;

  @override
  State<_SwapSheet> createState() => _SwapSheetState();
}

class _SwapSheetState extends State<_SwapSheet> {
  late String _sessionId;
  late String _targetFacultyId;
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    _sessionId = widget.controller.sessions.first.id;
    final current = widget.controller.sessionById(_sessionId)?.facultyId;
    _targetFacultyId = widget.controller.faculty
        .firstWhere(
          (teacher) => teacher.id != current,
          orElse: () => widget.controller.faculty.first,
        )
        .id;
    _note = TextEditingController(text: 'Review local teacher swap');
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.controller.sessionById(_sessionId);
    final current = session?.facultyId;
    final targets = widget.controller.faculty
        .where((teacher) => teacher.id != current)
        .toList();
    return _ChangeSheetScaffold(
      title: 'Teacher swap',
      subtitle: 'Create a reviewable local swap request; the session is not silently reassigned.',
      children: [
        DropdownButtonFormField<String>(
          initialValue: _sessionId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Session',
            prefixIcon: Icon(Icons.calendar_view_day_outlined),
          ),
          items: [
            for (final item in widget.controller.sessions)
              DropdownMenuItem(
                value: item.id,
                child: Text(
                  '${widget.controller.subjectById(item.subjectId)?.name ?? item.id} · ${widget.controller.dayName(item.day)} ${_time(item.startMinute)}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (value) {
            if (value == null) return;
            final nextCurrent = widget.controller.sessionById(value)?.facultyId;
            final nextTarget = widget.controller.faculty.firstWhere(
              (teacher) => teacher.id != nextCurrent,
              orElse: () => widget.controller.faculty.first,
            );
            setState(() {
              _sessionId = value;
              _targetFacultyId = nextTarget.id;
            });
          },
        ),
        const SizedBox(height: SynchroSpacing.md),
        DropdownButtonFormField<String>(
          initialValue: targets.any((teacher) => teacher.id == _targetFacultyId)
              ? _targetFacultyId
              : targets.firstOrNull?.id,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Target teacher',
            prefixIcon: Icon(Icons.swap_horiz_outlined),
          ),
          items: [
            for (final teacher in targets)
              DropdownMenuItem(value: teacher.id, child: Text(teacher.name)),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _targetFacultyId = value);
          },
        ),
        const SizedBox(height: SynchroSpacing.md),
        TextField(
          controller: _note,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Review note',
            prefixIcon: Icon(Icons.notes_outlined),
          ),
        ),
        const SizedBox(height: SynchroSpacing.lg),
        _submitButton(
          context,
          'Create swap request',
          () => Navigator.of(context).pop(
            _SwapForm(
              sessionId: _sessionId,
              targetFacultyId: _targetFacultyId,
              note: _note.text.trim(),
            ),
          ),
        ),
      ],
    );
  }
}

class _FacultyDropdown extends StatelessWidget {
  const _FacultyDropdown({
    required this.controller,
    required this.value,
    required this.onChanged,
  });

  final ManualTimetableController controller;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    initialValue: value,
    isExpanded: true,
    decoration: const InputDecoration(
      labelText: 'Teacher',
      prefixIcon: Icon(Icons.person_outline),
    ),
    items: [
      for (final teacher in controller.faculty)
        DropdownMenuItem(value: teacher.id, child: Text(teacher.name)),
    ],
    onChanged: (next) {
      if (next != null) onChanged(next);
    },
  );
}

class _DayTimeFields extends StatelessWidget {
  const _DayTimeFields({
    required this.controller,
    required this.day,
    required this.start,
    required this.end,
    required this.onDayChanged,
    required this.onStartChanged,
    required this.onEndChanged,
  });

  final ManualTimetableController controller;
  final int day;
  final int start;
  final int end;
  final ValueChanged<int> onDayChanged;
  final ValueChanged<int> onStartChanged;
  final ValueChanged<int> onEndChanged;

  @override
  Widget build(BuildContext context) {
    final slots = controller.timeSlots
        .where((slot) => slot.day == day && !slot.isBreak)
        .toList();
    final starts = <int>{
      for (final slot in slots) slot.startMinute,
      start,
    }.toList()..sort();
    final ends = <int>{for (final slot in slots) slot.endMinute, end}.toList()
      ..sort();
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < 390
            ? constraints.maxWidth
            : (constraints.maxWidth - SynchroSpacing.sm) / 2;
        return Wrap(
          spacing: SynchroSpacing.sm,
          runSpacing: SynchroSpacing.md,
          children: [
            SizedBox(
              width: width,
              child: DropdownButtonFormField<int>(
                initialValue: day,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Day'),
                items: [
                  for (
                    var index = 0;
                    index < ManualTimetableController.dayNames.length;
                    index++
                  )
                    DropdownMenuItem(
                      value: index,
                      child: Text(controller.dayName(index)),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) onDayChanged(value);
                },
              ),
            ),
            SizedBox(
              width: width,
              child: DropdownButtonFormField<int>(
                initialValue: starts.contains(start) ? start : null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Start'),
                items: [
                  for (final value in starts)
                    DropdownMenuItem(value: value, child: Text(_time(value))),
                ],
                onChanged: (value) {
                  if (value != null) onStartChanged(value);
                },
              ),
            ),
            SizedBox(
              width: width,
              child: DropdownButtonFormField<int>(
                initialValue: ends.contains(end) ? end : null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'End'),
                items: [
                  for (final value in ends)
                    DropdownMenuItem(value: value, child: Text(_time(value))),
                ],
                onChanged: (value) {
                  if (value != null) onEndChanged(value);
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ChangeSheetScaffold extends StatelessWidget {
  const _ChangeSheetScaffold({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        SynchroSpacing.gutter,
        SynchroSpacing.lg,
        SynchroSpacing.gutter,
        MediaQuery.viewInsetsOf(context).bottom + SynchroSpacing.gutter,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: SynchroSpacing.xs),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: SynchroSpacing.lg),
          ...children,
        ],
      ),
    ),
  );
}

Widget _submitButton(
  BuildContext context,
  String label,
  VoidCallback onPressed,
) => SizedBox(
  width: double.infinity,
  child: FilledButton.icon(
    onPressed: onPressed,
    icon: const Icon(Icons.check),
    label: Text(label),
  ),
);

manual_models.ManualTimeSlot _firstSlot(
  ManualTimetableController controller,
  int day,
) {
  for (final slot in controller.timeSlots) {
    if (slot.day == day && !slot.isBreak) return slot;
  }
  return const manual_models.ManualTimeSlot(
    day: 0,
    startMinute: 540,
    endMinute: 590,
  );
}

int _nextEnd(ManualTimetableController controller, int day, int start) {
  for (final slot in controller.timeSlots) {
    if (slot.day == day && !slot.isBreak && slot.startMinute == start) {
      return slot.endMinute;
    }
  }
  return start + 50;
}

String _time(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
