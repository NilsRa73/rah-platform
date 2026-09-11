# RAH Chronicle v0.1

RAH Chronicle is a privacy-first local work telemetry and daily-report prototype for the RAH Raven ecosystem.

## What v0.1 does

- Edge/Chrome Manifest V3 extension tracks active-tab **title, domain, sanitized URL path, and active duration**.
- Incognito tabs are skipped.
- Page body text, passwords, form values, screenshots, keystrokes, clipboard, microphone, and camera are not collected.
- Work domains keep title + URL path; other sites default to domain only and the title `Private tab`.
- Local Python collector binds only to `127.0.0.1:18766`.
- Data is stored in SQLite under `C:\RAH\Chronicle\Data\chronicle.db`.
- Daily Markdown reports are written to `C:\RAH\Chronicle\Reports` at 23:50 local time.
- If the app was off at report time, it generates the previous day's missing report on next start.
- A local dashboard is served at `http://127.0.0.1:18766/`.

## Default work domains

- chatgpt.com
- github.com
- dash.cloudflare.com
- cloudflare.com
- localhost / 127.0.0.1

These can be changed from the extension Options page.

## AI summaries

The deterministic local report works with **no AI service and no API key**.

Optional AI mode supports an OpenAI-compatible `/v1/chat/completions` endpoint. This can point at a local model server such as LM Studio or another compatible endpoint.

Environment variables:

```text
RAH_AI_MODE=openai_compatible
RAH_AI_BASE_URL=http://127.0.0.1:1234/v1
RAH_AI_MODEL=<your-model-name>
RAH_AI_API_KEY=<optional-for-local-server>
```

Only **aggregated daily activity** is sent to the configured AI summarizer by v0.1, not raw page content.

A ChatGPT web subscription itself is not an unattended API endpoint. To have OpenAI models generate the report outside this chat, configure an API-compatible endpoint separately. Local AI keeps the data on the machine.

## Install

After this feature is merged to `main`, run `agent/install.ps1` or use the root one-click installer we will expose later.

The installer automates the collector, scheduled startup, local folders, health check, dashboard shortcut, and extension download. One manual browser step remains: loading the unpacked extension. Normal Edge/Chrome security intentionally prevents arbitrary software from silently installing an unpacked extension.

## Architecture

```text
Edge / Chrome tabs
      |
      | title + sanitized URL + active time
      v
RAH Chronicle Extension
      |
      | localhost only
      v
RAH Chronicle Agent :18766
      |
      +--> SQLite activity log
      +--> local dashboard
      +--> daily deterministic report
      +--> optional AI summary
```

## Planned v0.2

- RAH system-tray app.
- Project auto-detection and grouping (Raven Core, Browser, RAH OS, Cloudflare, etc.).
- Optional GitHub commit/PR enrichment.
- Explicit opt-in ChatGPT conversation-text extraction for selected work chats only.
- Daily/weekly timeline charts.
- Export to RAH Cloud / Chronicle archive.
- One-click packaging into a signed Windows installer.
