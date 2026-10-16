"""SYNCHRO backend.

Everything that decides a timetable runs here rather than in the app: the solver, the independent
validator and the audit trail. The Flutter client renders what this API reports and cannot make a
timetable publishable by asserting so itself.

Run with:  uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
"""

from __future__ import annotations

import os
from pathlib import Path

from fastapi import Body, FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from .analysis import utilisation, workload_summary
from .models import Campus
from .sample import demo_campus
from .serialize import (
    CampusError,
    assignment_from_dict,
    assignment_to_dict,
    campus_from_payload,
    campus_to_payload,
)
from .solver import GenerationStatus, build_sessions, generate_timetable, preflight
from .store import CampusStore
from .validator import validate

BASE_DIR = Path(__file__).resolve().parent.parent
DATABASE = Path(os.environ.get("SYNCHRO_DB", BASE_DIR / "synchro.db"))
MAX_TIME_LIMIT_SECONDS = 120.0

app = FastAPI(
    title="SYNCHRO scheduling API",
    version="0.1.0",
    description="Constraint-based campus timetable generation and validation.",
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=os.environ.get("SYNCHRO_CORS_ORIGINS", "*").split(","),
    allow_methods=["*"],
    allow_headers=["*"],
)
store = CampusStore(DATABASE)


class CampusBody(BaseModel):
    name: str = Field(default="Untitled campus", max_length=120)
    campus: dict


class GenerateBody(BaseModel):
    time_limit_seconds: float = Field(default=10.0, gt=0, le=MAX_TIME_LIMIT_SECONDS)
    random_seed: int = Field(default=1, ge=1, le=10_000)
    fixed: list[dict] = Field(default_factory=list)


class ValidateBody(BaseModel):
    assignments: list[dict]


def _load(campus_id: str) -> tuple[dict, Campus]:
    record = store.get_campus(campus_id)
    if record is None:
        raise HTTPException(status_code=404, detail=f"No campus '{campus_id}'. Save it first.")
    try:
        return record, campus_from_payload(record["campus"])
    except CampusError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc


def _violations(campus: Campus, assignments) -> list[dict]:
    return [{"code": v.code, "message": v.message, "refs": list(v.refs)} for v in validate(campus, assignments)]


@app.get("/health")
def health() -> dict:
    return {"status": "ok", "database": str(DATABASE), "campuses": len(store.list_campuses())}


@app.get("/sample-campus")
def sample_campus() -> dict:
    """A full teaching campus the app can load with one tap — seed data, not a stub."""
    campus = demo_campus()
    payload = campus_to_payload(campus)
    return {"name": "SLRTCE demo semester", "campus": payload, "summary": workload_summary(campus)}


@app.put("/campuses/{campus_id}")
def put_campus(campus_id: str, body: CampusBody) -> dict:
    try:
        campus = campus_from_payload(body.campus)
    except CampusError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    record = store.save_campus(campus_id, body.name, campus_to_payload(campus))
    record["summary"] = workload_summary(campus)
    return record


@app.get("/campuses")
def get_campuses() -> dict:
    return {"campuses": store.list_campuses()}


@app.get("/campuses/{campus_id}")
def get_campus(campus_id: str) -> dict:
    record, campus = _load(campus_id)
    record["summary"] = workload_summary(campus)
    return record


@app.delete("/campuses/{campus_id}", status_code=204)
def delete_campus(campus_id: str) -> None:
    if not store.delete_campus(campus_id):
        raise HTTPException(status_code=404, detail=f"No campus '{campus_id}'.")


@app.post("/campuses/{campus_id}/preview")
def preview_campus(campus_id: str) -> dict:
    """FEATURE 1/2 gate: is the workload complete, and can these rooms hold these hours at all?"""
    _, campus = _load(campus_id)
    reason = preflight(campus, build_sessions(campus))
    return {
        "can_generate": reason is None,
        "blocker": reason,
        "summary": workload_summary(campus),
    }


@app.post("/campuses/{campus_id}/generate")
def generate(campus_id: str, body: GenerateBody) -> dict:
    _, campus = _load(campus_id)
    try:
        result = generate_timetable(
            campus,
            fixed=body.fixed,
            random_seed=body.random_seed,
            time_limit_seconds=body.time_limit_seconds,
        )
    except CampusError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc

    assignments = [assignment_to_dict(a) for a in result.assignments]
    violations = _violations(campus, result.assignments)
    run_id = store.record_run(
        campus_id,
        status=result.status.value,
        solver_status=result.solver_status,
        soft_cost=result.soft_cost,
        wall_time_ms=result.wall_time_ms,
        message=result.message,
        assignments=assignments,
    )
    payload = {
        "run_id": run_id,
        "campus_id": campus_id,
        "status": result.status.value,
        "solver_status": result.solver_status,
        "soft_cost": result.soft_cost,
        "wall_time_ms": result.wall_time_ms,
        "message": result.message,
        "assignments": assignments,
        "violations": violations,
        # The solver is never the judge of its own work: publication needs a clean validator run.
        "publishable": result.status is GenerationStatus.SOLVED and not violations,
    }
    if assignments:
        payload["utilisation"] = utilisation(campus, result.assignments)
    return payload


@app.get("/campuses/{campus_id}/runs")
def runs(campus_id: str, limit: int = Query(default=20, ge=1, le=100)) -> dict:
    _load(campus_id)
    return {"campus_id": campus_id, "runs": store.list_runs(campus_id, limit)}


@app.get("/runs/{run_id}")
def run(run_id: int) -> dict:
    record = store.get_run(run_id)
    if record is None:
        raise HTTPException(status_code=404, detail=f"No run '{run_id}'.")
    return record


@app.post("/campuses/{campus_id}/validate")
def validate_timetable(campus_id: str, body: ValidateBody = Body(...)) -> dict:
    """Re-check any timetable, including one a coordinator edited by hand."""
    _, campus = _load(campus_id)
    try:
        parsed = [assignment_from_dict(raw, campus) for raw in body.assignments]
    except (CampusError, KeyError, TypeError, ValueError) as exc:
        raise HTTPException(status_code=422, detail=f"assignment rejected: {exc}") from exc
    violations = _violations(campus, parsed)
    return {
        "campus_id": campus_id,
        "sessions": len(parsed),
        "violations": violations,
        "publishable": not violations,
        "utilisation": utilisation(campus, parsed),
    }
