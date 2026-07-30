# RAH Project Context

Updated: 2026-07-30

## Project

**Name:** RAH Platform  
**Repository:** https://github.com/NilsRa73/rah-platform  
**Owner:** Nils Ravnbø  
**Active milestone:** One-click Raven Vision local chain

## Core goal

RAH Platform is a mouse-first AI command center organized around goals and workflows. RAH Vision sees, Project Brain remembers, and Command Center acts.

## Current production pages

- Command Center v1.3: `index.html`
- Integrated Vision engine: `vision-module.js`
- Standalone Raven Vision workspace: `vision.html`
- GitHub Pages: https://nilsra73.github.io/rah-platform/
- Vision page: https://nilsra73.github.io/rah-platform/vision.html

The Command Center now loads Raven Vision v1.3 directly. The original v1.2 recovery point remains documented in `BACKUP_V1_2.md`.

## Completed Raven Vision v1.3

- One shared screenshot state for uploaded files, browser capture, and Desktop Bridge capture
- PNG, JPG, and WEBP validation
- Browser-native screen/window capture using `getDisplayMedia`
- Windows active-window capture through the local Desktop Bridge
- LM Studio discovery through `/v1/models`
- Vision requests through `/v1/chat/completions`
- User-selectable model and endpoint settings
- Clear LM Studio and bridge diagnostics
- Abortable analysis
- Numbered Norwegian guidance prompt
- Local analysis history, copy, save, and export
- Integrated Vision panel inside the main Command Center

## Desktop Bridge

Source: `desktop-bridge/server.py`

Defaults:

- Host: `127.0.0.1`
- Port: `8765`
- Health: `/health`
- Capture: `/capture/active-window`

The bridge does not save screenshots to disk and binds to localhost by default.

## One-click Windows startup

Primary launcher: `desktop-bridge/start-raven-vision.bat`

It automatically:

1. Finds Python.
2. Creates the local virtual environment.
3. Installs or checks dependencies.
4. Starts Desktop Bridge when needed.
5. Checks LM Studio and loaded-model availability.
6. Opens Command Center directly at Vision.
7. Runs Raven Doctor and prints a readiness report.

The simpler bridge-only launcher remains available as `desktop-bridge/start-bridge.bat`.

## Raven Doctor

Source: `desktop-bridge/doctor.py`

Checks:

- Python and required modules
- Desktop Bridge health
- real active-window screenshot capture
- LM Studio API connectivity
- loaded-model availability

Run:

```powershell
cd desktop-bridge
.\.venv\Scripts\python.exe doctor.py
```

A complete successful chain reports:

```text
RESULT: READY — Raven Vision local chain is operational.
```

## Automated validation

```powershell
cd desktop-bridge
.\.venv\Scripts\python.exe -m unittest discover -s tests -v
```

Tests cover bridge responses and Raven Doctor service/model detection.

## Local AI

Default LM Studio endpoint: `http://127.0.0.1:1234`

A loaded vision-capable model is required. Raven discovers model IDs automatically and sends screenshots only to the configured local endpoint.

## Recovery

Known working Command Center commit before the Vision completion pass:

`c6aff4cf9b29f48492f191c5a37363530fb46aa6`

The recovery marker is stored in `BACKUP_V1_2.md`.

## Next build priority

Package Raven Desktop Bridge and the launcher as a Windows application with a tray status window, startup controls, logs, and an installer. The existing Python and batch implementation remains the working fallback.

## Safety and privacy

- No hidden screen capture
- Screen/window selection always requires an explicit user action
- No public bridge binding by default
- No screenshot storage on disk
- No secret service-role keys in browser code
- Publishing, deletion, spending, and other high-impact actions remain approval-gated
