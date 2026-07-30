# RAH Project Context

Updated: 2026-07-30

## Project

**Name:** RAH Platform  
**Repository:** https://github.com/NilsRa73/rah-platform  
**Owner:** Nils Ravnbø  
**Active milestone:** Resumable Mission Control v1.5

## Core goal

RAH Platform is a mouse-first AI command center organized around goals and workflows. RAH Vision sees, Project Brain remembers, Mission Control coordinates, and Command Center acts.

## Current production system

- Command Center v1.5: `index.html`
- Mission execution engine: `mission-engine.js`
- Project Brain Cloud Sync: `cloud-sync.js`
- Integrated Vision engine: `vision-module.js`
- Standalone Raven Vision workspace: `vision.html`
- GitHub Pages: https://nilsra73.github.io/rah-platform/
- Vision page: https://nilsra73.github.io/rah-platform/vision.html

The original v1.2 recovery point remains documented in `BACKUP_V1_2.md`.

## Completed Mission Control v1.5

- Persistent missions stored in local RAH state and Supabase Cloud Sync
- Step states: PENDING, RUNNING, WAITING, COMPLETED and FAILED
- Internal actions complete automatically
- External/manual actions open the correct tool and wait for user confirmation
- Retry controls for failed steps
- Reopen controls for completed steps
- Attempt counts and execution timestamps
- Mission execution log
- Mission restoration after browser restart or cloud download
- Completed mission summaries stored in Project Brain
- Completed and cancelled mission history
- Prepared GitHub Issue reports containing status, progress and results
- Voice command support for running the next mission step
- Automated syntax and integration validation

## Project Brain Cloud Sync

- One private state row per authenticated Supabase user
- Row Level Security restricted to `auth.uid()`
- Local-first operation and offline fallback
- Manual upload and download controls
- Automatic synchronization
- Projects, tasks, active mission, mission history, Project Brain and settings included

Schema: `supabase/001_project_brain_sync.sql`

## Completed Raven Vision v1.3

- One shared screenshot state for upload, browser capture, and Desktop Bridge capture
- Browser-native screen/window capture using `getDisplayMedia`
- Windows active-window capture through the local Desktop Bridge
- LM Studio model discovery and vision requests
- Diagnostics, abortable analysis and Norwegian click guidance
- Local history, copy, save and export
- Integrated Vision panel inside the main Command Center

## Desktop Bridge and Windows launchers

Source: `desktop-bridge/server.py`

Defaults:

- Host: `127.0.0.1`
- Port: `8765`
- Health: `/health`
- Capture: `/capture/active-window`

Primary launcher: `desktop-bridge/start-raven-vision.bat`

Windows tray source: `desktop-bridge/tray_app.py`

Executable build script: `desktop-bridge/build-exe.bat`

Raven Doctor: `desktop-bridge/doctor.py`

The bridge does not save screenshots to disk and binds to localhost by default.

## Automated validation

Browser modules:

```powershell
node tests/cloud-sync.test.mjs
node tests/mission-engine.test.mjs
node --check mission-engine.js
```

Desktop Bridge:

```powershell
cd desktop-bridge
.\.venv\Scripts\python.exe -m unittest discover -s tests -v
```

GitHub Actions validates module hooks, load order, syntax and static safety conditions.

## Recovery

Known working Command Center commit before the modular completion passes:

`c6aff4cf9b29f48492f191c5a37363530fb46aa6`

The recovery marker is stored in `BACKUP_V1_2.md`.

## Next build priority

Connect Mission Control to more direct real actions through the Desktop Bridge, beginning with safe approved actions such as opening project folders, opening repositories in VS Code, reading Git status and starting approved development servers. Every local action must be allowlisted, logged and initiated by an explicit user click.

## Safety and privacy

- No hidden screen capture
- No secret monitoring or background command execution
- Local actions require an explicit user-triggered mission step
- Desktop Bridge remains localhost-only by default
- No screenshot storage on disk
- No secret service-role keys in browser code
- Publishing, deletion, spending, deployment and other high-impact actions remain approval-gated
