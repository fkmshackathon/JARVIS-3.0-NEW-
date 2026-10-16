"""Soft constraints are weighted preferences, and the weights must actually bite.

These tests exist because a penalty reified in one direction only is silently free: the solver
sets the penalty variable to zero and reports a spotless cost for a timetable full of
back-to-back lectures. Every test here pins an expected objective value.
"""

from app.models import Batch, Campus, Faculty, Room, RoomKind, Slot, Subject, TeachingRequirement
from app.solver import (
    CONSECUTIVE_LECTURE_PENALTY,
    STUDENT_GAP_PENALTY,
    GenerationStatus,
    generate_timetable,
)


def campus_with(slots, subjects, requirements, rooms=None, faculty=None, batches=None):
    return Campus(
        slots=slots,
        faculty=faculty or [Faculty(id="f1", name="Dr. A", max_weekly_hours=40)],
        rooms=rooms or [Room(id="r1", name="CR-1", kind=RoomKind.CLASSROOM, capacity=60, department="IT")],
        batches=batches or [Batch(id="b1", name="B1", year=1, size=40)],
        subjects=subjects,
        requirements=requirements,
    )


def periods(days, indexes):
    return [Slot(day=day, index=i, start=540 + i * 60, end=600 + i * 60) for day in days for i in indexes]


def lectures(n):
    return [Subject(id="s1", name="S1", lecture_hours=n, lab_hours=0)]


def req(batch="b1", subject="s1", faculty="f1"):
    return TeachingRequirement(batch_id=batch, subject_id=subject, faculty_id=faculty)


def consecutive_pairs(assignments):
    seen = {(a.day, a.index) for a in assignments}
    return [(day, i) for (day, i) in seen if (day, i + 1) in seen]


def test_back_to_back_lectures_are_paid_for_when_unavoidable():
    """One professor, one day, five periods, five lectures: four consecutive pairs are forced."""
    campus = campus_with(periods([0], range(5)), lectures(5), [req()])
    result = generate_timetable(campus)
    assert result.status is GenerationStatus.SOLVED
    assert len(result.assignments) == 5
    assert len(consecutive_pairs(result.assignments)) == 4
    assert result.soft_cost == 4 * CONSECUTIVE_LECTURE_PENALTY


def test_faculty_rest_preference_is_taken_when_slots_allow():
    """Five lectures across five mornings beat five lectures in one afternoon run."""
    campus = campus_with(periods(range(5), [0, 1]), lectures(5), [req()])
    result = generate_timetable(campus)
    assert result.status is GenerationStatus.SOLVED
    assert consecutive_pairs(result.assignments) == []
    assert result.soft_cost == 0


def test_stranded_free_period_is_paid_for():
    """A batch teaching at 9:00 and 11:00 with 10:00 empty is the gap students complain about."""
    campus = campus_with(
        periods([0], range(3)),
        lectures(2),
        [req()],
        faculty=[Faculty(id="f1", name="Dr. A", max_weekly_hours=40, unavailable=[(0, 1)])],
    )
    result = generate_timetable(campus)
    assert result.status is GenerationStatus.SOLVED
    assert sorted(a.index for a in result.assignments) == [0, 2]
    assert result.soft_cost == STUDENT_GAP_PENALTY


def test_scarcity_returns_a_timetable_with_a_price_rather_than_no_timetable():
    """Hard rules are constraints, preferences are costs: a tight campus still publishes.

    Two batches each needing two lectures, one day of three periods: either a professor takes a
    back-to-back pair (cost 10) or a batch sits idle in the middle (cost 2). The engine must pick
    the cheaper trade-off and still place every session.
    """
    campus = campus_with(
        periods([0], range(3)),
        lectures(2),
        [],
        batches=[Batch(id="b1", name="B1", year=1, size=40), Batch(id="b2", name="B2", year=1, size=40)],
        faculty=[Faculty(id="f1", name="Dr. A", max_weekly_hours=40), Faculty(id="f2", name="Dr. B", max_weekly_hours=40)],
        rooms=[
            Room(id="r1", name="CR-1", kind=RoomKind.CLASSROOM, capacity=60, department="IT"),
            Room(id="r2", name="CR-2", kind=RoomKind.CLASSROOM, capacity=60, department="IT"),
        ],
    )
    campus.requirements = [
        TeachingRequirement(batch_id="b1", subject_id="s1", faculty_id="f1"),
        TeachingRequirement(batch_id="b2", subject_id="s1", faculty_id="f2"),
    ]
    result = generate_timetable(campus, time_limit_seconds=20)
    assert result.status is GenerationStatus.SOLVED, result.message
    assert len(result.assignments) == 4
    assert consecutive_pairs(result.assignments) == []
    assert result.soft_cost == 2 * STUDENT_GAP_PENALTY
