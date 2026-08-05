# RAH Home Control – punkt 1

## Fullført i denne oppgaven

**Avgrenset oppgave:** romfilter for enhetsregisteret, kombinert med eksisterende statusfilter.

- Enhetsregisteret har nå romfilter for `Alle rom`, `Datarom`, `Stue 1`, `Stue 2`, `Soverom` og `Ikke valgt`.
- Romfilter og statusfilter brukes samtidig. Eksempel: `Synlige` + `Stue 1` viser bare synlige enheter i Stue 1.
- Filtrene endrer ikke registrerte enheter eller lokal lagring.
- Aktivt valg markeres med `aria-pressed`.
- Tellingen viser antall viste enheter og totalt antall registrerte enheter.
- Tomtilstanden er oppdatert til `Ingen enheter passer valgte filtre.`
- Bytte av filter lukker eventuell åpen enhetsredigering, slik at skjulte redigeringsskjema ikke blir stående.
- Eksisterende lagringsnøkkel `rah-home-control-v03` er beholdt, slik at tidligere registrerte data fortsatt lastes.
- Versjonsvisningen i siden er oppdatert til `v0.9`.
- JavaScript-koden er kontrollert med `node --check` uten syntaksfeil.

## Slik testes oppgaven

1. Åpne `RAH-HOME-CONTROL.html`.
2. Kontroller at statusfilteret starter på `Alle` og romfilteret på `Alle rom`.
3. Velg `Datarom`. Standard-enhetene `RAH Hoved-PC` og `HP Omen` skal vises.
4. Legg til en enhet i `Stue 1`, og kontroller at den ikke vises når `Datarom` er valgt.
5. Velg `Stue 1`. Bare enheter registrert i Stue 1 skal vises.
6. Velg samtidig statusen `Lagrede / frakoblede`. Bare frakoblede enheter i Stue 1 skal vises.
7. Marker en vist enhet som synlig. Den skal forsvinne når kombinasjonen `Lagrede / frakoblede` + `Stue 1` er aktiv.
8. Velg `Synlige`. Enheten skal vises igjen dersom den fortsatt er registrert i Stue 1.
9. Velg et rom uten registrerte enheter. Meldingen `Ingen enheter passer valgte filtre.` skal vises.
10. Last siden på nytt. Enhetsdata og status skal fortsatt være lagret, mens begge filtre starter på standardvalgene.

## Neste avgrensede oppgave

Lagre valgt statusfilter og romfilter lokalt, slik at brukerens siste filterkombinasjon gjenopprettes etter ny innlasting. Ugyldige eller utdaterte filterverdier skal falle tilbake til `Alle` og `Alle rom`.

## Senere veikart – ikke implementert ennå

- Oppdagelse og søk etter alle Wi‑Fi-enheter.
- Enkel sammenkobling og godkjenning av enheter.
- Clustering mellom hoved-PC, HP Omen og senere noder.
- Større eller flere AI-hjerner.
- Alternative konfigurasjoner for ledernode, delt arbeid og uavhengige noder.
