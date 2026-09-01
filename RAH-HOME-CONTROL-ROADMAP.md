# RAH Home Control – punkt 1

## Status: FULLFØRT – Stable/MVP

Punkt 1 er ferdigstilt som en avgrenset, lokal og testbar Home Control-MVP. Prioritetsrekkefølgen er gjennomført: rommodell, enhetsregister, statusvisning, kontrollknapper, lokal lagring og enkel feilhåndtering.

Runtime er fortsatt **RAH Home Control v1.24 Stable/MVP**. Denne ferdigstillingen utvider ikke omfanget til ekte nettverksoppdagelse eller fysisk styring.

## Ferdig Stable/MVP-kontrakt

### 1. Rommodell

- Faste kanoniske rom: `Datarom`, `Stue 1`, `Stue 2` og `Soverom`.
- Lagret hovedtilstand må inneholde alle fire rom.
- Romnavn og rom-ID-er må være unike.
- `Aktiver` / `Slå av` endrer bare lokal Home Control-status.
- Vellykket endring bekrefter eksplisitt `aktivt` eller `av`.
- `Hovedrom` gjør valgt rom til eneste aktive rom og bekrefter sluttstatusen eksplisitt.
- Begge romkontrollene ruller tilbake dersom lokal lagring feiler.

### 2. Enhetsregister

- Enheter har navn, rom, type, IPv4-adresse, forbindelse, rolle og lokal synlig/frakoblet-status.
- Enhetsnavn normaliseres og må være unike.
- Enhets-ID-er må være unike; nye ID-er kollisjonssjekkes.
- Satt IPv4-adresse må være gyldig og unik.
- `Ikke satt` kan brukes av flere enheter.
- Enhets- og skjermreferanser til rom valideres.
- Legg til, rediger og fjern er beskyttet med lokal rollback ved lagringsfeil.

### 3. Statusvisning

- Samlet lokal oversikt viser totalt antall enheter, synlige, lagrede/frakoblede og antall vist etter filtre.
- Statusen bygger bare på lokal `online`-markering; ingen nettverkspolling eller discovery brukes.
- `Marker synlig` / `Marker frakoblet` viser eksplisitt hvilken lokal endring som utføres.
- Vellykket statusendring bekrefter ny lokal status.
- Statusendring rulles tilbake dersom lokal lagring feiler.

### 4. Kontrollknapper

- `Aktiver` / `Slå av` for rom er lokal og rollback-sikret.
- `Hovedrom` er eksklusiv, lokal og rollback-sikret.
- Enhetsstatus kan markeres lokalt.
- Eksisterende lokale kontrollknapper for skjermer, noder og manuell oppgavekø endrer bare lokal tilstand.
- Ingen knapp i Stable/MVP påstår fysisk strømstyring eller kontakt med en ekstern enhet.

### 5. Lokal lagring

- Hovedtilstand lagres under `rah-home-control-v03`.
- Filtervalg lagres separat under `rah-home-control-filters-v01`.
- Konfigurasjon kan eksporteres/importeres med schema- og tilstandsvalidering.
- Importert og lagret hovedtilstand valideres før den brukes.
- Visningsfiltre er isolert fra hovedtilstanden.

### 6. Enkel feilhåndtering

- Lokal lagringsfeil vises eksplisitt.
- Sentrale mutasjoner tar rollback-kopi før lagring.
- Ugyldig eller korrupt hovedtilstand avvises før rendering og faller tilbake til `clone(defaults)`.
- Ugyldige filterverdier bruker standardverdi mens gyldige filterverdier beholdes.
- Korrupt filter-JSON faller tilbake til `Alle / Alle rom` uten å endre hovedtilstanden.
- Stable-regresjonstesten låser både hovedtilstands-fallback og filter-fallback.

## Stable-regresjonstest

Kjør fra roten av repoet:

`python tests/test_home_control_stable_contract.py`

Forventet resultat:

`PASS: RAH Home Control v1.24 Stable contract`

Testen låser nå hele punkt 1-kontrakten: de fire rommene, enhetsvalidering, lokal statusvisning, kontrollknapper, rollback, lokal hovedlagring, separat filterlagring, trygg hovedtilstands-fallback og defensiv filter-fallback.

Testen forbyr samtidig kjente nettverks-/discovery-mekanismer i denne Stable-versjonen (`RTCPeerConnection`, Web Bluetooth, Web USB, WebSocket og EventSource), slik at senere funksjoner ikke sniker seg inn i MVP-en ved et uhell.

## Ferdigstillingskriterium

**Punkt 1 regnes som ferdig.** Det er ikke flere planlagte Stable/MVP-oppgaver innenfor denne avgrensningen. Nye endringer i Home Control skal enten være feilrettinger/regresjonsarbeid eller starte en senere milepæl eksplisitt.

## Senere veikart – bevart, ikke implementert

- Oppdagelse og søk etter alle Wi‑Fi-enheter.
- Enkel sammenkobling og godkjenning av enheter.
- Clustering mellom hoved-PC, HP Omen og senere noder.
- Større eller flere AI-hjerner.
- Alternative konfigurasjoner for ledernode, delt arbeid og uavhengige noder.
- Eventuell fysisk enhetsstyring skal være en separat, eksplisitt milepæl med egne sikkerhets- og feilhåndteringskrav.
