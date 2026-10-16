"""Readings the committee needs *before* asking the solver to run.

FEATURE 1 requires the workload distribution to be checked for completeness and internal
consistency up front, and FEATURE 2 requires the resource audit. Both are arithmetic over the
campus definition, so they live apart from the search: a coordinator sees the same numbers the
engine will be held to.
"""

from __future__ import annotations

from .models import Campus
from .solver import build_sessions, preflight


def workload_summary(campus: Campus) -> dict:
    sessions = build_sessions(campus)
    usable = [slot for slot in campus.slots if slot.key not in set(campus.break_slots)]

    faculty = []
    for person in campus.faculty:
        theirs = [s for s in sessions if s.faculty_id == person.id]
        assigned = sum(s.duration for s in theirs)
        available = len([slot for slot in usable if slot.key not in set(person.unavailable)])
        faculty.append(
            {
                "id": person.id,
                "name": person.name,
                "department": person.department,
                "sessions": len(theirs),
                "assigned_hours": assigned,
                "max_weekly_hours": person.max_weekly_hours,
                "available_periods": available,
                "overloaded": assigned > person.max_weekly_hours,
                "no_capacity": assigned > available,
                "subjects": sorted({s.subject_id for s in theirs}),
            }
        )

    batches = []
    for batch in campus.batches:
        theirs = [s for s in sessions if s.batch_id == batch.id]
        batches.append(
            {
                "id": batch.id,
                "name": batch.name,
                "year": batch.year,
                "division_id": batch.division_id,
                "size": batch.size,
                "lecture_hours": sum(s.duration for s in theirs if not s.is_lab),
                "lab_periods": sum(s.duration for s in theirs if s.is_lab),
                "subjects": sorted({s.subject_id for s in theirs}),
            }
        )

    rooms = []
    for room in campus.rooms:
        rooms.append(
            {
                "id": room.id,
                "name": room.name,
                "kind": room.kind.value,
                "capacity": room.capacity,
                "department": room.department,
                "borrowable": room.borrowable,
                "closed_periods": len(room.closed),
                "usable_periods": len([slot for slot in campus.slots if slot.key not in set(room.closed)]),
            }
        )

    idle = [f for f in campus.faculty if not any(s.faculty_id == f.id for s in sessions)]
    empty = [
        f"{campus.batch_by_id(r.batch_id).name} / {campus.subject_by_id(r.subject_id).name} requires no "
        f"teaching hours — check the workload distribution."
        for r in campus.requirements
        if _resolved_hours(campus, r) == 0
    ]
    blocker = preflight(campus, sessions)
    return {
        "periods": {
            "total": len(campus.slots),
            "usable": len(usable),
            "break": len(campus.break_slots),
            "days": len({slot.day for slot in campus.slots}),
        },
        "demand": {
            "sessions": len(sessions),
            "lecture_periods": sum(s.duration for s in sessions if not s.is_lab),
            "lab_periods": sum(s.duration for s in sessions if s.is_lab),
        },
        "supply": {
            "classrooms": len([r for r in campus.rooms if r.kind.value == "classroom"]),
            "laboratories": len([r for r in campus.rooms if r.kind.value == "laboratory"]),
            "borrowable_from_other_departments": len(
                [r for r in campus.rooms if r.borrowable and r.department and
                 any(s.department and s.department != r.department for s in sessions)]
            ),
            "classroom_periods": sum(
                len([slot for slot in usable if slot.key not in set(r.closed)])
                for r in campus.rooms if r.kind.value == "classroom"
            ),
            "laboratory_periods": sum(
                len([slot for slot in usable if slot.key not in set(r.closed)])
                for r in campus.rooms if r.kind.value == "laboratory"
            ),
        },
        "faculty": faculty,
        "batches": batches,
        "rooms": rooms,
        "warnings": empty
        + [
            f"{person.name} is on the staff list but has no teaching assignment this semester."
            for person in idle
        ]
        + [
            f"{entry['name']} is assigned {entry['assigned_hours']} hours but is only available for "
            f"{entry['available_periods']} periods."
            for entry in faculty
            if entry["no_capacity"]
        ]
        + [
            f"{entry['name']} is assigned {entry['assigned_hours']} hours, above their "
            f"{entry['max_weekly_hours']} hour limit."
            for entry in faculty
            if entry["overloaded"]
        ],
        "blocker": blocker,
        "can_generate": blocker is None,
    }


def utilisation(campus: Campus, assignments) -> dict:
    """How much of the campus the published timetable actually consumed."""
    per_room: dict[str, int] = {}
    for assignment in assignments:
        per_room[assignment.room_id] = per_room.get(assignment.room_id, 0) + 1
    used = [room for room in campus.rooms if per_room.get(room.id)]
    return {
        "rooms_in_use": len(used),
        "rooms_on_campus": len(campus.rooms),
        "borrowed_periods": sum(
            1
            for assignment in assignments
            if assignment.department
            and campus.room_by_id(assignment.room_id).department != assignment.department
        ),
        "busiest": [
            {"room_id": room.id, "name": room.name, "sessions": per_room[room.id]}
            for room in sorted(used, key=lambda r: -per_room.get(r.id, 0))[:5]
        ],
    }


def _resolved_hours(campus: Campus, requirement) -> int:
    """Weekly periods a requirement asks for, after falling back to the subject's own hours."""
    subject = campus.subject_by_id(requirement.subject_id)
    lectures = (
        requirement.lecture_hours if requirement.lecture_hours is not None else subject.lecture_hours
    )
    labs = requirement.lab_hours if requirement.lab_hours is not None else subject.lab_hours
    return max(0, lectures) + max(0, labs) * max(1, subject.lab_duration_slots)
