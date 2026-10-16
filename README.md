# SYNCHRO / Project Chronos

SYNCHRO is a mobile-first smart-campus timetable workspace. The current product
flow is intentionally frontend-only: coordinators place, edit, move, delete,
save, discard, and locally check clearly labelled demo classes without a
backend, account, solver, or external service. The existing FastAPI solver and
API client remain in the repository as a preserved compatibility boundary and
regression surface, but the active SYNCHRO UI does not call them.

## Runtime pins

- Flutter: `3.47.1` (stable), recorded in `.fvmrc`
- Dart: `3.13.1` SDK floor in `pubspec.yaml`, locked by `pubspec.lock`
- Python: `3.14.7`, recorded in `.python-version`
- Backend packages: pinned in `backend/requirements.txt`

## Prerequisites

- Flutter `3.47.1` with a web or Android target
- Python `3.14.7`
- `make` for the single test entrypoint on Linux/macOS/WSL
- Optional: Docker for the reproducible container image

No global project dependencies are required. Flutter packages install into the
Flutter project cache and Python packages should be installed in a local virtual
environment.

## Local setup

```bash
python -m venv .venv
. .venv/bin/activate
python -m pip install -r backend/requirements.txt
flutter pub get
```

On Windows PowerShell, activate the environment with
`.venv\\Scripts\\Activate.ps1` instead.

Copy `.env.example` to `.env` only when working on the preserved backend
boundary. The frontend-only demo does not need an API URL, credentials, or
private local configuration.

## Run the preserved backend (optional)

This is only needed for backend development and regression checks; the current
frontend does not depend on it:

```bash
. .venv/bin/activate
uvicorn app.main:app --app-dir backend --reload --host 0.0.0.0 --port 8000
```

## Run the Flutter app

From the repository root:

```bash
flutter run -d chrome
```

The web target is rendered inside a centered phone-sized shell on wide screens
and uses the available width on real phones.

### Frontend-only demo mode

The app always opens the local workspace without contacting a backend. The
manual editor uses deterministic sample data labelled
`DEMO SAMPLE · LOCAL DRAFT ONLY`; browser/device persistence is provided by
`shared_preferences` and is local-only. The draft supports:

- manual class creation, editing, moving, deletion, save/discard, and reset;
- day/week views with batch selection, free slots, and breaks;
- local teacher, room, and batch conflict detection;
- faculty workload, room availability, absences, proxy drafts, and swap drafts;
- an Issues view that separates hard conflicts from soft warnings.

This state is not institutional data. It never pretends to publish, validate on
a server, or synchronize a local draft with an account or backend.

## Test and quality checks

The single offline test command is:

```bash
make test
```

It runs the Flutter widget/API tests and the preserved backend API, solver, and
validator tests. Individual checks are also available:

```bash
flutter analyze
flutter test
python -m pytest backend/tests
```

## Build and deploy

```bash
make build-web
make build-apk
```

The Docker image builds the Flutter web client and the preserved backend without
changing the solver contract:

```bash
docker build -t synchro:local .
docker run --rm -p 8000:8000 -p 8080:8080 synchro:local
```

Open `http://localhost:8080` for the web client and `http://localhost:8000`
for the optional API health endpoint. The current frontend does not require an
API URL for its local workflow.

## Product boundaries

The active frontend exposes local timetable editing, local conflict checks,
workload, room availability, and reviewable absence/proxy/swap drafts. It does
not expose real authentication, role authorization, server validation, solver
generation, publishing, or external synchronization. The backend and API
client listed below are preserved for compatibility and regression testing,
not used by the current product flow.

The scheduling implementation is deliberately protected in:

- `backend/app/solver.py`
- `backend/app/validator.py`
- `backend/app/analysis.py`
- `backend/app/store.py`
- `backend/app/main.py`
- `lib/data/synchro_api.dart`
- `lib/data/models.dart`
- `lib/state/scheduling_controller.dart`
