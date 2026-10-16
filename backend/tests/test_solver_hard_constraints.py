"""Hard-constraint tests for the SYNCHRO scheduling engine.

Every test builds a tiny campus, generates a timetable, and then asserts on the
result. Independent validation (app.validator) is deliberately NOT trusted here —
each test re-checks the raw assignments so a bug in the validator cannot hide a
bug in the solver.
"""

import pytest

from app.models import (
    Batch,
    Campus,
    Faculty,
    Room,
    RoomKind,
    Slot,
    Subject,
    TeachingRequirement,
)
from app.solver import GenerationStatus, generate_timetable

DAY_LENGTH = 8 * 60


def standard_slots():
    """Five 60-minute periods, staggered entry example: 9:15 and 10:15."""
    slots = []
    for day in range(5):
        for index, start in enumerate([9 * 60 + 15, 10 * 60 + 15, 11 * 60 + 15, 14 * 60, 15 * 60]):
            slots.append(Slot(day=day, index=index, start=start, end=start + 60))
    return slots


def make_campus():
    return Campus(
        slots=standard_slots(),
        faculty=[Faculty(id="f1", name="Dr. A"), Faculty(id="f2", name="Dr. B")],
        rooms=[
            Room(id="r1", name="CR-101", kind=RoomKind.CLASSROOM, capacity=60, department="IT"),
            Room(id="r2", name="CR-102", kind=RoomKind.CLASSROOM, capacity=60, department="IT"),
            Room(id="lab1", name="Lab-A", kind=RoomKind.LABORATORY, capacity=40, department="IT"),
        ],
        batches=[Batch(id="it_a", name="IT-A", year=1, size=40), Batch(id="it_b", name="IT-B", year=1, size=40)],
        subjects=[
            Subject(id="s1", name="DSA", lecture_hours=3, lab_hours=1),
            Subject(id="s2", name="DBMS", lecture_hours=2, lab_hours=0),
        ],
    )


def test_solver_returns_optimal_for_feasible_campus():
    campus = make_campus()
    campus.requirements = [
        TeachingRequirement(batch_id="it_a", subject_id="s1", faculty_id="f1"),
        TeachingRequirement(batch_id="it_b", subject_id="s2", faculty_id="f2"),
    ]
    result = generate_timetable(campus)
    assert result.status is GenerationStatus.SOLVED, result.message
    # it_a/s1 = 3 lectures + 1 lab, it_b/s2 = 2 lectures
    assert len(result.assignments) == 6


def test_faculty_never_teaches_two_sessions_in_the_same_slot():
    campus = make_campus()
    # One professor, two batches, both needing many hours — forced contention.
    campus.requirements = [
        TeachingRequirement(batch_id="it_a", subject_id="s1", faculty_id="f1"),
        TeachingRequirement(batch_id="it_b", subject_id="s2", faculty_id="f1"),
    ]
    result = generate_timetable(campus)
    assert result.status is GenerationStatus.SOLVED
    keys = [(a.slot.day, a.slot.index) for a in result.assignments]
    assert len(keys) == len(set(keys)), "faculty f1 double-booked in the same slot"


def test_batch_never_has_two_sessions_in_the_same_slot():
    campus = make_campus()
    campus.requirements = [
        TeachingRequirement(batch_id="it_a", subject_id="s1", faculty_id="f1"),
        TeachingRequirement(batch_id="it_a", subject_id="s2", faculty_id="f2"),
    ]
    result = generate_timetable(campus)
    assert result.status is GenerationStatus.SOLVED
    for batch_id in {"it_a"}:
        keys = [(a.slot.day, a.slot.index) for a in result.assignments if a.batch_id == batch_id]
        assert len(keys) == len(set(keys)), f"batch {batch_id} has overlapping sessions"


def test_room_is_never_double_booked():
    campus = make_campus()
    campus.rooms = [Room(id="r1", name="Only Room", kind=RoomKind.CLASSROOM, capacity=60, department="IT")]
    campus.requirements = [
        TeachingRequirement(batch_id="it_a", subject_id="s2", faculty_id="f1"),
        TeachingRequirement(batch_id="it_b", subject_id="s2", faculty_id="f2"),
    ]
    result = generate_timetable(campus)
    assert result.status is GenerationStatus.SOLVED
    keys = [(a.slot.day, a.slot.index) for a in result.assignments]
    assert len(keys) == len(set(keys)), "single shared room over-allocated"


def test_cross_year_faculty_is_checked_globally():
    """A professor teaching 1st and 4th year must not appear twice in one slot."""
    campus = make_campus()
    campus.batches.append(Batch(id="ce_c", name="CE-C", year=4, size=50))
    campus.requirements = [
        TeachingRequirement(batch_id="it_a", subject_id="s1", faculty_id="f1"),
        TeachingRequirement(batch_id="ce_c", subject_id="s2", faculty_id="f1"),
    ]
    result = generate_timetable(campus)
    assert result.status is GenerationStatus.SOLVED
    f1 = [a for a in result.assignments if a.faculty_id == "f1"]
    keys = [(a.slot.day, a.slot.index) for a in f1]
    assert len(keys) == len(set(keys)), "cross-year faculty overlap not prevented"


