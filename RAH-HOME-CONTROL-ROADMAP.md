# RAH Home Control – punkt 1

## Fullført i denne kjøringen

**Avgrenset oppgave:** gjør `Nullstill bare filtre` transaksjonssikker ved lokal lagringsfeil.

### Endring i v1.16

- Før filter-nullstilling tas kopi av `statusFilter`, `roomFilter` og `editingDeviceId`.
- `Alle` / `Alle rom` settes først i minnet og forsøkes deretter lagret med eksisterende `saveFilters()`.
- Standardfiltrene beholdes bare dersom filterlagringen lykkes.
- Dersom `saveFilters()` feiler, gjenopprettes tidligere statusfilter, romfilter og aktiv redigering i minnet.
- Ved lagringsfeil vises en eksplisitt rollback-melding, og ingen falsk suksessmelding vises.
- Ingen enhetsdata eller annen Home Control-tilstand endres av filter-nullstillingen.
- Eksisterende filterlagringsnøkkel beholdes uendret: `rah-home-control-filters-v01`.
- Versjonsvisning og footer er oppdatert til `v1.16`.
- Ingen GUI-finpolering eller Raven Vision-arbeid er gjort.

## Test

1. Åpne `RAH-HOME-CONTROL.html`.
2. Velg et annet statusfilter enn `Alle`, for eksempel `Synlige`.
3. Velg et annet romfilter enn `Alle rom`, for eksempel `Datarom`.
4. Åpne redigering på en synlig enhet dersom mulig.
5. Trykk `Nullstill bare filtre` og kontroller normal drift: filtrene går til `Alle` / `Alle rom`, aktiv redigering lukkes og grønn bekreftelse vises.
6. Last siden på nytt og kontroller at standardfiltrene fortsatt er lagret.
7. Velg deretter ikke-standard filtre på nytt og åpne eventuell enhetsredigering.
8. Simuler eller blokker feil i `localStorage.setItem` for filterlagringen.
9. Trykk `Nullstill bare filtre`.
10. Kontroller at de tidligere filtervalgene og eventuell aktiv redigering kommer tilbake, at rollback-feilen vises og at ingen grønn suksessmelding vises.

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

### Lokal lagring og enkel feilhåndtering

- Hovedtilstand lagres under `rah-home-control-v03`.
- Filtervalg lagres under `rah-home-control-filters-v01`.
- Lagringsfeil vises eksplisitt i grensesnittet.
- Nattoppgavehandlingene beskytter minnet mot lagringsfeil.
- Lokal konfigurasjon kan eksporteres og gjenopprettes via validert JSON-backup.
- Backup-gjenoppretting rulles tilbake dersom lokal lagring feiler.
- `Gjenopprett standarddata` er rollback-sikker fra v1.15.
- `Nullstill bare filtre` er rollback-sikker fra v1.16.

## Neste avgrensede oppgave

Gjør **de vanlige filterknappene transaksjonssikre**.

Dagens status- og romfilterknapper setter nye filterverdier og lukker eventuell aktiv redigering før `saveFilters()` er bekreftet. Dersom filterlagringen feiler, blir grensesnittet stående på et filtervalg som ikke faktisk ble lagret.

Neste kjøring skal derfor:

1. Ta kopi av gjeldende filterverdi og `editingDeviceId` før en status- eller romfilterknapp endrer dem.
2. Forsøke å lagre den nye filterverdien.
3. Beholde det nye filteret bare dersom `saveFilters()` lykkes.
4. Ved lagringsfeil gjenopprette tidligere filterverdi og redigeringsstatus i minnet.
5. Vise tydelig rollback-feil og ingen falsk suksessmelding.
6. Ikke endre enhetsdata eller hovedtilstanden.

## Senere veikart – ikke implementert ennå

- Oppdagelse og søk etter alle Wi‑Fi-enheter.
- Enkel sammenkobling og godkjenning av enheter.
- Clustering mellom hoved-PC, HP Omen og senere noder.
- Større eller flere AI-hjerner.
- Alternative konfigurasjoner for ledernode, delt arbeid og uavhengige noder.
