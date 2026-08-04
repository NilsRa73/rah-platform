# RAH Home Control – punkt 1

## Fullført i denne oppgaven

**Avgrenset oppgave:** statusfilter for enhetsregisteret.

- Enhetsregisteret har nå tre filtervalg: `Alle`, `Synlige` og `Lagrede / frakoblede`.
- Filteret bruker eksisterende `online`-status og endrer ikke lagrede enhetsdata.
- Aktivt filter markeres med `aria-pressed`, slik at valgt status også er tydelig for hjelpemidler.
- Tellingen viser både antall enheter som vises og totalt antall registrerte enheter.
- Dersom ingen enheter passer filteret, vises en tydelig tomtilstand.
- Bytte av filter lukker eventuell åpen redigering, slik at skjulte redigeringsskjema ikke blir hengende igjen.
- Filteret starter alltid på `Alle` etter ny innlasting og lagres ikke; dette er bevisst for å holde oppgaven avgrenset.
- Eksisterende lagringsnøkkel `rah-home-control-v03` er beholdt, så tidligere registrerte data lastes fortsatt.
- JavaScript-koden er kontrollert med `node --check` uten syntaksfeil.

## Slik testes oppgaven

1. Åpne `RAH-HOME-CONTROL.html`.
2. Kontroller at både `RAH Hoved-PC` og `HP Omen` vises når `Alle` er valgt.
3. Trykk `Synlige`. Bare enheter merket `SYNLIG` skal vises.
4. Trykk `Lagrede / frakoblede`. Bare enheter merket `LAGRET` skal vises.
5. Marker `HP Omen` som synlig mens filteret `Lagrede / frakoblede` er aktivt. Kortet skal forsvinne fra dette filteret.
6. Trykk `Synlige`. `HP Omen` skal nå vises der.
7. Marker alle enheter som synlige og velg `Lagrede / frakoblede`. Meldingen `Ingen enheter passer valgt statusfilter.` skal vises.
8. Last siden på nytt. Enhetsstatusene skal fortsatt være lagret, mens filteret skal starte på `Alle`.
9. Kontroller at tellingen viser både antall viste og totalt registrerte enheter.

## Neste avgrensede oppgave

Legge til et enkelt romfilter for enhetsregisteret: alle rom, Datarom, Stue 1, Stue 2, Soverom og Ikke valgt. Romfilteret skal kunne brukes sammen med statusfilteret uten å endre lagrede data.

## Senere veikart – ikke implementert ennå

- Oppdagelse og søk etter alle Wi‑Fi-enheter.
- Enkel sammenkobling og godkjenning av enheter.
- Clustering mellom hoved-PC, HP Omen og senere noder.
- Større eller flere AI-hjerner.
- Alternative konfigurasjoner for ledernode, delt arbeid og uavhengige noder.
