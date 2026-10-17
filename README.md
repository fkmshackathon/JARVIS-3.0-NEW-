# JARVIS 3.0 / SYNCHRO — Smart Campus Timetable System

[![Android APK Download](https://img.shields.io/badge/Download-JARVIS--3.0--v1.0.0.apk-2ea44f?style=for-the-badge&logo=android&logoColor=white)](https://github.com/fkmshackathon/JARVIS-3.0-NEW-/releases/latest/download/JARVIS-3.0-v1.0.0.apk)
[![Release CI](https://img.shields.io/badge/CI-GitHub%20Actions-blue?style=for-the-badge&logo=githubactions&logoColor=white)](https://github.com/fkmshackathon/JARVIS-3.0-NEW-/actions)
[![Flutter](https://img.shields.io/badge/Flutter-3.47.1%20Stable-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.143.3-009688?style=for-the-badge&logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com)

---

## 📱 Quick Android Installation

Anyone with a compatible Android smartphone can download and install the official release build directly:

1. **Direct Download:** Tap to download **[JARVIS-3.0-v1.0.0.apk](https://github.com/fkmshackathon/JARVIS-3.0-NEW-/releases/latest/download/JARVIS-3.0-v1.0.0.apk)**.
2. **Enable Unknown Apps / Sideloading (if prompted):**
   - When opening the downloaded APK, Android may ask for permission to install apps from your browser or file manager.
   - Tap **Settings** → toggle **Allow from this source** → return and tap **Install**.
3. **Compatibility:** Requires **Android 8.0 (Oreo / API Level 26) or newer**.
4. **Offline First:** The app operates completely standalone out of the box with zero required cloud setup.

---

## 🏛️ System Overview & Architecture

JARVIS 3.0 (SYNCHRO) is an automated smart-campus timetable management system built with Flutter and Python FastAPI. It automates class schedule generation, conflict detection, room utilization, and faculty workload management.

```
┌─────────────────────────────────────────────────────────────┐
│                    JARVIS 3.0 Mobile App                   │
│         (Flutter 3.47.1 · Material 3 · Local-First)          │
└──────────────┬───────────────────────────────┬──────────────┘
               │                               │
       (Local Workflows)               (Remote Solver API)
               │                               │
               ▼                               ▼
┌──────────────────────────────┐ ┌──────────────────────────────┐
│  Local Deterministic Engine  │ │     FastAPI / OR-Tools       │
│  - SharedPreferences Library │ │  - CP-SAT Constraint Engine  │
│  - Multi-Timetable Drafts    │ │  - Campus Store (SQLite)     │
│  - Conflict & Load Check     │ │  - Audited JSON API          │
└──────────────────────────────┘ └──────────────────────────────┘
```

### Key Capabilities
- **Overview Dashboard:** Institutional summary, academic calendar rhythm, readiness metrics, and timetable library switcher.
- **Academic Setup:** Configure working days, mandatory break intervals, classrooms/laboratories, departments, faculty rosters, student batches, and teaching requirements.
- **Deterministic Solver & Timetable Grid:** Interactive day/week timetable matrix with live class inspection, conflict highlighting, and unassigned period accounting.
- **Timetable Library:** Manage multiple persistent academic schedules (duplicate, rename, delete, switch) stored locally via `shared_preferences`.
- **Issues & Audit:** Dedicated conflict detection reporting hard constraints (faculty clashes, room double-bookings, capacity violations) and soft balance warnings.
- **FastAPI / OR-Tools Backend (Preserved Boundary):** Industrial-grade CP-SAT constraint satisfaction engine for server-side solving, validation, and historical run inspection.

---

## ⚙️ Environment Configuration

Copy `.env.example` to configure local or deployment environments:

```bash
cp .env.example .env
```

| Variable | Description | Default | Target |
|---|---|---|---|
| `SYNCHRO_API` | HTTPS URL of deployed FastAPI backend | `https://jarvis-synchro-backend.up.railway.app` | Flutter Build / Client |
| `PORT` | Listening port for FastAPI server | `8000` | Backend |
| `HOST` | Binding address for FastAPI server | `0.0.0.0` | Backend |
| `SYNCHRO_DB` | SQLite database file location | `synchro.db` | Backend |
| `SYNCHRO_CORS_ORIGINS`| Allowed CORS origins (comma-separated or `*`) | `*` | Backend |

---

## 💻 Local Development Guide

### Prerequisites
- Flutter SDK `3.47.1` (or current stable)
- Python `3.12` or `3.14`
- Git

### 1. Backend Setup (FastAPI)
```bash
# Create and activate virtual environment
python -m venv .venv
# Linux / macOS:
source .venv/bin/activate
# Windows PowerShell:
.venv\Scripts\Activate.ps1

# Install dependencies
python -m pip install -r backend/requirements.txt

# Run the backend locally
uvicorn app.main:app --app-dir backend --reload --host 0.0.0.0 --port 8000
```
Verify the backend at:
- Health check: `http://localhost:8000/health`
- Interactive Swagger docs: `http://localhost:8000/docs`
- Sample campus payload: `http://localhost:8000/sample-campus`

### 2. Frontend Setup (Flutter)
```bash
# Get dependencies
flutter pub get

# Run on Android device or emulator
flutter run

# Run on Chrome for web development
flutter run -d chrome
```

---

## 🧪 Testing and Quality Assurance

Run the comprehensive test suites across both the Flutter client and the Python solver backend:

```bash
# 1. Run Flutter static analysis
flutter analyze

# 2. Run all Flutter unit & widget tests (51 tests)
flutter test

# 3. Run all Python backend tests (47 tests)
pytest backend
```

---

## 🚀 Backend Production Deployment Guide

The backend can be deployed in minutes on any container platform or cloud provider.

### Option A: Railway / Render (One-Click Docker)
1. Fork or push this repository to GitHub.
2. In **Render** or **Railway**, create a **New Web Service** connected to your repository.
3. Configure:
   - **Environment:** Docker
   - **Dockerfile Path:** `./Dockerfile`
   - **Port:** `8000`
   - **Healthcheck Path:** `/health`
4. Deploy the service. Your backend will be accessible at `https://your-app.onrender.com`.

### Option B: Docker CLI / VPS
```bash
# Build the production container image
docker build -t jarvis-synchro:latest .

# Run the container
docker run -d \
  -p 8000:8000 \
  -p 8080:8080 \
  -e SYNCHRO_CORS_ORIGINS="*" \
  --name jarvis-synchro \
  jarvis-synchro:latest
```

---

## 📦 Building the Android Release APK Locally

To build a production release APK on your workstation:

```bash
flutter build apk --release --dart-define=SYNCHRO_API=https://your-backend-domain.com
```

The compiled APK will be located at:
`build/app/outputs/flutter-apk/app-release.apk`

---

## 🔄 Automated CI/CD & GitHub Actions

The repository includes a GitHub Actions release pipeline (`.github/workflows/release.yml`) that:
1. Runs Python backend test suite on `ubuntu-latest`.
2. Verifies Flutter code formatting and static analysis (`flutter analyze`).
3. Executes all Flutter unit and widget tests (`flutter test`).
4. Compiles the Android release APK with production Dart defines.
5. Computes SHA-256 checksums and publishes the release asset as `JARVIS-3.0-v1.0.0.apk` to GitHub Releases.
