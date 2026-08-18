# RAH Home Control – punkt 1

## Fullført i denne kjøringen

**Avgrenset oppgave:** gjør delvis ugyldige, men lesbare filtervalg synlige uten å blokkere Home Control.

### Endring i v1.19

- `loadFilters()` validerer nå lagret `status` og `room` etter at filter-JSON er lest.
- En verdi som ikke støttes gir en tydelig feilmelding i Home Control i stedet for stille normalisering.
- Bare det ugyldige feltet faller tilbake til standardverdien `all`; et fortsatt gyldig felt beholdes.
- Uleselig eller ugyldig JSON bruker fortsatt v1.18-feilstien med synlig melding og trygg fallback til `Alle` / `Alle rom`.
- Hovedtilstanden under `rah-home-control-v03` endres eller slettes ikke av filterfeilene.
- Eksisterende filterlagringsnøkkel beholdes uendret: `rah-home-control-filters-v01`.
- Ingen migrering eller ny lagringsnøkkel er introdusert.
- Versjonsvisning og footer er oppdatert til `v1.19`.
- Ingen nettverksoppdagelse, automatisk oppgavekjøring, ekstern nettverkstrafikk eller ny authority er lagt til.

## Test

1. Åpne `RAH-HOME-CONTROL.html` med gyldige eller ingen lagrede filterdata og kontroller normal oppstart.
2. Sett `rah-home-control-filters-v01` i `localStorage` til `{"status":"ukjent","room":"Datarom"}`.
3. Last siden på nytt og kontroller at en tydelig melding om en ikke-støttet filterverdi vises.
4. Kontroller at status normaliseres til `Alle`, mens det gyldige rommet `Datarom` beholdes.
5. Test motsatt retning med `{"status":"online","room":"Ukjent rom"}` og kontroller at status beholdes mens rom faller tilbake til `Alle rom`.
6. Sett filterverdien til ugyldig JSON, for eksempel `{broken`, og kontroller at v1.18-feilstien fortsatt viser melding og bruker `Alle` / `Alle rom`.
7. Kontroller at hovedtilstanden under `rah-home-control-v03` fortsatt er urørt og at rom, enheter, skjermer, noder og nattoppgaver lastes som før.
8. Rett eller fjern filterverdien og kontroller at normal filterlasting fungerer igjen.

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

Ingen ny Home Control-runtimeoppgave åpnes automatisk nå.

**v1.19 forblir paused Stable.** Neste endring må være en konkret bugfix som bevarer dagens lokale sikkerhetsgrense, eller en eksplisitt reopen av utviklingen.

## Senere veikart – ikke implementert ennå

- Oppdagelse og søk etter alle Wi‑Fi-enheter.
- Enkel sammenkobling og godkjenning av enheter.
- Clustering mellom hoved-PC, HP Omen og senere noder.
- Større eller flere AI-hjerner.
- Alternative konfigurasjoner for ledernode, delt arbeid og uavhengige noder.
