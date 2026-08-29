# RAH Home Control – punkt 1

## Fullført i denne kjøringen

**Avgrenset oppgave:** gjøre bekreftelsen etter lokal enhetsstatusendring eksplisitt og testbar.

### Endring

- `Marker synlig` / `Marker frakoblet` endrer fortsatt bare lokal `online`-status.
- Etter vellykket lagring sier meldingen nå eksplisitt om enheten er markert `synlig` eller `frakoblet`.
- Teksten antyder ikke at en fysisk enhet er slått på, slått av, kontaktet eller koblet fra nettverket.
- Eksisterende rollback ved lagringsfeil er bevart uendret.
- `tests/test_home_control_stable_contract.py` låser nå denne bekreftelsen som del av Stable-kontrakten.
- Ingen ping, polling, Wi‑Fi-discovery, pairing, clustering eller fysisk enhetsstyring ble introdusert.
- Home Control runtime forblir **v1.24 Stable/MVP**.

## Stable/MVP-kontrakt

Home Control v1.24 regnes som Stable/MVP for lokal kontroll.

Dette innebærer nå:

- fast rommodell for Datarom, Stue 1, Stue 2 og Soverom,
- lokal `Aktiver` / `Slå av`-kontroll for rom,
- lokal `Hovedrom`-kontroll som gjør valgt rom eksklusivt aktivt,
- rollback av hele romtilstanden dersom lagring av Hovedrom feiler,
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
- trygg fallback ved ugyldig lagret tilstand.

Stable/MVP betyr fortsatt **ikke** at ekte nettverksoppdagelse eller fysisk enhetsstyring er implementert.

## Test

Kjør fra roten av repoet:

`python tests/test_home_control_stable_contract.py`

Forventet resultat:

`PASS: RAH Home Control v1.24 Stable contract`

Statusdelen av testen krever nå blant annet:

- `d.online?'Marker frakoblet':'Marker synlig'`,
- rollback-kopi før endring,
- rollback dersom `save()` feiler,
- eksplisitt bekreftelse med `synlig` eller `frakoblet` etter vellykket lagring.

## Gjeldende implementert grunnlag

### Rommodell

- Datarom, Stue 1, Stue 2 og Soverom finnes i standardtilstanden.
- Rom kan aktiveres/deaktiveres lokalt.
- Ett rom kan settes som hovedrom.
- `Hovedrom` gjør valgt rom eksklusivt aktivt.
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
- Ugyldig lagret/importert tilstand avvises før rendering.
- Sentrale endringer rulles tilbake dersom lokal lagring feiler.

## Neste avgrensede oppgave

Gjør **romkontrollen `Aktiver` / `Slå av`** like eksplisitt i suksessmeldingen: meldingen skal si om rommet nå er `aktivt` eller `av`, uten å antyde fysisk strømstyring. Lås teksten i Stable-regresjonstesten og behold eksisterende rollback-adferd.

## Senere veikart – ikke implementert ennå

- Oppdagelse og søk etter alle Wi‑Fi-enheter.
- Enkel sammenkobling og godkjenning av enheter.
- Clustering mellom hoved-PC, HP Omen og senere noder.
- Større eller flere AI-hjerner.
- Alternative konfigurasjoner for ledernode, delt arbeid og uavhengige noder.
