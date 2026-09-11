# RAH Raven Vision v0.3

Raven Vision v0.3 reduces manual screenshot/copy-paste work while keeping message sending under explicit user control.

## ChatGPT userscript features

- Remembers the selected monitor, area coordinates and reusable task prompt in local browser storage.
- `Bilde + oppdrag` captures the selected source, attaches the image to the current ChatGPT composer and inserts the configured task prompt.
- `Alt+Shift+R` performs the same selected-source + prompt flow.
- `Alt+Shift+1..9` captures a specific monitor.
- `Alt+Shift+A` captures the active window after a short switch delay.
- `Alt+Shift+O` captures the configured desktop area.
- Displays canonical Raven Bridge health status.
- Provides a direct button to open the local Raven Vision UI.
- Never presses ChatGPT Send automatically.

## Local boundary

The userscript talks only to the canonical local Raven Bridge at `http://127.0.0.1:18765`. Screen images stay on the local bridge until the user explicitly attaches them to the ChatGPT composer.

## Validation

`.github/workflows/validate-raven-vision-v03.yml` runs `node --check`, verifies the v0.3 interaction contract, rejects automatic-send markers and requires the canonical loopback endpoint.
