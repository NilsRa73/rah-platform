# RAH Raven Core — status

Dato: 6. august 2026

## Fullført i denne byggeøkten

### Raven Council v0.1

Status: **fungerende lokal førsteversjon**.

Filer:
- `raven-council.js`
- `RAH-RAVEN-COUNCIL.html`
- `tests/raven-council.test.mjs`
- `.github/workflows/validate-raven-council.yml`

Funksjoner:
- automatisk oppdagelse av modeller i LM Studio på port 1234
- fem strukturerte roller: Archivist, Planner, Builder, Reviewer og Safety
- Chair Raven samler rådene til én beslutning
- sekvensiell lokal kjøring med stoppknapp
- lokal historikk
- demo uten AI-kall
- eksplisitt lagring til Project Brain
- eksplisitt overføring av Council-plan til Mission Control
- Markdown-eksport
- ingen automatiske PC-handlinger
- automatisk syntaks- og funksjonsvalidering i GitHub Actions

Raven Start er oppdatert med Council-status og direkte knapp.

## Hva Council v0.1 gjør

Council v0.1 er en plan- og kontrollmotor. Den gjør et mål om til en kildebevisst beslutning og en planleggingsmission. Den påstår ikke at produktarbeidet er ferdig bare fordi planen er laget.

Når brukeren trykker «Send plan til Mission Control»:

1. Council-resultatet lagres i Project Brain.
2. Planpunktene blir gjort om til prosjektoppgaver.
3. En kontrollert planleggingsmission blir aktiv.
4. Mission Control kan lagre resultatet, opprette oppgavene og stoppe for kontroll i Project Brain.

## Oppdaget blokkering i Raven Vision

Den gjeldende Bridge v1.6/v1.7 bruker som standard:

- `http://127.0.0.1:18765`

Den eldre integrerte `vision-module.js` bruker fremdeles:

- `http://127.0.0.1:8765`

Dette må samles i én konfigurasjon før Vision kan kalles stabil i alle innganger.

## Neste byggepunkt

1. Lag én delt lokal konfigurasjon for Bridge og LM Studio.
2. Oppdater Vision til Bridge-port 18765 eller les porten fra konfigurasjonen.
3. Kontroller at aktiv-vindu-fangst virker mot `server_v17.py`.
4. Lag en Vision-test som oppdager gamle porter.
5. Kjør første komplette demo:
   - Vision analyserer valgt vindu
   - Council lager plan
   - Mission Control mottar planen
   - Project Brain og Chronicle lagrer resultatet

## Test Council nå

1. Åpne `RAH-RAVEN-START.html`.
2. Trykk **Raven Council**.
3. Trykk **Kjør demo uten AI** for å kontrollere skjermen.
4. Start LM Studio og last inn en tekstmodell.
5. Trykk **Test lokal AI**.
6. Skriv et mål og trykk **Kjør Council**.
7. Trykk **Send plan til Mission Control**.
8. Åpne Command Center og kontroller den aktive missionen.

## Fast sikkerhetsregel

**Council gir råd. Mission Control organiserer. Desktop Bridge utfører bare tillatte handlinger. Risikable handlinger krever menneskelig godkjenning.**
