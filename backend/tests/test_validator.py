"""The validator must reject hand-built bad timetables and accept solver output."""

import pytest

from app.models import Assignment, RoomKind, Slot, TeachingRequirement
from app.solver import GenerationStatus, generate_timetable
from app.validator import occupied_keys, validate
from tests.test_solver_hard_constraints import make_campus


def assignment(session_id, batch, subject, faculty, room, day, index, is_lab=False, kind=RoomKind.CLASSROOM):
    return Assignment(
        session_id=session_id,
        batch_id=batch,
        subject_id=subject,
        faculty_id=faculty,
        room_id=room,
        slot=Slot(day=day, index=index, start=540 + index * 60, end=600 + index * 60),
        is_lab=is_lab,
        room_kind=kind,
        department="IT",
    )


def codes(violations):
    return {v.code for v in violations}


def test_clean_timetable_has_no_violations():
    campus = make_campus()
    campus.requirements = [
        TeachingRequirement(batch_id="it_a", subject_id="s1", faculty_id="f1"),
        TeachingRequirement(batch_id="it_b", subject_id="s2", faculty_id="f2"),
    ]
    result = generate_timetable(campus)
    assert result.status is GenerationStatus.SOLVED
    assert validate(campus, result.assignments) == []


def test_detects_faculty_double_booking():
    campus = make_campus()
    bad = [
        assignment("a", "it_a", "s2", "f1", "r1", 0, 0),
        assignment("b", "it_b", "s2", "f1", "r2", 0, 0),
    ]
    assert "FACULTY_CLASH" in codes(validate(campus, bad))


def test_detects_room_double_booking():
    campus = make_campus()
    bad = [
        assignment("a", "it_a", "s2", "f1", "r1", 0, 0),
        assignment("b", "it_b", "s2", "f2", "r1", 0, 0),
    ]
    assert "ROOM_CLASH" in codes(validate(campus, bad))


def test_detects_batch_double_booking():
    campus = make_campus()
    bad = [
        assignment("a", "it_a", "s2", "f1", "r1", 0, 0),
        assignment("b", "it_a", "s2", "f2", "r2", 0, 0),
    ]
    assert "BATCH_CLASH" in codes(validate(campus, bad))


def test_detects_lab_placed_in_classroom():
    campus = make_campus()
    bad = [assignment("a", "it_a", "s1", "f1", "r1", 0, 0, is_lab=True)]
    assert "ROOM_KIND" in codes(validate(campus, bad))


def test_detects_over_capacity_room():
    campus = make_campus()
    campus.rooms.append(RoomForTest.small())
    bad = [assignment("a", "it_a", "s2", "f1", "tiny", 0, 0)]
    assert "ROOM_CAPACITY" in codes(validate(campus, bad))


def test_detects_non_borrowable_department_room():
    campus = make_campus()
    from app.models import Room

    campus.rooms.append(Room(id="mech_locked", name="MR-X", kind=RoomKind.CLASSROOM, capacity=60,
                             department="MECH", borrowable=False))
    bad = [assignment("a", "it_a", "s2", "f1", "mech_locked", 0, 0)]
    assert "ROOM_POLICY" in codes(validate(campus, bad))


def test_detects_assignment_in_a_break():
    campus = make_campus()
    campus.break_slots = [(0, 2)]
    bad = [assignment("a", "it_a", "s2", "f1", "r1", 0, 2)]
    assert "BREAK_USED" in codes(validate(campus, bad))


def test_detects_unavailable_faculty():
    campus = make_campus()
    campus.faculty[0].unavailable = [(0, 1)]
    bad = [assignment("a", "it_a", "s2", "f1", "r1", 0, 1)]
    assert "FACULTY_UNAVAILABLE" in codes(validate(campus, bad))


def test_detects_closed_room():
    campus = make_campus()
    campus.rooms[0].closed = [(0, 1)]
    bad = [assignment("a", "it_a", "s2", "f1", "r1", 0, 1)]
    assert "ROOM_CLOSED" in codes(validate(campus, bad))


def test_detects_missing_required_hours():
    campus = make_campus()
    from app.models import TeachingRequirement

    campus.requirements = [TeachingRequirement(batch_id="it_a", subject_id="s1", faculty_id="f1")]
    assert {"MISSING_LECTURES", "MISSING_LABS"} <= codes(validate(campus, []))


def test_detects_excess_workload():
    campus = make_campus()
    campus.faculty[0].max_weekly_hours = 1
    bad = [
        assignment("a", "it_a", "s2", "f1", "r1", 0, 0),
        assignment("b", "it_a", "s2", "f1", "r2", 0, 1),
    ]
    assert "WORKLOAD_EXCEEDED" in codes(validate(campus, bad))


