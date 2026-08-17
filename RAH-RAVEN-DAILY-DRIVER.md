# RAH Raven Daily Driver v1.0 Candidate

A local-first Python desktop sidecar for the existing `rah-platform`.

It deliberately does **not** modify the stable Command Center 2.0 or frozen Chronicle 1.7.1 runtime files.

## Daily Driver modules

- Council — mixed LM Studio/local and OpenAI/cloud agents
- Investigator — Facebook ZIP/JSON/HTML and local tool-export ingestion
- Chronicle — common SQLite desktop memory for the new Daily Driver modules
- Mission — JSON mission reports
- Insights — priorities, recovery backlog, project status and device summary
- Devices — local registry for PC/Kali/phone/display/storage/agent nodes

## Install

Double-click `INSTALL-RAH-RAVEN.bat`.

The installer creates an isolated `.venv`, installs `requests`, creates runtime folders and makes a desktop shortcut.

## Local AI

Start LM Studio's local server. The default Daily Driver config checks `http://127.0.0.1:1234/v1` and automatically uses the first loaded model.

## OpenAI cloud

Cloud mode is disabled by default. To enable it:

1. Set `OPENAI_API_KEY` in your Windows environment.
2. Set `agents.openai_cloud.enabled` to `true` in `apps/rah-raven-daily-driver/config.json`.

The adapter uses the Responses API with `store: false`.

## Stable Gate

This is a Candidate until it passes the target Windows runtime checks in `STABLE-GATE.md`.

## Runtime Gate

Run `apps\rah-raven-daily-driver\RUNTIME-GATE-RAH-RAVEN.bat` after installation.

Pass your real Facebook ZIP as the first argument to make that required gate concrete. The tool also tests Chronicle persistence, Investigator extraction, Frozen guards, the main-PC device node, LM Studio status, and bridge availability.
