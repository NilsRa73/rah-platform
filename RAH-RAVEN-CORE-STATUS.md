# RAH Raven Core — status

Dato: 6. august 2026

## Nåværende resultat

Raven Core har nå fungerende førsteversjoner av:

1. Raven Vision Core
2. Raven Council
3. Project Brain-overføring
4. Mission Control-overføring
5. skrivebeskyttet Agent Runner
6. Raven Core Demo Runner
7. lokal Bridge-proxy for tekst- og vision-AI
8. énklikk-launcher med lokale sikkerhetstester
9. automatiske valideringer i GitHub Actions

Den komplette planlagte kjeden finnes nå i kode:

`Vision → Project Brain → Council → Mission Control → Agent Runner → lagret testresultat`

Dette er kontrollert lokal autonomi, ikke fri autonom tilgang. Brukeren velger fangst, lagring, planoverføring og hver Agent Runner-kjøring eksplisitt.

## Raven Vision Core v0.1

Filer:

- `raven-vision-core.js`
- `RAH-RAVEN-VISION-CORE.html`
- `tests/raven-vision-core.test.mjs`
- `.github/workflows/validate-raven-vision-core.yml`

Funksjoner:

- Desktop Bridge-standard på port 18765
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

Den eldre `vision-module.js` bruker fortsatt port 8765. Den anbefalte inngangen er den nye Vision Core-siden. Den gamle modulen skal oppdateres eller arkiveres etter godkjent Windows-test.

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

Lokal kjede:

`Council-side → Desktop Bridge 18765 → LM Studio 1234`

Bridge-endepunkt:

- `POST /lm/chat`

Proxyen utfører ingen verktøy eller automatiske handlinger. Svaret inneholder:

- `tools_executed: false`
- `automatic_actions: false`

Council kan:

- oppdage lokal tekstmodell
- kjøre rollene sekvensielt
- stoppes under kjøring
- vise delresultater og uenighet
- lage Chair-beslutning
- lagre i Project Brain
- gjøre planpunkter om til Mission Control-oppgaver
- eksportere Markdown
- kjøre trygg demo uten modell

## Raven Agent Runner v0.1.1

Filer:

- `desktop-bridge/agent_runner.py`
- `RAH-RAVEN-AGENT-RUNNER.html`
- `desktop-bridge/test_agent_runner.py`
- `tests/raven-agent-runner.test.mjs`
- `.github/workflows/validate-raven-agent-runner.yml`

Modus:

- `read-only-allowlist`
- ingen vilkårlige kommandoer
- ingen shell-streng
- aldri `shell=True`
- ingen filskriving
- ingen automatisk kjøring
- eksplisitt `confirm=true` kreves for hver handling

Tillatte første capabilities:

- liste prosjektfiler
- lese Git-status
- teste Raven Council
- teste Raven Vision Core
- teste Raven Core Demo
- teste Mission Engine
- teste Bridge-sikkerhet

Agent Runner-siden kan lagre resultatet i Project Brain eller aktiv mission. Et Mission-steg kan bare markeres ferdig etter en separat brukerbekreftelse.

## Raven Core Demo Runner v0.2

Filer:

- `RAH-RAVEN-CORE-DEMO.html`
- `tests/raven-core-demo.test.mjs`
- `.github/workflows/validate-raven-core-demo.yml`

Demo Runner kontrollerer seks ledd:

1. Bridge, lokal modell og Agent Runner-modus er klare.
2. Vision-resultat finnes.
3. Vision-resultatet er lagret i Project Brain.
4. Council-resultat finnes.
5. Council-planen er sendt til Mission Control.
6. En skrivebeskyttet Agent-kjøring er lagret i aktiv mission.

Siden markerer bare ett neste steg med gull. Den erklærer ikke kjeden ferdig før Agent-resultatets ID faktisk finnes i den aktive missionen.

## Desktop Bridge og sikkerhet

`desktop-bridge/raven_bridge.py` beskytter:

- `/capture/*`
- `/lm/*`
- `/case*`
- `/chronicle*`
- `/agent/*`

Tillatt er:

- lokale Raven-filer med Origin `null`
- `http://127.0.0.1:18765`
- `http://localhost:18765`
- direkte lokale kall uten Origin-header

Fremmede nettsteder avvises med HTTP 403. Sikkerhetstesten kontrollerer fangst, LM, Case Center, Chronicle og Agent Runner.

Bridge-helsestatus rapporterer nå:

- `council_proxy: true`
- `agent_runner: true`
- `agent_runner_version`
- `agent_runner_mode: read-only-allowlist`

## Autoritativ start

Launcher: `START-RAH-RAVEN-V2.bat` v2.8.

Den:

1. kontrollerer eller åpner LM Studio
2. oppretter eller bruker lokal Python-venv
3. installerer nødvendige pakker
4. kompilerer Bridge- og Agent-filer
5. kjører Chronicle-, AI-, sikkerhets- og Agent Runner-tester
6. starter kanonisk Bridge på port 18765
7. venter til Case Center, Chronicle, Council-proxy og Agent Runner er bekreftet
8. åpner `RAH-RAVEN-START.html`

På startsiden trykkes **Start Raven Core-demoen**, og deretter følges bare det gullmarkerte steget.

## CI-status

Følgende workflows har fullførte grønne kjøringer:

- Validate Raven Vision Core
- Validate Raven Council
- Validate Raven Core Demo
- Validate Raven Agent Runner

CI kontrollerer syntaks, modulkontrakter, Project Brain-overføring, Mission-format, Origin-beskyttelse og Agent Runner-allowlist.

## Det som er kodevalidert

- JavaScript-kjernenes syntaks
- inline JavaScript i Vision, Council, Demo Runner og Agent Runner
- Council-roller og Mission-format
- Vision-endepunkter og lagringsformat
- Project Brain-overføring
- aktiv Mission-overføring
- Agent-resultat koblet til aktiv mission
- Bridge-proxyens Python-syntaks
- read-only allowlist og fravær av vilkårlig kommando
- fremmede Origins avvist for sensitive endepunkter
- deterministisk sortert prosjektfilliste

## Det som fortsatt må testes fysisk på Nils sin Windows-PC

- at launcher v2.8 starter riktig venv og kanonisk Bridge
- at Bridge svarer på port 18765 med Council og Agent Runner aktivert
- at LM Studio har en kompatibel tekstmodell
- at LM Studio har en kompatibel vision-modell
- at aktiv-vindu-fangst returnerer riktig vindu
- at ekte Council-kjøring fullfører alle seks modellkall
- at én allowlistet Agent-test kjører lokalt
- at Mission Control viser planmission og Agent-resultat
- at tilstanden består etter lukking og ny åpning av nettleseren

Kode og CI kan ikke bekrefte Windows-vindu, kjørende lokale prosesser, GPU/modellkompatibilitet eller nettleserens lokale lagring før denne testen kjøres på maskinen.

## Neste utviklingssteg etter fysisk test

1. rette eventuelle oppstarts-, modell- eller vindusfangstfeil
2. koble Council- og Agent-resultater direkte til Chronicle-endepunktene
3. bygge én godkjenningsport for fremtidige skrivehandlinger
4. legge til svært begrensede bygge-capabilities, én etter én
5. kjøre én ekte forbedring fra Vision til test og rapport
6. bruke Raven Core til å styre Raven Care og senere Lovable

## Fast sikkerhetsregel

**Vision observerer bare etter brukerens valg. Council gir råd. Mission Control organiserer. Agent Runner kjører bare eksplisitt tillatte handlinger etter bekreftelse. Risikable handlinger krever en egen godkjenningsport.**
