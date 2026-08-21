# RAH Home Control – punkt 1

## Fullført i denne kjøringen

**Avgrenset oppgave:** valider at lagrede og importerte skjermer peker til et kjent romnavn.

### Endring

- Runtime er oppdatert til **v1.22**.
- Den tidligere enhetsspesifikke romkontrollen er gjort generell som `knownRoomReference()`.
- Både `device.room` og `screen.room` må nå peke til et rom som faktisk finnes i `state.rooms`, eller den eksplisitte plassholderen `Ikke valgt`.
- `validBackupState()` bruker den samme romreferanse-kontrollen for både enheter og skjermer.
- Dermed arver både `validStoredState()` og backup-import via `validConfigBackup()` samme validering.
- En lagret eller importert skjerm med for eksempel `room: "Ukjent rom"` avvises før rendering eller gjenoppretting.
- De fire kanoniske rommene `Datarom`, `Stue 1`, `Stue 2` og `Soverom` er fortsatt obligatoriske for lagret hovedtilstand.
- `Ikke valgt` beholdes som gyldig eksplisitt tilstand for skjermer som ennå ikke er plassert.
- Ingen GUI-finpolering eller Raven Vision er berørt.
- Ingen nettverksoppdagelse, sammenkobling, clustering eller AI-konfigurasjon er implementert.

## Test

Regresjonstesten `tests/test_home_control_stable_contract.py` er oppdatert til v1.22.

Kjør fra roten av repoet:

`python tests/test_home_control_stable_contract.py`

Forventet resultat:

`PASS: RAH Home Control v1.22 Stable contract`

Testen verifiserer blant annet at:

- de fire faste rommene fortsatt finnes,
- `knownRoomReference()` finnes,
- både enheter og skjermer går gjennom den samme romreferanse-valideringen,
- både lagret hovedtilstand og importert backup bruker den samme valideringskjeden,
- lokale lagringsnøkler og sentrale rollback-kontrakter er bevart,
- utsatte nettverks-/oppdagelses-API-er fortsatt ikke er introdusert.

## Gjeldende implementert grunnlag

### Rommodell

- Datarom, Stue 1, Stue 2 og Soverom finnes i standardtilstanden.
- Rom kan aktiveres/deaktiveres lokalt.
- Ett rom kan settes som hovedrom.
- Begge kontrollflytene ruller tilbake dersom lokal lagring feiler.
- Fra v1.20 må også en lagret hovedtilstand inneholde alle fire kanoniske rom før den kan rendres.

### Enhetsregister

- Enheter har navn, rom, type, IPv4-adresse, forbindelse, rolle og synlig/lagret-status.
- Navn må være unikt.
- En satt IPv4-adresse valideres og må være unik.
- Legg til, fjern og redigering ruller tilbake ved lagringsfeil.
- Fra v1.21 må en lagret eller importert enhets `room` være et eksisterende romnavn eller `Ikke valgt`.

### Statusvisning og kontrollknapper

- Enheter kan markeres synlige/frakoblede.
- Rom, skjermer og noder har synlig status.
- Statusendringer for enheter, rom, skjermer og noder rulles tilbake dersom lokal lagring feiler.
- Fra v1.22 må også en lagret eller importert skjerms `room` være et eksisterende romnavn eller `Ikke valgt`.
- Filter for enhetsstatus og rom finnes og lagres separat.
- `Nullstill bare filtre` er rollback-sikker fra v1.16.
- Vanlige status- og romfilterknapper er rollback-sikre fra v1.17.

### Lokal lagring og enkel feilhåndtering

- Hovedtilstand lagres under `rah-home-control-v03`.
- Filtervalg lagres under `rah-home-control-filters-v01`.
- Lagringsfeil vises eksplisitt i grensesnittet.
- Uleselige lagrede filtervalg gir synlig feilmelding og trygg fallback fra v1.18.
- Lesbare filterdata med ikke-støttet `status` eller `room` gir synlig feilmelding og feltvis trygg normalisering fra v1.19.
- Fra v1.20 valideres hvert lagret hovedobjekt før rendering; ugyldig lokal hovedtilstand gir fallback til standarddata.
- Fra v1.21 valideres enhetsreferanser mot rommodellen for både lagrede data og backup-import.
- Fra v1.22 valideres skjermreferanser mot samme rommodell.
- Nattoppgavehandlingene beskytter minnet mot lagringsfeil.
- Lokal konfigurasjon kan eksporteres og gjenopprettes via validert JSON-backup.
- Backup-gjenoppretting rulles tilbake dersom lokal lagring feiler.
- `Gjenopprett standarddata` er rollback-sikker fra v1.15.
- Vanlige filtervalg er rollback-sikre fra v1.17.

## Neste avgrensede oppgave

Neste kjøring bør sikre at **romnavn i lagret/importert tilstand er unike**. Romreferanser er nå navnebaserte; derfor skal en tilstand med to rom som begge heter for eksempel `Stue 1` avvises før rendering eller backup-gjenoppretting. Oppgaven skal kun styrke valideringen og regresjonstesten, uten GUI-endringer.

## Senere veikart – ikke implementert ennå

- Oppdagelse og søk etter alle Wi‑Fi-enheter.
- Enkel sammenkobling og godkjenning av enheter.
- Clustering mellom hoved-PC, HP Omen og senere noder.
- Større eller flere AI-hjerner.
- Alternative konfigurasjoner for ledernode, delt arbeid og uavhengige noder.
