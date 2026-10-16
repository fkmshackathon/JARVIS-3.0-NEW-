"""JSON payloads to and from the domain model.

The API never hands a half-formed campus to the solver: every payload is parsed here and a
missing or contradictory field is reported by name, because a coordinator reading "400 Bad
Request" cannot fix a timetable they cannot locate.
"""

from __future__ import annotations

from .models import (
    Assignment,
    Batch,
    Campus,
    Faculty,
    Room,
    RoomKind,
    Session,
    Slot,
    Subject,
    TeachingRequirement,
)


class CampusError(ValueError):
    """A payload field is missing, malformed or inconsistent."""


def _require(mapping: dict, key: str, where: str):
    if not isinstance(mapping, dict) or key not in mapping or mapping[key] in (None, ""):
        raise CampusError(f"{where}: '{key}' is required")
    return mapping[key]


def _slot(raw, where: str) -> Slot:
    if not isinstance(raw, dict):
        raise CampusError(f"{where}: a period must be an object, not {type(raw).__name__}")
    return Slot(
        day=int(_require(raw, "day", where)),
        index=int(_require(raw, "index", where)),
        start=int(_require(raw, "start", where)),
        end=int(_require(raw, "end", where)),
    )


def _keys(raw, where: str) -> list[tuple[int, int]]:
    if raw is None:
        return []
    if not isinstance(raw, list):
        raise CampusError(f"{where}: expected a list of [day, index] pairs")
    out = []
    for pair in raw:
        if isinstance(pair, dict):
            pair = [pair.get("day"), pair.get("index")]
        if not isinstance(pair, (list, tuple)) or len(pair) != 2:
            raise CampusError(f"{where}: each entry must be [day, index]")
        out.append((int(pair[0]), int(pair[1])))
    return out


def campus_from_payload(payload: dict) -> Campus:
    if not isinstance(payload, dict):
        raise CampusError("body must be a JSON object")

    slots = [_slot(raw, f"slots[{i}]") for i, raw in enumerate(payload.get("slots") or [])]
    if not slots:
        raise CampusError("campus needs at least one timetabled period in 'slots'")

    faculty = []
    for i, raw in enumerate(payload.get("faculty") or []):
        where = f"faculty[{i}]"
        faculty.append(
            Faculty(
                id=str(_require(raw, "id", where)),
                name=str(_require(raw, "name", where)),
                department=str(raw.get("department") or ""),
                max_weekly_hours=int(raw.get("max_weekly_hours", 24)),
                unavailable=_keys(raw.get("unavailable"), f"{where}.unavailable"),
                qualified_subjects=[str(s) for s in (raw.get("qualified_subjects") or [])],
            )
        )

    rooms = []
    for i, raw in enumerate(payload.get("rooms") or []):
        where = f"rooms[{i}]"
        try:
            kind = RoomKind(str(_require(raw, "kind", where)).lower())
        except ValueError as exc:
            raise CampusError(f"{where}.kind: expected 'classroom' or 'laboratory'") from exc
        rooms.append(
            Room(
                id=str(_require(raw, "id", where)),
                name=str(_require(raw, "name", where)),
                kind=kind,
                capacity=int(_require(raw, "capacity", where)),
                department=str(raw.get("department") or ""),
                borrowable=bool(raw.get("borrowable", True)),
                closed=_keys(raw.get("closed"), f"{where}.closed"),
            )
        )

    batches = []
    for i, raw in enumerate(payload.get("batches") or []):
        where = f"batches[{i}]"
        batches.append(
            Batch(
                id=str(_require(raw, "id", where)),
                name=str(_require(raw, "name", where)),
                year=int(_require(raw, "year", where)),
                size=int(_require(raw, "size", where)),
                division_id=str(raw.get("division_id") or ""),
                stagger_group=int(raw.get("stagger_group", 0)),
            )
        )

    subjects = []
    for i, raw in enumerate(payload.get("subjects") or []):
        where = f"subjects[{i}]"
        subjects.append(
            Subject(
                id=str(_require(raw, "id", where)),
                name=str(_require(raw, "name", where)),
                lecture_hours=int(raw.get("lecture_hours", 0)),
                lab_hours=int(raw.get("lab_hours", 0)),
                lab_duration_slots=int(raw.get("lab_duration_slots", 1)),
                department=str(raw.get("department") or ""),
            )
        )

    requirements = []
    for i, raw in enumerate(payload.get("requirements") or []):
        where = f"requirements[{i}]"
        hours = raw.get("lecture_hours")
        labs = raw.get("lab_hours")
        requirements.append(
            TeachingRequirement(
                batch_id=str(_require(raw, "batch_id", where)),
                subject_id=str(_require(raw, "subject_id", where)),
                faculty_id=str(_require(raw, "faculty_id", where)),
                department=str(raw.get("department") or ""),
                lecture_hours=None if hours is None else int(hours),
                lab_hours=None if labs is None else int(labs),
            )
        )

    break_slots = _keys(payload.get("break_slots"), "break_slots")
    known = {slot.key for slot in slots}
    for pair in break_slots:
        if pair not in known:
            raise CampusError(f"break_slots: period {list(pair)} is not one of the campus slots")

    return Campus(
        slots=slots,
        faculty=faculty,
        rooms=rooms,
        batches=batches,
        subjects=subjects,
        requirements=requirements,
        break_slots=break_slots,
    )


