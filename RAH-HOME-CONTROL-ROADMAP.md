# RAH Home Control – punkt 1

## Fullført i denne kjøringen

**Avgrenset oppgave:** låse `Hovedrom` som en eksplisitt, testbar lokal kontroll i v1.24 Stable-kontrakten.

### Endring

- Runtime hadde allerede én `Hovedrom`-knapp per rom.
- Klikk på `Hovedrom` gjør valgt rom eksklusivt aktivt og de øvrige rommene inaktive.
- Handlingen tar kopi av forrige romtilstand før endring.
- Hvis lokal lagring feiler, gjenopprettes hele forrige romtilstand.
- Ved suksess vises eksplisitt at valgt rom er satt som hovedrom og lagret lokalt.
- `tests/test_home_control_stable_contract.py` låser nå hele denne kontrollflyten.
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

Kontrolldelen av testen krever nå blant annet:

- `data-main="${r.id}"`,
- `document.querySelectorAll('[data-main]')`,
- `const previousRooms=clone(state.rooms)`,
- `state.rooms.forEach(r=>r.active=r.id===b.dataset.main)`,
- rollback til `previousRooms` dersom `save()` feiler,
- lokal suksessbekreftelse etter lagring.

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

Gjør **bekreftelsen etter en lokal enhetsstatusendring** like tydelig som selve knappen: suksessmeldingen skal si om enheten nå er markert `synlig` eller `frakoblet`, uten å antyde at en fysisk enhet er slått på, koblet fra eller kontaktet. Lås teksten med Stable-regresjonstesten og behold samme rollback-adferd.

## Senere veikart – ikke implementert ennå

- Oppdagelse og søk etter alle Wi‑Fi-enheter.
- Enkel sammenkobling og godkjenning av enheter.
- Clustering mellom hoved-PC, HP Omen og senere noder.
- Større eller flere AI-hjerner.
- Alternative konfigurasjoner for ledernode, delt arbeid og uavhengige noder.
