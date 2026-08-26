# RAH Home Control – punkt 1

## Fullført i denne kjøringen

**Avgrenset oppgave:** håndheve IPv4-kontrakten også i lagret og importert Home Control-tilstand.

### Endring

- `RAH-HOME-CONTROL.html` har fått `validDeviceIPv4s(x)`.
- Alle enhets-IP-er som ikke er `Ikke satt` må være gyldige IPv4-adresser etter den eksisterende `isValidIPv4()`-regelen.
- Alle satte IPv4-adresser må være unike på tvers av enhetsregisteret.
- Flere enheter kan fortsatt bruke `Ikke satt`.
- `validBackupState(x)` bruker nå denne IPv4-kontrollen, slik at både lokal hovedtilstand og importert JSON-backup håndhever samme regel før rendering.
- Footer-dokumentasjonen i Home Control beskriver kontrakten.
- `tests/test_home_control_stable_contract.py` låser den nye regelen som del av v1.24 Stable-kontrakten.
- Ingen GUI-finpolering, nettverksoppdagelse, pairing, clustering, Raven Vision eller fysisk device-control er introdusert.
- Home Control runtime forblir **v1.24 Stable/MVP**.

## Hvorfor dette var riktig neste oppgave

Opprettelsesflyten avviste allerede ugyldige og dupliserte IPv4-adresser, men manipulert eller korrupt lokal/importert tilstand kunne tidligere omgå denne regelen. Nå valideres den samme IPv4-kontrakten også før lagret/importert tilstand tas i bruk.

## Stable/MVP-kontrakt

Home Control v1.24 regnes som **Stable/MVP for lokal kontroll**.

Stable/MVP betyr her:

- fast rommodell for Datarom, Stue 1, Stue 2 og Soverom,
- lokalt enhetsregister med unike normaliserte navn,
- satt IPv4 må være gyldig og unik både ved opprettelse og ved lasting/import,
- `Ikke satt` kan brukes av flere enheter,
- genererte enhets-ID-er kollisjonssjekkes ved opprettelse,
- lagret/importert tilstand krever entydige romnavn, rom-ID-er, enhets-ID-er og enhetsnavn,
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
- enhets- og skjermreferanser peker på kjente rom eller `Ikke valgt`,
- romnavn, rom-ID-er, enhets-ID-er og normaliserte enhetsnavn er unike,
- `validDeviceIPv4s()` finnes og brukes av `validBackupState()`,
- `Ikke satt` filtreres ut før IPv4-unikhetskontrollen,
- alle øvrige IP-er må bestå `isValidIPv4()`,
- alle øvrige IP-er må være unike,
- både lokal hovedtilstand og importert backup bruker samme valideringskjede,
- opprettelsesflytens eksisterende navn/IP-kontroller er bevart,
- sentrale rollback- og lagringskontrakter er bevart,
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
- Lagret/importert tilstand krever også unike normaliserte enhetsnavn.
- En satt IPv4-adresse valideres og må være unik ved opprettelse.
- Lagret/importert tilstand håndhever nå samme IPv4-regel.
- Flere enheter kan bruke `Ikke satt`.
- Nye genererte enhets-ID-er kollisjonssjekkes mot eksisterende enheter.
- Lagret og importert tilstand krever unike enhets-ID-er.
- Legg til, fjern og redigering ruller tilbake ved lagringsfeil.
- En lagret eller importert enhets `room` må være et eksisterende romnavn eller `Ikke valgt`.

### Statusvisning og kontrollknapper

- Enheter kan markeres synlige/frakoblede.
- Rom, skjermer og noder har synlig status.
- Statusendringer for enheter, rom, skjermer og noder rulles tilbake dersom lokal lagring feiler.
- Filter for enhetsstatus og rom finnes og lagres separat.
- `Nullstill bare filtre` og vanlige filtervalg er rollback-sikre.

### Lokal lagring og enkel feilhåndtering

- Hovedtilstand lagres under `rah-home-control-v03`.
- Filtervalg lagres under `rah-home-control-filters-v01`.
- Lagringsfeil vises eksplisitt i grensesnittet.
- Lagret hovedtilstand valideres før rendering.
- Backup-gjenoppretting valideres før tilstanden tas i bruk.
- Ugyldige eller dupliserte satte IPv4-adresser avvises ved lasting/import.
- Backup-gjenoppretting og standard-nullstilling rulles tilbake dersom lokal lagring feiler.

## Neste avgrensede oppgave

Gå videre til **statusvisning**: legg inn en liten, tydelig samlet status for enhetsregisteret som skiller mellom totalt registrerte, synlige og lagrede/frakoblede enheter. Dette skal kun bruke eksisterende lokal `online`-status, uten nettverksprober eller discovery, og låses med en liten Stable-regresjonstest.

## Senere veikart – ikke implementert ennå

- Oppdagelse og søk etter alle Wi‑Fi-enheter.
- Enkel sammenkobling og godkjenning av enheter.
- Clustering mellom hoved-PC, HP Omen og senere noder.
- Større eller flere AI-hjerner.
- Alternative konfigurasjoner for ledernode, delt arbeid og uavhengige noder.
