# RAH Home Control – punkt 1

## Status: FULLFØRT – Stable/MVP

Punkt 1 er ferdigstilt som en avgrenset, lokal og testbar Home Control-MVP. Prioritetsrekkefølgen er gjennomført: rommodell, enhetsregister, statusvisning, kontrollknapper, lokal lagring og enkel feilhåndtering.

Runtime er nå **RAH Home Control v1.25 Stable/MVP**. Vedlikeholdsarbeidet utvider ikke omfanget til ekte nettverksoppdagelse eller fysisk styring.

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
- Statusfilter, romfilter og `Nullstill bare filtre` beholder tidligere filtervalg dersom separat filterlagring feiler.
- En åpen enhetsredigering gjenopprettes også ved filterlagringsfeil, slik at en ren visningsendring ikke mister brukerens lokale redigeringskontekst.
- Den manuelle lokale oppgavekøen tar rollback-kopi ved `+ Testoppgave`, `Fjern`, `Tøm kø` og `Stopp alle` før lokal lagring forsøkes.
- `+ Testoppgave`, `Fjern`, `Tøm kø` og `Stopp alle` viser eksplisitt suksess ved lagring og tydelig rollback-feil ved lagringssvikt.
- Stable-regresjonstestene låser hovedtilstands-fallback, filter-fallback, rollback for filterendringer og feedback/rollback-kontrakten for den lokale oppgavekøen.

## Stable-regresjonstest og CI

Lokale tester fra roten av repoet:

`python tests/test_home_control_stable_contract.py`

`python tests/test_home_control_task_queue_contract.py`

Forventede resultater:

`PASS: RAH Home Control v1.25 Stable contract`

`PASS: RAH Home Control local task queue feedback and rollback contract`

Testene låser punkt 1-kontrakten: de fire rommene, enhetsvalidering, lokal statusvisning, kontrollknapper, rollback, lokal hovedlagring, separat filterlagring, trygg hovedtilstands-fallback, defensiv filter-fallback, transaksjonell rollback ved filterendringer og lokal feedback/rollback for manuell oppgavekø.

Testene forbyr samtidig kjente nettverks-/discovery-mekanismer i denne Stable-versjonen (`RTCPeerConnection`, Web Bluetooth, Web USB, WebSocket og EventSource), slik at senere funksjoner ikke sniker seg inn i MVP-en ved et uhell.

GitHub Actions-filen `.github/workflows/validate-home-control-stable.yml` kjører begge Stable-testene automatisk når Home Control-runtime, Stable-testene, dette veikartet eller selve workflowen endres, og ved relevante pull requests. Workflowen kan også startes manuelt med `workflow_dispatch`.

## Vedlikeholdslogg

### 2026-09-05 – `Tøm kø` har eksplisitt rollback-feedback

- Én avgrenset oppgave utført: `Tøm kø` viser nå en konkret feilmelding dersom lokal lagring svikter etter at den forrige køtilstanden er gjenopprettet.
- Eksisterende suksessmelding og bekreftelsesdialog er beholdt uendret.
- `tests/test_home_control_task_queue_contract.py` låser nå både suksess- og rollback-meldingen for `Tøm kø`.
- Ingen discovery, pairing, clustering, AI-utvidelser, Raven Vision eller GUI-finpolering ble lagt til.

**Neste avgrensede oppgave:** lås eksisterende rollback ved `Gjenopprett standarddata` tydeligere i Stable-regresjonstesten, uten runtime-utvidelse.

### 2026-09-04 – tydelig feedback og rollback i lokal oppgavekø

- Én avgrenset oppgave utført: `+ Testoppgave`, `Fjern` og `Stopp alle` viser nå eksplisitt suksessmelding når lokal lagring lykkes.
- De samme tre operasjonene viser en konkret rollback-feilmelding dersom lokal lagring svikter, etter at forrige køtilstand er gjenopprettet.
- `tests/test_home_control_task_queue_contract.py` er utvidet slik at både suksess- og rollback-meldingene er del av regresjonskontrakten.
- Ingen automatisk kjøring, discovery, pairing, clustering, AI-utvidelser, Raven Vision eller GUI-finpolering ble lagt til.

### 2026-09-03 – lokal oppgavekø-rollback låst i egen regresjonstest

- Én avgrenset oppgave utført: opprettet `tests/test_home_control_task_queue_contract.py` for å låse eksisterende rollback ved `+ Testoppgave`, `Fjern`, `Tøm kø` og `Stopp alle`.
- Stable-workflowen kjører nå både hovedkontrakten og den nye oppgavekø-kontrakten.
- Ingen runtime-funksjoner, GUI-polering, discovery, pairing, clustering eller AI-utvidelser ble implementert i denne kjøringen.

### 2026-09-02 – filter-rollback låst i Stable-testen

- Én avgrenset oppgave utført: utvidet `tests/test_home_control_stable_contract.py` slik at eksisterende rollback ved statusfilter, romfilter og nullstilling av filtre er eksplisitt testet.
- Ingen runtime-funksjoner, GUI eller senere nettverksfunksjoner ble lagt til i denne kjøringen.
- Målet er å hindre regresjon i enkel feilhåndtering når filterlagring feiler.

## Ferdigstillingskriterium

**Punkt 1 regnes som ferdig som Stable/MVP.** Videre kjøringer i punkt 1 er små, avgrensede feilrettinger og regresjonsforbedringer. Senere milepæler startes eksplisitt.

## Senere veikart – bevart, ikke implementert

- Oppdagelse og søk etter alle Wi‑Fi-enheter.
- Enkel sammenkobling og godkjenning av enheter.
- Clustering mellom hoved-PC, HP Omen og senere noder.
- Større eller flere AI-hjerner.
- Alternative konfigurasjoner for ledernode, delt arbeid og uavhengige noder.
- Eventuell fysisk enhetsstyring skal være en separat, eksplisitt milepæl med egne sikkerhets- og feilhåndteringskrav.
- Raven Vision er ikke del av punkt 1 nå.
