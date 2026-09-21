# RAH Home Control – punkt 1

## Status: FULLFØRT – Stable/MVP

RAH Home Control v1.25 er en avgrenset, lokal og testbar Stable/MVP. Prioritetsrekkefølgen er gjennomført: rommodell, enhetsregister, statusvisning, kontrollknapper, lokal lagring og enkel feilhåndtering. Vedlikehold av punkt 1 skal ikke utvide omfanget til ekte nettverksoppdagelse eller fysisk styring.

## Stable/MVP-kontrakt

### 1. Rommodell
- Faste kanoniske rom: `Datarom`, `Stue 1`, `Stue 2` og `Soverom`.
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

Runneren registrerer **16 kontrakter** og gjør precheck av runtime, veikart, kontraktfiler og Python-syntaks. Den avviser også nye `test_home_control_*_contract.py`-filer som ikke er registrert.

Forventet sluttresultat:

`RAH HOME CONTROL FINAL/STABLE: PASS (16/16 kontrakter)`

GitHub Actions-workflowen `.github/workflows/validate-home-control-stable.yml` kjører den samme samlede runneren ved relevante endringer og pull requests, og kan startes med `workflow_dispatch`.

## Vedlikeholdslogg

### 2026-09-21 – veikart synkronisert med faktisk testgate
- Én avgrenset oppgave: erstattet den utdaterte seks-testers beskrivelsen med den kanoniske FINAL/STABLE-runneren.
- Dokumentert faktisk gate: 16 registrerte kontrakter og forventet `PASS (16/16 kontrakter)`.
- Verifisert mot `tests/run_home_control_stable.py`, som registrerer 16 kontrakter.
- Verifisert at workflowen allerede kaller `python tests/run_home_control_stable.py`.
- Ingen runtime- eller GUI-endring og ingen senere funksjoner implementert.

**Neste avgrensede oppgave:** legg en liten dokumentasjonskontrakt rundt veikartets `16/16`-markør og runnerkommando dersom dette kan gjøres uten å utvide runtime-scope; ellers gå videre til neste konkrete Stable-feil/regresjon.

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
