# RAH Project Context

Updated: 2026-07-30

## Project

**Name:** RAH Platform  
**Repository:** https://github.com/NilsRa73/rah-platform  
**Owner:** Nils Ravnbø  
**Active milestone:** RAH Raven Command Center + Raven Vision v1.3

## Core goal

RAH Platform is a mouse-first AI command center organized around goals and workflows. RAH Vision sees, Project Brain remembers, and Command Center acts.

## Current production pages

- Command Center v1.2: `index.html`
- Raven Vision v1.3: `vision.html`
- GitHub Pages: https://nilsra73.github.io/rah-platform/
- Vision page: https://nilsra73.github.io/rah-platform/vision.html

The stable Command Center remains unchanged during the Vision completion pass. Vision v1.3 is a separate page so the known-good dashboard and login remain recoverable.

## Completed Raven Vision v1.3

- One shared screenshot state for uploaded files, browser capture, and Desktop Bridge capture
- PNG, JPG, and WEBP validation with a 15 MB limit
- Browser-native screen/window capture using `getDisplayMedia`
- Windows active-window capture through the local Desktop Bridge
- LM Studio discovery through `/v1/models`
- Vision requests through `/v1/chat/completions`
- User-selectable model and endpoint settings
- Clear LM Studio and bridge diagnostics
- Abortable analysis
- Numbered Norwegian guidance prompt
- Local analysis history, copy, save, and JSON export
- One-click Windows bridge launcher
- Bridge unit tests
- Complete README setup and troubleshooting notes

## Desktop Bridge

Source: `desktop-bridge/server.py`

Defaults:

- Host: `127.0.0.1`
- Port: `8765`
- Health: `/health`
- Capture: `/capture/active-window`

The bridge does not save screenshots to disk and binds to localhost by default.

## Local AI

Default LM Studio endpoint: `http://127.0.0.1:1234`

A loaded vision-capable model is required. Raven Vision discovers model IDs automatically and sends screenshots only to the configured local endpoint.

## Recovery

Known working Command Center commit before this completion pass:

`c6aff4cf9b29f48492f191c5a37363530fb46aa6`

The recovery marker is stored in `BACKUP_V1_2.md`.

## Validation

Run bridge tests from `desktop-bridge`:

```powershell
.\.venv\Scripts\python.exe -m unittest -v test_server.py
```

Manual validation sequence:

1. Start LM Studio Local Server with a vision model.
2. Run `desktop-bridge/start-bridge.bat`.
3. Open `vision.html`.
4. Test LM Studio and Desktop Bridge.
5. Capture an active window.
6. Analyze it and confirm numbered click guidance.
7. Confirm history, copy, save, and export.

## Next build priority

Package Desktop Bridge as a signed Windows executable and add a direct Vision v1.3 navigation link inside the Command Center after real-machine validation.

## Safety and privacy

- No hidden screen capture
- Screen/window selection always requires an explicit user action
- No public bridge binding by default
- No screenshot storage on disk
- No secret service-role keys in browser code
- Publishing, deletion, spending, and other high-impact actions remain approval-gated
