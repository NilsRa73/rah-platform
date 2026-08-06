# RAH Raven Core — status

Dato: 6. august 2026

## Nåværende resultat

Raven Core har nå fungerende førsteversjoner av:

1. Raven Vision Core
2. Raven Council
3. Project Brain-overføring
4. Mission Control-overføring
5. Raven Core Demo Runner
6. lokal Bridge-proxy for tekst- og vision-AI
7. automatiske statiske valideringer i GitHub Actions

Dette er ikke ennå full autonom agentdrift. Det er en kontrollert, lokal kjede hvor brukeren eksplisitt velger fangst, lagring og overføring.

## Raven Vision Core v0.1

Filer:

- `raven-vision-core.js`
- `RAH-RAVEN-VISION-CORE.html`
- `tests/raven-vision-core.test.mjs`
- `.github/workflows/validate-raven-vision-core.yml`

Funksjoner:

- riktig standardport for Desktop Bridge: 18765
- statuskontroll av Bridge og lokal modell
- eksplisitt fangst av aktivt vindu
- forsinket fangst
- nettleserens skjerm-/vindusdeling
- lokal opplasting av PNG, JPG og WEBP
- lokal vision-analyse gjennom Bridge `/lm/analyze`
- stopp av pågående analyse
- lokal historikk uten lagring av bildet
- lagring av tekstresultat i Project Brain og aktiv mission
- Markdown-eksport

Den eldre `vision-module.js` bruker fortsatt port 8765, men den anbefalte inngangen er nå den nye Vision Core-siden. Den gamle modulen skal senere enten oppdateres eller arkiveres etter at Windows-testen er godkjent.

## Raven Council v0.2

Filer:

- `raven-council.js`
- `RAH-RAVEN-COUNCIL.html`
- `tests/raven-council.test.mjs`
- `.github/workflows/validate-raven-council.yml`

Roller:

- Archivist
- Planner
- Builder
- Reviewer
- Safety
- Chair Raven

Council går nå gjennom den beskyttede lokale kjeden:

`Council-side → Desktop Bridge 18765 → LM Studio 1234`

Bridge-endepunkt:

- `POST /lm/chat`

Proxyen utfører ingen verktøy eller automatiske handlinger. Svaret inneholder eksplisitt:

- `tools_executed: false`
- `automatic_actions: false`

Council kan:

- oppdage lokal tekstmodell
- kjøre rollene sekvensielt
- stoppes under kjøring
- vise uenighet og delresultater
- lage Chair-beslutning
- lagre i Project Brain
- gjøre planpunkter om til Mission Control-oppgaver
- eksportere Markdown
- kjøre trygg demo uten modell

## Raven Core Demo Runner v0.1

Filer:

- `RAH-RAVEN-CORE-DEMO.html`
- `tests/raven-core-demo.test.mjs`
- `.github/workflows/validate-raven-core-demo.yml`

Demo Runner kontrollerer denne kjeden:

1. Bridge og lokal modell er klare.
2. Vision-resultat finnes.
3. Vision-resultatet er lagret i Project Brain.
4. Council-resultat finnes.
5. Council-planen er sendt til Mission Control.

Siden markerer bare ett neste steg med gull. Den kan også lage et trygt Council-demorespons uten AI for å kontrollere lagring og Mission-overføring.

## Sikkerhetsforbedring

`desktop-bridge/raven_bridge.py` beskytter nå sensitive lokale endepunkter mot fremmede nettsider:

- `/capture/*`
- `/lm/*`
- `/case*`
- `/chronicle*`

Tillatt er:

- lokale Raven-filer med Origin `null`
- `http://127.0.0.1:18765`
- `http://localhost:18765`
- direkte lokale kall uten Origin-header

Sikkerhetstesten kontrollerer at fremmed Origin blir avvist for fangst, LM, Case Center og Chronicle.

## Autoritativ start

1. Kjør `START-RAH-RAVEN-V2.bat`.
2. Startfilen åpner `RAH-RAVEN-START.html`.
3. Trykk **Start Raven Core-demoen**.
4. Følg bare det gullmarkerte neste steget.

## Det som er kodevalidert

- JavaScript-kjernenes syntaks
- inline JavaScript i Vision, Council og Demo Runner
- Council-roller og mission-format
- Vision-endepunkter og lagringsformat
- Project Brain-overføring
- aktiv Mission-overføring
- Bridge-proxyens Python-syntaks
- lokale sikkerhetsregler i testkode

## Det som fortsatt må prøves fysisk på Nils sin Windows-PC

- at `START-RAH-RAVEN-V2.bat` starter riktig venv og Bridge
- at Bridge svarer på port 18765
- at LM Studio har lastet en kompatibel tekstmodell
- at LM Studio har lastet en kompatibel vision-modell
- at aktiv-vindu-fangst returnerer riktig vindu
- at faktisk Council-kjøring fullfører alle seks modellkall
- at Mission Control viser planmissionen etter overføring
- at resultatene består etter lukking og ny åpning av nettleseren

Koden kan ikke bekrefte maskinvare, kjørende lokale prosesser eller modellkompatibilitet før denne testen gjennomføres på PC-en.

## Neste utviklingssteg etter Windows-testen

1. rette eventuelle lokale oppstarts- eller modellfeil
2. koble Council-beslutningen tettere til Chronicle
3. legge tillatte Agent Runner-handlinger i Desktop Bridge
4. kjøre én faktisk byggeoppgave fra plan til test og rapport
5. først deretter bruke Raven Core til å styre Raven Care og Lovable

## Fast sikkerhetsregel

**Vision observerer bare etter brukerens valg. Council gir råd. Mission Control organiserer. Desktop Bridge utfører bare eksplisitt tillatte handlinger. Risikable handlinger krever menneskelig godkjenning.**
