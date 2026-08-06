# RAH Home Control – punkt 1

## Fullført i denne oppgaven

**Avgrenset oppgave:** lagre valgt statusfilter og romfilter lokalt.

- Statusfilteret lagres nå som `all`, `online` eller `offline`.
- Romfilteret lagres nå som `all`, `Datarom`, `Stue 1`, `Stue 2`, `Soverom` eller `Ikke valgt`.
- Siste gyldige filterkombinasjon gjenopprettes etter at siden lastes på nytt.
- Filtervalg lagres separat under nøkkelen `rah-home-control-filters-v01`.
- Eksisterende enhetsdata bruker fortsatt nøkkelen `rah-home-control-v03`, slik at tidligere registrerte data beholdes.
- Ugyldige, utdaterte eller ødelagte filterverdier faller trygt tilbake til `Alle` og `Alle rom`.
- `Gjenopprett standarddata` nullstiller også filtervalgene.
- Versjonsvisningen er oppdatert til `v1.0`.
- JavaScript-koden er kontrollert med `node --check` uten syntaksfeil.

## Slik testes oppgaven

1. Åpne `RAH-HOME-CONTROL.html`.
2. Velg statusfilteret `Lagrede / frakoblede`.
3. Velg romfilteret `Datarom`.
4. Last siden på nytt.
5. Kontroller at begge filterknappene fortsatt er aktive og at riktig enhetsutvalg vises.
6. Åpne nettleserens utviklerverktøy og sett `rah-home-control-filters-v01` til ugyldig JSON. Last siden på nytt.
7. Kontroller at siden fortsatt åpnes og at filtrene faller tilbake til `Alle` og `Alle rom`.
8. Sett gyldig JSON med ukjente verdier, for eksempel `{"status":"x","room":"y"}`. Last siden på nytt.
9. Kontroller samme trygge tilbakefall.
10. Kontroller at registrerte enheter og romstatus fortsatt er bevart.

## Neste avgrensede oppgave

Legg til en egen knapp som nullstiller bare statusfilter og romfilter uten å endre registrerte enheter, romstatus, skjermer, noder eller nattoppgaver.

## Senere veikart – ikke implementert ennå

- Oppdagelse og søk etter alle Wi‑Fi-enheter.
- Enkel sammenkobling og godkjenning av enheter.
- Clustering mellom hoved-PC, HP Omen og senere noder.
- Større eller flere AI-hjerner.
- Alternative konfigurasjoner for ledernode, delt arbeid og uavhengige noder.