def test_lab_spanning_two_periods_blocks_both(campus=None):
    from app.models import Subject

    campus = make_campus()
    campus.subjects = [Subject(id="s1", name="DSA", lecture_hours=0, lab_hours=1, lab_duration_slots=2)]
    lab = assignment("a", "it_a", "s1", "f1", "lab1", 0, 1, is_lab=True, kind=RoomKind.LABORATORY)
    assert occupied_keys(campus, lab) == [(0, 1), (0, 2)]
    clash = assignment("b", "it_b", "s1", "f2", "lab1", 0, 2, is_lab=True, kind=RoomKind.LABORATORY)
    assert "ROOM_CLASH" in codes(validate(campus, [lab, clash]))


def test_run_off_the_end_of_day_is_flagged():
    campus = make_campus()
    from app.models import Subject

    campus.subjects = [Subject(id="s1", name="DSA", lecture_hours=0, lab_hours=1, lab_duration_slots=2)]
    last = assignment("a", "it_a", "s1", "f1", "lab1", 0, 4, is_lab=True, kind=RoomKind.LABORATORY)
    assert "SESSION_RUN_OFF" in codes(validate(campus, [last]))


class RoomForTest:
    @staticmethod
    def small():
        from app.models import Room

        return Room(id="tiny", name="Tiny", kind=RoomKind.CLASSROOM, capacity=10, department="IT")


def realistic_campus(labs=4):
    """TE/B.E. shape: 3 years x 2 divisions x 2 batches, tight room count, staggered slots."""
    from app.models import Batch, Campus, Faculty, Room, Subject, TeachingRequirement

    slots = []
    for day in range(5):
        for index, start in enumerate([9 * 60 + 15, 10 * 60 + 15, 11 * 60 + 30, 14 * 60, 15 * 60, 16 * 60]):
            slots.append(Slot(day=day, index=index, start=start, end=start + 60))
    faculty = [Faculty(id=f"t{i}", name=f"Prof {i}", max_weekly_hours=20) for i in range(12)]
    rooms = (
        [Room(id=f"c{i}", name=f"CR-{i}", kind=RoomKind.CLASSROOM, capacity=70, department="IT") for i in range(5)]
        + [Room(id=f"m{i}", name=f"MR-{i}", kind=RoomKind.CLASSROOM, capacity=60, department="MECH") for i in range(3)]
        + [Room(id=f"l{i}", name=f"LAB-{i}", kind=RoomKind.LABORATORY, capacity=45, department="IT") for i in range(labs)]
    )
    batches = [
        Batch(id=f"y{y}d{d}b{b}", name=f"Y{y}D{d}B{b}", year=y, size=40, division_id=f"y{y}d{d}")
        for y in (1, 2, 3)
        for d in (1, 2)
        for b in (1, 2)
    ]
    subjects = [Subject(id=f"sub{i}", name=f"Subject {i}", lecture_hours=3, lab_hours=1, lab_duration_slots=2)
                for i in range(6)]
    campus = Campus(slots=slots, faculty=faculty, rooms=rooms, batches=batches, subjects=subjects)
    campus.break_slots = [(d, 2) for d in range(5)]
    requirements = []
    n = 0
    for batch in batches:
        for subject in subjects[:3]:
            requirements.append(
                TeachingRequirement(batch_id=batch.id, subject_id=subject.id, faculty_id=faculty[n % 12].id,
                                    department="IT")
            )
            n += 1
    campus.requirements = requirements
    return campus


def test_realistic_campus_scales():
    campus = realistic_campus()
    result = generate_timetable(campus, time_limit_seconds=30)
    assert result.status is GenerationStatus.SOLVED, result.message
    assert validate(campus, result.assignments) == []
    assert len(result.assignments) == 12 * 3 * 4  # 12 batches x 3 subjects x (3 lectures + 1 lab)


def test_preflight_names_room_scarcity_instead_of_timing_out():
    """36 two-period labs cannot fit in 3 labs: say so immediately, with the numbers."""
    from app.solver import build_sessions, preflight

    campus = realistic_campus(labs=3)
    result = generate_timetable(campus, time_limit_seconds=30)
    assert result.status is GenerationStatus.INFEASIBLE
    assert "laboratory" in result.message
    assert "at most 30" in result.message, result.message
    assert preflight(campus, build_sessions(campus)) == result.message


@pytest.mark.parametrize("bad_code", ["FACULTY_CLASH", "ROOM_CLASH", "BATCH_CLASH"])
def test_violations_name_the_sessions(bad_code):
    campus = make_campus()
    if bad_code == "FACULTY_CLASH":
        pair = [assignment("a", "it_a", "s2", "f1", "r1", 0, 0), assignment("b", "it_b", "s2", "f1", "r2", 0, 0)]
    elif bad_code == "ROOM_CLASH":
        pair = [assignment("a", "it_a", "s2", "f1", "r1", 0, 0), assignment("b", "it_b", "s2", "f2", "r1", 0, 0)]
    else:
        pair = [assignment("a", "it_a", "s2", "f1", "r1", 0, 0), assignment("b", "it_a", "s2", "f2", "r2", 0, 0)]
    hits = [v for v in validate(campus, pair) if v.code == bad_code]
    assert hits and set(hits[0].refs) == {"a", "b"}