def campus_to_payload(campus: Campus) -> dict:
    return {
        "slots": [{"day": s.day, "index": s.index, "start": s.start, "end": s.end} for s in campus.slots],
        "break_slots": [[day, index] for day, index in campus.break_slots],
        "faculty": [
            {
                "id": f.id,
                "name": f.name,
                "department": f.department,
                "max_weekly_hours": f.max_weekly_hours,
                "unavailable": [[d, i] for d, i in f.unavailable],
                "qualified_subjects": list(f.qualified_subjects),
            }
            for f in campus.faculty
        ],
        "rooms": [
            {
                "id": r.id,
                "name": r.name,
                "kind": r.kind.value,
                "capacity": r.capacity,
                "department": r.department,
                "borrowable": r.borrowable,
                "closed": [[d, i] for d, i in r.closed],
            }
            for r in campus.rooms
        ],
        "batches": [
            {
                "id": b.id,
                "name": b.name,
                "year": b.year,
                "size": b.size,
                "division_id": b.division_id,
                "stagger_group": b.stagger_group,
            }
            for b in campus.batches
        ],
        "subjects": [
            {
                "id": s.id,
                "name": s.name,
                "lecture_hours": s.lecture_hours,
                "lab_hours": s.lab_hours,
                "lab_duration_slots": s.lab_duration_slots,
                "department": s.department,
            }
            for s in campus.subjects
        ],
        "requirements": [
            {
                "batch_id": r.batch_id,
                "subject_id": r.subject_id,
                "faculty_id": r.faculty_id,
                "department": r.department,
                "lecture_hours": r.lecture_hours,
                "lab_hours": r.lab_hours,
            }
            for r in campus.requirements
        ],
    }


def assignment_to_dict(assignment: Assignment) -> dict:
    return {
        "session_id": assignment.session_id,
        "batch_id": assignment.batch_id,
        "subject_id": assignment.subject_id,
        "faculty_id": assignment.faculty_id,
        "room_id": assignment.room_id,
        "day": assignment.day,
        "index": assignment.index,
        "start": assignment.slot.start,
        "end": assignment.slot.end,
        "is_lab": assignment.is_lab,
        "room_kind": assignment.room_kind.value,
        "department": assignment.department,
    }


def assignment_from_dict(raw: dict, campus: Campus) -> Assignment:
    where = f"assignments[{raw.get('session_id')}]"
    slot = campus.slot_by_key((int(_require(raw, "day", where)), int(_require(raw, "index", where))))
    if slot is None:
        raise CampusError(f"{where}: period is not part of this campus")
    room_id = str(_require(raw, "room_id", where))
    try:
        room = campus.room_by_id(room_id)
    except StopIteration as exc:
        raise CampusError(f"{where}: unknown room '{room_id}'") from exc
    session = Session(
        id=str(raw.get("session_id") or ""),
        batch_id=str(_require(raw, "batch_id", where)),
        subject_id=str(_require(raw, "subject_id", where)),
        faculty_id=str(_require(raw, "faculty_id", where)),
        department=str(raw.get("department") or ""),
        is_lab=bool(raw.get("is_lab", False)),
        duration=1,
    )
    try:
        subject = campus.subject_by_id(session.subject_id)
        session = Session(
            session.id, session.batch_id, session.subject_id, session.faculty_id, session.department,
            session.is_lab, max(1, subject.lab_duration_slots) if session.is_lab else 1,
        )
    except StopIteration:
        pass
    return Assignment(
        session_id=session.id,
        batch_id=session.batch_id,
        subject_id=session.subject_id,
        faculty_id=session.faculty_id,
        room_id=room.id,
        slot=slot,
        is_lab=session.is_lab,
        room_kind=room.kind,
        department=session.department,
    )
