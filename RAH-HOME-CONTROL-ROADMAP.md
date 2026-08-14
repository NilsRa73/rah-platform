# RAH Home Control – punkt 1

## Status for denne kjøringen

**Avgrenset oppgave:** synkroniser veikartet med faktisk implementert `RAH-HOME-CONTROL.html` v1.14, slik at neste kjøring ikke gjentar allerede ferdig arbeid.

Gjennomgang av gjeldende kode viser at den tidligere blokkerte `+ Legg til enhet`-oppgaven allerede er implementert, og at flere påfølgende rollback-forbedringer også er på plass.

## Verifisert implementert i v1.14

### Rommodell

- Datarom, Stue 1, Stue 2 og Soverom finnes i standardtilstanden.
- Rom kan aktiveres/deaktiveres lokalt.
- Ett rom kan settes som hovedrom.
- Begge kontrollflytene ruller tilbake dersom lokal lagring feiler.

### Enhetsregister

- Enheter har navn, rom, type, IPv4-adresse, forbindelse, rolle og synlig/lagret-status.
- Navn må være unikt.
- En satt IPv4-adresse valideres og må være unik.
- `+ Legg til enhet` tar kopi av forrige enhetsliste før endring og ruller tilbake dersom `save()` feiler.
- Registreringsskjemaet beholdes ved lagringsfeil slik at brukeren kan prøve igjen.
- `Fjern` for en registrert enhet ruller tilbake ved lagringsfeil.
- Redigering av rom, forbindelse og rolle ruller tilbake ved lagringsfeil.

### Statusvisning og kontrollknapper

- Enheter kan markeres synlige/frakoblede.
- Rom, skjermer og noder har synlig status.
- Statusendringer for enheter, rom, skjermer og noder rulles tilbake dersom lokal lagring feiler.
- Filter for enhetsstatus og rom finnes og lagres separat.

### Lokal lagring og enkel feilhåndtering

- Hovedtilstand lagres under `rah-home-control-v03`.
- Filtervalg lagres under `rah-home-control-filters-v01`.
- Lagringsfeil vises eksplisitt i grensesnittet.
- Nattoppgavehandlingene `+ Testoppgave`, `Fjern`, `Tøm kø` og `Stopp alle` beskytter minnet mot lagringsfeil.
- Lokal konfigurasjon kan eksporteres til JSON-backup.
- Backup kan gjenopprettes etter formatvalidering og eksplisitt bekreftelse.
- Backup-gjenoppretting rulles tilbake dersom lokal lagring feiler.

## Kontroll mot tidligere roadmap

Den tidligere teksten sa at `+ Legg til enhet` ikke var committed. Dette er ikke lenger riktig. Gjeldende v1.14-kode inneholder eksplisitt `previousDevices`, kandidat-enhet, rollback ved mislykket `save()` og tømming av navn/IP først etter vellykket lagring.

`Fjern` for registrert enhet er også allerede transaksjonssikker og beholder tidligere enhetsliste og redigeringsstatus ved lagringsfeil.

## Neste avgrensede oppgave

Gjør **`Gjenopprett standarddata` transaksjonssikker**.

Dagens flyt setter `state=clone(defaults)`, nullstiller redigerings-/filtertilstand, forsøker å fjerne lagringsnøklene og kaller deretter `save()` og `saveFilters()` uten å gjenopprette tidligere tilstand dersom en av lagringsoperasjonene feiler.

Neste kjøring skal derfor:

1. Ta kopi av gjeldende `state`, `editingDeviceId`, `statusFilter` og `roomFilter` før nullstilling.
2. Forsøke å lagre standardtilstanden og standardfiltrene.
3. Beholde standarddata bare dersom begge lagringsoperasjonene lykkes.
4. Ved feil gjenopprette tidligere tilstand og filtre i minnet.
5. Vise en tydelig feilmelding og ikke vise falsk suksessmelding.
6. Ikke endre øvrig kontrollflyt eller lagringsnøkler.

### Test for neste oppgave

- Normal drift: bekreft nullstilling, last siden på nytt og kontroller standarddata + standardfiltre.
- Avbryt: kontroller at ingenting endres.
- Simulert feil i `localStorage`: kontroller at tidligere rom, enheter, filtre og øvrig tilstand fortsatt vises etter forsøket.
- Kontroller at ingen falsk suksessmelding vises ved feil.

## Senere veikart – ikke implementert ennå

- Oppdagelse og søk etter alle Wi‑Fi-enheter.
- Enkel sammenkobling og godkjenning av enheter.
- Clustering mellom hoved-PC, HP Omen og senere noder.
- Større eller flere AI-hjerner.
- Alternative konfigurasjoner for ledernode, delt arbeid og uavhengige noder.
