"""CP-SAT scheduling engine for SYNCHRO.

Timetabling has two halves of very different shape. Deciding *when* every session runs is a
search problem: sessions compete for the same faculty, batches and periods. Deciding *where*
they run, once the times are fixed, is a much smaller assignment problem. Solving both in one
model multiplies the search space — measured at 300 ms for the clock alone against 6.5 s for
the combined model on a 144-session campus — so they run in sequence and are joined by a
cutting-plane loop: a legal set of times that the rooms cannot house is forbidden and the
clock half is re-solved.

Hard rules are constraints. Quality rules are weighted penalties, so a campus short on rooms
still returns a valid timetable instead of deadlocking.
"""

from __future__ import annotations

import time
from dataclasses import dataclass, field
from enum import Enum

from ortools.sat.python import cp_model

from .models import Assignment, Campus, Room, RoomKind, Session, Slot, SlotKey

CONSECUTIVE_LECTURE_PENALTY = 10
STUDENT_GAP_PENALTY = 2
ROOM_SPRAWL_PENALTY = 1
CROSS_DEPARTMENT_PENALTY = 4

# How many time patterns the engine will reject before telling the committee the rooms lose.
MAX_ROOM_RETRIES = 4


class GenerationStatus(str, Enum):
    SOLVED = "solved"
    INFEASIBLE = "infeasible"
    ERROR = "error"


@dataclass
class GenerationResult:
    status: GenerationStatus
    assignments: list[Assignment] = field(default_factory=list)
    message: str = ""
    solver_status: str = ""
    soft_cost: int | None = None
    wall_time_ms: int = 0


@dataclass(frozen=True)
class Placement:
    """One session and the run of consecutive periods it was given."""

    session: Session
    position: int
    window: tuple[Slot, ...]

    @property
    def periods(self) -> list[SlotKey]:
        return [slot.key for slot in self.window]


def build_sessions(campus: Campus) -> list[Session]:
    sessions: list[Session] = []
    for req in campus.requirements:
        subject = campus.subject_by_id(req.subject_id)
        batch = campus.batch_by_id(req.batch_id)
        department = req.department or subject.department or batch.division_id
        lectures = req.lecture_hours if req.lecture_hours is not None else subject.lecture_hours
        labs = req.lab_hours if req.lab_hours is not None else subject.lab_hours
        for n in range(lectures):
            sessions.append(
                Session(f"{req.batch_id}:{req.subject_id}:L{n}", req.batch_id, req.subject_id,
                        req.faculty_id, department, False, 1)
            )
        for n in range(labs):
            sessions.append(
                Session(f"{req.batch_id}:{req.subject_id}:P{n}", req.batch_id, req.subject_id,
                        req.faculty_id, department, True, max(1, subject.lab_duration_slots))
            )
    return sessions


def allowed_windows(campus: Campus, session: Session) -> list[tuple[Slot, ...]]:
    """Same-day runs of `duration` consecutive periods, avoiding breaks and blocked slots."""
    faculty = campus.faculty_by_id(session.faculty_id)
    blocked = set(campus.break_slots) | set(faculty.unavailable)
    by_day: dict[int, dict[int, Slot]] = {}
    for slot in campus.slots:
        by_day.setdefault(slot.day, {})[slot.index] = slot

    windows: list[tuple[Slot, ...]] = []
    for day in sorted(by_day):
        indexes = by_day[day]
        for start in sorted(indexes):
            run: list[Slot] = []
            for offset in range(session.duration):
                slot = indexes.get(start + offset)
                if slot is None or slot.key in blocked:
                    run = []
                    break
                run.append(slot)
            if len(run) == session.duration:
                windows.append(tuple(run))
    return windows


def eligible_rooms(campus: Campus, session: Session) -> list[Room]:
    batch = campus.batch_by_id(session.batch_id)
    faculty = campus.faculty_by_id(session.faculty_id)
    wanted = RoomKind.LABORATORY if session.is_lab else RoomKind.CLASSROOM
    if not faculty.can_teach(session.subject_id):
        return []
    rooms = []
    for room in campus.rooms:
        if room.kind is not wanted or room.capacity < batch.size:
            continue
        owned = not session.department or not room.department or room.department == session.department
        if not owned and not room.borrowable:
            continue
        rooms.append(room)
    return rooms


