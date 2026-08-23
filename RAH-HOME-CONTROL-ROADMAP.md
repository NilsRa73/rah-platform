# RAH Home Control – punkt 1

## Fullført i denne kjøringen

**Avgrenset oppgave:** herd Stable-regresjonskontrakten for enhetsregisteret uten å endre runtime eller gjenåpne Home Control v1.24.

### Endring

- `tests/test_home_control_stable_contract.py` verifiserer nå eksplisitt enhetsregisterets eksisterende sikkerhetsregler.
- Testen krever at `isValidIPv4()` fortsatt finnes.
- Testen krever at `normalizeName()` fortsatt brukes for å avvise duplikate enhetsnavn uavhengig av store/små bokstaver.
- Testen krever at `createUniqueDeviceId()` fortsatt kollisjonssjekker nye ID-er mot registrerte enheter.
- Testen krever at duplikate IPv4-adresser oppdages før lagring.
- Testen krever synlige feilmeldinger for ugyldig IPv4, duplikatnavn og duplikat-IP.
- Testen krever at tom IP fortsatt normaliseres til `Ikke satt`.
- Ingen GUI-endringer, Raven Vision-endringer eller fysisk device-control er gjort.
- Home Control runtime forblir **v1.24 Stable/MVP**.

## Hvorfor dette var neste riktige oppgave

Rommodellen er allerede Stable-hardet med obligatoriske rom, unike romnavn og unike rom-ID-er. Neste prioritet er derfor enhetsregisteret. Selve runtime-reglene for navn/IP var allerede implementert, men de var ikke fullt låst av Stable-testen. Denne kjøringen reduserer regresjonsrisiko uten å utvide funksjonelt scope.

## Stable/MVP-kontrakt

Home Control v1.24 regnes som **Stable/MVP for lokal kontroll**.

Stable/MVP betyr her:

- fast rommodell for Datarom, Stue 1, Stue 2 og Soverom,
- lokalt enhetsregister med unik navn/IP-validering,
- genererte enhets-ID-er kollisjonssjekkes ved opprettelse,
- synlig status for rom, enheter, skjermer og noder,
- lokale kontrollknapper med rollback ved lagringsfeil,
- separat lagring av filtre,
- validert eksport/import av lokal Home Control-konfigurasjon,
- trygg fallback ved ugyldig lagret tilstand,
- entydige romnavn og rom-ID-er.

Stable/MVP betyr **ikke** at ekte nettverksoppdagelse eller fysisk enhetsstyring er implementert.

## Test

Kjør fra roten av repoet:

`python tests/test_home_control_stable_contract.py`

Forventet resultat:

`PASS: RAH Home Control v1.24 Stable contract`

Testen verifiserer nå blant annet at:

- de fire faste rommene fortsatt finnes,
- `knownRoomReference()` beskytter enheter og skjermer,
- `uniqueRoomNames()` krever entydige romnavn,
- `uniqueRoomIds()` krever entydige rom-ID-er,
- `validBackupState()` bruker begge romunikhetskontrollene,
- både lagret hovedtilstand og importert backup bruker samme valideringskjede,
- enhetsregisteret beholder IPv4-validering,
- enhetsnavn sammenlignes normalisert før opprettelse,
- nye enhets-ID-er kollisjonssjekkes,
- duplikate IPv4-adresser avvises,
- sentrale brukerfeil fortsatt vises eksplisitt,
- lokale lagringsnøkler og rollback-kontrakter er bevart,
- utsatte nettverks-/oppdagelses-API-er fortsatt ikke er introdusert.

## Gjeldende implementert grunnlag

### Rommodell

- Datarom, Stue 1, Stue 2 og Soverom finnes i standardtilstanden.
- Rom kan aktiveres/deaktiveres lokalt.
- Ett rom kan settes som hovedrom.
- Begge kontrollflytene ruller tilbake dersom lokal lagring feiler.
- Lagret hovedtilstand må inneholde alle fire kanoniske rom.
- Romnavn og rom-ID-er må være unike.

### Enhetsregister

- Enheter har navn, rom, type, IPv4-adresse, forbindelse, rolle og synlig/lagret-status.
- Navn må være unikt ved opprettelse og sammenlignes normalisert.
- En satt IPv4-adresse valideres og må være unik ved opprettelse.
- Nye genererte enhets-ID-er kollisjonssjekkes mot eksisterende enheter.
- Tom IPv4 lagres som `Ikke satt`.
- Legg til, fjern og redigering ruller tilbake ved lagringsfeil.
- En lagret eller importert enhets `room` må være et eksisterende romnavn eller `Ikke valgt`.

### Statusvisning og kontrollknapper

- Enheter kan markeres synlige/frakoblede.
- Rom, skjermer og noder har synlig status.
- Statusendringer for enheter, rom, skjermer og noder rulles tilbake dersom lokal lagring feiler.
- En lagret eller importert skjerms `room` må være et eksisterende romnavn eller `Ikke valgt`.
- Filter for enhetsstatus og rom finnes og lagres separat.
- `Nullstill bare filtre` og vanlige filtervalg er rollback-sikre.

### Lokal lagring og enkel feilhåndtering

- Hovedtilstand lagres under `rah-home-control-v03`.
- Filtervalg lagres under `rah-home-control-filters-v01`.
- Lagringsfeil vises eksplisitt i grensesnittet.
- Uleselige eller ikke-støttede filtervalg faller trygt tilbake.
- Lagret hovedtilstand valideres før rendering.
- Enhet- og skjermreferanser valideres mot rommodellen.
- Duplikate romnavn og rom-ID-er avvises.
- Nattoppgavehandlingene beskytter minnet mot lagringsfeil.
- Lokal konfigurasjon kan eksporteres og gjenopprettes via validert JSON-backup.
- Backup-gjenoppretting og standard-nullstilling rulles tilbake dersom lokal lagring feiler.

## Neste avgrensede oppgave

Neste Home Control-kjøring bør fortsette på **enhetsregisteret** ved å validere at lagret/importert tilstand ikke kan inneholde duplikate `device.id`-verdier. Runtime genererer allerede kollisjonssikre ID-er for nye enheter, men backup/lokal lagring bør også kreve entydige enhets-ID-er før rendering. Dette bør gjøres som en liten valideringsendring med regresjonstest, uten GUI-endringer.

## Senere veikart – ikke implementert ennå

- Oppdagelse og søk etter alle Wi‑Fi-enheter.
- Enkel sammenkobling og godkjenning av enheter.
- Clustering mellom hoved-PC, HP Omen og senere noder.
- Større eller flere AI-hjerner.
- Alternative konfigurasjoner for ledernode, delt arbeid og uavhengige noder.
