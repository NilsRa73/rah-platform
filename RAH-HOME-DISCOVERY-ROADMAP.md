# RAH Home Discovery – punkt 2

## Status: FUNGERENDE PROTOTYPE – passiv discovery + approval inbox

Punkt 1, RAH Home Control Stable/MVP, er ferdig. Punkt 2 har nå en fungerende ende-til-ende prototype for passiv Windows-discovery og eksplisitt godkjenning inn i Home Control.

## Implementert prototype

### 1. Passiv Windows-kilde

`RAH-HOME-DISCOVERY.ps1` leser eksisterende Windows IPv4 neighbor-cache med `Get-NetNeighbor` og adaptermetadata med `Get-NetAdapter`. Resultatet er maskinlesbar JSON med schema `rah-home-discovery-cache`, versjon 1.

Foundationen sender ikke ping, åpner ikke porter, gjør ikke HTTP-probing og kjører ikke subnettskanning. Den viser derfor bare enheter Windows allerede har observert.

### 2. Discovery Inbox

`RAH-HOME-DISCOVERY-INBOX.html` kan laste discovery-JSON fra fil, utklippstavle eller tekstfelt. Dokumentet valideres før kandidater vises.

- bare schema `rah-home-discovery-cache` v1 godtas,
- dokumentet og hver kandidat må være markert `passive: true`,
- IPv4 valideres,
- kandidater vises før noe lagres,
- hver kandidat må godkjennes eksplisitt,
- eksisterende IPv4 i Home Control blokkeres som duplikat,
- godkjent kandidat får nøytral startplassering `Ikke valgt`, type `Annet` og rolle `Ubestemt`,
- forbindelse avledes konservativt fra adaptermetadata som Wi-Fi eller Ethernet,
- kandidatens lokale `online`-status settes bare til sann når Windows-state er `Reachable`,
- lagringsfeil rulles tilbake.

Inbox bruker samme lokale Home Control-nøkkel `rah-home-control-v03`, slik at en godkjent kandidat vises direkte i Home Control på samme GitHub Pages-origin.

### 3. One-click runner

`RAH-HOME-DISCOVERY-RUN.ps1` kjører den passive discovery-kilden, skriver `rah-home-discovery.json` til brukerens Downloads-mappe, åpner Discovery Inbox i nettleseren og markerer JSON-filen i Explorer.

## Tester og CI

Kjør:

`python tests/test_home_discovery_contract.py`

Forventet:

`PASS: RAH Home Discovery passive foundation contract`

Kjør også:

`python tests/test_home_discovery_inbox_contract.py`

Forventet:

`PASS: RAH Home Discovery Inbox prototype contract`

GitHub Actions:

- `.github/workflows/validate-home-discovery-foundation.yml`
- `.github/workflows/validate-home-discovery-inbox.yml`

Begge kontraktene forbyr aktiv discovery i denne prototypen.

## Bruk på Windows

Enklest:

`powershell -ExecutionPolicy Bypass -File .\RAH-HOME-DISCOVERY-RUN.ps1`

Manuelt:

`powershell -ExecutionPolicy Bypass -File .\RAH-HOME-DISCOVERY.ps1 -OutputPath .\rah-home-discovery.json`

Deretter åpnes `RAH-HOME-DISCOVERY-INBOX.html`, discovery-filen lastes inn og ønskede kandidater godkjennes.

## Prototype-kriterium

**Fungerende prototype er nå oppnådd for passiv discovery → validering → menneskelig godkjenning → lokalt Home Control-enhetsregister.**

Prototypen hevder ikke å finne alle Wi-Fi-enheter. Full aktiv discovery er neste egen milepæl og skal bygges med tydelig lokalnett-avgrensning, rate limits og eksplisitt brukerhandling.

## Neste milepæler – bevart

- Sikker oppdagelse/søk etter alle relevante Wi-Fi-enheter i brukerens eget nettverk.
- Enkel sammenkobling og eksplisitt godkjenning av enheter.
- Clustering mellom godkjente noder.
- Større eller flere AI-hjerner.
- Alternative konfigurasjoner for ledernode, delt arbeid og uavhengige noder.
- Fysisk enhetsstyring som egen milepæl med eksplisitte sikkerhets- og feilhåndteringskrav.