def _infeasible(message: str) -> GenerationResult:
    return GenerationResult(status=GenerationStatus.INFEASIBLE, message=message)


def _window_starts(campus: Campus, duration: int, blocked: set[SlotKey]) -> dict[int, tuple[set[int], list[int]]]:
    """Per day: the usable period indexes, and the starts of `duration` consecutive usable periods."""
    by_day: dict[int, set[int]] = {}
    for slot in campus.slots:
        if slot.key not in blocked:
            by_day.setdefault(slot.day, set()).add(slot.index)
    return {
        day: (
            indexes,
            [start for start in sorted(indexes) if all(start + offset in indexes for offset in range(duration))],
        )
        for day, indexes in sorted(by_day.items())
    }


def _disjoint_window_capacity(campus: Campus, duration: int, blocked: set[SlotKey]) -> int:
    """Most sessions of `duration` periods one room can host — the classic tight-resource bound.

    Greedy earliest-start is optimal here because every candidate window has the same length,
    so it doubles as the earliest-finish schedule.
    """
    total = 0
    for indexes, starts in _window_starts(campus, duration, blocked).values():
        taken: set[int] = set()
        for start in starts:
            run = {start + offset for offset in range(duration)}
            if run <= indexes and not run & taken:
                taken |= run
                total += 1
    return total


def _pools(campus: Campus, kind: RoomKind) -> list[Room]:
    return [room for room in campus.rooms if room.kind is kind]


def _blocked_for(campus: Campus, room: Room) -> set[SlotKey]:
    return set(campus.break_slots) | set(room.closed)


def _aggregate_infeasibility(campus: Campus, sessions: list[Session]) -> str | None:
    """Necessary conditions the committee can act on: not enough periods, rooms, faculty or batch time."""
    counts = {kind: len([s for s in sessions if s.is_lab is (kind is RoomKind.LABORATORY)]) for kind in RoomKind}
    needs = {kind: sum(s.duration for s in sessions if s.is_lab is (kind is RoomKind.LABORATORY)) for kind in RoomKind}

    for kind in RoomKind:
        rooms = _pools(campus, kind)
        if not rooms or not needs[kind]:
            continue
        durations = {s.duration for s in sessions if s.is_lab is (kind is RoomKind.LABORATORY)}
        if len(durations) == 1:
            duration = durations.pop()
            capacity = sum(_disjoint_window_capacity(campus, duration, _blocked_for(campus, room)) for room in rooms)
            if counts[kind] > capacity:
                label = "laboratory blocks" if kind is RoomKind.LABORATORY else "lectures"
                return (
                    f"{counts[kind]} {label} of {duration} consecutive period(s) are required, but the "
                    f"{len(rooms)} suitable {kind.value}(s) fit at most {capacity}. "
                    f"Add {kind.value} capacity, shorten the block, or reduce required hours."
                )
        else:
            capacity = sum(
                len([slot for slot in campus.slots if slot.key not in _blocked_for(campus, room)]) for room in rooms
            )
            if needs[kind] > capacity:
                return (
                    f"{needs[kind]} {kind.value} periods are required but the {len(rooms)} suitable "
                    f"{kind.value}(s) offer {capacity}. Add rooms, or move a block earlier or later."
                )

    usable = [slot for slot in campus.slots if slot.key not in set(campus.break_slots)]

    # Sessions that can use exactly the same rooms compete for exactly that pool, which is how a
    # locked department starves its neighbours even when the campus as a whole looks roomy.
    by_pool: dict[tuple[bool, tuple[str, ...]], list[Session]] = {}
    for session in sessions:
        signature = tuple(sorted(room.id for room in eligible_rooms(campus, session)))
        if signature:
            by_pool.setdefault((session.is_lab, signature), []).append(session)
    for (is_lab, signature), group in by_pool.items():
        if len(group) < 2:
            continue
        needed = sum(session.duration for session in group)
        available = sum(
            len([slot for slot in usable if slot.key not in set(campus.room_by_id(room_id).closed)])
            for room_id in signature
        )
        if needed > available:
            kind = "laboratory" if is_lab else "classroom"
            names = ", ".join(campus.room_by_id(room_id).name for room_id in signature)
            return (
                f"{len(group)} {kind} sessions need {needed} periods but the only rooms they are "
                f"allowed to use ({names}) offer {available}. Open more rooms for borrowing, or "
                f"reduce required hours."
            )

    loads: dict[str, int] = {}
    for session in sessions:
        loads[session.faculty_id] = loads.get(session.faculty_id, 0) + session.duration
        loads[f"batch:{session.batch_id}"] = loads.get(f"batch:{session.batch_id}", 0) + session.duration
    for key, periods in loads.items():
        if key.startswith("batch:"):
            batch = campus.batch_by_id(key.split(":", 1)[1])
            room = len(usable)
            who = f"batch {batch.name}"
            limit = f"{room} timetabled periods"
        else:
            faculty = campus.faculty_by_id(key)
            room = len([slot for slot in usable if slot.key not in set(faculty.unavailable)])
            who = faculty.name
            limit = f"{room} periods they are available for"
        if periods > room:
            return f"{who} needs {periods} periods but only has {limit}. Reduce the load or widen availability."
        if not key.startswith("batch:") and periods > faculty.max_weekly_hours:
            return (
                f"{faculty.name} is assigned {periods} hours but their maximum weekly load is "
                f"{faculty.max_weekly_hours}. Fix the workload distribution before generating."
            )
    return None


