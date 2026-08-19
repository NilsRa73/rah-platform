# RAH Home Control – punkt 1

## Fullført i denne kjøringen

**Avgrenset oppgave:** legg til en liten regresjonstest som beskytter v1.19 Stable-kontrakten uten å endre runtime-koden.

### Endring

- Ny testfil: `tests/test_home_control_stable_contract.py`.
- Testen bruker bare Python-standardbiblioteket.
- Den verifiserer at rommodellen fortsatt inneholder `Datarom`, `Stue 1`, `Stue 2` og `Soverom`.
- Den verifiserer at de eksisterende lokale lagringsnøklene fortsatt er `rah-home-control-v03` og `rah-home-control-filters-v01`.
- Den verifiserer at sentrale rollback-feilmeldinger for rom, enheter og filtre fortsatt finnes i runtime-filen.
- Den feiler dersom typiske nettverks-/oppdagelses-API-er som WebRTC, Web Bluetooth, WebUSB, WebSocket eller EventSource introduseres i `RAH-HOME-CONTROL.html` uten en eksplisitt reopen av dette senere veikartet.
- `RAH-HOME-CONTROL.html` er ikke endret i denne kjøringen; v1.19 Stable beholdes.

## Test

Kjør fra roten av repoet:

`python tests/test_home_control_stable_contract.py`

Forventet resultat:

`PASS: RAH Home Control v1.19 Stable contract`

En manglende rommodell, endret lagringsnøkkel, fjernet rollback-kontrakt eller utilsiktet nettverksoppdagelses-API skal gi `AssertionError` og non-zero exit.

## Gjeldende implementert grunnlag

### Rommodell

- Datarom, Stue 1, Stue 2 og Soverom finnes i standardtilstanden.
- Rom kan aktiveres/deaktiveres lokalt.
- Ett rom kan settes som hovedrom.
- Begge kontrollflytene ruller tilbake dersom lokal lagring feiler.

### Enhetsregister

- Enheter har navn, rom, type, IPv4-adresse, forbindelse, rolle og synlig/lagret-status.
- Navn må være unikt.
- En satt IPv4-adresse valideres og må være unik.
- Legg til, fjern og redigering ruller tilbake ved lagringsfeil.

### Statusvisning og kontrollknapper

- Enheter kan markeres synlige/frakoblede.
- Rom, skjermer og noder har synlig status.
- Statusendringer for enheter, rom, skjermer og noder rulles tilbake dersom lokal lagring feiler.
- Filter for enhetsstatus og rom finnes og lagres separat.
- `Nullstill bare filtre` er rollback-sikker fra v1.16.
- Vanlige status- og romfilterknapper er rollback-sikre fra v1.17.

### Lokal lagring og enkel feilhåndtering

- Hovedtilstand lagres under `rah-home-control-v03`.
- Filtervalg lagres under `rah-home-control-filters-v01`.
- Lagringsfeil vises eksplisitt i grensesnittet.
- Uleselige lagrede filtervalg gir synlig feilmelding og trygg fallback fra v1.18.
- Lesbare filterdata med ikke-støttet `status` eller `room` gir synlig feilmelding og feltvis trygg normalisering fra v1.19.
- Nattoppgavehandlingene beskytter minnet mot lagringsfeil.
- Lokal konfigurasjon kan eksporteres og gjenopprettes via validert JSON-backup.
- Backup-gjenoppretting rulles tilbake dersom lokal lagring feiler.
- `Gjenopprett standarddata` er rollback-sikker fra v1.15.
- `Nullstill bare filtre` er rollback-sikker fra v1.16.
- Vanlige filtervalg er rollback-sikre fra v1.17.

## Neste avgrensede oppgave

Neste kjøring bør være én konkret bugfix eller én liten testbar hardening av lokal lagring/feilhåndtering. En naturlig kandidat er å styrke valideringen av lagret hovedtilstand før den rendres, slik at delvis korrupte objekter ikke godtas bare fordi toppnivåfeltene er arrays.

Runtime-versjonen forblir **v1.19 Stable** til en konkret runtime-bugfix faktisk gjøres.

## Senere veikart – ikke implementert ennå

- Oppdagelse og søk etter alle Wi‑Fi-enheter.
- Enkel sammenkobling og godkjenning av enheter.
- Clustering mellom hoved-PC, HP Omen og senere noder.
- Større eller flere AI-hjerner.
- Alternative konfigurasjoner for ledernode, delt arbeid og uavhengige noder.
