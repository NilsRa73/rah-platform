# RAH Raven Daily Driver v1.0 — Stable Gate

## Build gate
- Python syntax: required PASS
- Unit/smoke tests: required PASS
- Existing stable Command Center runtime files modified: MUST be false
- Existing frozen Chronicle runtime files modified: MUST be false

## Windows runtime gate
1. Run `INSTALL-RAH-RAVEN.bat` on Windows 10/11.
2. Confirm desktop shortcut launches Daily Driver.
3. Confirm read-only local bridge `/health` on `127.0.0.1:18767`.
4. Start LM Studio server, load a model, confirm both local Council roles answer.
5. With cloud disabled, confirm no OpenAI request is made.
6. Optional cloud test: set `OPENAI_API_KEY`, enable cloud agent, confirm one Responses API answer.
7. Import a real Facebook archive ZIP and confirm emails/usernames/accounts populate.
8. Import one Sherlock CSV, PhoneInfoga TXT/JSON, and passive SpiderFoot JSON/CSV export.
9. Change recovery states and restart; verify SQLite persistence.
10. Record a decision, restart, ask “Hva bestemte vi forrige uke?”
11. Generate a Mission Report.
12. Refresh Devices; confirm main PC metadata and simulated nodes.
13. Verify Frozen guard rejects normal transition of a Frozen component.

## Promotion
Candidate -> Runtime Test -> Stable -> Frozen only after all applicable checks pass.

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

A validator `ELIGIBLE` result means the automated evidence is eligible for **Runtime Test review only**. The validator is structurally forbidden from promoting Stable; the manual Windows checks above still have to be completed before Stable promotion.
