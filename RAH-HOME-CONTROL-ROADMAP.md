# RAH Home Control – punkt 1

## Fullført i denne kjøringen

**Avgrenset oppgave:** kreve unike, normaliserte enhetsnavn også i lagret og importert Home Control-tilstand.

### Endring

- `RAH-HOME-CONTROL.html` har fått `uniqueDeviceNames(x)`.
- Funksjonen bruker den eksisterende `normalizeName()`-regelen, slik at for eksempel `HP Omen`, ` hp omen ` og `HP OMEN` behandles som samme navn.
- `validBackupState(x)` krever nå unike normaliserte enhetsnavn i tillegg til unike romnavn, rom-ID-er og enhets-ID-er.
- Samme kontroll gjelder både lokal hovedtilstand og importert JSON-backup fordi begge går gjennom den samme valideringskjeden.
- Footer-dokumentasjonen i Home Control beskriver den nye kontrakten.
- `tests/test_home_control_stable_contract.py` låser regelen som del av v1.24 Stable-kontrakten.
- Ingen GUI-finpolering, nettverksoppdagelse, pairing, clustering, Raven Vision eller fysisk device-control er introdusert.
- Home Control runtime forblir **v1.24 Stable/MVP**.

## Hvorfor dette var riktig neste oppgave

Opprettelsesflyten avviste allerede duplikate enhetsnavn med `normalizeName()`, men tidligere kunne manipulert eller korrupt lokal/importert tilstand inneholde to navn som bare skilte seg på mellomrom eller store/små bokstaver. Det kunne gjøre registeret tvetydig selv om vanlig opprettelse var trygg. Nå håndhever lagring/import samme navnekontrakt som opprettelsesflyten.

## Stable/MVP-kontrakt

Home Control v1.24 regnes som **Stable/MVP for lokal kontroll**.

Stable/MVP betyr her:

- fast rommodell for Datarom, Stue 1, Stue 2 og Soverom,
- lokalt enhetsregister med unik navn/IP-validering ved opprettelse,
- genererte enhets-ID-er kollisjonssjekkes ved opprettelse,
- lagret/importert tilstand krever entydige romnavn, rom-ID-er, enhets-ID-er og normaliserte enhetsnavn,
- synlig status for rom, enheter, skjermer og noder,
- lokale kontrollknapper med rollback ved lagringsfeil,
- separat lagring av filtre,
- validert eksport/import av lokal Home Control-konfigurasjon,
- trygg fallback ved ugyldig lagret tilstand.

Stable/MVP betyr **ikke** at ekte nettverksoppdagelse eller fysisk enhetsstyring er implementert.

## Test

Kjør fra roten av repoet:

`python tests/test_home_control_stable_contract.py`

Forventet resultat:

`PASS: RAH Home Control v1.24 Stable contract`

Testen verifiserer blant annet at:

- de fire faste rommene fortsatt finnes,
- `knownRoomReference()` beskytter enheter og skjermer,
- `uniqueRoomNames()` krever entydige romnavn,
- `uniqueRoomIds()` krever entydige rom-ID-er,
- `uniqueDeviceIds()` krever entydige enhets-ID-er,
- `uniqueDeviceNames()` krever entydige normaliserte enhetsnavn,
- `validBackupState()` bruker alle disse unikhetskontrollene,
- både lagret hovedtilstand og importert backup bruker samme valideringskjede,
- enhetsregisteret beholder IPv4-validering,
- enhetsnavn sammenlignes normalisert før opprettelse,
- nye enhets-ID-er kollisjonssjekkes,
- duplikate IPv4-adresser avvises ved opprettelse,
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
- Lagret/importert tilstand krever nå også unike normaliserte enhetsnavn.
- En satt IPv4-adresse valideres og må være unik ved opprettelse.
- Nye genererte enhets-ID-er kollisjonssjekkes mot eksisterende enheter.
- Lagret og importert tilstand krever unike enhets-ID-er.
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
- Duplikate romnavn, rom-ID-er, enhets-ID-er og normaliserte enhetsnavn avvises.
- Nattoppgavehandlingene beskytter minnet mot lagringsfeil.
- Lokal konfigurasjon kan eksporteres og gjenopprettes via validert JSON-backup.
- Backup-gjenoppretting og standard-nullstilling rulles tilbake dersom lokal lagring feiler.

## Neste avgrensede oppgave

Fortsett på **enhetsregisteret** ved å håndheve IPv4-kontrakten også i lagret/importert tilstand: satt IPv4 må være gyldig og unik, mens `Ikke satt` fortsatt skal være tillatt på flere enheter. Opprettelsesflyten gjør allerede dette; neste steg er å bruke samme regel før rendering av lokal/importert tilstand, med en liten Stable-regresjonstest og uten GUI-endringer.

## Senere veikart – ikke implementert ennå

- Oppdagelse og søk etter alle Wi‑Fi-enheter.
- Enkel sammenkobling og godkjenning av enheter.
- Clustering mellom hoved-PC, HP Omen og senere noder.
- Større eller flere AI-hjerner.
- Alternative konfigurasjoner for ledernode, delt arbeid og uavhengige noder.
