# RAH Håkøya RetroNet

**Versjon:** v0.2-plan  
**Status:** Project plan / prototype track  
**Dato:** 2026-09-27  
**Del av:** RAH Social + Håkøya Supernett

## Visjon

RAH Håkøya RetroNet skal gjøre PC-er, eldre maskiner, Android-enheter, projektorer, Smart-TV-er og hjemmelagde arcade-kabinetter til ett lokalt retrospillmiljø over Håkøya Supernett.

Målet er: **Én installasjon. Én meny. Mange maskiner. Ett lokalt spillnett.**

En nabo eller venn skal kunne koble til en enhet, trykke **INSTALLER / BLI MED**, koble til håndkontroll og få en enkel RAH-meny med retrospill, lokale spillrom, highscore, stemmekanaler og trygg enhetsdeling.

## Plattformspor

### 1. Windows / PC Arcade
- MAME for arkade-emulering.
- RetroArch for flere klassiske systemer.
- Fullskjerm RAH-meny for TV, ultrawide og arcade-kabinett.
- USB/Bluetooth-håndkontrollere, arcade sticks, knapper og tastatur.
- Én skrivebordssnarvei: **RAH RETRO**.

### 2. Batocera
- USB/SSD-boot for eldre PC-er og dedikerte retro-noder.
- RAH-tema og Håkøya-serverkobling rundt Batocera/EmulationStation.
- Enkel controller-pairing og egen profil per stasjon.
- Egnet for maskiner som skal starte rett inn i spillmodus.

### 3. Android / Android TV / Smart-TV
- Lett RAH-klient for telefon, nettbrett, Android-projektor og Android TV.
- RetroArch-basert lokal emulering der maskinvaren passer.
- Game-streaming fra sterk PC-node til svak TV/projektor.
- Stor fjernkontroll-/touchvennlig meny.

## Håkøya Supernett-server

Supernett-serveren blir felles knutepunkt for:
- enhetsregistrering og vennlige enhetsnavn
- spillkatalog/metadata/artwork
- lokale highscore-lister og utfordringer
- profiler, favoritter og gjestemodus
- save/sync for støttede emulatorer
- installasjonsmanifest og oppdateringer
- lokal lobby: **Hvem spiller nå?**
- status for PC-er, TV-er og arcade-stasjoner
- RAH Walkie-Talkie Wi-Fi
- RAH Bifröst Bluetooth Fabric

## RAH Walkie-Talkie Wi-Fi

Push-to-talk over lokalnettet:
- kanaler som **RETRO**, **NABO**, **TEKNISK** og midlertidige spillrom
- hold inne knapp for å snakke
- headset/mobil/PC først, senere TV/projektor der plattformen tillater det
- tydelig mikrofonindikator
- ingen skjult opptak
- lokal/LAN-først, med mulighet for senere fjernkobling mellom inviterte noder

## RAH Bifröst Bluetooth Fabric

Målet er ikke å skrive en ny Bluetooth-driver fra bunnen av i første versjon. Vi bygger et **RAH-kontrollag over Windows Bluetooth API-er og Linux/BlueZ**, slik at Bluetooth blir enklere og mer nyttig enn den vanlige systemmenyen.

### Første funksjoner
- samlet oversikt over Bluetooth-adaptere på alle godkjente Håkøya-noder
- finn/pair/glem enhet fra én RAH-meny
- controller-profiler og automatisk mapping
- batteristatus og signalstyrke der enheten eksponerer dette
- navn som **Stue Controller 1**, **Kjells Headset**, **Arcade Stick**
- QR/invite-basert pairing der teknisk mulig
- automatisk gjenkobling til foretrukket node
- varsling ved konflikt: en enhet er allerede i bruk på en annen node
- enkel flytting av logisk funksjon mellom noder, f.eks. controller eller sensor
- gateway for BLE/GATT-sensorer og små enheter
- RFCOMM/datafunksjoner for kompatible Classic Bluetooth-enheter
- kobling mot Walkie-Talkie, RetroNet og Home Control

### Bluetooth-pool
En fysisk Bluetooth-enhet er fortsatt koblet til en konkret radio/node. **Poolen** betyr derfor at Supernett-serveren holder orden på hvilke adaptere og enheter som finnes hvor, og eksponerer funksjonene på høyere nivå til andre RAH-klienter.

Eksempel:
1. En Bluetooth-controller er fysisk paret med PC-en i stua.
2. RAH Bifröst registrerer controlleren som tilgjengelig.
3. RetroNet kan vise den som en ressurs og bruke den lokalt.
4. Senere kan input-eventer, sensordata eller andre støttede funksjoner videresendes over LAN til en annen godkjent RAH-node.

Vi starter med funksjoner som tåler nettverksforsinkelse. Lyd og realtime gaming-input over flere hopp testes senere og mer konservativt.

## RAH Retro One-Click v0.1 Candidate

Windows-installasjonen skal gjøre dette i én kjøring:

