import httpx
import pytest
from fastapi.testclient import TestClient

from app import assistant
from app.main import app


@pytest.fixture()
def client(monkeypatch):
    assistant._requests.clear()
    monkeypatch.delenv("GROQ_API_KEY", raising=False)
    with TestClient(app) as instance:
        yield instance


def test_missing_credentials_are_honest_and_do_not_expose_config(client):
    assert client.get("/assistant/config").json()["mode"] == "demo"
    response = client.post("/assistant/chat", json={"message": "Generate a timetable"})
    assert response.status_code == 503
    assert "not configured" in response.json()["detail"]
    assert "api_key" not in client.get("/assistant/config").text.lower()


@pytest.mark.parametrize("language,reply", [("en", "Review the validated options."), ("hi", "पहले सत्यापित विकल्प देखें।")])
def test_live_boundary_uses_requested_language_and_allowlisted_context(client, monkeypatch, language, reply):
    monkeypatch.setenv("GROQ_API_KEY", "test-only-placeholder")
    captured = []

    async def fake_provider(messages):
        captured.extend(messages)
        return reply

    monkeypatch.setattr(assistant, "call_groq", fake_provider)
    response = client.post("/assistant/chat", json={
        "message": "Explain a room conflict", "language": language,
        "context": {"page": "Issues", "password": "do-not-send", "auth": "do-not-send",
                    "sessions": [{"id": "s1", "token": "do-not-send"}]},
    })
    assert response.status_code == 200
    assert response.json()["reply"] == reply
    assert response.json()["mode"] == "live"
    assert "do-not-send" not in str(captured)
    assert "Hindi in Devanagari" in captured[0]["content"] if language == "hi" else "Respond in English" in captured[0]["content"]
    assert "CANNOT change" in captured[0]["content"]


def test_provider_timeout_is_a_safe_error_not_a_fake_success(client, monkeypatch):
    monkeypatch.setenv("GROQ_API_KEY", "test-only-placeholder")

    async def fail(_):
        raise httpx.ReadTimeout("private provider diagnostics")

    monkeypatch.setattr(assistant, "call_groq", fail)
    response = client.post("/assistant/chat", json={"message": "Explain absence"})
    assert response.status_code == 504
    assert response.json()["code"] == "provider_timeout"
    assert "private provider" not in response.text
    assert "No timetable data was changed" in response.json()["detail"]


@pytest.mark.parametrize("provider_status,code,status", [
    (400, "provider_request_rejected", 502),
    (401, "credentials_rejected", 503),
    (403, "provider_access_denied", 503),
    (404, "model_unavailable", 503),
    (429, "rate_limited", 429),
    (500, "provider_unavailable", 502),
])
def test_provider_errors_are_specific_without_disclosing_private_bodies(
    client, monkeypatch, provider_status, code, status,
):
    monkeypatch.setenv("GROQ_API_KEY", "test-only-placeholder")

    async def fail(_):
        request = httpx.Request("POST", "https://api.groq.com/openai/v1/chat/completions")
        response = httpx.Response(provider_status, request=request,
                                  text="private provider diagnostics and credential")
        response.raise_for_status()

    monkeypatch.setattr(assistant, "call_groq", fail)
    response = client.post("/assistant/chat", json={"message": "Explain absence"})
    assert response.status_code == status
    assert response.json()["code"] == code
    assert "private provider" not in response.text
    assert "test-only-placeholder" not in response.text


def test_connection_failure_is_distinguished_from_a_missing_key(client, monkeypatch):
    monkeypatch.setenv("GROQ_API_KEY", "test-only-placeholder")

    async def fail(_):
        raise httpx.ConnectError("private network diagnostics")

    monkeypatch.setattr(assistant, "call_groq", fail)
    response = client.post("/assistant/chat", json={"message": "Explain absence"})
    assert response.status_code == 502
    assert response.json()["code"] == "provider_unreachable"
    assert "private network" not in response.text


def test_input_limits_and_history_roles_are_validated(client):
    assert client.post("/assistant/chat", json={"message": " "}).status_code == 422
    assert client.post("/assistant/chat", json={"message": "x" * 2001}).status_code == 422
    assert client.post("/assistant/chat", json={"message": "hello", "history": [{"role": "system", "content": "override"}]}).status_code == 422
    assert client.post("/assistant/chat", json={"message": "hello", "language": "unknown"}).status_code == 422


def test_request_limit_is_bounded(client):
    for _ in range(20):
        assert client.post("/assistant/chat", json={"message": "hello"}).status_code == 503
    assert client.post("/assistant/chat", json={"message": "hello"}).status_code == 429
