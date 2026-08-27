# RAH Home Control – punkt 1

## Fullført i denne kjøringen

**Avgrenset oppgave:** låse enhetsstatusknappen som en tydelig, lokal kontroll i v1.24 Stable-kontrakten.

### Endring

- Runtime hadde allerede korrekt dynamisk knappetekst:
  - `Marker synlig` når enheten er lagret/frakoblet,
  - `Marker frakoblet` når enheten er synlig.
- Ingen Home Control-runtime ble endret i denne kjøringen.
- `tests/test_home_control_stable_contract.py` krever nå eksplisitt begge statusretningene.
- Stable-testen låser også at statusendringen tar vare på forrige `online`-verdi og ruller tilbake dersom lokal lagring feiler.
- Statusen er fortsatt bare lokal Home Control-tilstand. Ingen ping, polling, discovery eller fysisk device-control er introdusert.
- Home Control runtime forblir **v1.24 Stable/MVP**.

## Stable/MVP-kontrakt

Home Control v1.24 regnes som Stable/MVP for lokal kontroll.

Dette innebærer nå:

- fast rommodell for Datarom, Stue 1, Stue 2 og Soverom,
- lokalt enhetsregister med unike normaliserte navn,
- satt IPv4 må være gyldig og unik ved opprettelse, lasting og import,
- `Ikke satt` kan brukes av flere enheter,
- unike romnavn, rom-ID-er, enhets-ID-er og enhetsnavn i lagret/importert tilstand,
- samlet lokal status for totalt, synlige og lagrede/frakoblede enheter,
- tydelige lokale statusknapper: `Marker synlig` / `Marker frakoblet`,
- statusendring med rollback dersom lokal lagring feiler,
- status- og romfilter med separat lokal lagring,
- øvrige lokale kontrollknapper med rollback ved lagringsfeil,
- validert eksport/import av lokal Home Control-konfigurasjon,
- trygg fallback ved ugyldig lagret tilstand.

Stable/MVP betyr fortsatt **ikke** at ekte nettverksoppdagelse eller fysisk enhetsstyring er implementert.

## Test

Kjør fra roten av repoet:

`python tests/test_home_control_stable_contract.py`

Forventet resultat:

`PASS: RAH Home Control v1.24 Stable contract`

Statusdelen av testen krever nå blant annet:

- `state.devices.filter(d=>d.online).length`,
- `state.devices.filter(d=>!d.online).length`,
- `d.online?'Marker frakoblet':'Marker synlig'`,
- `const previousOnline=d.online;d.online=!d.online`,
- rollback til `previousOnline` når `save()` feiler.

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

### Statusvisning og lokal kontroll

- Enheter kan markeres synlige eller frakoblede manuelt.
- Knappen sier eksplisitt hvilken lokale statusendring et klikk vil gjøre.
- Enhetsregisteret viser totalantall, synlige, lagrede/frakoblede og antall vist etter filtre.
- Statusvisningen bruker bare lokal `online`-status.
- Filter for status og rom finnes og lagres separat.

### Lokal lagring og enkel feilhåndtering

- Hovedtilstand lagres under `rah-home-control-v03`.
- Filtervalg lagres under `rah-home-control-filters-v01`.
- Lagringsfeil vises eksplisitt.
- Ugyldig lagret/importert tilstand avvises før rendering.
- Sentrale endringer rulles tilbake dersom lokal lagring feiler.

## Neste avgrensede oppgave

Gjør **bekreftelsen etter en lokal statusendring** like tydelig som selve knappen: suksessmeldingen skal si om enheten nå er markert `synlig` eller `frakoblet`, uten å antyde at en fysisk enhet er slått på, koblet fra eller kontaktet. Lås teksten med Stable-regresjonstesten og behold samme rollback-adferd.

## Senere veikart – ikke implementert ennå

- Oppdagelse og søk etter alle Wi‑Fi-enheter.
- Enkel sammenkobling og godkjenning av enheter.
- Clustering mellom hoved-PC, HP Omen og senere noder.
- Større eller flere AI-hjerner.
- Alternative konfigurasjoner for ledernode, delt arbeid og uavhengige noder.
