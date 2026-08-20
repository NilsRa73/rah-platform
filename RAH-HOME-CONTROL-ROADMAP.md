# RAH Home Control – punkt 1

## Fullført i denne kjøringen

**Avgrenset oppgave:** styrk valideringen av lagret hovedtilstand før den rendres.

### Endring

- Runtime er oppdatert til **v1.20**.
- `loadState()` godtar ikke lenger en lagret tilstand bare fordi toppnivåfeltene `rooms`, `devices`, `screens`, `nodes` og `tasks` er arrays.
- Ny `validStoredState()` bruker den eksisterende detaljerte felt-/type-/størrelsesvalideringen fra backup-formatet før lagrede data tas i bruk.
- Den lagrede tilstanden må i tillegg fortsatt inneholde de fire kanoniske rommene: `Datarom`, `Stue 1`, `Stue 2` og `Soverom`.
- Delvis korrupte eller strukturelt ugyldige lokale data rendres derfor ikke. Home Control faller trygt tilbake til standarddata og viser en tydelig feilmelding.
- Eksisterende lagringsnøkler er uendret: `rah-home-control-v03` og `rah-home-control-filters-v01`.
- Ingen nettverksoppdagelse, sammenkobling, clustering eller AI-konfigurasjon er implementert.

## Test

Regresjonstesten `tests/test_home_control_stable_contract.py` er oppdatert til v1.20.

Kjør fra roten av repoet:

`python tests/test_home_control_stable_contract.py`

Forventet resultat:

`PASS: RAH Home Control v1.20 Stable contract`

Testen verifiserer blant annet at:

- de fire faste rommene fortsatt finnes,
- `validStoredState()` finnes,
- `loadState()` faktisk bruker den strenge valideringen,
- fallback-feilen er synlig,
- lokale lagringsnøkler og sentrale rollback-kontrakter er bevart,
- utsatte nettverks-/oppdagelses-API-er fortsatt ikke er introdusert.

## Gjeldende implementert grunnlag

### Rommodell

- Datarom, Stue 1, Stue 2 og Soverom finnes i standardtilstanden.
- Rom kan aktiveres/deaktiveres lokalt.
- Ett rom kan settes som hovedrom.
- Begge kontrollflytene ruller tilbake dersom lokal lagring feiler.
- Fra v1.20 må også en lagret hovedtilstand inneholde alle fire kanoniske rom før den kan rendres.

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
- Fra v1.20 valideres hvert lagret hovedobjekt før rendering; ugyldig lokal hovedtilstand gir fallback til standarddata.
- Nattoppgavehandlingene beskytter minnet mot lagringsfeil.
- Lokal konfigurasjon kan eksporteres og gjenopprettes via validert JSON-backup.
- Backup-gjenoppretting rulles tilbake dersom lokal lagring feiler.
- `Gjenopprett standarddata` er rollback-sikker fra v1.15.
- `Nullstill bare filtre` er rollback-sikker fra v1.16.
- Vanlige filtervalg er rollback-sikre fra v1.17.

## Neste avgrensede oppgave

Neste kjøring bør gjøre én liten hardening av **enhetsreferanser mot rommodellen**: en lagret eller importert enhet skal ikke godtas dersom `room` peker til et ukjent romnavn. Oppgaven bør gjenbruke dagens validering og ha en liten regresjonstest, uten å endre GUI.

## Senere veikart – ikke implementert ennå

- Oppdagelse og søk etter alle Wi‑Fi-enheter.
- Enkel sammenkobling og godkjenning av enheter.
- Clustering mellom hoved-PC, HP Omen og senere noder.
- Større eller flere AI-hjerner.
- Alternative konfigurasjoner for ledernode, delt arbeid og uavhengige noder.
