# RAH Home Control – punkt 1

## Fullført i denne kjøringen

**Avgrenset oppgave:** gjør feil ved lasting av lagrede filtervalg synlig uten å blokkere Home Control.

### Endring i v1.18

- `loadFilters()` faller fortsatt trygt tilbake til `Alle` / `Alle rom` dersom lagrede filterdata ikke kan leses.
- Ugyldig JSON eller annen lesefeil viser nå en tydelig feilmelding i Home Control.
- Feilmeldingen forklarer at standardfiltre brukes midlertidig.
- Hovedtilstanden under `rah-home-control-v03` endres eller slettes ikke av denne feilstien.
- Eksisterende filterlagringsnøkkel beholdes uendret: `rah-home-control-filters-v01`.
- Ingen migrering eller ny lagringsnøkkel er introdusert.
- Resten av Home Control fortsetter å laste med standardfiltre selv om filterdataene er ødelagt.
- Versjonsvisning og footer er oppdatert til `v1.18`.
- Ingen GUI-finpolering eller Raven Vision-arbeid er gjort.

## Test

1. Åpne `RAH-HOME-CONTROL.html` med gyldige eller ingen lagrede filterdata og kontroller normal oppstart.
2. Sett `rah-home-control-filters-v01` i `localStorage` til ugyldig JSON, for eksempel `{broken`.
3. Last siden på nytt.
4. Kontroller at Home Control fortsatt åpnes og bruker `Alle` / `Alle rom`.
5. Kontroller at en tydelig feilmelding om uleselige lagrede filtervalg vises.
6. Kontroller at hovedtilstanden under `rah-home-control-v03` fortsatt er urørt og at rom, enheter, skjermer, noder og nattoppgaver lastes som før.
7. Rett eller fjern den ugyldige filterverdien og last siden på nytt.
8. Kontroller at normal filterlasting fungerer igjen.

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
- Nattoppgavehandlingene beskytter minnet mot lagringsfeil.
- Lokal konfigurasjon kan eksporteres og gjenopprettes via validert JSON-backup.
- Backup-gjenoppretting rulles tilbake dersom lokal lagring feiler.
- `Gjenopprett standarddata` er rollback-sikker fra v1.15.
- `Nullstill bare filtre` er rollback-sikker fra v1.16.
- Vanlige filtervalg er rollback-sikre fra v1.17.

## Neste avgrensede oppgave

Gjør **delvis ugyldige, men lesbare filtervalg synlige**.

Dagens filterlasting kan normalisere en ukjent `status` eller `room` til standardverdi uten å fortelle brukeren at lagret filterinnhold var ugyldig. Neste kjøring skal derfor:

1. Fortsatt normalisere ukjente filterverdier trygt til `Alle` / `Alle rom`.
2. Vise en enkel feilmelding dersom JSON er lesbar, men `status` eller `room` inneholder en verdi som ikke støttes.
3. Ikke endre eller slette hovedtilstanden under `rah-home-control-v03`.
4. Ikke introdusere ny lagringsnøkkel eller migrering.
5. Beholde resten av Home Control funksjonell med de normaliserte standardfiltrene.

## Senere veikart – ikke implementert ennå

- Oppdagelse og søk etter alle Wi‑Fi-enheter.
- Enkel sammenkobling og godkjenning av enheter.
- Clustering mellom hoved-PC, HP Omen og senere noder.
- Større eller flere AI-hjerner.
- Alternative konfigurasjoner for ledernode, delt arbeid og uavhengige noder.
