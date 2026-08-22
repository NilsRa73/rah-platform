# RAH Local Device Adapter

Status: **v0.2 Bridge Candidate**

## Fase 1 – adapterkjerne

`desktop-bridge/local_device_adapter.py` er den lokale adaptergrensen mellom RAH Home Control og senere fysisk enhetsstyring.

Tillatte handlinger:

- `PING_DEVICE` – tester adaptergrensen uten nettverkstrafikk.
- `GET_STATUS` – returnerer lokal adapterstatus.
- `LOCAL_TEST_COMMAND` – simulerer en kommando uten systemendring.

Ukjente handlinger avvises. Resultater logges lokalt som JSONL, og loggfeil kan ikke returnere falsk PASS.

## Fase 2 – Raven Desktop Bridge

Adapteren er registrert i `desktop-bridge/raven_bridge.py`.

Lokale endepunkter:

- `GET /device/status` – adapterstatus via `GET_STATUS`.
- `POST /device/action` – strukturert allowlist-handling.
- `/health` rapporterer adapterversjon og `local-only-allowlist`-modus.

`/device/` er lagt til Raven Bridges eksisterende origin-beskyttelse. Fremmede web-origins får HTTP 403. Adapterens egen allowlist gjelder fortsatt etter origin-kontrollen.

## Tester

Fra `desktop-bridge`:

`python test_local_device_adapter.py`

Forventet:

`PASS: RAH Local Device Adapter v0.1 contract`

Deretter:

`python test_local_device_bridge.py`

Forventet:

`PASS: RAH Local Device Adapter Bridge boundary`

Bridge-testen dekker health-metadata, lokal status, tillatt PING, avvist `RUN_SHELL` og blokkering av fremmed origin.

## Neste avgrensede oppgave

Koble én eksisterende Home Control-enhet til `POST /device/action` med `PING_DEVICE`, slik at brukeren får den første synlige Home Control → Bridge → Adapter-flyten. Dette skal være en eksplisitt testknapp, ikke automatisk polling eller discovery.

## Senere – ikke implementert

- Oppdagelse og søk etter alle Wi-Fi-enheter.
- Enkel sammenkobling og godkjenning av enheter.
- Fysisk styring av TV, projektor, PC og andre enheter.
- Clustering mellom noder.
- Større eller flere AI-hjerner.
- Alternative leder-/arbeidsnode-konfigurasjoner.
