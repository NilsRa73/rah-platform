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
7. eksplisitt Chronicle Memory Sync
8. lokal Bridge-proxy for tekst- og vision-AI
9. énklikk-launcher med lokale sikkerhetstester
10. automatiske valideringer i GitHub Actions

Den komplette kjeden finnes nå i kode:

`Vision → Project Brain → Council → Mission Control → Agent Runner → privat Chronicle-metadata`

Dette er kontrollert lokal autonomi, ikke fri tilgang. Brukeren velger fangst, lagring, planoverføring, hver Agent Runner-kjøring og Chronicle-synkronisering eksplisitt.

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
- lokal bildeopplasting
- lokal vision-analyse gjennom `/lm/analyze`
- stopp av pågående analyse
- lokal historikk uten lagring av bildet
- lagring av tekstresultat i Project Brain og aktiv mission
- Markdown-eksport

Den eldre `vision-module.js` bruker fortsatt port 8765. Den anbefalte inngangen er Vision Core. Den gamle modulen oppdateres eller arkiveres etter godkjent Windows-test.

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

Council kan oppdage lokal modell, kjøre rollene sekvensielt, stoppes, vise delresultater, lage Chair-beslutning, lagre i Project Brain, opprette Mission Control-oppgaver og eksportere Markdown.

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
- ingen endring av prosjektfiler
- ingen automatisk kjøring
- eksplisitt `confirm=true` for hver handling

Tillatte første capabilities:

- liste prosjektfiler
- lese Git-status
- teste Raven Council
- teste Raven Vision Core
- teste Raven Core Demo
- teste Mission Engine
- teste Bridge-sikkerhet

Fillisten er deterministisk sortert. Agent-resultater kan lagres i Project Brain eller aktiv mission. Et Mission-steg kan bare markeres ferdig etter separat bekreftelse.

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

Siden markerer bare ett neste steg med gull og erklærer ikke kjeden ferdig før Agent-resultatets ID finnes i missionen.

## Raven Memory Sync v0.1

Filer:

- `raven-chronicle-sync.js`
- `RAH-RAVEN-MEMORY-SYNC.html`
- `tests/raven-chronicle-sync.test.mjs`
- `.github/workflows/validate-raven-chronicle-sync.yml`

Memory Sync er separat for å bevare Agent Runner sin read-only-garanti. Den skriver bare etter avkrysset bekreftelse og et eksplisitt klikk.

Chronicle kan få privat metadata om:

- at en Vision-analyse ble fullført
- at Council ble fullført
- at en Agent-capability ble kjørt og om den besto
- at en Mission ble oppdatert

Følgende sendes aldri til Chronicle av Memory Sync:

- bilder
- Vision-prompt eller Vision-svar
- Council-mål, råd eller Chair-svar
- dokumenttekst
- kommando-output eller feillogg
- Mission-tittel, oppgaveinnhold eller resultater

Personverntesten konstruerer falske hemmeligheter i alle disse feltene og kontrollerer at ingen av dem finnes i Chronicle-payloaden.

## Desktop Bridge og sikkerhet

`desktop-bridge/raven_bridge.py` beskytter:

- `/capture/*`
- `/lm/*`
- `/case*`
- `/chronicle*`
- `/agent/*`

Tillatt er lokale Raven-filer med Origin `null`, lokal Bridge-origin og direkte lokale kall uten Origin-header. Fremmede nettsteder avvises med HTTP 403.

Bridge-helsestatus rapporterer:

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

Deretter brukes **Start Raven Core-demoen**. Når private statusmetadata skal bevares i Chronicle, brukes **Memory Sync**.

## CI-status

Følgende workflows har fullførte grønne kjøringer:

- Validate Raven Vision Core
- Validate Raven Council
- Validate Raven Core Demo
- Validate Raven Agent Runner
- Validate Raven Chronicle Sync

CI kontrollerer syntaks, modulkontrakter, Project Brain-overføring, Mission-format, Origin-beskyttelse, Agent Runner-allowlist og Memory Sync-personvern.

## Det som er kodevalidert

- JavaScript- og Python-syntaks
- Council-roller og Mission-format
- Vision-endepunkter og lagringsformat
- Project Brain- og Mission-overføring
- Agent-resultat koblet til aktiv mission
- read-only allowlist og fravær av vilkårlig kommando
- fremmede Origins avvist
- deterministisk prosjektfilliste
- Memory Sync uten sensitive innholdsfelter

## Det som fortsatt må testes fysisk på Nils sin Windows-PC

- launcher v2.8 og lokal venv
- Bridge på port 18765 med Council og Agent Runner aktivert
- kompatibel tekstmodell i LM Studio
- kompatibel vision-modell i LM Studio
- aktiv-vindu-fangst mot riktig vindu
- ekte Council-kjøring med alle seks modellkall
- én allowlistet Agent-test
- Mission Control med planmission og Agent-resultat
- Memory Sync til lokal Chronicle
- gjenoppretting etter lukking og ny åpning

Kode og CI kan ikke bekrefte Windows-vindu, kjørende prosesser, GPU/modellkompatibilitet eller nettleserens lokale lagring før denne testen kjøres på maskinen.

## Neste utviklingssteg etter fysisk test

1. rette eventuelle oppstarts-, modell- eller vindusfangstfeil
2. bygge en separat godkjenningsport for fremtidige skrivehandlinger
3. legge til svært begrensede bygge-capabilities én etter én
4. kjøre én ekte forbedring fra Vision til test og Chronicle-metadata
5. bruke Raven Core til å styre Raven Care og senere Lovable

## Fast sikkerhetsregel

**Vision observerer bare etter brukerens valg. Council gir råd. Mission Control organiserer. Agent Runner kjører bare eksplisitt tillatte handlinger etter bekreftelse. Memory Sync skriver bare privat minimumsmetadata etter et eget samtykkeklikk.**
