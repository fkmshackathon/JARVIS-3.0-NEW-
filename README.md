# SYNCHRO / Project Chronos

SYNCHRO is a mobile-first smart-campus timetable client with a local manual
timetable workspace plus an optional FastAPI-backed solver. The manual editor
is the primary frontend workflow: coordinators can place, edit, move, delete,
save, discard, and validate sample classes without a running backend. When the
API is available, the existing solver, independent validator, and audit trail
remain available as a separate server-result view.

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

Copy `.env.example` to `.env` for reference. The current app reads the API
override through Flutter's compile-time `SYNCHRO_API` define and reads backend
settings from process environment; never commit credentials or private local
configuration.

## Run the backend

From the repository root:

```bash
. .venv/bin/activate
uvicorn app.main:app --app-dir backend --reload --host 0.0.0.0 --port 8000
```

## Run the Flutter app

In a second terminal:

```bash
flutter run -d chrome --dart-define=SYNCHRO_API=http://localhost:8000
```

For an Android emulator, the client defaults to `http://10.0.2.2:8000`.
For a physical device, pass the host machine's LAN address:

```bash
flutter run -d <device> --dart-define=SYNCHRO_API=http://<host-lan-ip>:8000
```

The web target is rendered inside a centered phone-sized shell on wide screens
and uses the available width on real phones.

### Frontend-only demo mode

The app can be demonstrated without a backend. If the API is offline, choose
`Continue with demo mode` on the branded connection screen. The manual editor
then uses deterministic sample data labelled `DEMO SAMPLE · LOCAL DRAFT ONLY`.
The local draft supports:

- manual class creation, editing, moving, deletion, save/discard, and reset;
- day/week views with batch selection, free slots, and breaks;
- local teacher, room, and batch conflict detection;
- faculty workload, room availability, absences, proxy drafts, and swap drafts;
- an Issues view that separates hard conflicts from soft warnings.

This state is intentionally in-memory and is not institutional data. It never
pretends to publish or synchronize a local draft with the backend.

## Test and quality checks

The single offline test command is:

```bash
make test
```

It runs the Flutter widget/API tests and the backend API, solver, and validator
tests. Individual checks are also available:

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

The Docker image builds the Flutter web client and the backend without changing
the solver contract:

```bash
docker build -t synchro:local .
docker run --rm -p 8000:8000 -p 8080:8080 synchro:local
```

Open `http://localhost:8080` for the web client and `http://localhost:8000`
for the API health endpoint. Configure production signing, a non-wildcard CORS
allowlist, and an externally reachable `SYNCHRO_API` before shipping.

## Product boundaries

The current repository exposes campus loading, workload/preflight, timetable
generation, server validation, and generation history. It does not expose a
real authentication, role authorization, campus editing, alternative
refinement, or publishing endpoint. The Chrome demo therefore includes a
clearly labelled **local-only demo account**: sign-in and sign-up validate the
form and keep a profile in memory for the running session, but never store or
send passwords and never authorize backend requests. Refinement offers only the
currently supported revalidation/history flow.

The scheduling implementation is deliberately protected in:

- `backend/app/solver.py`
- `backend/app/validator.py`
- `backend/app/analysis.py`
- `backend/app/store.py`
- `backend/app/main.py`
- `lib/data/synchro_api.dart`
- `lib/data/models.dart`
- `lib/state/scheduling_controller.dart`
