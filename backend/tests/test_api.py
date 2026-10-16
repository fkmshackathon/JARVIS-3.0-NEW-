"""End-to-end API tests: the HTTP surface the Flutter app will actually call."""

import pytest
from fastapi.testclient import TestClient

from app import main as api
from app.store import CampusStore

# The demo campus is 144 sessions and takes this machine 8–13 seconds to solve. A test that
# asks for less gets an honest UNKNOWN back — which the API reports as `error` — so these
# tests budget for a real search. Solver quality itself belongs in test_solver_*.py.
SOLVE_BUDGET = 25


@pytest.fixture()
def client(tmp_path):
    api.store = CampusStore(tmp_path / "synchro-test.db")
    with TestClient(api.app) as test_client:
        yield test_client


def sample_payload(client) -> dict:
    return client.get("/sample-campus").json()


def test_health(client):
    body = client.get("/health").json()
    assert body["status"] == "ok"


def test_sample_campus_is_a_real_campus_not_a_placeholder(client):
    body = sample_payload(client)
    summary = body["summary"]
    campus = body["campus"]
    assert len(campus["batches"]) == 12
    assert len(campus["rooms"]) == 12
    assert summary["demand"]["sessions"] == 144
    assert summary["can_generate"], summary["blocker"]
    # The demo is supposed to show cross-department pressure, so it must actually have it.
    assert summary["supply"]["classrooms"] > 0 and summary["supply"]["laboratories"] > 0


def test_generated_timetable_is_validated_before_it_can_be_published(client):
    payload = sample_payload(client)
    client.put("/campuses/demo", json={"name": "Demo", "campus": payload["campus"]})
    result = client.post("/campuses/demo/generate", json={"time_limit_seconds": SOLVE_BUDGET}).json()
    assert result["status"] == "solved", result["message"]
    assert result["violations"] == []
    assert result["publishable"] is True
    assert len(result["assignments"]) == 144
    assert result["utilisation"]["rooms_on_campus"] == 12


def test_generation_is_written_to_the_audit_trail(client):
    payload = sample_payload(client)
    client.put("/campuses/audit", json={"name": "Audit", "campus": payload["campus"]})
    first = client.post("/campuses/audit/generate", json={"time_limit_seconds": SOLVE_BUDGET}).json()
    second = client.post("/campuses/audit/generate", json={"time_limit_seconds": SOLVE_BUDGET}).json()
    history = client.get("/campuses/audit/runs").json()["runs"]
    assert [run["id"] for run in history][:2] == [second["run_id"], first["run_id"]]
    assert history[0]["status"] == "solved"
    detail = client.get(f"/runs/{first['run_id']}").json()
    assert len(detail["assignments"]) == 144


def test_room_scarcity_is_reported_as_a_blocker_not_a_timeout(client):
    payload = sample_payload(client)
    payload["campus"]["rooms"] = [r for r in payload["campus"]["rooms"] if r["kind"] != "laboratory"][:2]
    client.put("/campuses/short", json={"name": "Short on labs", "campus": payload["campus"]})
    preview = client.post("/campuses/short/preview").json()
    assert preview["can_generate"] is False
    assert "laborator" in preview["blocker"]
    result = client.post("/campuses/short/generate", json={"time_limit_seconds": 20}).json()
    assert result["status"] == "infeasible"
    assert result["publishable"] is False


def test_payload_errors_name_the_rejected_field(client):
    broken = sample_payload(client)["campus"]
    broken["faculty"][0].pop("name")
    response = client.put("/campuses/bad", json={"name": "Bad", "campus": broken})
    assert response.status_code == 422
    assert "faculty[0]" in response.json()["detail"]


def test_borrowing_a_room_across_departments_is_visible_in_the_result(client):
    """The requirements' own case: IT owns no classroom, so every lecture borrows Mechanical's."""
    payload = sample_payload(client)
    for room in payload["campus"]["rooms"]:
        if room["kind"] == "classroom" and room["department"] == "IT":
            room["department"] = "MECH"
    client.put("/campuses/borrow", json={"name": "Borrow", "campus": payload["campus"]})
    result = client.post("/campuses/borrow/generate", json={"time_limit_seconds": 20}).json()
    assert result["publishable"], result["message"]
    assert result["utilisation"]["borrowed_periods"] == 108, "every lecture should be a borrowed room"


def test_non_borrowable_rooms_are_never_used(client):
    """A locked department refuses to host another's classes, and the validator proves it."""
    payload = sample_payload(client)
    for room in payload["campus"]["rooms"]:
        if room["kind"] == "classroom" and room["department"] == "IT":
            room["department"] = "MECH"
            room["borrowable"] = False
    client.put("/campuses/locked", json={"name": "Locked", "campus": payload["campus"]})
    preview = client.post("/campuses/locked/preview").json()
    assert preview["can_generate"] is False
    assert "allowed to use" in preview["blocker"]


def test_hand_edited_clash_is_rejected_by_the_validator(client):
    payload = sample_payload(client)
    client.put("/campuses/edit", json={"name": "Edit", "campus": payload["campus"]})
    generated = client.post("/campuses/edit/generate", json={"time_limit_seconds": SOLVE_BUDGET}).json()
    assignments = generated["assignments"]
    # Move the last session onto the first session's period: a coordinator's classic mistake.
    assignments[-1]["day"] = assignments[0]["day"]
    assignments[-1]["index"] = assignments[0]["index"]
    verdict = client.post("/campuses/edit/validate", json={"assignments": assignments}).json()
    assert verdict["publishable"] is False
    codes = {v["code"] for v in verdict["violations"]}
    assert {"ROOM_CLASH"} <= codes or {"BATCH_CLASH", "FACULTY_CLASH"} & codes


def test_unknown_campus_is_a_clear_404(client):
    assert client.get("/campuses/nope").status_code == 404
    assert client.post("/campuses/nope/generate", json={}).status_code == 404
