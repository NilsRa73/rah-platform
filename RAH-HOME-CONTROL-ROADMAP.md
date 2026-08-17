# RAH Home Control – punkt 1

## Fullført i denne kjøringen

**Avgrenset oppgave:** gjør de vanlige status- og romfilterknappene transaksjonssikre ved lokal lagringsfeil.

### Endring i v1.17

- Før en statusfilterknapp endrer visningen tas kopi av tidligere `statusFilter` og `editingDeviceId`.
- Før en romfilterknapp endrer visningen tas kopi av tidligere `roomFilter` og `editingDeviceId`.
- Det nye filtervalget beholdes bare dersom eksisterende `saveFilters()` lykkes.
- Dersom filterlagringen feiler, gjenopprettes tidligere filterverdi og eventuell aktiv enhetsredigering i minnet.
- Ved lagringsfeil vises en eksplisitt rollback-melding.
- Ingen enhetsdata eller annen Home Control-hovedtilstand endres av filterknappene.
- Eksisterende filterlagringsnøkkel beholdes uendret: `rah-home-control-filters-v01`.
- Versjonsvisning og footer er oppdatert til `v1.17`.
- Ingen GUI-finpolering eller Raven Vision-arbeid er gjort.

## Test

1. Åpne `RAH-HOME-CONTROL.html`.
2. Velg `Synlige` og kontroller at bare synlige enheter vises.
3. Last siden på nytt og kontroller at statusfilteret er beholdt.
4. Velg et romfilter, for eksempel `Datarom`, og kontroller at visningen oppdateres og beholdes etter reload.
5. Åpne redigering på en synlig enhet.
6. Simuler eller blokker feil i `localStorage.setItem` for filterlagringen.
7. Trykk et annet statusfilter.
8. Kontroller at tidligere statusfilter og aktiv redigering kommer tilbake, og at rollback-feilen vises.
9. Gjenta testen med en romfilterknapp.
10. Kontroller at enhetsdata, romstatus, skjermer, noder og nattoppgaver er uendret gjennom begge feilstiene.

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
- Nattoppgavehandlingene beskytter minnet mot lagringsfeil.
- Lokal konfigurasjon kan eksporteres og gjenopprettes via validert JSON-backup.
- Backup-gjenoppretting rulles tilbake dersom lokal lagring feiler.
- `Gjenopprett standarddata` er rollback-sikker fra v1.15.
- `Nullstill bare filtre` er rollback-sikker fra v1.16.
- Vanlige filtervalg er rollback-sikre fra v1.17.

## Neste avgrensede oppgave

Gjør **feil ved lasting av lagrede filtervalg synlig** uten å blokkere Home Control.

Dagens `loadFilters()` faller stille tilbake til `Alle` / `Alle rom` dersom lagret filter-JSON ikke kan leses. Neste kjøring skal derfor:

1. Fortsatt falle trygt tilbake til standardfiltre ved ugyldige eller uleselige lagrede filterdata.
2. Vise en tydelig, enkel feilmelding om at lagrede filtervalg ikke kunne leses.
3. Ikke endre eller slette hovedtilstanden under `rah-home-control-v03`.
4. Ikke introdusere ny lagringsnøkkel eller migrering.
5. Beholde resten av Home Control funksjonell med standardfiltre.

## Senere veikart – ikke implementert ennå

- Oppdagelse og søk etter alle Wi‑Fi-enheter.
- Enkel sammenkobling og godkjenning av enheter.
- Clustering mellom hoved-PC, HP Omen og senere noder.
- Større eller flere AI-hjerner.
- Alternative konfigurasjoner for ledernode, delt arbeid og uavhengige noder.
