# RAH Raven Daily Driver v1.0 — Stable Gate

## Build gate
- Python syntax: required PASS
- Unit/smoke tests: required PASS
- Existing stable Command Center runtime files modified: MUST be false
- Existing frozen Chronicle runtime files modified: MUST be false

## Pre-Stable hosted machine evidence

GitHub Actions now verifies the machine-testable Windows path without claiming Stable:

- exact 37-file Candidate package staged under a path containing spaces: PASS
- real `INSTALL-RAH-RAVEN.bat` installation in explicit headless/no-start acceptance mode: PASS
- isolated `.venv`, `requests`, and runtime directories: PASS
- actual Windows `.lnk` shortcut creation, target and working directory: PASS
- complete repository unit/smoke regression using the installed venv: PASS
- installed-package Runtime Gate: PASS with only `LM Studio` and `Real Facebook/archive import` required checks still pending
- read-only loopback bridge `/health` and POST rejection: PASS
- cloud-disabled path cannot issue an OpenAI request: PASS
- Chronicle persistence, Mission Report, main-PC device snapshot and Frozen guard: PASS

Authoritative machine evidence is recorded in `BUILD-VALIDATION.json`. This hosted evidence runs on GitHub `windows-latest`; it does **not** substitute for the final owned Windows 10/11 + live-model + owned-data acceptance below.

## Manual Windows / owned-data runtime gate
1. Run `INSTALL-RAH-RAVEN.bat` on an owned Windows 10/11 machine.
2. Confirm the installed desktop shortcut actually launches Daily Driver interactively.
3. Confirm read-only local bridge `/health` on `127.0.0.1:18767` on that machine.
4. Start LM Studio server, load a real model, confirm both local Council roles answer.
5. With cloud disabled, confirm no OpenAI request is made during the owned-machine session.
6. Optional cloud test: set `OPENAI_API_KEY`, enable cloud agent, confirm one Responses API answer.
7. Import a real user-owned Facebook archive ZIP and confirm emails/usernames/accounts populate.
8. Import representative owned Sherlock CSV, PhoneInfoga TXT/JSON, and passive SpiderFoot JSON/CSV exports; review their rendered results.
9. Change recovery states and restart; verify SQLite persistence on the owned machine.
10. Record a decision, restart, ask “Hva bestemte vi forrige uke?”
11. Generate and review a Mission Report.
12. Refresh Devices; confirm main PC metadata and simulated nodes.
13. Verify Frozen guard rejects normal transition of a Frozen component.

Items already covered by the hosted machine gate still require only the final owned-machine acceptance context; they must not be auto-promoted from hosted CI evidence.

## Promotion
Candidate -> Runtime Test -> Stable -> Frozen only after all applicable checks pass.

No GitHub workflow, Runtime Acceptance runner, evidence exporter, evidence validator, or hosted Pre-Stable machine gate may promote directly to Stable or Frozen.

## Automated Windows gate

After installation, run:

`apps\rah-raven-daily-driver\RUNTIME-GATE-RAH-RAVEN.bat`

To include a real Facebook/archive ZIP:

`RUNTIME-GATE-RAH-RAVEN.bat "C:\path\to\facebook-export.zip"`

The machine-readable result is written to:

`runtime\state\runtime-gate.json`

Only when all required checks are `PASS` may `promote_runtime_test.py` advance eligible Candidate components to `Runtime Test`. It never promotes directly to Stable or Frozen.

## Runtime Evidence

`TEST-RAH-RAVEN-RUNTIME.bat` also exports a privacy-safe evidence ZIP under:

`apps\rah-raven-daily-driver\runtime\exports`

The evidence ZIP intentionally excludes Chronicle databases, personal archive source files, chat/Council content, API-key or token values, raw device hostnames, raw external IP addresses, and application logs.

Validate the newest evidence bundle with:

`VALIDATE-RAH-RAVEN-RUNTIME-EVIDENCE.bat`

Or validate an explicit bundle:

`VALIDATE-RAH-RAVEN-RUNTIME-EVIDENCE.bat "C:\path\to\RAH-Raven-Runtime-Evidence-*.zip"`

The validator verifies schema v1, exact ZIP closure, path safety, manifest byte counts, SHA-256 values, privacy declarations, and critical runtime checks. It writes a sibling `*.readiness.json` report.

A validator `ELIGIBLE` result means the automated evidence is eligible for **Runtime Test review only**. The validator is structurally forbidden from promoting Stable; the manual owned-machine checks above still have to be completed before Stable promotion.
