# RAH Raven Wheel + Vault — status

Dato: 24. august 2026

## Mål

Raven Wheel skal gjøre ChatGPT til den primære inngangen til RAH uten at brukeren må lete gjennom mange Windows-mapper og filversjoner.

## Bygget nå

### Raven Wheel v1.1.0

Fil: `RAH-RAVEN-WHEEL.user.js`

Tampermonkey-script for:

- `https://chatgpt.com/*`
- `https://chat.openai.com/*`

Wheel vises som en gull/ravn-knapp nederst til høyre og har snarveier til:

- Command Center
- Mission Control
- System Doctor med direkte systemkontroll
- RAH AI Studio
- siste Raven-filer
- Raven Vault
- filoversikt
- Raven Vision

Wheel registrerer klikk på sannsynlige ChatGPT-nedlastinger og sender bare forventet filnavn/filtype og kort lenketekst til den lokale Desktop Bridge.

Wheel stopper eller erstatter ikke nettleserens vanlige nedlasting.

### Raven Download Manager v0.1.1

Fil: `desktop-bridge/download_manager.py`

Modus: `chatgpt-expected-only`

Viktig regel:

**Download Manager skal ikke rydde eller flytte tilfeldige filer i Nedlastinger. Bare filer som Raven Wheel nettopp har registrert som forventede ChatGPT-nedlastinger kan flyttes automatisk.**

Lagring:

`Documents/RAH-Raven-Vault/YYYY/MM/DD/`

Lokal indeks inneholder:

- originalt filnavn
- lagret filnavn
- dato/tid
- kilde
- automatisk prosjekt-tag
- relativ Vault-sti
- filstørrelse
- SHA-256 for filer opptil 100 MB

Endepunkter:

- `GET /downloads/status`
- `POST /downloads/config`
- `POST /downloads/expect`
- `POST /downloads/scan`
- `GET /downloads/recent`
- `GET /downloads/search`
- `POST /downloads/open-vault`
- `POST /downloads/open-file`
- `GET /downloads/ui`

### Raven Vault dashboard

Fil: `RAH-RAVEN-DOWNLOADS.html`

Lokal adresse når Bridge kjører:

`http://127.0.0.1:18765/downloads/ui`

Dashboardet viser status, ventende ChatGPT-filer, Vault-plassering, siste fangst, søk og siste filer. Automatikk kan pauses.

### One-time installer

Fil: `INSTALL-RAH-RAVEN-WHEEL.bat`

Åpner den autoritative `RAH-RAVEN-WHEEL.user.js` fra GitHub. Tampermonkey krever én eksplisitt installasjonsgodkjenning.

### Launcher

`START-RAH-RAVEN-V2.bat` er oppdatert til v3.1.

Launcheren krever nå:

- `desktop-bridge/download_manager.py`
- `RAH-RAVEN-DOWNLOADS.html`

Den kompilerer Download Manager og godkjenner ikke Bridge som klar før `/health` rapporterer `download_manager: true`.

## Sikkerhet

`/downloads/*` inngår i Desktop Bridge sin local-origin-beskyttelse.

Fremmede nettsider skal få HTTP 403 mot Vault-API-et.

Raven Wheel bruker Tampermonkeys eksplisitte localhost-tillatelse for å kommunisere med Bridge.

Åpning av en Vault-mappe eller en indeksert fil krever `confirm=true` i det lokale API-kallet.

Download Manager har ingen slettefunksjon og bruker ikke rekursiv rydding av Nedlastinger.

## Validering

Filer:

- `tests/raven-download-manager.test.mjs`
- `desktop-bridge/test_raven_bridge_security.py`
- `.github/workflows/validate-raven-download-manager.yml`

CI validerer:

- Python-syntaks
- userscript-syntaks
- Wheel/Manager-kontrakten
- at Download Manager bare jobber mot forventede filer
- at `/downloads/*` er lokalbeskyttet
- at Raven Vault-siden serveres gjennom den kanoniske Bridge på port 18765

## Første fysiske Windows-test

1. Oppdater/laste ned siste `rah-platform`.
2. Dobbeltklikk `INSTALL-RAH-RAVEN-WHEEL.bat` én gang og godkjenn i Tampermonkey.
3. Dobbeltklikk `START-RAH-RAVEN-V2.bat` v3.1.
4. Last ChatGPT på nytt.
5. Kontroller at gull/ravn-knappen vises nederst til høyre.
6. Last ned én test-PDF fra ChatGPT.
7. Wheel skal vise «Raven følger denne nedlastingen».
8. Etter noen sekunder skal filen finnes under `Documents/RAH-Raven-Vault/<år>/<måned>/<dag>/` og under «Siste filer» i Wheel.

## Neste versjon etter godkjent test

- CURRENT/arkiv-versjonering per prosjekt
- bedre automatisk prosjektklassifisering
- søk med lokal AI over filnavn og metadata
- «Finn den PDF-en vi laget i går»-kommando
- eventuell metadata-overføring til Project Brain/Chronicle uten dokumentinnhold

## Fast regel

**ChatGPT er arbeidsflaten. Raven Wheel er inngangen. Raven Vault er lageret. Windows-mappene er bare underliggende lagring.**
