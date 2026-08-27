# RAH Home Control – punkt 1

## Fullført i denne kjøringen

**Avgrenset oppgave:** ferdigstille samlet statusvisning for enhetsregisteret.

### Endring

- `RAH-HOME-CONTROL.html` viser nå samlet status direkte i enhetsregisterets teller.
- Statusen skiller mellom:
  - totalt registrerte enheter,
  - synlige enheter (`online === true`),
  - lagrede/frakoblede enheter (`online === false`),
  - hvor mange enheter som vises etter aktive filtre.
- Tellerne beregnes kun fra eksisterende lokal Home Control-tilstand.
- Ingen ping, polling, discovery eller nettverksprober er introdusert.
- Den eksisterende Stable-regresjonstesten krever allerede disse tre statuskategoriene og er nå tilfredsstilt av runtime-implementasjonen.
- Ingen GUI-finpolering, Raven Vision, pairing, clustering eller større AI-funksjoner er implementert.

Eksempel på visning:

`2 totalt · 1 synlige · 1 lagrede/frakoblede · 2 vist`

## Stable/MVP-kontrakt

Home Control v1.24 regnes som Stable/MVP for lokal kontroll.

Dette innebærer nå:

- fast rommodell for Datarom, Stue 1, Stue 2 og Soverom,
- lokalt enhetsregister med unike normaliserte navn,
- satt IPv4 må være gyldig og unik ved opprettelse, lasting og import,
- `Ikke satt` kan brukes av flere enheter,
- unike romnavn, rom-ID-er, enhets-ID-er og enhetsnavn i lagret/importert tilstand,
- samlet lokal status for totalt, synlige og lagrede/frakoblede enheter,
- status- og romfilter med separat lokal lagring,
- lokale kontrollknapper med rollback ved lagringsfeil,
- validert eksport/import av lokal Home Control-konfigurasjon,
- trygg fallback ved ugyldig lagret tilstand.

Stable/MVP betyr fortsatt **ikke** at ekte nettverksoppdagelse eller fysisk enhetsstyring er implementert.

## Test

Kjør fra roten av repoet:

`python tests/test_home_control_stable_contract.py`

Forventet resultat:

`PASS: RAH Home Control v1.24 Stable contract`

Statusdelen av testen krever at runtime inneholder:

- `state.devices.filter(d=>d.online).length`,
- `state.devices.filter(d=>!d.online).length`,
- tekst for `totalt`, `synlige` og `lagrede/frakoblede`.

## Gjeldende implementert grunnlag

### Rommodell

- Datarom, Stue 1, Stue 2 og Soverom finnes i standardtilstanden.
- Rom kan aktiveres/deaktiveres lokalt.
- Ett rom kan settes som hovedrom.
- Begge kontrollflytene ruller tilbake dersom lokal lagring feiler.
- Lagret hovedtilstand må inneholde alle fire kanoniske rom.

### Enhetsregister

- Enheter har navn, rom, type, IPv4-adresse, forbindelse, rolle og lokal synlig/lagret-status.
- Navn og satte IPv4-adresser må være entydige.
- Nye enhets-ID-er kollisjonssjekkes.
- Legg til, fjern og redigering er rollback-sikret ved lagringsfeil.

### Statusvisning

- Enheter kan markeres synlige eller frakoblede manuelt.
- Enhetsregisteret viser nå totalantall, synlige, lagrede/frakoblede og antall vist etter filtre.
- Statusvisningen bruker bare lokal `online`-status.
- Filter for status og rom finnes og lagres separat.

### Lokal lagring og enkel feilhåndtering

- Hovedtilstand lagres under `rah-home-control-v03`.
- Filtervalg lagres under `rah-home-control-filters-v01`.
- Lagringsfeil vises eksplisitt.
- Ugyldig lagret/importert tilstand avvises før rendering.
- Sentrale endringer rulles tilbake dersom lokal lagring feiler.

## Neste avgrensede oppgave

Gå videre til **kontrollknapper** med én liten, testbar forbedring: gjør enhetsstatusknappen tydeligere som en lokal kontroll ved å skille eksplisitt mellom `Marker synlig` og `Marker frakoblet`, og lås at statusendringen fortsatt rulles tilbake dersom lokal lagring feiler. Dette skal fortsatt være rent lokalt og uten ping, discovery eller fysisk device-control.

## Senere veikart – ikke implementert ennå

- Oppdagelse og søk etter alle Wi‑Fi-enheter.
- Enkel sammenkobling og godkjenning av enheter.
- Clustering mellom hoved-PC, HP Omen og senere noder.
- Større eller flere AI-hjerner.
- Alternative konfigurasjoner for ledernode, delt arbeid og uavhengige noder.