def preflight(campus: Campus, sessions: list[Session]) -> str | None:
    """Name the reason an impossible campus is impossible, instead of a bare INFEASIBLE."""
    for session in sessions:
        batch = campus.batch_by_id(session.batch_id)
        subject = campus.subject_by_id(session.subject_id)
        kind = "laboratory" if session.is_lab else "classroom"
        of_kind = _pools(campus, RoomKind.LABORATORY if session.is_lab else RoomKind.CLASSROOM)
        if not of_kind:
            return f"No {kind} room exists on campus, but {batch.name} needs {session.duration} {kind} period(s) for {subject.name}."
        if not any(r.capacity >= batch.size for r in of_kind):
            return (
                f"No {kind} room has sufficient capacity for batch {batch.name} "
                f"({batch.size} students); largest available is {max((r.capacity for r in of_kind), default=0)}."
            )
        if not eligible_rooms(campus, session):
            return (
                f"No eligible {kind} room for {batch.name} / {subject.name} — every candidate is "
                f"owned by another department and marked non-borrowable."
            )
        if not allowed_windows(campus, session):
            faculty = campus.faculty_by_id(session.faculty_id)
            return (
                f"No usable slot window for {faculty.name} teaching {subject.name} "
                f"({session.duration} consecutive period(s)) — check breaks, availability and period layout."
            )
    return _aggregate_infeasibility(campus, sessions)


class _ModelInfeasible(Exception):
    """A committee pin cannot be honoured — known while building, before any solving."""


def _reified_and(model: cp_model.CpModel, name: str, literals: list) -> object:
    """A variable that is true exactly when every literal is true.

    Both directions matter: an only-if-one-way penalty is free, and the solver reports a cost of
    zero for a timetable full of back-to-back lectures.
    """
    flag = model.NewBoolVar(name)
    model.AddBoolAnd(literals).OnlyEnforceIf(flag)
    model.AddBoolOr([lit.Not() for lit in literals]).OnlyEnforceIf(flag.Not())
    return flag


