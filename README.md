# RAH Raven Platform

RAH Raven Platform is a local-first command center for projects, missions, voice control, GitHub synchronization, member login, and AI-assisted screen understanding.

## Live pages

- Command Center v1.3: https://nilsra73.github.io/rah-platform/
- Raven Vision workspace: https://nilsra73.github.io/rah-platform/vision.html
- Repository: https://github.com/NilsRa73/rah-platform

## Current architecture

### `index.html`
The RAH Raven Command Center v1.3. It contains project tracking, missions, voice commands, Project Brain, GitHub synchronization, Supabase member login, and the integrated Raven Vision v1.3 module.

### `vision-module.js`
The integrated Command Center Vision engine. It uses one shared screenshot state for file upload, browser screen sharing, Desktop Bridge capture, and LM Studio analysis.

### `vision.html`
The full standalone Raven Vision workspace with image upload, screen sharing, Desktop Bridge capture, automatic LM Studio model discovery, abortable analysis, diagnostics, local history, copy, save, and export.

### `desktop-bridge/`
A localhost-only Python service and Windows launcher set that captures the currently active window and validates the complete local Vision chain.

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

From the repository root:

```powershell
cd desktop-bridge
.\.venv\Scripts\python.exe -m unittest discover -s tests -v
```

The test suite validates:

- bridge health response
- successful screenshot JSON response
- structured capture errors
- Raven Doctor model detection
- Raven Doctor empty-model detection
- Raven Doctor bridge and capture checks

## Privacy and security

- The bridge binds to `127.0.0.1` by default, not the public network.
- Screen capture occurs only after the user presses a capture button.
- Screenshots are sent only to the configured LM Studio address.
- The bridge does not save screenshots to disk.
- Analysis history is stored in browser `localStorage`.
- The bridge returns `Cache-Control: no-store`.
- Supabase secret service-role keys must never be placed in this public repository.

## Recovery

`BACKUP_V1_2.md` records the last known working v1.2 recovery commit before the Vision v1.3 completion pass.

## Troubleshooting

### Raven Doctor says Desktop Bridge failed
Run `desktop-bridge/start-bridge.bat` in a visible window to see the Python error. Confirm port `8765` is not occupied by another application.

### Raven Doctor says LM Studio failed
Open LM Studio and start Local Server at `http://127.0.0.1:1234`.

### Raven Doctor says no model is loaded
Load a vision-capable model in LM Studio, then rerun `doctor.py`.

### Preview works but analysis says no image
Refresh the Command Center. The v1.3 integration uses `vision-module.js` and one shared image state.

### Screen/window chooser does not open
Use a current Chromium, Edge, or Firefox browser over HTTPS. GitHub Pages already provides HTTPS.
