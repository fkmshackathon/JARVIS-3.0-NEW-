"""SQLite persistence for campuses and every generation the committee ran.

Kept deliberately small — one connection per call, two tables — because a hackathon demo needs
to be resettable by deleting a file, not by running a migration framework. The runs table is the
audit trail: FEATURE 12 asks for timetable history, and history is only trustworthy if it is
written by the server rather than reported by the client.
"""

from __future__ import annotations

import json
import sqlite3
from datetime import datetime, timezone
from pathlib import Path

_SCHEMA = """
CREATE TABLE IF NOT EXISTS campuses (
    id         TEXT PRIMARY KEY,
    name       TEXT NOT NULL,
    payload    TEXT NOT NULL,
    updated_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS runs (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    campus_id     TEXT NOT NULL REFERENCES campuses(id) ON DELETE CASCADE,
    created_at    TEXT NOT NULL,
    status        TEXT NOT NULL,
    solver_status TEXT,
    soft_cost     INTEGER,
    wall_time_ms  INTEGER,
    message       TEXT NOT NULL,
    assignments   TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS runs_campus_idx ON runs(campus_id, id DESC);
"""


def _now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


class CampusStore:
    def __init__(self, path: str | Path) -> None:
        self.path = Path(path)
        self.path.parent.mkdir(parents=True, exist_ok=True)
        with self._connect() as db:
            db.executescript(_SCHEMA)

    def _connect(self) -> sqlite3.Connection:
        db = sqlite3.connect(self.path)
        db.row_factory = sqlite3.Row
        db.execute("PRAGMA foreign_keys = ON")
        return db

    def save_campus(self, campus_id: str, name: str, payload: dict) -> dict:
        with self._connect() as db:
            db.execute(
                """
                INSERT INTO campuses (id, name, payload, updated_at) VALUES (?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET name = excluded.name,
                                               payload = excluded.payload,
                                               updated_at = excluded.updated_at
                """,
                (campus_id, name, json.dumps(payload), _now()),
            )
        return self.get_campus(campus_id)

    def get_campus(self, campus_id: str) -> dict | None:
        with self._connect() as db:
            row = db.execute("SELECT * FROM campuses WHERE id = ?", (campus_id,)).fetchone()
        if row is None:
            return None
        return {
            "id": row["id"],
            "name": row["name"],
            "updated_at": row["updated_at"],
            "campus": json.loads(row["payload"]),
        }

    def list_campuses(self) -> list[dict]:
        with self._connect() as db:
            rows = db.execute(
                "SELECT id, name, updated_at, payload FROM campuses ORDER BY updated_at DESC"
            ).fetchall()
        out = []
        for row in rows:
            payload = json.loads(row["payload"])
            out.append(
                {
                    "id": row["id"],
                    "name": row["name"],
                    "updated_at": row["updated_at"],
                    "faculty_count": len(payload.get("faculty", [])),
                    "room_count": len(payload.get("rooms", [])),
                    "batch_count": len(payload.get("batches", [])),
                    "requirement_count": len(payload.get("requirements", [])),
                }
            )
        return out

    def delete_campus(self, campus_id: str) -> bool:
        with self._connect() as db:
            cursor = db.execute("DELETE FROM campuses WHERE id = ?", (campus_id,))
            db.execute("DELETE FROM runs WHERE campus_id = ?", (campus_id,))
        return cursor.rowcount > 0

    def record_run(
        self,
        campus_id: str,
        *,
        status: str,
        solver_status: str,
        soft_cost: int | None,
        wall_time_ms: int,
        message: str,
        assignments: list[dict],
    ) -> int:
        with self._connect() as db:
            cursor = db.execute(
                """
                INSERT INTO runs (campus_id, created_at, status, solver_status, soft_cost,
                                  wall_time_ms, message, assignments)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (campus_id, _now(), status, solver_status, soft_cost, wall_time_ms, message,
                 json.dumps(assignments)),
            )
        return int(cursor.lastrowid)

    def list_runs(self, campus_id: str, limit: int = 20) -> list[dict]:
        with self._connect() as db:
            rows = db.execute(
                "SELECT * FROM runs WHERE campus_id = ? ORDER BY id DESC LIMIT ?",
                (campus_id, max(1, int(limit))),
            ).fetchall()
        return [
            {
                "id": row["id"],
                "created_at": row["created_at"],
                "status": row["status"],
                "solver_status": row["solver_status"],
                "soft_cost": row["soft_cost"],
                "wall_time_ms": row["wall_time_ms"],
                "message": row["message"],
                "session_count": len(json.loads(row["assignments"])),
            }
            for row in rows
        ]

    def get_run(self, run_id: int) -> dict | None:
        with self._connect() as db:
            row = db.execute("SELECT * FROM runs WHERE id = ?", (run_id,)).fetchone()
        if row is None:
            return None
        record = dict(row)
        record["assignments"] = json.loads(record["assignments"])
        return record
