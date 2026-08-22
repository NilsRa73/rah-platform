# RAH Local Device Adapter

Status: **v0.1 Candidate**

## Fullført

Første lokale adaptergrense mellom RAH Home Control og senere fysisk enhetsstyring er implementert i `desktop-bridge/local_device_adapter.py`.

Adapteren støtter kun tre eksplisitte handlinger:

- `PING_DEVICE` – tester selve adaptergrensen uten nettverkstrafikk.
- `GET_STATUS` – returnerer lokal adapterstatus.
- `LOCAL_TEST_COMMAND` – simulerer en kommando uten systemendring.

Alle forespørsler bruker strukturert `device_id`, `action` og `parameters`. Resultater inneholder `ok`, `device_id`, `action`, `status`, `message`, `timestamp` og `data`.

## Sikkerhetsgrense

v0.1 har med vilje ingen Wi-Fi-oppdagelse, Bluetooth, pairing, nettverksskanning, shell-kommandoer, vilkårlige prosesser eller fjernstyring. Ukjente action-ID-er avvises. Resultater logges lokalt som JSONL; dersom logging feiler returneres feil i stedet for falsk PASS.

## Test

Kjør fra `desktop-bridge`:

`python test_local_device_adapter.py`

Forventet resultat:

`PASS: RAH Local Device Adapter v0.1 contract`

Testen dekker de tre tillatte handlingene, avvisning av en ikke-tillatt `RUN_SHELL`-handling og lokal JSONL-logg.

## Neste avgrensede oppgave

Registrer adapteren i Raven Desktop Bridge med et lokalt, origin-beskyttet API for `GET_STATUS`/testhandlinger. Home Control v1.24 Stable skal ikke endres før Bridge-endepunktet har egen test.

## Senere – ikke implementert

- Oppdagelse og søk etter alle Wi-Fi-enheter.
- Enkel sammenkobling og godkjenning av enheter.
- Fysisk styring av TV, projektor, PC og andre enheter.
- Clustering mellom noder.
- Større eller flere AI-hjerner.
- Alternative leder-/arbeidsnode-konfigurasjoner.