def test_labs_only_take_lab_rooms():
    campus = make_campus()
    campus.rooms = [
        Room(id="r1", name="CR-101", kind=RoomKind.CLASSROOM, capacity=60, department="IT"),
        Room(id="r2", name="CR-102", kind=RoomKind.CLASSROOM, capacity=60, department="IT"),
        Room(id="lab1", name="Lab-A", kind=RoomKind.LABORATORY, capacity=40, department="IT"),
    ]
    campus.requirements = [TeachingRequirement(batch_id="it_a", subject_id="s1", faculty_id="f1")]
    result = generate_timetable(campus)
    assert result.status is GenerationStatus.SOLVED
    labs = [a for a in result.assignments if a.is_lab]
    assert labs, "expected at least one lab session from s1's 1 lab hour"
    assert all(a.room_kind is RoomKind.LABORATORY for a in labs), "lab scheduled in a plain classroom"
    assert all(not a.is_lab or a.room_kind is RoomKind.LABORATORY for a in result.assignments)


def test_room_capacity_must_cover_batch_size():
    campus = make_campus()
    campus.batches = [Batch(id="it_a", name="IT-A", year=1, size=80)]
    campus.rooms = [Room(id="r1", name="Tiny", kind=RoomKind.CLASSROOM, capacity=40, department="IT")]
    campus.requirements = [TeachingRequirement(batch_id="it_a", subject_id="s1", faculty_id="f1")]
    result = generate_timetable(campus)
    assert result.status is GenerationStatus.INFEASIBLE
    assert "capacity" in result.message.lower() or "no room" in result.message.lower()


def test_faculty_availability_is_enforced():
    campus = make_campus()
    campus.slots = [
        Slot(day=0, index=0, start=540, end=600),
        Slot(day=0, index=1, start=600, end=660),
        Slot(day=0, index=2, start=660, end=720),
    ]
    campus.faculty = [Faculty(id="f1", name="Dr. A", unavailable=[(0, 0)])]
    campus.requirements = [TeachingRequirement(batch_id="it_a", subject_id="s2", faculty_id="f1")]
    result = generate_timetable(campus)
    assert result.status is GenerationStatus.SOLVED
    assert all((a.slot.day, a.slot.index) != (0, 0) for a in result.assignments)


def test_required_hours_are_never_silently_dropped():
    campus = make_campus()
    campus.requirements = [
        TeachingRequirement(batch_id="it_a", subject_id="s1", faculty_id="f1"),
        TeachingRequirement(batch_id="it_b", subject_id="s2", faculty_id="f2"),
    ]
    result = generate_timetable(campus)
    counts = {}
    for a in result.assignments:
        counts[(a.batch_id, a.subject_id, a.is_lab)] = counts.get((a.batch_id, a.subject_id, a.is_lab), 0) + 1
    assert counts[("it_a", "s1", False)] == 3
    assert counts[("it_a", "s1", True)] == 1
    assert counts[("it_b", "s2", False)] == 2


def test_infeasible_input_reports_infeasible_rather_than_a_fake_timetable():
    """Two batches, one slot, one room: no valid timetable exists."""
    campus = make_campus()
    campus.slots = [Slot(day=0, index=0, start=540, end=600)]
    campus.rooms = [Room(id="r1", name="Only", kind=RoomKind.CLASSROOM, capacity=60, department="IT")]
    campus.requirements = [
        TeachingRequirement(batch_id="it_a", subject_id="s1", faculty_id="f1"),
        TeachingRequirement(batch_id="it_b", subject_id="s2", faculty_id="f2"),
    ]
    result = generate_timetable(campus)
    assert result.status is GenerationStatus.INFEASIBLE
    assert result.assignments == []


def test_cross_department_borrowing_respects_policy():
    campus = make_campus()
    campus.rooms = [
        Room(id="mech1", name="MR-1", kind=RoomKind.CLASSROOM, capacity=60, department="MECH", borrowable=False),
        Room(id="mech2", name="MR-2", kind=RoomKind.CLASSROOM, capacity=60, department="MECH", borrowable=True),
    ]
    campus.requirements = [
        TeachingRequirement(batch_id="it_a", subject_id="s2", faculty_id="f1", department="IT"),
    ]
    result = generate_timetable(campus)
    assert result.status is GenerationStatus.SOLVED
    assert all(a.room_id != "mech1" for a in result.assignments), "non-borrowable room was used by another dept"
    assert any(a.room_id == "mech2" for a in result.assignments)


def test_fixed_session_is_respected():
    campus = make_campus()
    campus.requirements = [TeachingRequirement(batch_id="it_a", subject_id="s2", faculty_id="f1")]
    result = generate_timetable(campus, fixed=[{"batch_id": "it_a", "subject_id": "s2", "day": 2, "index": 0}])
    assert result.status is GenerationStatus.SOLVED
    pinned = [a for a in result.assignments if a.batch_id == "it_a" and a.subject_id == "s2"]
    assert any((a.slot.day, a.slot.index) == (2, 0) for a in pinned), "fixed session was moved"


@pytest.mark.parametrize("seed", [1, 2])
def test_generation_is_repeatable(seed):
    campus = make_campus()
    campus.requirements = [
        TeachingRequirement(batch_id="it_a", subject_id="s1", faculty_id="f1"),
        TeachingRequirement(batch_id="it_b", subject_id="s2", faculty_id="f2"),
    ]
    first = generate_timetable(campus, random_seed=seed, num_workers=1)
    second = generate_timetable(campus, random_seed=seed, num_workers=1)
    assert [(a.batch_id, a.subject_id, a.slot.day, a.slot.index, a.room_id) for a in first.assignments] == [
        (a.batch_id, a.subject_id, a.slot.day, a.slot.index, a.room_id) for a in second.assignments
    ]
