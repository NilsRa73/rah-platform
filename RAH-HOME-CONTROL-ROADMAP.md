# RAH Home Control – punkt 1

## Fullført i denne kjøringen

**Avgrenset oppgave:** gjør `Gjenopprett standarddata` transaksjonssikker ved lokal lagringsfeil.

### Endring i v1.15

- Før nullstilling tas kopi av hele Home Control-tilstanden, aktiv redigerings-ID og begge filterverdiene.
- Standarddata og standardfiltre settes først i minnet og forsøkes deretter lagret.
- Standardtilstanden beholdes bare dersom både hovedtilstanden og filtertilstanden kan lagres.
- Dersom en av lagringsoperasjonene feiler, gjenopprettes tidligere Home Control-data, redigeringsstatus og filtre i minnet.
- Etter rollback forsøkes den tidligere tilstanden skrevet tilbake til lokal lagring dersom nettleseren tillater det.
- Ved feil vises en eksplisitt rollback-melding, og ingen falsk suksessmelding vises.
- Ved vellykket nullstilling vises en tydelig bekreftelse.
- Eksisterende lagringsnøkler beholdes uendret: `rah-home-control-v03` og `rah-home-control-filters-v01`.
- Ingen annen kontrollflyt, rommodell, enhetsregister, skjermstatus, nodestatus eller backupformat er endret.

## Test

1. Åpne `RAH-HOME-CONTROL.html` og gjør minst én synlig endring i data og filtre.
2. Trykk `Gjenopprett standarddata` og velg `Avbryt`; kontroller at ingenting endres.
3. Trykk igjen og bekreft; kontroller at standardrom, standardenheter og filtrene `Alle` / `Alle rom` vises.
4. Last siden på nytt og kontroller at standardtilstanden fortsatt er lagret.
5. Gjør nye endringer i data og filtre.
6. Simuler eller blokker feil i `localStorage.setItem`.
7. Bekreft `Gjenopprett standarddata`.
8. Kontroller at de tidligere dataene, filtervalgene og eventuell aktiv redigering kommer tilbake i grensesnittet.
9. Kontroller at feilmeldingen sier at nullstillingen ble rullet tilbake.
10. Kontroller at ingen grønn suksessmelding vises ved lagringsfeil.

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

### Lokal lagring og enkel feilhåndtering

- Hovedtilstand lagres under `rah-home-control-v03`.
- Filtervalg lagres under `rah-home-control-filters-v01`.
- Lagringsfeil vises eksplisitt i grensesnittet.
- Nattoppgavehandlingene beskytter minnet mot lagringsfeil.
- Lokal konfigurasjon kan eksporteres og gjenopprettes via validert JSON-backup.
- Backup-gjenoppretting rulles tilbake dersom lokal lagring feiler.
- `Gjenopprett standarddata` er rollback-sikker fra v1.15.

## Neste avgrensede oppgave

Gjør **`Nullstill bare filtre` transaksjonssikker**.

Dagens filter-nullstilling setter `statusFilter='all'` og `roomFilter='all'` før `saveFilters()` er bekreftet. Dersom filterlagring feiler, blir grensesnittet stående på standardfiltrene selv om de ikke ble lagret.

Neste kjøring skal derfor:

1. Ta kopi av gjeldende `statusFilter`, `roomFilter` og `editingDeviceId`.
2. Forsøke å lagre `all` / `all`.
3. Beholde standardfiltrene bare dersom `saveFilters()` lykkes.
4. Ved lagringsfeil gjenopprette tidligere filtre og redigeringsstatus i minnet.
5. Vise tydelig rollback-feil og ingen falsk suksessmelding.
6. Ikke endre enhetsdata eller hovedtilstanden.

## Senere veikart – ikke implementert ennå

- Oppdagelse og søk etter alle Wi‑Fi-enheter.
- Enkel sammenkobling og godkjenning av enheter.
- Clustering mellom hoved-PC, HP Omen og senere noder.
- Større eller flere AI-hjerner.
- Alternative konfigurasjoner for ledernode, delt arbeid og uavhengige noder.
