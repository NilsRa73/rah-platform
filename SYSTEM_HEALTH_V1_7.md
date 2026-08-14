# RAH Raven System Health v1.7

System Health is the integrated diagnostics panel for the RAH Raven Command Center.

## Open it

1. Open https://nilsra73.github.io/rah-platform/
2. Refresh with `Ctrl + F5`.
3. Open **Innstillinger**.
4. Find **Raven System Health v1.7**.
5. Press **Kjør full systemkontroll**.

The panel loads with the Command Center, but diagnostics run only after you press **Kjør full systemkontroll**. No automatic system check runs on page load.

## Services checked

- Command Center core state
- Integrated Raven Vision module
- Desktop Bridge at `http://127.0.0.1:18765/health`
- LM Studio models at `http://127.0.0.1:1234/v1/models`
- Supabase login and Cloud Sync module
- Browser voice recognition and speech synthesis
- Mission Engine v1.5

## Status meanings

- **KLAR**: the service is available.
- **FEIL**: the service is unavailable or incomplete.
- **VENTER**: the service has not been checked yet.

Every failed check includes a direct repair instruction.

## Quick repair order

1. Refresh the Command Center with `Ctrl + F5`.
2. Log in to the RAH member account.
3. Run `desktop-bridge/start-raven-vision.bat`.
4. Open LM Studio.
5. Load a vision-capable model.
6. Start LM Studio Local Server on port `1234`.
7. Run the full system check again.

## Privacy

- Checks use only local status endpoints and the active browser session.
- System Health does not capture a screenshot.
- No passwords or secret keys are stored.
- Check history is stored locally in browser `localStorage` as summary counts and timestamps only; service details are not persisted.
- History can be cleared explicitly from the panel.

## Developer validation

```powershell
node tests/system-health.test.mjs
```

GitHub Actions runs the same validation whenever the module or integration hook changes.