class _ClockModel:
    """When every session runs. Rooms are deliberately absent; capacity appears here only as cuts."""

    def __init__(self, campus: Campus, sessions: list[Session], fixed: list[dict] | None) -> None:
        self.campus = campus
        self.sessions = sessions
        self.model = cp_model.CpModel()
        self.windows = {s.id: allowed_windows(campus, s) for s in sessions}
        self.start_var: dict[str, list] = {}
        self.occ: dict[tuple[str, SlotKey], object] = {}
        self.reachable: dict[str, set[SlotKey]] = {}
        self.rank: dict[str, object] = {}
        self.cost: list = []

        self._build_placements()
        self._break_symmetry()
        self._build_hard_rules(campus, sessions, fixed)
        self._build_resource_bounds(campus, sessions)
        self._build_soft_costs(campus, sessions)

    def _build_placements(self) -> None:
        campus, model = self.campus, self.model
        slot_order = {slot.key: position for position, slot in enumerate(sorted(campus.slots, key=lambda s: s.key))}
        horizon = max(slot_order.values()) if slot_order else 0

        for session in self.sessions:
            windows = self.windows[session.id]
            ys = [model.NewBoolVar(f"start_{session.id}_{i}") for i in range(len(windows))]
            model.AddExactlyOne(ys)
            self.start_var[session.id] = ys

            covered: dict[SlotKey, list] = {}
            for position, window in enumerate(windows):
                for slot in window:
                    covered.setdefault(slot.key, []).append(ys[position])
            self.reachable[session.id] = set(covered)

            for key, terms in covered.items():
                day, index = key
                cell = model.NewBoolVar(f"occ_{session.id}_{day}_{index}")
                model.Add(cell == sum(terms))
                self.occ[(session.id, key)] = cell

            rank = model.NewIntVar(0, horizon, f"order_{session.id}")
            model.Add(rank == sum(slot_order[window[0].key] * ys[i] for i, window in enumerate(windows)))
            self.rank[session.id] = rank

    def _break_symmetry(self) -> None:
        """Repeated sessions of one requirement are interchangeable, so fix their order."""
        twins: dict[tuple, list[Session]] = {}
        for session in self.sessions:
            twins.setdefault((session.batch_id, session.subject_id, session.is_lab), []).append(session)
        for group in twins.values():
            for earlier, later in zip(group, group[1:]):
                self.model.Add(self.rank[later.id] > self.rank[earlier.id])

    def _build_hard_rules(self, campus: Campus, sessions: list[Session], fixed: list[dict] | None) -> None:
        model, occ, reachable = self.model, self.occ, self.reachable

        # No faculty or batch may be in two places in the same period.
        for attr in ("faculty_id", "batch_id"):
            groups: dict[str, list[Session]] = {}
            for session in sessions:
                groups.setdefault(getattr(session, attr), []).append(session)
            for group in groups.values():
                for slot in campus.slots:
                    cells = [occ[(s.id, slot.key)] for s in group if slot.key in reachable[s.id]]
                    if len(cells) > 1:
                        model.Add(sum(cells) <= 1)

        # Committee-pinned sessions stay put.
        for spec in fixed or []:
            target = (int(spec["day"]), int(spec["index"]))
            selected = [
                s
                for s in sessions
                if s.batch_id == spec["batch_id"]
                and s.subject_id == spec["subject_id"]
                and (spec.get("is_lab") is None or s.is_lab == bool(spec["is_lab"]))
            ]
            pins = [
                self.start_var[s.id][position]
                for s in selected
                for position, window in enumerate(self.windows[s.id])
                if window[0].key == target
            ]
            if not pins:
                raise _ModelInfeasible(
                    f"Fixed session {spec} cannot be honoured — that period is blocked by availability "
                    f"or a break, or has no eligible room."
                )
            model.Add(sum(pins) >= 1)

    def _build_resource_bounds(self, campus: Campus, sessions: list[Session]) -> None:
        """Hall-style cuts: sessions sharing a room pool cannot outnumber it in any period.

        Without them the clock happily packs twelve batches into four classrooms and only
        discovers the impossibility once the rooms are handed out.
        """
        pools: dict[tuple[RoomKind, tuple[str, ...]], list[Session]] = {}
        for session in sessions:
            kind = RoomKind.LABORATORY if session.is_lab else RoomKind.CLASSROOM
            signature = tuple(sorted(room.id for room in eligible_rooms(campus, session)))
            pools.setdefault((kind, signature), []).append(session)
        for (_, pool_ids), group in pools.items():
            self._bound(group, set(pool_ids))
        for kind in RoomKind:
            group = [s for s in sessions if s.is_lab is (kind is RoomKind.LABORATORY)]
            self._bound(group, {room.id for room in _pools(campus, kind)})

    def _bound(self, group: list[Session], pool: set[str]) -> None:
        if len(group) < 2 or not pool:
            return
        closed = {room.id: set(room.closed) for room in self.campus.rooms if room.id in pool}
        for slot in self.campus.slots:
            free = len([room_id for room_id in pool if slot.key not in closed[room_id]])
            cells = [self.occ[(s.id, slot.key)] for s in group if slot.key in self.reachable[s.id]]
            if len(cells) > free:
                self.model.Add(sum(cells) <= free)

    def _build_soft_costs(self, campus: Campus, sessions: list[Session]) -> None:
        model = self.model
        busy: dict[tuple[str, str, SlotKey], object] = {}
        for attr in ("faculty_id", "batch_id"):
            owners = {getattr(s, attr) for s in sessions}
            for owner in owners:
                group = [s for s in sessions if getattr(s, attr) == owner]
                for slot in campus.slots:
                    cells = [self.occ[(s.id, slot.key)] for s in group if slot.key in self.reachable[s.id]]
                    if not cells:
                        continue
                    cell = model.NewBoolVar(f"busy_{attr}_{owner}_{slot.day}_{slot.index}")
                    model.Add(cell == sum(cells))
                    busy[(attr, owner, slot.key)] = cell

        by_day: dict[int, dict[int, Slot]] = {}
        for slot in campus.slots:
            by_day.setdefault(slot.day, {})[slot.index] = slot

        for faculty in campus.faculty:
            for day, indexes in by_day.items():
                for j in sorted(indexes):
                    if (j + 1) not in indexes:
                        continue
                    first = busy.get(("faculty_id", faculty.id, (day, j)))
                    second = busy.get(("faculty_id", faculty.id, (day, j + 1)))
                    if first is None or second is None:
                        continue
                    penalty = _reified_and(model, f"consec_{faculty.id}_{day}_{j}", [first, second])
                    self.cost.append(CONSECUTIVE_LECTURE_PENALTY * penalty)

        for batch in campus.batches:
            for day, indexes in by_day.items():
                for j in sorted(indexes):
                    if (j + 1) not in indexes or (j + 2) not in indexes:
                        continue
                    before = busy.get(("batch_id", batch.id, (day, j)))
                    after = busy.get(("batch_id", batch.id, (day, j + 2)))
                    if before is None or after is None:
                        continue
                    # A period the batch can never occupy counts as idle, so it has no literal of
                    # its own in the conjunction — the gap is between the two sessions either way.
                    middle = busy.get(("batch_id", batch.id, (day, j + 1)))
                    literals = [before, after] if middle is None else [before, after, middle.Not()]
                    penalty = _reified_and(model, f"gap_{batch.id}_{day}_{j}", literals)
                    self.cost.append(STUDENT_GAP_PENALTY * penalty)

    def placements(self, solver: cp_model.CpSolver) -> list[Placement]:
        out = []
        for session in self.sessions:
            ys = self.start_var[session.id]
            position = next(i for i, v in enumerate(ys) if solver.Value(v))
            out.append(Placement(session, position, self.windows[session.id][position]))
        return out

    def forbid(self, placements: list[Placement]) -> None:
        """Reject this exact set of times so the next solve must find a housing-able one."""
        terms = [self.start_var[p.session.id][p.position] for p in placements]
        self.model.Add(sum(terms) <= len(terms) - 1)