1. **PRECHECK** – Windows, nettverk, lagringsplass, lyd, GPU, Bluetooth og kontrollere.
2. **INSTALL / REPAIR** – hent godkjente emulatorer/frontends fra offisielle kilder.
3. Opprett `C:\RAH\Retro\` med config, saves, artwork og lokal cache.
4. Finn Håkøya Supernett-server eller bruk offline-modus.
5. Installer **RAH Bifröst Bluetooth Client** og lokal node-agent når valgt.
6. Opprett **RAH RETRO**-snarvei på skrivebordet.
7. Kjør controller-, Bluetooth-, skjerm- og lydtest.
8. Start RAH Retro-menyen.
9. **POSTCHECK** – tydelig **PASS / CHECK / FAIL**.

Profiler:
- **PLAYER PC** – vanlig Windows-maskin.
- **ARCADE CABINET** – kiosk/fullskjerm, joystick og knapper.
- **RETRO NODE** – kan også bidra med streaming/compute.
- **SERVER** – Håkøya Supernett, katalog, lobby og Bifröst registry.
- **TV CLIENT** – Android/TV/projektor med enkel fjernkontrollmeny.

## Prioritering

### P0 — Frys arkitektur og mapper
- Standard: `C:\RAH\Retro\`
- Én prosjekt-ID og én catalog-entry.
- Ingen nye parallelle RetroNet-versjoner uten tydelig Candidate/Stable-navn.

### P1 — Windows One-Click
Bygg **START-HER.cmd** som gjør PRECHECK → INSTALL/REPAIR → START → POSTCHECK og lager snarvei. Dette gir raskest vei til faktisk bruk på hoved-PC og nabo-PC-er.

### P2 — Retro Launcher
Én RAH black/gold controller-first meny med MAME, RetroArch, lokale spill og serverstatus.

### P3 — Håkøya Server MVP
Enhetsregister, lobby, profiler, highscores, install-manifest og health/status.

### P4 — Walkie-Talkie Wi-Fi MVP
Lokal push-to-talk mellom to Windows/Android-enheter. Deretter rom/kanaler og headset-integrasjon.

### P5 — RAH Bifröst Bluetooth v0.1
Start med discovery, pairing, friendly names, battery/signal, controller-profiler og node-register. Ikke forsøk full driver-erstatning først.

### P6 — Android / Android TV-klient
RAH Retro launcher + server discovery + PTT + status. Lokal emulering eller streaming avhengig av enhet.

### P7 — Batocera-integrasjon
Auto-discovery av server, RAH-profil, controller-status og enkel import av config uten å bryte Batoceras normale oppdateringsløp.

### P8 — Bluetooth Pool / avanserte broer
Eksperimenter med input-forwarding, BLE sensor gateways, audio routing og flere adaptere/noder. Bare funksjoner som er stabile nok går videre til Candidate.

## Første konkrete leveranse

**RAH Håkøya RetroNet v0.1 Candidate**
- Windows one-click bootstrap
- RAH Retro launcher
- emulator discovery/install-manifest
- controller diagnostics
- Bluetooth diagnostics
- LAN server discovery
- lokal spillerprofil
- PTT proof-of-concept
- Bifröst registry proof-of-concept
- Android/TV-klientplan
- PASS/CHECK/FAIL sluttrapport

## Spillbibliotek og ROM-policy

RAH-pakken distribuerer ikke kommersielle ROM-er, BIOS-filer eller piratkopiert innhold. Installereren kan installere emulatorer/frontends og opprette mapper; brukeren legger inn egne lovlige dumps, lisensiert innhold eller lovlig frigitt programvare.

Offisielle referanser:
- MAME: https://www.mamedev.org/
- MAME docs: https://docs.mamedev.org/
- Batocera: https://batocera.org/
- Batocera systems/controllers: https://wiki.batocera.org/
- RetroArch: https://www.retroarch.com/
- Microsoft Bluetooth APIs: https://learn.microsoft.com/windows/apps/develop/devices-sensors/bluetooth
- BlueZ: https://bluez.readthedocs.io/

## Senere idéer

- lokale turneringer og highscore-kvelder
- RAH Gammon og sjakk i samme lounge
- vertikal 65" TV som hjemme-arcade
- Quest 3-visning av spillrom/scoreboard
- **Bring your controller** gjestemodus
- BBS-inspirert chat, scoreboards og utfordringer
- game-streaming fra sterk PC til svak TV/projektor
- Bluetooth-sensorer, knapper, beacons og DIY-enheter som RAH-ressurser
- ett eget **RAH Bifröst** kontrollpanel som er raskere og enklere enn Windows' vanlige Bluetooth-innstillinger

## Mål

**Én meny. Én installasjon. Mange gamle maskiner. Ett lokalt spillnett.**

RAH Håkøya RetroNet skal gjøre Håkøya Supernett til både teknisk nabolagsnett, lokal retro-arcade og en testarena for RAHs egne nettverks- og Bluetooth-verktøy.
