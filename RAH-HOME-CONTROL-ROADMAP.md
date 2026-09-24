# RAH Home Control – punkt 1

## Status: FULLFØRT – Stable/MVP

RAH Home Control v1.25 er en avgrenset, lokal og testbar Stable/MVP. Prioritetsrekkefølgen er gjennomført: rommodell, enhetsregister, statusvisning, kontrollknapper, lokal lagring og enkel feilhåndtering. Vedlikehold av punkt 1 skal ikke utvide omfanget til ekte nettverksoppdagelse eller fysisk styring.

## Stable/MVP-kontrakt

### 1. Rommodell
- Faste kanoniske rom: `Datarom`, `Stue 1`, `Stue 2` og `Soverom`.
- Kanonisk ID-mapping er låst til `datarom → Datarom`, `stue1 → Stue 1`, `stue2 → Stue 2`, `soverom → Soverom`.
- Lagret hovedtilstand må inneholde alle fire rom; romnavn og rom-ID-er er unike.
- `Aktiver` / `Slå av` endrer bare lokal status.
- `Hovedrom` gjør valgt rom til eneste aktive rom.
- Romkontroller ruller tilbake dersom lokal lagring feiler.

### 2. Enhetsregister
- Enheter har navn, rom, type, IPv4-adresse, forbindelse, rolle og lokal synlig/frakoblet-status.
- Navn og ID-er er unike; satt IPv4-adresse må være gyldig og unik.
- `Ikke satt` kan brukes av flere enheter.
- Romreferanser valideres.
- Legg til, rediger og fjern er rollback-sikret ved lagringsfeil.
- En egen regresjonskontrakt låser MVP-feltene og de kanoniske lokale valgene for rom, forbindelse og rolle.

### 3. Statusvisning
- Lokal oversikt viser totalt antall enheter, synlige, lagrede/frakoblede og antall etter filtre.
- Status bygger bare på lokal markering; ingen nettverkspolling eller discovery brukes.
- Enhets-, skjerm- og node-status har eksplisitt lokal feedback og rollback ved lagringsfeil.

### 4. Kontrollknapper
- Rom: `Aktiver`, `Slå av`, `Hovedrom`.
- Enheter: lokal synlig/frakoblet-status.
- Skjermer/noder/oppgavekø: eksisterende lokale testkontroller.
- Ingen knapp i Stable/MVP påstår fysisk strømstyring eller kontakt med ekstern enhet.

### 5. Lokal lagring
- Hovedtilstand: `rah-home-control-v03`.
- Filtre: `rah-home-control-filters-v01`.
- Import/eksport bruker schema- og tilstandsvalidering.
- Lagret hovedtilstand valideres før bruk; filtre er isolert fra hovedtilstanden.

### 6. Enkel feilhåndtering
- Lagringsfeil vises eksplisitt og sentrale mutasjoner bruker rollback-kopi.
- Ugyldig/korrupt hovedtilstand avvises og faller tilbake til `clone(defaults)`.
- Ugyldige eller korrupte filtre faller trygt tilbake uten å skade hovedtilstanden.
- Reset, backup-restore, rom-, enhets-, skjerm-, node- og oppgavekømutasjoner er dekket av Stable-kontrakter.

## FINAL/STABLE-testgate

Kanonisk lokal kommando fra repo-roten:

`python tests/run_home_control_stable.py`

Runneren registrerer **17 kontrakter** og gjør precheck av runtime, veikart, kontraktfiler og Python-syntaks. Den avviser også nye `test_home_control_*_contract.py`-filer som ikke er registrert. Prechecken krever dessuten at veikartet fortsatt inneholder den kanoniske runnerkommandoen og `PASS (17/17 kontrakter)`-markøren, slik at dokumentasjonen ikke stille driver bort fra den faktiske Stable-gaten.

Forventet sluttresultat:

`RAH HOME CONTROL FINAL/STABLE: PASS (17/17 kontrakter)`

GitHub Actions-workflowen `.github/workflows/validate-home-control-stable.yml` kjører den samme samlede runneren ved relevante endringer og pull requests, og kan startes med `workflow_dispatch`.

## Vedlikeholdslogg

### 2026-09-24 – enhetsregisterets MVP-schema låst
- Én avgrenset oppgave i neste prioriterte område: enhetsregisteret.
- Ny `test_home_control_device_registry_contract.py` verifiserer at et lokalt enhetsobjekt fortsatt har navn, rom, type, IPv4, forbindelse, rolle og lokal status.
- Kontrakten låser også kanoniske lokale valg for rom, forbindelse og rolle, samt eksisterende integritetsregler for unik ID, unikt navn, IPv4 og romreferanse.
- FINAL/STABLE-runneren registrerer nå 17 kontrakter.
- Ingen runtime-, GUI-, discovery-, pairing-, clustering-, AI- eller Raven Vision-funksjon ble lagt til.

**Neste avgrensede oppgave:** gjennomgå statusvisningen for ett konkret udekket regresjonshull og beskytt bare det.

### 2026-09-23 – kanonisk rom-ID-mapping låst
- Én avgrenset oppgave i høyest prioriterte område: rommodellen.
- Stable-kontrakten verifiserer nå eksplisitt mappingen `datarom → Datarom`, `stue1 → Stue 1`, `stue2 → Stue 2`, `soverom → Soverom` i standardmodellen.
- Testbar effekt: utilsiktet endring av en kanonisk rom-ID eller kobling mellom ID og navn får `test_home_control_stable_contract.py` til å feile.
- Ingen runtime-, GUI-, discovery-, pairing-, clustering-, AI- eller Raven Vision-funksjon ble lagt til.

### 2026-09-22 – regresjonsvern for veikartets Stable-gate
- Én avgrenset oppgave: la FINAL/STABLE-prechecken validere veikartets kanoniske runnerkommando og `PASS (16/16 kontrakter)`-markør.
- Testbar effekt: dersom en av markørene fjernes eller endres, stopper runneren i PRECHECK med tydelig dokumentasjonsdrift-feil.
- Ingen ny runtime-funksjon, GUI-endring eller ekstra kontraktfil; Stable-gaten var da 16/16.
- Senere scope er fortsatt bare bevart i veikartet.

### 2026-09-21 – veikart synkronisert med faktisk testgate
- Én avgrenset oppgave: erstattet den utdaterte seks-testers beskrivelsen med den kanoniske FINAL/STABLE-runneren.
- Dokumentert faktisk gate på dette tidspunktet: 16 registrerte kontrakter og forventet `PASS (16/16 kontrakter)`.
- Verifisert at workflowen allerede kaller `python tests/run_home_control_stable.py`.
- Ingen runtime- eller GUI-endring og ingen senere funksjoner implementert.

## Ferdigstillingskriterium

**Punkt 1 regnes som ferdig som Stable/MVP.** Videre kjøringer er små, avgrensede feilrettinger, regresjonsforbedringer eller dokumentasjonssynk. Senere milepæler startes eksplisitt.

## Senere veikart – bevart, ikke implementert

- Oppdagelse og søk etter alle Wi‑Fi-enheter.
- Enkel sammenkobling og godkjenning av enheter.
- Clustering mellom hoved-PC, HP Omen og senere noder.
- Større eller flere AI-hjerner.
- Alternative konfigurasjoner for ledernode, delt arbeid og uavhengige noder.
- Eventuell fysisk enhetsstyring som separat milepæl med egne sikkerhets- og feilhåndteringskrav.
- Raven Vision er ikke del av punkt 1.