def _solve(
    model: cp_model.CpModel, time_limit: float, random_seed: int, num_workers: int
) -> tuple[cp_model.CpSolver, int]:
    solver = cp_model.CpSolver()
    solver.parameters.max_time_in_seconds = float(time_limit)
    solver.parameters.random_seed = int(random_seed)
    solver.parameters.num_search_workers = max(1, int(num_workers))
    status = solver.Solve(model)
    return solver, status


def _assign_rooms(campus: Campus, placements: list[Placement], time_limit: float,
                  random_seed: int, num_workers: int) -> list[Assignment] | None:
    """House a fixed set of times in rooms. Exact, small, and cheap because time is no longer a variable."""
    model = cp_model.CpModel()
    choice: dict[str, dict[str, object]] = {}
    by_period: dict[SlotKey, list[Session]] = {}

    for placement in placements:
        session = placement.session
        usable = [
            room
            for room in eligible_rooms(campus, session)
            if all(key not in set(room.closed) for key in placement.periods)
        ]
        if not usable:
            return None
        vars = {room.id: model.NewBoolVar(f"room_{session.id}_{room.id}") for room in usable}
        model.AddExactlyOne(list(vars.values()))
        choice[session.id] = vars
        for key in placement.periods:
            by_period.setdefault(key, []).append(session)

    for group in by_period.values():
        for room in campus.rooms:
            users = [choice[s.id][room.id] for s in group if room.id in choice[s.id]]
            if len(users) > 1:
                model.Add(sum(users) <= 1)

    cost = []
    for room in campus.rooms:
        users = [choice[p.session.id][room.id] for p in placements if room.id in choice[p.session.id]]
        if users:
            used = model.NewBoolVar(f"used_{room.id}")
            model.AddMaxEquality(used, users)
            cost.append(ROOM_SPRAWL_PENALTY * used)
    if any(p.session.department for p in placements):
        for placement in placements:
            session = placement.session
            for room in campus.rooms:
                if room.id not in choice[session.id] or room.department == session.department:
                    continue
                cost.append(CROSS_DEPARTMENT_PENALTY * choice[session.id][room.id])
    if cost:
        model.Minimize(sum(cost))

    solver, status = _solve(model, time_limit, random_seed, num_workers)
    if status not in (cp_model.OPTIMAL, cp_model.FEASIBLE):
        return None

    assignments = []
    for placement in placements:
        session = placement.session
        room_id = next(rid for rid, var in choice[session.id].items() if solver.Value(var))
        room = campus.room_by_id(room_id)
        assignments.append(
            Assignment(
                session_id=session.id,
                batch_id=session.batch_id,
                subject_id=session.subject_id,
                faculty_id=session.faculty_id,
                room_id=room.id,
                slot=placement.window[0],
                is_lab=session.is_lab,
                room_kind=room.kind,
                department=session.department,
            )
        )
    assignments.sort(key=lambda a: (a.day, a.index, a.batch_id))
    return assignments


