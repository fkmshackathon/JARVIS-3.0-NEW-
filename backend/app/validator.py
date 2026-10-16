"""Independent timetable validation.

Deliberately re-derives every rule from the campus definition rather than trusting the
solver: a timetable is publishable only if this module finds no violation. Occupied
periods are expanded from the session start plus its duration, so a two-period lab is
checked against both periods.
"""

from __future__ import annotations

from dataclasses import dataclass

from .models import Assignment, Campus, RoomKind, SlotKey


@dataclass(frozen=True)
class Violation:
    code: str
    message: str
    refs: tuple[str, ...] = ()

    def __str__(self) -> str:
        return f"[{self.code}] {self.message}"


def occupied_keys(campus: Campus, assignment: Assignment) -> list[SlotKey]:
    subject = campus.subject_by_id(assignment.subject_id)
    duration = max(1, subject.lab_duration_slots) if assignment.is_lab else 1
    by_day = {slot.day: {} for slot in campus.slots}
    for slot in campus.slots:
        by_day[slot.day][slot.index] = slot
    keys: list[SlotKey] = []
    indexes = by_day.get(assignment.slot.day, {})
    for offset in range(duration):
        index = assignment.slot.index + offset
        if index in indexes:
            keys.append((assignment.slot.day, index))
    return keys


def validate(campus: Campus, assignments: list[Assignment]) -> list[Violation]:
    violations: list[Violation] = []
    slot_keys = {slot.key for slot in campus.slots}
    expanded: dict[Assignment, list[SlotKey]] = {}

    for assignment in assignments:
        keys = occupied_keys(campus, assignment)
        subject = campus.subject_by_id(assignment.subject_id)
        duration = max(1, subject.lab_duration_slots) if assignment.is_lab else 1
        if len(keys) != duration:
            violations.append(
                Violation(
                    "SESSION_RUN_OFF",
                    f"{assignment.batch_id} {assignment.subject_id} starting at day "
                    f"{assignment.slot.day} period {assignment.slot.index} runs past the end of the day.",
                    (assignment.session_id,),
                )
            )
        expanded[assignment] = keys

    def clash_on(picker, label: str, code: str) -> None:
        buckets: dict[tuple, list[Assignment]] = {}
        for assignment, keys in expanded.items():
            owner = picker(assignment)
            if owner is None:
                continue
            for key in keys:
                buckets.setdefault((owner, key), []).append(assignment)
        for (owner, key), group in buckets.items():
            if len(group) > 1:
                violations.append(
                    Violation(
                        code,
                        f"{label} '{owner}' double-booked at day {key[0]} period {key[1]} by "
                        f"{', '.join(a.session_id for a in group)}.",
                        tuple(a.session_id for a in group),
                    )
                )

    clash_on(lambda a: a.faculty_id, "faculty", "FACULTY_CLASH")
    clash_on(lambda a: a.batch_id, "batch", "BATCH_CLASH")
    clash_on(lambda a: a.room_id, "room", "ROOM_CLASH")

    for assignment, keys in expanded.items():
        batch = campus.batch_by_id(assignment.batch_id)
        room = campus.room_by_id(assignment.room_id)
        faculty = campus.faculty_by_id(assignment.faculty_id)
        subject = campus.subject_by_id(assignment.subject_id)

        wanted = RoomKind.LABORATORY if assignment.is_lab else RoomKind.CLASSROOM
        if room.kind is not wanted:
            violations.append(
                Violation(
                    "ROOM_KIND",
                    f"{subject.name} {'lab' if assignment.is_lab else 'lecture'} for {batch.name} is in "
                    f"{room.name} ({room.kind.value}).",
                    (assignment.session_id,),
                )
            )
        if room.capacity < batch.size:
            violations.append(
                Violation(
                    "ROOM_CAPACITY",
                    f"{room.name} holds {room.capacity} but {batch.name} has {batch.size} students.",
                    (assignment.session_id,),
                )
            )
        owned = not assignment.department or not room.department or room.department == assignment.department
        if not owned and not room.borrowable:
            violations.append(
                Violation(
                    "ROOM_POLICY",
                    f"{room.name} belongs to {room.department} and is not borrowable, but is used by "
                    f"{assignment.department}.",
                    (assignment.session_id,),
                )
            )
        for key in keys:
            if key not in slot_keys:
                violations.append(
                    Violation("UNKNOWN_SLOT", f"{assignment.session_id} uses undefined slot {key}.",
                              (assignment.session_id,))
                )
            if key in campus.break_slots:
                violations.append(
                    Violation("BREAK_USED", f"{assignment.session_id} is scheduled inside a break.",
                              (assignment.session_id,))
                )
            if key in faculty.unavailable:
                violations.append(
                    Violation("FACULTY_UNAVAILABLE",
                              f"{faculty.name} is unavailable at day {key[0]} period {key[1]}.",
                              (assignment.session_id,))
                )
            if key in room.closed:
                violations.append(
                    Violation("ROOM_CLOSED", f"{room.name} is closed at day {key[0]} period {key[1]}.",
                              (assignment.session_id,))
                )
        if not faculty.can_teach(subject.id):
            violations.append(
                Violation("NOT_QUALIFIED", f"{faculty.name} is not qualified to teach {subject.name}.",
                          (assignment.session_id,))
            )

    counts: dict[tuple[str, str, bool], int] = {}
    for assignment in assignments:
        key = (assignment.batch_id, assignment.subject_id, assignment.is_lab)
        counts[key] = counts.get(key, 0) + 1
    for req in campus.requirements:
        subject = campus.subject_by_id(req.subject_id)
        want_lecture = req.lecture_hours if req.lecture_hours is not None else subject.lecture_hours
        want_lab = req.lab_hours if req.lab_hours is not None else subject.lab_hours
        got_lecture = counts.get((req.batch_id, req.subject_id, False), 0)
        got_lab = counts.get((req.batch_id, req.subject_id, True), 0)
        if got_lecture != want_lecture:
            violations.append(
                Violation("MISSING_LECTURES",
                          f"{req.batch_id} / {subject.name}: {got_lecture} lecture(s) scheduled, "
                          f"{want_lecture} required.", (req.batch_id, req.subject_id))
            )
        if got_lab != want_lab:
            violations.append(
                Violation("MISSING_LABS",
                          f"{req.batch_id} / {subject.name}: {got_lab} lab session(s) scheduled, "
                          f"{want_lab} required.", (req.batch_id, req.subject_id))
            )

    load: dict[str, int] = {}
    for assignment, keys in expanded.items():
        load[assignment.faculty_id] = load.get(assignment.faculty_id, 0) + len(keys)
    for faculty_id, hours in load.items():
        faculty = campus.faculty_by_id(faculty_id)
        if hours > faculty.max_weekly_hours:
            violations.append(
                Violation("WORKLOAD_EXCEEDED",
                          f"{faculty.name} teaches {hours} hours, above their {faculty.max_weekly_hours} "
                          f"hour limit.", (faculty_id,))
            )

    return violations


def is_publishable(campus: Campus, assignments: list[Assignment]) -> bool:
    return not validate(campus, assignments)
