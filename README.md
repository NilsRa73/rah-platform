# RAH Raven Platform

RAH Raven Platform is a local-first command center for projects, resumable missions, voice control, GitHub synchronization, member login, cloud-backed Project Brain, and AI-assisted screen understanding.

## Live pages

- Command Center v1.5: https://nilsra73.github.io/rah-platform/
- Raven Vision workspace: https://nilsra73.github.io/rah-platform/vision.html
- Repository: https://github.com/NilsRa73/rah-platform

## Current architecture

### `index.html`
The RAH Raven Command Center v1.5. It contains project tracking, Mission Control, voice commands, Project Brain, GitHub synchronization, Supabase member login, Raven Vision, and cloud-sync integration.

### `mission-engine.js`
The resumable Mission Control engine. It adds:

- persistent step states: pending, running, waiting, completed, failed
- two-stage handling for manual browser actions
- retry and reopen controls
- execution timestamps and attempt counts
- a local mission log
- automatic result storage in Project Brain
- mission history summaries
- restoration after browser restart or cloud download
- prepared GitHub Issue reports

### `cloud-sync.js`
Private Supabase synchronization for each authenticated member. Local browser state remains the working copy and is synchronized to one RLS-protected row per user.

### `vision-module.js`
The integrated Command Center Vision engine. It uses one shared screenshot state for file upload, browser screen sharing, Desktop Bridge capture, and LM Studio analysis.

### `vision.html`
The full standalone Raven Vision workspace with image upload, screen sharing, Desktop Bridge capture, automatic LM Studio model discovery, abortable analysis, diagnostics, local history, copy, save, and export.

### `desktop-bridge/`
A localhost-only Python service and Windows launcher set that captures the currently active window and validates the complete local Vision chain.

## Mission Control usage

1. Open **Mission Control** in the Command Center.
2. Select a mission preset or create a custom mission.
3. Press **Kjør neste steg**.
4. Internal steps complete automatically.
5. For a step that opens GitHub, Vision, YouTube Studio, or another tool, finish the action and press **Bekreft ferdig**.
6. Failed steps show **Prøv igjen**.
7. Completed missions are written to Project Brain and retained in Mission history.

Mission state is stored in the normal RAH state object, so it is preserved by local storage and Project Brain Cloud Sync.

## Project Brain Cloud Sync

Cloud Sync requires the SQL schema in:

`supabase/001_project_brain_sync.sql`

Run it once in the Supabase SQL Editor. After login, open **Settings → Project Brain Cloud Sync** and use **Bruk denne enheten** for the first upload. Row Level Security restricts every record to `auth.uid()`.

## One-click Windows start

After downloading or cloning the repository:

1. Open the `desktop-bridge` folder.
2. Double-click **`start-raven-vision.bat`**.

The launcher automatically:

- finds Python
- creates a local `.venv`
- installs or validates dependencies
- starts Desktop Bridge if it is not already running
- checks LM Studio on port `1234`
- detects whether a model is loaded
- opens the Command Center directly at Vision
- runs Raven Doctor and prints a complete readiness report

LM Studio itself must be installed and a vision-capable model must be loaded. The launcher never downloads models or changes LM Studio settings without the user.

## Basic Windows setup

1. Install Python 3.11 or newer.
2. Install LM Studio.
3. Load a vision-capable model in LM Studio.
4. Start LM Studio Local Server on port `1234`.
5. Double-click `desktop-bridge/start-raven-vision.bat`.
6. In Raven, press **Hent aktivt vindu** or **Velg skjerm/vindu**.
7. Press **Analyser skjermbilde**.

## Raven Doctor

Raven Doctor checks:

- Python version and executable
- Flask, Flask-CORS, MSS, and Pillow
- Desktop Bridge health
- real screenshot capture
- LM Studio OpenAI-compatible API
- loaded model availability

Run it from `desktop-bridge` after the bridge starts:

```powershell
.\.venv\Scripts\python.exe doctor.py
```

Machine-readable output:

```powershell
.\.venv\Scripts\python.exe doctor.py --json
```

Skip the screenshot test:

```powershell
.\.venv\Scripts\python.exe doctor.py --skip-capture
```

A successful run ends with:

```text
RESULT: READY — Raven Vision local chain is operational.
```

## Manual bridge setup

```powershell
cd desktop-bridge
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
python server.py
```

Health check:

```text
http://127.0.0.1:8765/health
```

Capture endpoint:

```text
http://127.0.0.1:8765/capture/active-window
```

## LM Studio requirements

Raven Vision uses LM Studio's OpenAI-compatible endpoints:

```text
GET  http://127.0.0.1:1234/v1/models
POST http://127.0.0.1:1234/v1/chat/completions
```

The loaded model must support image input. A text-only model may appear in the model list but cannot inspect screenshots.

## Tests

Browser-module validation from the repository root:

```powershell
node tests/cloud-sync.test.mjs
node tests/mission-engine.test.mjs
node --check mission-engine.js
```

Desktop Bridge tests:

```powershell
cd desktop-bridge
.\.venv\Scripts\python.exe -m unittest discover -s tests -v
```

GitHub Actions validates Vision integration, cloud sync, and Mission Engine script order and syntax.

## Privacy and security

- The bridge binds to `127.0.0.1` by default, not the public network.
- Screen capture occurs only after the user presses a capture button.
- Screenshots are sent only to the configured LM Studio address.
- The bridge does not save screenshots to disk.
- Analysis and mission history are stored in the normal RAH browser state.
- Supabase records are protected by Row Level Security and `auth.uid()`.
- Supabase secret service-role keys must never be placed in this public repository.
- Publishing, deletion, spending, and other high-impact actions remain user-controlled.

## Recovery

`BACKUP_V1_2.md` records the last known working v1.2 recovery commit before the modular Vision, cloud-sync, and Mission Engine integrations.

## Troubleshooting

### Mission opens a page but does not complete
This is expected for manual actions. Finish the work in the opened page, return to Mission Control, and press **Bekreft ferdig**.

### Mission is restored after restart
Mission Engine intentionally restores active, waiting, blocked, or paused missions from local or cloud state.

### Cloud Sync panel reports a missing table
Run `supabase/001_project_brain_sync.sql` in the Supabase SQL Editor.

### Raven Doctor says Desktop Bridge failed
Run `desktop-bridge/start-bridge.bat` in a visible window to see the Python error. Confirm port `8765` is not occupied by another application.

### Raven Doctor says LM Studio failed
Open LM Studio and start Local Server at `http://127.0.0.1:1234`.

### Raven Doctor says no model is loaded
Load a vision-capable model in LM Studio, then rerun `doctor.py`.

### Preview works but analysis says no image
Refresh the Command Center. The integrated Vision module uses one shared image state.

### Screen/window chooser does not open
Use a current Chromium, Edge, or Firefox browser over HTTPS. GitHub Pages already provides HTTPS.
