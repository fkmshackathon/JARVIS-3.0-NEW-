# SYNCHRO / Project Chronos

SYNCHRO is a mobile-first smart-campus timetable generator. The active product
flow is local-first and deterministic: coordinators review college setup,
faculty loads, batches, subjects, rooms, and teaching requirements; generate a
schedule; inspect hard conflicts, soft warnings, and unassigned sessions; then
edit, revalidate, and save a local draft. The first screen is a demo-only
sign-in/create-account gate: any valid email and non-empty password are accepted
in memory, and the password is never persisted. No backend is required.
The existing FastAPI solver and API client remain in the repository as a
preserved compatibility boundary and regression surface, but the active UI does
not call them.

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

### Local generator flow

The app opens with four primary areas:

1. **Overview** — institution/semester summary, setup progress, collection
   counts, honest timetable state, and local sign-out.
2. **Setup** — working days, a mandatory break, editable batches, subjects,
   faculty, rooms/labs, term rhythm, preferences, and teaching requirements.
3. **Generate & Timetable** — a real pre-generation hand-off followed by the
   generated day/week timetable and class editor.
4. **Issues** — hard conflicts, soft warnings, unassigned sessions, and setup
   problems detected in the current result.

After the demo access screen, the bundled sample data is labelled
`DEMO SAMPLE · LOCAL DRAFT ONLY`. Sign out clears only the in-memory profile;
the local timetable draft remains available after signing back in. The local
generator expands configured teaching requirements and uses bounded,
deterministic placement with hard checks for faculty, room, batch, break,
capacity, room type, closure, and absence constraints. It scores soft
preferences such as back-to-back teaching, room sharing, and workload balance.
If resources are insufficient, it returns a partial/infeasible result with the
affected requirements and an explanation instead of claiming success.

After generation, coordinators can edit, move, reassign, delete, or save a
class; handle a faculty absence with a proxy or room closure; and revalidate the
same local timetable. Browser/device persistence is provided by
`shared_preferences` and is local-only. A generated timetable is never shown
before the Generate action.

## Test and quality checks

The single offline test command is:

```bash
make test
```

It runs the Flutter generator, controller, widget/API tests and the preserved
backend API, solver, and validator tests. Individual checks are also available:

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

The active frontend exposes local setup, deterministic timetable generation,
local conflict checks, workload, room availability, and reviewable
absence/proxy/swap drafts. It does not expose real authentication, role
authorization, server validation, publishing, or external synchronization. The
local generator is intentionally a bounded hackathon-scale search, not a claim
of university-scale optimization. The backend and API client listed below are
preserved for compatibility and regression testing, not used by the current
product flow.

The scheduling implementation is deliberately protected in:

- `backend/app/solver.py`
- `backend/app/validator.py`
- `backend/app/analysis.py`
- `backend/app/store.py`
- `backend/app/main.py`
- `lib/data/synchro_api.dart`
- `lib/data/models.dart`
- `lib/state/scheduling_controller.dart`
