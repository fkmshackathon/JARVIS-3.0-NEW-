import 'package:flutter/material.dart';

import '../state/manual_timetable_controller.dart';
import '../state/manual_timetable_models.dart' as manual_models;
import '../theme/tokens.dart';
import '../widgets/ui.dart';

/// Room and laboratory management for the local manual timetable draft.
///
/// Room availability is evaluated against the selected day/time and the
/// controller's actual sessions/closures. Add and edit callbacks are optional
/// because the T1 controller exposes marking availability, but intentionally has
/// no room collection mutation methods yet.
class ManualRoomsScreen extends StatefulWidget {
  const ManualRoomsScreen({
    super.key,
    required this.controller,
    this.onAddRoom,
    this.onEditRoom,
  });

  final ManualTimetableController controller;
  final ValueChanged<manual_models.ManualRoom>? onAddRoom;
  final ValueChanged<manual_models.ManualRoom>? onEditRoom;

  @override
  State<ManualRoomsScreen> createState() => _ManualRoomsScreenState();
}

class _ManualRoomsScreenState extends State<ManualRoomsScreen> {
  _RoomFilter _filter = _RoomFilter.all;
  late int _day;
  late int _start;
  late int _end;

  ManualTimetableController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _day = controller.selectedDay;
    final slot = controller.timeSlots.firstWhere(
      (candidate) => candidate.day == _day && !candidate.isBreak,
      orElse: () =>
          const ManualTimeSlot(day: 0, startMinute: 540, endMinute: 590),
    );
    _start = slot.startMinute;
    _end = slot.endMinute;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final rooms = controller.rooms.where(_matchesFilter).toList();
        return SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => ListView(
              padding: const EdgeInsets.fromLTRB(
                SynchroSpacing.gutter,
                SynchroSpacing.lg,
                SynchroSpacing.gutter,
                SynchroSpacing.xxl,
              ),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rooms & labs',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: SynchroSpacing.xs),
                          Text(
                            'Check availability before placing a local class.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: SynchroSpacing.sm),
                    IconButton.filled(
                      tooltip: 'Add room',
                      onPressed: () => _openRoomEditor(context),
                      icon: const Icon(Icons.add),
                      style: IconButton.styleFrom(
                        backgroundColor: SynchroColors.orange,
                        foregroundColor: SynchroColors.navyDeep,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: SynchroSpacing.md),
                const _RoomsDemoBanner(),
                const SizedBox(height: SynchroSpacing.lg),
                SectionCard(
                  overline: 'Availability context',
                  title:
                      '${controller.dayName(_day)} · ${_time(_start)}–${_time(_end)}',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _RoomContextFields(
                        controller: controller,
                        day: _day,
                        start: _start,
                        end: _end,
                        onDayChanged: (value) => setState(() {
                          _day = value;
                          _selectFirstSlotForDay(value);
                        }),
                        onStartChanged: (value) => setState(() {
                          _start = value;
                          if (_end <= _start) _end = _nextEnd(value);
                        }),
                        onEndChanged: (value) => setState(() => _end = value),
                      ),
                      const SizedBox(height: SynchroSpacing.md),
                      Text(
                        'Room type',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      const SizedBox(height: SynchroSpacing.sm),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final filter in _RoomFilter.values)
                              Padding(
                                padding: EdgeInsets.only(
                                  right: filter == _RoomFilter.values.last
                                      ? 0
                                      : SynchroSpacing.sm,
                                ),
                                child: ChoiceChip(
                                  label: Text(filter.label),
                                  selected: _filter == filter,
                                  onSelected: (_) =>
                                      setState(() => _filter = filter),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: SynchroSpacing.lg),
                if (rooms.isEmpty)
                  const EmptyState(
                    title: 'No rooms in this filter',
                    body: 'Try another room type or add a local room record.',
                    icon: Icons.meeting_room_outlined,
                  )
                else ...[
                  Text(
                    '${rooms.length} ${rooms.length == 1 ? 'space' : 'spaces'} · selected slot availability',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(height: SynchroSpacing.sm),
                  for (var index = 0; index < rooms.length; index++) ...[
                    if (index > 0) const SizedBox(height: SynchroSpacing.md),
                    _RoomCard(
                      room: rooms[index],
                      controller: controller,
                      day: _day,
                      start: _start,
                      end: _end,
                      onMarkUnavailable: () =>
                          _openAvailabilityActions(context, rooms[index]),
                      onEdit: () =>
                          _openRoomEditor(context, room: rooms[index]),
                    ),
                  ],
                ],
                if (constraints.maxWidth > 600) ...[
                  const SizedBox(height: SynchroSpacing.lg),
                  Text(
                    'The selected slot checks closures and existing local sessions; it does not reserve a room.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    ),
  );

  bool _matchesFilter(ManualRoom room) => switch (_filter) {
    _RoomFilter.all => true,
    _RoomFilter.classrooms => !room.isLab,
    _RoomFilter.labs => room.isLab,
  };

  void _selectFirstSlotForDay(int day) {
    final slots = controller.timeSlots.where(
      (slot) => slot.day == day && !slot.isBreak,
    );
    final first = slots.isEmpty ? null : slots.first;
    _start = first?.startMinute ?? 540;
    _end = first?.endMinute ?? 590;
  }

  int _nextEnd(int start) {
    for (final slot in controller.timeSlots) {
      if (slot.day == _day && !slot.isBreak && slot.startMinute == start) {
        return slot.endMinute;
      }
    }
    return start + 50;
  }

  Future<void> _openAvailabilityActions(
    BuildContext context,
    ManualRoom room,
  ) async {
    final closure = _closureAt(room);
    final globallyUnavailable = !room.isAvailable;
    final unavailableAtSlot = room.isUnavailableAt(_day, _start, _end);
    final action = await showModalBottomSheet<_RoomAvailabilityAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(SynchroRadius.sheet),
        ),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            SynchroSpacing.gutter,
            SynchroSpacing.lg,
            SynchroSpacing.gutter,
            SynchroSpacing.gutter,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(room.name, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: SynchroSpacing.xs),
              Text(
                '${controller.dayName(_day)} · ${_time(_start)}–${_time(_end)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: SynchroSpacing.md),
              Text(
                unavailableAtSlot
                    ? globallyUnavailable
                          ? 'This room is unavailable all day.'
                          : 'This room has a closure in the selected slot${closure == null ? '' : ': ${closure.reason}'}. '
                    : 'The room is open at the selected slot.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: SynchroSpacing.lg),
              if (unavailableAtSlot)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(sheetContext).pop(
                      globallyUnavailable
                          ? _RoomAvailabilityAction.makeGloballyAvailable
                          : _RoomAvailabilityAction.openSlot,
                    ),
                    icon: const Icon(Icons.lock_open_outlined),
                    label: Text(
                      globallyUnavailable
                          ? 'Make room available'
                          : 'Open selected slot',
                    ),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () =>
                        Navigator.of(sheetContext)
                            .pop(_RoomAvailabilityAction.closeSlot),
                    icon: const Icon(Icons.block_outlined),
                    label: const Text('Mark selected slot unavailable'),
                  ),
                ),
              const SizedBox(height: SynchroSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!context.mounted || action == null) return;
    switch (action) {
      case _RoomAvailabilityAction.closeSlot:
        controller.markRoomUnavailable(
          room.id,
          day: _day,
          startMinute: _start,
          endMinute: _end,
          unavailable: true,
          reason: 'Closed for local draft',
        );
      case _RoomAvailabilityAction.openSlot:
        controller.markRoomUnavailable(
          room.id,
          day: _day,
          startMinute: _start,
          endMinute: _end,
          unavailable: false,
        );
      case _RoomAvailabilityAction.makeGloballyAvailable:
        controller.markRoomUnavailable(room.id, unavailable: false);
    }
    controller.validate();
    _showMessage(
      context,
      action == _RoomAvailabilityAction.closeSlot
          ? '${room.name} marked unavailable for the selected slot.'
          : '${room.name} availability updated in the local draft.',
    );
  }

  ManualRoomClosure? _closureAt(ManualRoom room) {
    for (final closure in room.unavailableSlots) {
      if (closure.day == _day &&
          closure.startMinute == _start &&
          closure.endMinute == _end) {
        return closure;
      }
    }
    return null;
  }

  Future<void> _openRoomEditor(BuildContext context, {ManualRoom? room}) async {
    final edited = await showModalBottomSheet<ManualRoom>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(SynchroRadius.sheet),
        ),
      ),
      builder: (_) => _RoomEditorSheet(room: room),
    );
    if (!context.mounted || edited == null) return;
    final editing = room != null;
    final applied = _callRoomMethod(controller, edited, editing: editing);
    if (applied) {
      _showMessage(
        context,
        editing
            ? 'Room edit applied to the local draft.'
            : 'Room added to the local draft.',
      );
      return;
    }
    final callback = editing ? widget.onEditRoom : widget.onAddRoom;
    if (callback != null) {
      callback(edited);
      _showMessage(context, 'Room editor callback applied locally.');
    } else {
      _showMessage(
        context,
        'Room add/edit is not exposed by this controller yet; no data was changed.',
      );
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _RoomsDemoBanner extends StatelessWidget {
  const _RoomsDemoBanner();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(
      horizontal: SynchroSpacing.md,
      vertical: SynchroSpacing.sm,
    ),
    decoration: BoxDecoration(
      color: SynchroColors.cream,
      borderRadius: BorderRadius.circular(SynchroRadius.chip),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.science_outlined,
          size: 17,
          color: SynchroColors.navyDeep,
        ),
        const SizedBox(width: SynchroSpacing.sm),
        Expanded(
          child: Text(
            ManualTimetableController.sampleDataLabel,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: SynchroColors.navyDeep),
          ),
        ),
        Text(
          'In memory',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: SynchroColors.navyDeep),
        ),
      ],
    ),
  );
}

class _RoomContextFields extends StatelessWidget {
  const _RoomContextFields({
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
    final daySlots = controller.timeSlots
        .where((slot) => slot.day == day && !slot.isBreak)
        .toList();
    final starts = <int>{
      for (final slot in daySlots) slot.startMinute,
      start,
    }.toList()..sort();
    final ends = <int>{
      for (final slot in daySlots) slot.endMinute,
      end,
    }.toList()..sort();
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
                decoration: const InputDecoration(
                  labelText: 'Day',
                  prefixIcon: Icon(Icons.today_outlined),
                ),
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
                decoration: const InputDecoration(
                  labelText: 'Start',
                  prefixIcon: Icon(Icons.schedule_outlined),
                ),
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
                decoration: const InputDecoration(
                  labelText: 'End',
                  prefixIcon: Icon(Icons.schedule_outlined),
                ),
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

class _RoomCard extends StatelessWidget {
  const _RoomCard({
    required this.room,
    required this.controller,
    required this.day,
    required this.start,
    required this.end,
    required this.onMarkUnavailable,
    required this.onEdit,
  });

  final ManualRoom room;
  final ManualTimetableController controller;
  final int day;
  final int start;
  final int end;
  final VoidCallback onMarkUnavailable;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final session = _sessionAt(controller, room.id, day, start, end);
    final closed = room.isUnavailableAt(day, start, end);
    final available = !closed && session == null;
    final tone = available
        ? Tone.good
        : closed
        ? Tone.bad
        : Tone.warn;
    final status = available
        ? 'Available'
        : closed
        ? room.isAvailable
              ? 'Closed'
              : 'Unavailable'
        : 'Occupied';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SynchroSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(SynchroRadius.card),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                room.isLab
                    ? Icons.science_outlined
                    : Icons.meeting_room_outlined,
                color: room.isLab
                    ? SynchroColors.orangeDeep
                    : SynchroColors.navy,
              ),
              const SizedBox(width: SynchroSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: SynchroSpacing.xs),
                    Text(
                      '${room.kind} · capacity ${room.capacity} · ${room.department}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: SynchroSpacing.sm),
              StatusChip(label: status, tone: tone),
              IconButton(
                tooltip: 'Edit room',
                visualDensity: VisualDensity.compact,
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 19),
              ),
            ],
          ),
          const SizedBox(height: SynchroSpacing.sm),
          Text(
            session == null
                ? 'No local session occupies the selected slot.'
                : 'Occupied by ${controller.subjectById(session.subjectId)?.name ?? 'a class'} · ${controller.batchById(session.batchId)?.name ?? 'batch'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: SynchroSpacing.sm),
          Wrap(
            spacing: SynchroSpacing.sm,
            runSpacing: SynchroSpacing.xs,
            children: [
              OutlinedButton.icon(
                onPressed: onMarkUnavailable,
                icon: Icon(
                  closed ? Icons.lock_open_outlined : Icons.block_outlined,
                  size: 17,
                ),
                label: Text(closed ? 'Open slot' : 'Mark unavailable'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 38),
                  padding: const EdgeInsets.symmetric(
                    horizontal: SynchroSpacing.md,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.tune_outlined, size: 17),
                label: const Text('Edit details'),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 38),
                  padding: const EdgeInsets.symmetric(
                    horizontal: SynchroSpacing.sm,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

ManualSession? _sessionAt(
  ManualTimetableController controller,
  String roomId,
  int day,
  int start,
  int end,
) {
  for (final session in controller.sessions) {
    if (session.roomId == roomId &&
        session.day == day &&
        session.startMinute < end &&
        start < session.endMinute) {
      return session;
    }
  }
  return null;
}

enum _RoomFilter {
  all,
  classrooms,
  labs;

  String get label => switch (this) {
    _RoomFilter.all => 'All',
    _RoomFilter.classrooms => 'Classrooms',
    _RoomFilter.labs => 'Labs',
  };
}

enum _RoomAvailabilityAction { closeSlot, openSlot, makeGloballyAvailable }

String _time(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

bool _callRoomMethod(
  ManualTimetableController controller,
  ManualRoom room, {
  required bool editing,
}) {
  final dynamic target = controller;
  try {
    // ignore: avoid_dynamic_calls
    final result = editing ? target.editRoom(room) : target.addRoom(room);
    return result is bool ? result : true;
  } on NoSuchMethodError {
    return false;
  }
}

class _RoomEditorSheet extends StatefulWidget {
  const _RoomEditorSheet({this.room});

  final ManualRoom? room;

  @override
  State<_RoomEditorSheet> createState() => _RoomEditorSheetState();
}

class _RoomEditorSheetState extends State<_RoomEditorSheet> {
  late final TextEditingController _name;
  late final TextEditingController _capacity;
  late final TextEditingController _department;
  late String _kind;
  late bool _borrowable;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final room = widget.room;
    _name = TextEditingController(text: room?.name ?? '');
    _capacity = TextEditingController(text: '${room?.capacity ?? 45}');
    _department = TextEditingController(
      text: room?.department ?? 'Information Technology',
    );
    _kind = room?.kind ?? 'classroom';
    _borrowable = room?.borrowable ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _capacity.dispose();
    _department.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        SynchroSpacing.gutter,
        SynchroSpacing.lg,
        SynchroSpacing.gutter,
        MediaQuery.viewInsetsOf(context).bottom + SynchroSpacing.gutter,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.room == null ? 'Add room' : 'Edit room',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: SynchroSpacing.xs),
            Text(
              'Room details stay in the local draft until the host supplies a mutation method.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: SynchroSpacing.lg),
            TextFormField(
              controller: _name,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Room name',
                prefixIcon: Icon(Icons.meeting_room_outlined),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a room name'
                  : null,
            ),
            const SizedBox(height: SynchroSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: _kind,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Type',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: const [
                DropdownMenuItem(value: 'classroom', child: Text('Classroom')),
                DropdownMenuItem(
                  value: 'laboratory',
                  child: Text('Laboratory / lab'),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _kind = value);
              },
            ),
            const SizedBox(height: SynchroSpacing.md),
            LayoutBuilder(
              builder: (context, constraints) => Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _capacity,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Capacity',
                        prefixIcon: Icon(Icons.groups_outlined),
                      ),
                      validator: (value) {
                        final parsed = int.tryParse(value?.trim() ?? '');
                        return parsed == null || parsed <= 0
                            ? 'Use a positive number'
                            : null;
                      },
                    ),
                  ),
                  const SizedBox(width: SynchroSpacing.sm),
                  Expanded(
                    child: TextFormField(
                      controller: _department,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Department',
                        prefixIcon: Icon(Icons.account_tree_outlined),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Enter a department'
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _borrowable,
              onChanged: (value) => setState(() => _borrowable = value ?? true),
              title: const Text('Borrowable by another department'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: SynchroSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.check),
                label: Text(
                  widget.room == null ? 'Add to draft' : 'Apply edit',
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final existing = widget.room;
    Navigator.of(context).pop(
      ManualRoom(
        id: existing?.id ?? _slug(_name.text),
        name: _name.text.trim(),
        kind: _kind,
        capacity: int.parse(_capacity.text.trim()),
        department: _department.text.trim(),
        borrowable: _borrowable,
        isAvailable: existing?.isAvailable ?? true,
        unavailableSlots:
            existing?.unavailableSlots ?? const <ManualRoomClosure>[],
      ),
    );
  }
}

String _slug(String value) {
  final slug = value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  return 'room-${slug.replaceAll(RegExp(r'^-+|-+$'), '')}';
}
