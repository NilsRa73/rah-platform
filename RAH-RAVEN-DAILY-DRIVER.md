# RAH Raven Daily Driver v1.0 Candidate

A local-first Python desktop sidecar for the existing `rah-platform`.

It deliberately does **not** modify the canonical Command Center 2.3 Stable, Node Agent 1.3 Stable, or frozen Chronicle 1.7.1 runtime files.

## Daily Driver modules

- Council — mixed LM Studio/local and optional OpenAI/cloud agents
- Investigator — Facebook ZIP/JSON/HTML and local tool-export ingestion
- Chronicle — common SQLite desktop memory for the new Daily Driver modules
- Mission — JSON mission reports
- Insights — priorities, recovery backlog, project status and device summary
- Devices — local registry for PC/Kali/phone/display/storage/agent nodes

## Candidate security boundary

- Daily Driver Bridge binds to loopback and exposes read-only `GET /health` + `GET /status` only.
- Device dispatch is simulated, fixed-allowlist only, and requires explicit approval.
- No shell, generic process execution, generic file API, native remote-control API, credential attack feature, or Stable Command Center authority is added.
- OpenAI cloud mode is disabled by default; the adapter uses the Responses API with `store: false` when explicitly enabled.
- Lifecycle stages may advance only one step at a time: Prototype -> Candidate -> Runtime Test -> Stable -> Frozen.
- Runtime Acceptance can make a package eligible for Runtime Test review, but it can never promote Stable.

## Install

Double-click `INSTALL-RAH-RAVEN.bat`.

The installer creates an isolated `.venv`, installs `requests`, creates runtime folders and makes a desktop shortcut.

## Local AI

Start LM Studio's local server. The default Daily Driver config checks `http://127.0.0.1:1234/v1` and automatically uses the first loaded model.

## OpenAI cloud

Cloud mode is disabled by default. To enable it:

1. Set `OPENAI_API_KEY` in your Windows environment.
2. Set `agents.openai_cloud.enabled` to `true` in `apps/rah-raven-daily-driver/config.json`.

The adapter uses the Responses API with `store: false`. The default model alias is `gpt-5.6`.

## Stable Gate

This is a Candidate until it passes the target Windows runtime checks in `STABLE-GATE.md`.

## Runtime Gate

Run `apps\rah-raven-daily-driver\RUNTIME-GATE-RAH-RAVEN.bat` after installation if you want only the raw Runtime Gate.

Pass your real Facebook ZIP as the first argument to make that required gate concrete. The tool also tests Chronicle persistence, Investigator extraction, Frozen guards, the main-PC device node, LM Studio status, and bridge availability.

The Runtime Gate launcher explicitly preserves `runtime_check.py`'s exit code. When called by the acceptance runner it uses a non-interactive mode so the result cannot be lost behind a `pause` command.

### Simplest Windows acceptance test

After installation, double-click `TEST-RAH-RAVEN-RUNTIME.bat`.

For the real archive gate, drag your Facebook export ZIP onto `TEST-RAH-RAVEN-RUNTIME.bat`.

This is now the one-click Runtime Acceptance path:

1. run the Windows Runtime Gate;
2. preserve the Runtime Gate exit code;
3. export a privacy-safe Runtime Evidence ZIP even when the gate is pending or failed;
4. validate the newest evidence bundle fail-closed;
5. write the corresponding `.readiness.json` next to the evidence ZIP;
6. return exit code `0` only when automated evidence is eligible for Runtime Test review, `2` when valid but still pending, and `1` for failure/blocked evidence.

The runner always reports `Stable promotion: BLOCKED`. It does not call the Stable promotion path and does not expand Command Center or Node authority.

Only a complete machine-readable Runtime Gate result with all required checks present and `PASS` can allow `PROMOTE-RAH-RAVEN-TO-RUNTIME-TEST.bat` to advance eligible Daily Driver components from Candidate to Runtime Test. It never promotes to Stable.

## Runtime Evidence Bundle

You can also run `EXPORT-RAH-RAVEN-RUNTIME-EVIDENCE.bat` by itself. It writes a ZIP plus SHA-256 file under:

`apps\rah-raven-daily-driver\runtime\exports`

The evidence schema is `rah-raven-runtime-evidence-v1`. It includes only sanitized Runtime Gate status, lifecycle state, device classes, AI/bridge configuration summary, basic OS/Python/CPU metadata, and local package provenance metadata/hashes.

It deliberately excludes the Chronicle database, Facebook/archive source files, Council/chat content, API-key or token values, raw device hostnames, raw external IP addresses, and application logs. The raw Runtime Gate file is not copied into the evidence ZIP; only its SHA-256 is recorded so the sanitized evidence can still be tied to the exact local gate result.

`VALIDATE-RAH-RAVEN-RUNTIME-EVIDENCE.bat` prefers the application's isolated `.venv` Python and falls back to system `python` only when needed. Its generated `.readiness.json` is the machine-readable acceptance summary used for Runtime Test review.