def generate_timetable(
    campus: Campus,
    fixed: list[dict] | None = None,
    random_seed: int = 1,
    time_limit_seconds: float = 30.0,
    num_workers: int = 4,
) -> GenerationResult:
    started = time.perf_counter()
    sessions = build_sessions(campus)
    if not sessions:
        return _infeasible("No teaching requirements were supplied.")

    reason = preflight(campus, sessions)
    if reason:
        return _infeasible(reason)

    try:
        clock = _ClockModel(campus, sessions, fixed)
    except _ModelInfeasible as exc:
        return _infeasible(str(exc))

    if clock.cost:
        clock.model.Minimize(sum(clock.cost))

    room_budget = max(0.5, min(5.0, float(time_limit_seconds) / 6))
    for attempt in range(MAX_ROOM_RETRIES + 1):
        remaining = max(0.5, float(time_limit_seconds) - (time.perf_counter() - started))
        solver, status = _solve(clock.model, remaining, random_seed + attempt, num_workers)
        name = solver.StatusName(status)

        if status == cp_model.INFEASIBLE:
            return GenerationResult(
                status=GenerationStatus.INFEASIBLE,
                solver_status=name,
                message="No timetable satisfies the hard constraints. Release a fixed session, add a "
                "room, or reduce required hours.",
                wall_time_ms=int((time.perf_counter() - started) * 1000),
            )
        if status not in (cp_model.OPTIMAL, cp_model.FEASIBLE):
            return GenerationResult(
                status=GenerationStatus.ERROR,
                solver_status=name,
                message=f"Solver returned {name} without a usable timetable.",
                wall_time_ms=int((time.perf_counter() - started) * 1000),
            )

        placements = clock.placements(solver)
        assignments = _assign_rooms(campus, placements, room_budget, random_seed + attempt, num_workers)
        if assignments is not None:
            elapsed = int((time.perf_counter() - started) * 1000)
            return GenerationResult(
                status=GenerationStatus.SOLVED,
                assignments=assignments,
                solver_status=name,
                soft_cost=int(solver.ObjectiveValue()),
                message=f"{len(assignments)} sessions scheduled ({name}) in {elapsed} ms",
                wall_time_ms=elapsed,
            )
        clock.forbid(placements)

    return GenerationResult(
        status=GenerationStatus.INFEASIBLE,
        message="The periods needed exist but the rooms cannot house them: every candidate timetable "
        "tried left a period without a free, suitable room. Open more rooms for borrowing, or reduce "
        "how many batches run at once.",
        wall_time_ms=int((time.perf_counter() - started) * 1000),
    )
