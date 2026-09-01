# RAH Home Discovery – punkt 2

## Status: FUNGERENDE PROTOTYPE – passiv + eksplisitt aktiv lokal discovery

Punkt 1, RAH Home Control Stable/MVP, er ferdig. Punkt 2 har nå en fungerende ende-til-ende prototype for både passiv Windows-discovery og en strengt avgrenset aktiv lokalnettmodus, med eksplisitt godkjenning inn i Home Control.

## Implementert prototype

### 1. Passiv Windows-kilde

`RAH-HOME-DISCOVERY.ps1` leser eksisterende Windows IPv4 neighbor-cache med `Get-NetNeighbor` og adaptermetadata med `Get-NetAdapter`. Resultatet er JSON med schema `rah-home-discovery-cache`, versjon 1 og mode `passive-neighbor-cache`.

Den passive kilden sender ingen pakker selv.

### 2. Aktiv lokalnett-kilde

`RAH-HOME-DISCOVERY-ACTIVE.ps1` er en separat, eksplisitt aktiv prototype.

Sikkerhetsavgrensning:

- kjører ikke uten `-Start`,
- velger bare aktiv privat RFC1918 IPv4-adapter,
- støtter kun lokale subnett fra `/24` til `/30`,
- skanner maksimalt 254 host-adresser,
- bruker kun ICMP echo,
- har kort timeout og forsinkelse mellom forespørsler,
- bruker ingen portskanning, TCP/UDP-probing, HTTP-probing eller `nmap`,
- resultatet merkes `mode: active-local-subnet`, `passive: false`,
- hver kandidat må fortsatt godkjennes manuelt i Inbox før Home Control endres.

`RAH-HOME-DISCOVERY-ACTIVE-RUN.ps1` krever i tillegg at brukeren skriver `JA` før den sender aktiv trafikk. Runneren skriver resultatet til Downloads, åpner Inbox og markerer JSON-filen i Explorer.

### 3. Discovery Inbox v0.2

`RAH-HOME-DISCOVERY-INBOX.html` validerer nå begge eksplisitte modes:

- `passive-neighbor-cache` med `passive: true`,
- `active-local-subnet` med `passive: false`.

Nettsiden gjør fortsatt ingen nettverksdiscovery selv. Den importerer bare JSON lokalt.

Kandidater vises som `PASSIV KANDIDAT` eller `AKTIV KANDIDAT`. Ingen kandidat lagres automatisk. Hver kandidat må trykkes gjennom `Godkjenn til Home Control`. Duplikat-IP blokkeres, lagringsfeil rulles tilbake, og ny kandidat starter som `Ikke valgt` / `Annet` / `Ubestemt`.

## Bruk på Windows

Passiv one-click:

`powershell -ExecutionPolicy Bypass -File .\RAH-HOME-DISCOVERY-RUN.ps1`

Aktiv one-click på eget/autoriserte lokalnett:

`powershell -ExecutionPolicy Bypass -File .\RAH-HOME-DISCOVERY-ACTIVE-RUN.ps1`

Direkte aktiv kjøring:

`powershell -ExecutionPolicy Bypass -File .\RAH-HOME-DISCOVERY-ACTIVE.ps1 -Start -OutputPath .\rah-home-discovery-active.json`

## Tester og CI

- `python tests/test_home_discovery_contract.py`
- `python tests/test_home_discovery_inbox_contract.py`
- `python tests/test_home_discovery_active_contract.py`

GitHub Actions:

- `.github/workflows/validate-home-discovery-foundation.yml`
- `.github/workflows/validate-home-discovery-inbox.yml`
- `.github/workflows/validate-home-discovery-active.yml`

Den aktive kontrakten låser eksplisitt start, RFC1918-avgrensning, `/24`–`/30`, maksimum 254 hosts og ICMP-only, og forbyr port-/tjenesteprobing.

## Prototype-kriterium

**Fungerende prototype er oppnådd for discovery → validering → menneskelig godkjenning → lokalt Home Control-enhetsregister.**

Den aktive prototypen er bevisst konservativ. Neste funksjonelle milepæl er enkel pairing/identifisering av godkjente enheter, ikke bredere eller mer aggressiv scanning.

## Neste milepæler – bevart

- Enkel sammenkobling og eksplisitt godkjenning/identifisering av enheter.
- Bedre enhetsnavn og produsentidentifikasjon uten invasiv probing.
- Clustering mellom godkjente noder.
- Større eller flere AI-hjerner.
- Alternative konfigurasjoner for ledernode, delt arbeid og uavhengige noder.
- Fysisk enhetsstyring som egen milepæl med eksplisitte sikkerhets- og feilhåndteringskrav.
