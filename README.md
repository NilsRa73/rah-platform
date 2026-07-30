# RAH Raven Platform

RAH Raven Platform is a local-first command center for projects, missions, voice control, GitHub synchronization, member login, and AI-assisted screen understanding.

## Live pages

- Command Center: https://nilsra73.github.io/rah-platform/
- Raven Vision v1.3: https://nilsra73.github.io/rah-platform/vision.html
- Repository: https://github.com/NilsRa73/rah-platform

## Current architecture

### `index.html`
The stable RAH Raven Command Center v1.2. It contains project tracking, missions, voice commands, Project Brain, GitHub synchronization, Supabase member login, and the original embedded Vision panel.

### `vision.html`
The completed Raven Vision v1.3 workspace. It provides:

- PNG, JPG, and WEBP upload
- drag-and-drop images
- browser-native screen/window selection
- active-window capture through Desktop Bridge
- automatic LM Studio model discovery
- OpenAI-compatible local vision requests
- configurable LM Studio and bridge addresses
- abortable analysis
- local browser history
- copy, save, and JSON export
- clear diagnostics for LM Studio, CORS, model, and bridge errors

### `desktop-bridge/`
A localhost-only Python service that captures the currently active Windows window and returns it as a PNG data URL.

## Fast Windows setup

1. Install Python 3.11 or newer.
2. Download or clone this repository.
3. Open `desktop-bridge`.
4. Double-click `start-bridge.bat`.
5. In LM Studio, load a vision-capable model.
6. Start LM Studio Local Server on port `1234` and enable CORS/local network access.
7. Open Raven Vision and press **Test LM Studio**.
8. Press **Hent aktivt vindu** or **Velg skjerm/vindu**, then **Analyser skjermbilde**.

The batch file creates its own `.venv`, installs dependencies, starts the bridge on `127.0.0.1:8765`, and opens Raven Vision.

## Manual bridge setup

```powershell
cd desktop-bridge
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
python server.py
```

Health check:

```text
http://127.0.0.1:8765/health
```

Capture endpoint:

```text
http://127.0.0.1:8765/capture/active-window
```

## LM Studio requirements

Raven Vision uses LM Studio's OpenAI-compatible endpoint:

```text
POST http://127.0.0.1:1234/v1/chat/completions
```

The loaded model must support image input. A text-only model can answer normal text prompts but cannot inspect screenshots. Raven Vision obtains available model IDs from:

```text
GET http://127.0.0.1:1234/v1/models
```

## Tests

From the `desktop-bridge` folder:

```powershell
.\.venv\Scripts\python.exe -m unittest -v test_server.py
```

The tests validate:

- bridge health response
- successful screenshot JSON response
- structured JSON error handling

## Privacy and security

- The bridge binds to `127.0.0.1` by default, not the public network.
- Screenshots are sent only to the configured local LM Studio address.
- Analysis history is stored in browser `localStorage`.
- Supabase uses a publishable browser key; secret service-role keys must never be placed in this repository.
- The bridge returns `Cache-Control: no-store` and does not save screenshots to disk.

## Recovery

`BACKUP_V1_2.md` records the last known working v1.2 recovery commit before the Vision v1.3 completion pass.

## Troubleshooting

### Preview works but analysis says no image
Use `vision.html`. It fixes the original split-state bug where Desktop Bridge capture and LM Studio analysis used different image variables.

### LM Studio unavailable
Confirm Local Server is running at `http://127.0.0.1:1234`, CORS is enabled, and a model is loaded.

### No models found
Load a vision-capable model in LM Studio before pressing **Test LM Studio**.

### Desktop Bridge unavailable
Run `desktop-bridge/start-bridge.bat` and open the health URL. Windows Firewall should not require public access because the service is localhost-only.

### Screen/window chooser does not open
Use a current Chromium, Edge, or Firefox browser and serve the page over HTTPS. GitHub Pages already provides HTTPS.
