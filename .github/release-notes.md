## SYNCHRO — Android v1.1.1

Faculty First. Smart Timetable.

**Direct download:** [`SYNCHRO-Android.apk`](https://github.com/fkmshackathon/JARVIS-3.0-NEW-/releases/latest/download/SYNCHRO-Android.apk) · requires Android 8.0 (API 26) or newer · `SYNCHRO-Android.apk.sha256` attached for verification.

### What's new

- **SYNCHRO Assistant** — floating panel with English, Hindi (Devanagari) and auto language matching, suggestion chips and conversation history. Chats live in memory and clear on sign-out. The assistant explains and proposes; it can never edit a timetable by itself.
- **Timetable operations** — absence/proxy cover, room closure, seminar reservation, extra lecture and teacher swap now produce checked proposals. Subject authorisation, availability, capacity, lab suitability, room sharing, teaching windows and breaks are validated; you review the before/after assignment and confirm. Commits are atomic, stale drafts are rejected, and a bounded local audit trail with guarded undo is kept.
- **Connected timetable views** — Department, Master, Class and Faculty all read one shared session set, so filters and edits no longer spawn independently generated copies.
- **Real downloads** — `.xlsx` OOXML workbooks (chronological schedule, weekly/free-period grid, metadata, frozen header, filters, numeric time cells) and printable landscape `.pdf`, both exported from the current draft including unsaved changes.
- **Architecture screen** — open Architecture from Overview for a pannable diagram of the local, server and external boundaries.
- **Local access** — sign-in now collects name and college for the demo session.
- **Bundled fonts and nature theme** — Noto Sans / Noto Sans Devanagari ship inside the APK; shared forest/mint tokens and responsive layouts from 375px phone to 1440px desktop.
- **Backend** — added `/assistant/config` and `/assistant/chat` (Groq, server-side key only, deterministic offline fallback), same-origin Docker image serving the Flutter web build with the API, and a rewritten CI/CD pipeline.

### Honest boundaries

Sign-in is a local demo session, not production authentication — no faculty messaging, remote approvals or multi-user locking. Disruptions edit the recurring weekly draft; date-specific exceptions and academic-calendar overrides are not implemented. Live AI needs a server-side `GROQ_API_KEY`; without it the assistant is visibly labelled as offline guidance. Room equipment is configured inventory, not a generator constraint. No mathematically optimal result is claimed.

### Upgrading from v1.0.0 — please read

This build is signed with SYNCHRO's new permanent release certificate (`CN=SYNCHRO`). The v1.0.0 APK was signed by a throwaway certificate generated inside a CI runner and since destroyed, which Android treats as a different app identity. **If v1.0.0 is already installed, uninstall it before installing v1.1.0**, otherwise Android refuses the install with a signature-mismatch error. Saved timetables live in app storage and are lost on uninstall, so export them first. Fresh installs are unaffected, and every future release reuses this certificate so normal in-place updates work from here on.
