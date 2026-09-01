# RAH Home Control – punkt 1

## Fullført i denne kjøringen

**Avgrenset oppgave:** låse fallback ved ugyldige eller korrupte lokalt lagrede Home Control-data i Stable-regresjonstesten.

### Endring

- `tests/test_home_control_stable_contract.py` krever nå at hovedtilstanden JSON-parses og valideres med `validStoredState` før den kan brukes.
- Testen krever eksplisitt lagringsfeil-status når lagrede data ikke kan leses eller valideres.
- Testen krever den eksisterende tydelige fallback-meldingen til brukeren.
- Testen krever at fallback returnerer en frisk kopi av standarddata via `clone(defaults)`.
- Runtime-adferden i `RAH-HOME-CONTROL.html` var allerede implementert; denne kjøringen gjør den til en eksplisitt Stable-kontrakt og endrer ikke runtime.
- Ingen ping, polling, Wi‑Fi-discovery, pairing, clustering eller Raven Vision ble introdusert.
- Home Control runtime forblir **v1.24 Stable/MVP**.

## Stable/MVP-kontrakt

Home Control v1.24 regnes som Stable/MVP for lokal kontroll.

Dette innebærer nå:

- fast rommodell for Datarom, Stue 1, Stue 2 og Soverom,
- lokal `Aktiver` / `Slå av`-kontroll for rom,
- eksplisitt lokal rombekreftelse som sier `aktivt` eller `av`,
- lokal `Hovedrom`-kontroll som gjør valgt rom eksklusivt aktivt,
- eksplisitt bekreftelse på at valgt rom er eneste aktive hovedrom,
- rollback av romtilstand dersom lokal lagring feiler,
- lokalt enhetsregister med unike normaliserte navn,
- satt IPv4 må være gyldig og unik ved opprettelse, lasting og import,
- `Ikke satt` kan brukes av flere enheter,
- unike romnavn, rom-ID-er, enhets-ID-er og enhetsnavn i lagret/importert tilstand,
- samlet lokal status for totalt, synlige og lagrede/frakoblede enheter,
- tydelige lokale statusknapper: `Marker synlig` / `Marker frakoblet`,
- eksplisitt lokal suksessbekreftelse som sier `synlig` eller `frakoblet`,
- statusendring med rollback dersom lokal lagring feiler,
- status- og romfilter med separat lokal lagring,
- øvrige lokale kontrollknapper med rollback ved lagringsfeil,
- validert eksport/import av lokal Home Control-konfigurasjon,
- trygg fallback ved ugyldig eller korrupt lagret hovedtilstand,
- Stable-test som eksplisitt låser fallback-status, feilmelding og standarddata.

Stable/MVP betyr fortsatt **ikke** at ekte nettverksoppdagelse eller fysisk enhetsstyring er implementert.

## Test

Kjør fra roten av repoet:

`python tests/test_home_control_stable_contract.py`

Forventet resultat:

`PASS: RAH Home Control v1.24 Stable contract`

Fallback-delen av testen krever nå blant annet:

- `JSON.parse(raw)` før lagret tilstand brukes,
- `validStoredState(parsed)` før rendering,
- eksplisitt `Lagringsfeil`-status ved korrupt/ugyldig lagring,
- tydelig melding om at standarddata er lastet,
- `clone(defaults)` som sikker midlertidig fallback.

## Gjeldende implementert grunnlag

### Rommodell

- Datarom, Stue 1, Stue 2 og Soverom finnes i standardtilstanden.
- Rom kan aktiveres/deaktiveres lokalt.
- Vellykket romendring bekreftes med den faktiske lokale sluttstatusen `aktivt` eller `av`.
- Ett rom kan settes som hovedrom.
- `Hovedrom` gjør valgt rom eksklusivt aktivt og bekrefter dette eksplisitt.
- Begge kontrollflytene ruller tilbake dersom lokal lagring feiler.
- Lagret hovedtilstand må inneholde alle fire kanoniske rom.

### Enhetsregister

- Enheter har navn, rom, type, IPv4-adresse, forbindelse, rolle og lokal synlig/lagret-status.
- Navn og satte IPv4-adresser må være entydige.
- Nye enhets-ID-er kollisjonssjekkes.
- Legg til, fjern og redigering er rollback-sikret ved lagringsfeil.

### Statusvisning og lokal kontroll

- Enheter kan markeres synlige eller frakoblede manuelt.
- Knappen sier eksplisitt hvilken lokal statusendring et klikk vil gjøre.
- Suksessmeldingen sier eksplisitt hvilken lokal status enheten fikk.
- Enhetsregisteret viser totalantall, synlige, lagrede/frakoblede og antall vist etter filtre.
- Statusvisningen bruker bare lokal `online`-status.
- Filter for status og rom finnes og lagres separat.

### Lokal lagring og enkel feilhåndtering

- Hovedtilstand lagres under `rah-home-control-v03`.
- Filtervalg lagres under `rah-home-control-filters-v01`.
- Lagringsfeil vises eksplisitt.
- Ugyldig eller korrupt lagret hovedtilstand avvises før rendering og erstattes midlertidig med en frisk kopi av standarddata.
- Stable-regresjonstesten låser nå denne fallback-adferden.
- Sentrale endringer rulles tilbake dersom lokal lagring feiler.

## Neste avgrensede oppgave

Lås **fallback ved ugyldige eller korrupte lagrede filterdata** like eksplisitt i Stable-regresjonstesten: ugyldige filterverdier skal bruke standardverdi, gyldige verdier skal beholdes, og korrupt JSON skal falle tilbake til `Alle / Alle rom` uten å påvirke hovedtilstanden.

## Senere veikart – ikke implementert ennå

- Oppdagelse og søk etter alle Wi‑Fi-enheter.
- Enkel sammenkobling og godkjenning av enheter.
- Clustering mellom hoved-PC, HP Omen og senere noder.
- Større eller flere AI-hjerner.
- Alternative konfigurasjoner for ledernode, delt arbeid og uavhengige noder.
