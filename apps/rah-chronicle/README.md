# RAH Chronicle v0.2

RAH Chronicle is a privacy-first local work-telemetry, project-detection, and reporting app for the RAH Raven ecosystem.

## v0.2 highlights

- Tracks active work tabs from Edge/Chrome through the local extension.
- Automatically groups activity into RAH projects such as Chronicle, Cloudflare/Software Distribution, Raven Browser, Raven Core/Command Center, RAH OS/Linux, RAH Gammon, infrastructure, and general RAH work.
- Adds a 24-hour work timeline to the local black/gold dashboard.
- Enriches reports with GitHub commits and pull-request activity for configured repositories.
- Generates both daily and seven-day weekly Markdown reports.
- Uses GitHub activity as a confirmation layer so the report does not claim something is finished just because a browser tab was open.
- Can automatically use a local OpenAI-compatible model server at `127.0.0.1:1234/v1` (for example LM Studio). If no local model is available, Chronicle falls back to its deterministic local report.
- Extension badge shows `ON` when the local collector answers and `!` when it is offline. Clicking the extension icon opens Chronicle.
- Safer localhost API: ordinary websites cannot post Chronicle events through CORS.
- Upgrade/install path preserves existing database, reports, and config; backs up the previous runtime; verifies SHA-256 and Python syntax; then performs health/API checks.

## Privacy defaults

Chronicle records active-tab title, domain, sanitized URL path for allowlisted work domains, active duration, and inferred RAH project. Incognito tabs are skipped.

v0.2 does **not** collect page body text, passwords, form values, keystrokes, clipboard, screenshots, microphone, or camera.

For non-work sites the default is domain-only with the title `Private tab`.

## Local paths

- Runtime: `C:\RAH\Chronicle\App`
- Browser extension: `C:\RAH\Chronicle\Extension`
- SQLite database: `C:\RAH\Chronicle\Data\chronicle.db`
- Reports: `C:\RAH\Chronicle\Reports`
- Logs: `C:\RAH\Chronicle\Logs`
- Config: `C:\RAH\Chronicle\config.json`
- Dashboard: `http://127.0.0.1:18766/`

## Reports and endpoints

- Health: `/health`
- Today: `/api/today`
- GitHub enrichment: `/api/github`
- Seven-day aggregate: `/api/week`
- Daily report: `/report/today`
- Weekly report: `/report/week`

Daily reporting defaults to 23:50 local time. Weekly reporting defaults to Sunday at the same time. Both are configurable in `config.json`.

## GitHub enrichment

The default repository is `NilsRa73/rah-platform`. Public repositories work without credentials. Additional repositories can be added in `C:\RAH\Chronicle\config.json`.

Private repositories require a GitHub token supplied locally through the `RAH_GITHUB_TOKEN` environment variable. Do not paste private tokens into chat.

## Local AI

Default configuration uses `auto_local` mode against `http://127.0.0.1:1234/v1`. Chronicle checks `/models`, chooses an available local model, and sends only aggregated Chronicle + configured GitHub activity to the summarizer. Raw page bodies are not sent.

A normal ChatGPT web subscription is not an unattended API endpoint. A separate compatible endpoint is needed for background AI generation.

## Install / upgrade

Run `agent/install.ps1`. It is the stable entrypoint for v0.2 and works both as a fresh install and an upgrade from v0.1.

After the extension files are replaced, existing unpacked Edge/Chrome installs should be reloaded once in `edge://extensions` or `chrome://extensions`.

## Validation completed before merge

- Python `py_compile`: PASS.
- Temporary local SQLite/runtime smoke test: PASS.
- `/health`, `/event`, `/api/today`, `/report/today`, `/report/week`, and dashboard responses exercised successfully.
- Synthetic ChatGPT/GitHub/private-tab sessions classified and summarized correctly.
- Browser background JavaScript `node --check`: PASS.
- Manifest JSON parse: PASS.
- Runtime payload SHA-256 pinned in the Windows installer.
- Final Windows-specific upgrade/extension reload still requires validation on HOVED-PC.

## v0.3 candidates

System-tray pause controls, selected-chat opt-in content extraction, private-repository setup UI, CI/release enrichment, automatic PDF/HTML executive reports, and encrypted Chronicle cloud sync.
