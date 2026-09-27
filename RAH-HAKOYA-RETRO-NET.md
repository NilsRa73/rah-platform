# RAH Håkøya RetroNet

**Status:** Project plan / prototype track  
**Dato:** 2026-09-27  
**Del av:** RAH Social + Håkøya Supernett

## Idé

RAH Håkøya RetroNet skal gjøre gamle spillmaskiner, PC-er, Android-enheter, projektorer og Smart-TV-er til ett enkelt lokalt retrospillmiljø over Håkøya Supernett.

Målet er at en nabo eller venn skal kunne koble til en enhet, trykke **INSTALLER / BLI MED**, koble en håndkontroll til og få en enkel meny med retrospill, lokale spillrom, scoreboards og push-to-talk.

## Plattformspor

### 1. Windows / PC Arcade
- MAME for arkade-emulering.
- RetroArch for flere klassiske systemer.
- Fullskjerm RAH-meny for TV, ultrawide og hjemmelagde arkadekabinetter.
- Støtte for USB/Bluetooth-håndkontroller, arcade sticks og knapper.
- Én skrivebordssnarvei: **RAH RETRO**.

### 2. Batocera
- Dedikert USB/SSD-boot for maskiner som skal være rene retro-konsoller.
- Kan brukes på eldre reserve-PC-er og framtidige Håkøya-spillnoder.
- RAH-tema, serverkobling og lokal profil legges oppå Batocera-konfigurasjonen.

### 3. Android / Android TV / Smart-TV
- Lett klient for telefon, nettbrett, Android-projektor og Android TV.
- RetroArch-basert emulatorprofil der det passer.
- Stor touch-/fjernkontrollvennlig RAH-meny.
- Mulighet for game-streaming fra sterkere PC-node når TV-en ikke bør emulere lokalt.

## Håkøya Supernett-server

Serveren blir felles knutepunkt for:
- enhetsregistrering og vennlige enhetsnavn
- spillkatalog/metadata og artwork
- lokale highscore-lister og utfordringer
- profiler og favoritter
- save/sync for støttede spill
- installasjonsmanifest og oppdateringer
- lokal lobby: "Hvem spiller nå?"
- enkel lokal status for PC-er og arcade-stasjoner
- **RAH Walkie-Talkie Wi-Fi**: push-to-talk-rom over lokalnettet

### Walkie-Talkie Wi-Fi
En enkel push-to-talk-modus for Håkøya Supernett:
- kanaler som **RETRO**, **NABO**, **TEKNISK** og midlertidige spillrom
- hold inne knapp for å snakke
- lokal/LAN-først, med tydelig mikrofonindikator
- ingen skjult opptak
- senere støtte for headset, mobil, PC og Android TV

## RAH Retro One-Click v0.1

Windows-installasjonen skal etter hvert gjøre dette i én kjøring:

1. PRECHECK av Windows, nettverk, lagringsplass, lyd, GPU og kontroller.
2. Installer/oppdater godkjente emulatorer og frontend fra offisielle kilder.
3. Opprett `C:\RAH\Retro\` med config, saves, artwork og lokal cache.
4. Finn Håkøya Supernett-server eller bruk lokal/offline modus.
5. Opprett **RAH RETRO**-snarvei.
6. Kjør controller-test og skjerm/lyd-test.
7. Start RAH Retro-menyen.
8. POSTCHECK med tydelig **PASS / CHECK / FAIL**.

Profiler:
- **PLAYER PC** – vanlig Windows-maskin.
- **ARCADE CABINET** – kiosk/fullskjerm, arcade-knapper og joystick.
- **RETRO NODE** – maskin som også kan bidra med streaming/compute.
- **SERVER** – Håkøya Supernett-tjenester og lokal katalog.

## Spillbibliotek og ROM-policy

RAH-pakken skal **ikke distribuere kommersielle ROM-er, BIOS-filer eller piratkopiert innhold**. One-click-installasjonen kan installere emulatorer/frontends og opprette riktige mapper, men brukeren legger inn egne lovlige dumpede spill, lisensiert innhold eller spill som er frigitt lovlig.

MAME-dokumentasjonen presiserer at ROM-, disk- og medieavbildninger normalt er opphavsrettsbeskyttet. Batocera har egne system-/MAME-guider for organisering og kompatibilitet.

Offisielle kilder:
- MAME: https://www.mamedev.org/
- MAME docs: https://docs.mamedev.org/
- Batocera: https://batocera.org/
- Batocera systems: https://wiki.batocera.org/systems
- RetroArch/Libretro: https://www.retroarch.com/

## Første byggepakke

**RAH Håkøya RetroNet v0.1 Candidate**
- prosjekt-/serverstruktur
- Windows one-click bootstrap
- RAH Retro launcher
- emulator discovery/install-manifest
- controller diagnostics
- LAN server discovery
- lokal spillerprofil
- PTT/walkie-talkie proof-of-concept
- Android/TV-klientplan

## Senere idéer

- lokale turneringer: Pac-Man, Galaga, Street Fighter, Mario Kart-lignende oppsett der lovlig
- RAH Gammon og sjakk i samme lounge
- vertikal 65" TV som ekte hjemme-arcade
- Quest 3-visning av spillrom/scoreboard
- "bring your controller" gjestemodus
- retro-kvelder mellom hus på Håkøya
- streaming fra sterk PC til svak TV/projektor
- lokal BBS-følelse med chat, scoreboards og utfordringer

## Mål

**Én meny. Én installasjon. Mange gamle maskiner. Ett lokalt spillnett.**

RAH Håkøya RetroNet skal gjøre Håkøya Supernett til både teknisk nabolagsnett og en sosial retro-arcade.
