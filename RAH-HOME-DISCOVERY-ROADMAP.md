# RAH Home Discovery – punkt 2

## Status: STARTET – passiv foundation

Punkt 1, RAH Home Control Stable/MVP, er ferdig. Punkt 2 starter den senere milepælen for oppdagelse og søk etter nettverksenheter.

## Fullført i denne kjøringen

**Avgrenset oppgave:** etablere en testbar, passiv Windows-discovery-kilde uten aktiv nettverksskanning.

`RAH-HOME-DISCOVERY.ps1` leser den eksisterende Windows IPv4 neighbor-cachen med `Get-NetNeighbor` og lokale adaptermetadata med `Get-NetAdapter`. Resultatet er maskinlesbar JSON med schema `rah-home-discovery-cache`, versjon 1.

Foundationen er med vilje passiv: den sender ikke ping, åpner ikke porter, gjør ikke HTTP-probing og kjører ikke aktiv subnettskanning. Derfor kan den bare vise enheter Windows allerede har observert i neighbor-cachen; den lover ikke ennå å finne alle Wi-Fi-enheter.

## Kontrakt v1

Discovery-dokumentet inneholder:

- `schema: rah-home-discovery-cache`
- `version: 1`
- `product: RAH Home Control`
- `mode: passive-neighbor-cache`
- `passive: true`
- UTC-tidspunkt i `generatedAt`
- lokale adaptere med interface-index, navn, beskrivelse, status, MAC og link speed
- observerte IPv4-neighbors med IP, MAC, interface-index, neighbor-state, kilde og passiv-markering

## Test

Kjør fra roten av repoet:

`python tests/test_home_discovery_contract.py`

Forventet resultat:

`PASS: RAH Home Discovery passive foundation contract`

Testen krever JSON-kontrakten og forbyr aktive mekanismer som `Test-Connection`, `ping.exe`, `Test-NetConnection`, HTTP-probing, rå TCP-probing og `nmap` i denne foundationen.

## Bruk på Windows

Vis JSON direkte:

`powershell -ExecutionPolicy Bypass -File .\RAH-HOME-DISCOVERY.ps1`

Skriv JSON til fil:

`powershell -ExecutionPolicy Bypass -File .\RAH-HOME-DISCOVERY.ps1 -OutputPath .\rah-home-discovery.json`

## Neste avgrensede oppgave

Importer og valider `rah-home-discovery-cache` i en separat Discovery Inbox før noen kandidat kan legges inn i Home Control-enhetsregisteret. Import skal være eksplisitt og skal ikke automatisk godkjenne, pare eller styre enheter.

## Senere krav – bevart

- Utvide fra passiv cache til sikker oppdagelse/søk etter alle relevante Wi-Fi-enheter i brukerens eget nettverk.
- Enkel sammenkobling og eksplisitt godkjenning av enheter.
- Clustering mellom godkjente noder.
- Større eller flere AI-hjerner.
- Alternative konfigurasjoner for ledernode, delt arbeid og uavhengige noder.
- Fysisk enhetsstyring som egen milepæl med eksplisitte sikkerhets- og feilhåndteringskrav.
