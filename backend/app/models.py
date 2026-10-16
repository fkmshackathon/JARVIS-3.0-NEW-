"""Domain model for SYNCHRO campus scheduling."""

from __future__ import annotations

from dataclasses import dataclass, field
from enum import Enum


class RoomKind(str, Enum):
    CLASSROOM = "classroom"
    LABORATORY = "laboratory"


SlotKey = tuple[int, int]


@dataclass(frozen=True)
class Slot:
    """One timetabled period. Staggered entries are ordinary slots with different starts."""

    day: int
    index: int
    start: int
    end: int

    @property
    def key(self) -> SlotKey:
        return (self.day, self.index)

    @property
    def duration(self) -> int:
        return self.end - self.start


@dataclass
class Faculty:
    id: str
    name: str
    department: str = ""
    max_weekly_hours: int = 24
    unavailable: list[SlotKey] = field(default_factory=list)
    qualified_subjects: list[str] = field(default_factory=list)

    def can_teach(self, subject_id: str) -> bool:
        return not self.qualified_subjects or subject_id in self.qualified_subjects


@dataclass
class Room:
    id: str
    name: str
    kind: RoomKind
    capacity: int
    department: str = ""
    borrowable: bool = True
    closed: list[SlotKey] = field(default_factory=list)


@dataclass
class Batch:
    """A student batch — a division split into two batches uses the same division_id."""

    id: str
    name: str
    year: int
    size: int
    division_id: str = ""
    stagger_group: int = 0


@dataclass
class Subject:
    id: str
    name: str
    lecture_hours: int = 0
    lab_hours: int = 0
    lab_duration_slots: int = 1
    department: str = ""


@dataclass
class TeachingRequirement:
    batch_id: str
    subject_id: str
    faculty_id: str
    department: str = ""
    lecture_hours: int | None = None
    lab_hours: int | None = None


@dataclass
class Campus:
    slots: list[Slot]
    faculty: list[Faculty]
    rooms: list[Room]
    batches: list[Batch]
    subjects: list[Subject]
    requirements: list[TeachingRequirement] = field(default_factory=list)
    break_slots: list[SlotKey] = field(default_factory=list)

    def slot_by_key(self, key: SlotKey) -> Slot | None:
        return next((s for s in self.slots if s.key == key), None)

    def faculty_by_id(self, fid: str) -> Faculty:
        return next(f for f in self.faculty if f.id == fid)

    def room_by_id(self, rid: str) -> Room:
        return next(r for r in self.rooms if r.id == rid)

    def batch_by_id(self, bid: str) -> Batch:
        return next(b for b in self.batches if b.id == bid)

    def subject_by_id(self, sid: str) -> Subject:
        return next(s for s in self.subjects if s.id == sid)


@dataclass(frozen=True)
class Session:
    """One instance that must be placed: a single lecture period or one lab block."""

    id: str
    batch_id: str
    subject_id: str
    faculty_id: str
    department: str
    is_lab: bool
    duration: int


@dataclass(frozen=True)
class Assignment:
    session_id: str
    batch_id: str
    subject_id: str
    faculty_id: str
    room_id: str
    slot: Slot
    is_lab: bool
    room_kind: RoomKind
    department: str

    @property
    def day(self) -> int:
        return self.slot.day

    @property
    def index(self) -> int:
        return self.slot.index
