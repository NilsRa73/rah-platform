# RAH Home Control – punkt 1

## Fullført i denne kjøringen

**Avgrenset oppgave:** krev unike rom-ID-er i lagret og importert Home Control-tilstand, og avslutt rommodell-hardening med en Stable/MVP-gate.

### Endring

- Runtime er oppdatert til **v1.24**.
- `uniqueRoomNames()` beholdes fra v1.23.
- Ny `uniqueRoomIds()` avviser tilstand der to eller flere rom har samme `id`.
- `validBackupState()` krever nå både unike romnavn og unike rom-ID-er før resten av tilstanden godtas.
- Dermed kan navnebaserte enhet-/skjermreferanser og ID-baserte romkontroller ikke bli tvetydige ved lokal lasting eller backup-import.
- De fire kanoniske rommene `Datarom`, `Stue 1`, `Stue 2` og `Soverom` er fortsatt obligatoriske for lagret hovedtilstand.
- Ingen GUI-finpolering eller Raven Vision er berørt.
- Ingen Wi-Fi-oppdagelse, sammenkobling, clustering eller AI-konfigurasjon er implementert.

## Stable/MVP-kontrakt

Home Control v1.24 regnes som **Stable/MVP for lokal kontroll** når denne branchen er promotert til `main` med kontrakttesten og Stable-markøren synkronisert.

Stable/MVP betyr her:

- fast rommodell for Datarom, Stue 1, Stue 2 og Soverom,
- lokalt enhetsregister med unik navn/IP-validering,
- synlig status for rom, enheter, skjermer og noder,
- lokale kontrollknapper med rollback ved lagringsfeil,
- separat lagring av filtre,
- validert eksport/import av lokal Home Control-konfigurasjon,
- trygg fallback ved ugyldig lagret tilstand,
- entydige romnavn og rom-ID-er.

Stable/MVP betyr **ikke** at ekte nettverksoppdagelse eller fysisk enhetsstyring er implementert.

## Test

Regresjonstesten `tests/test_home_control_stable_contract.py` er oppdatert til v1.24.

Kjør fra roten av repoet:

`python tests/test_home_control_stable_contract.py`

Forventet resultat:

`PASS: RAH Home Control v1.24 Stable contract`

Testen verifiserer blant annet at:

- de fire faste rommene fortsatt finnes,
- `knownRoomReference()` beskytter enheter og skjermer,
- `uniqueRoomNames()` krever entydige romnavn,
- `uniqueRoomIds()` krever entydige rom-ID-er,
- `validBackupState()` bruker begge unikhetskontrollene,
- både lagret hovedtilstand og importert backup bruker samme valideringskjede,
- lokale lagringsnøkler og sentrale rollback-kontrakter er bevart,
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
- Navn må være unikt.
- En satt IPv4-adresse valideres og må være unik.
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

## Neste avgrensede oppgave etter Stable

Første post-Stable-oppgave bør være en **funksjonell lokal device-control adapter-kontrakt**: definer én liten, eksplisitt og trygg adaptergrense for senere fysisk kontroll av registrerte enheter, uten å implementere Wi-Fi-søk eller automatisk oppdagelse. Dette skal være et eget Candidate-arbeid og skal ikke endre v1.24 Stable-kontrakten uten eksplisitt gjenåpning.

## Senere veikart – ikke implementert ennå

- Oppdagelse og søk etter alle Wi‑Fi-enheter.
- Enkel sammenkobling og godkjenning av enheter.
- Clustering mellom hoved-PC, HP Omen og senere noder.
- Større eller flere AI-hjerner.
- Alternative konfigurasjoner for ledernode, delt arbeid og uavhengige noder.
