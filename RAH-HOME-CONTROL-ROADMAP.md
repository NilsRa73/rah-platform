# RAH Home Control – punkt 1

## Fullført i denne oppgaven

**Avgrenset oppgave:** vis en kort bekreftelsesmelding etter at `Tøm kø` er gjennomført og lokal lagring lykkes.

- `Tøm kø` bruker fortsatt eksisterende bekreftelsesdialog før noen oppgaver fjernes.
- Ved `Avbryt` endres ikke køen, og ingen grønn bekreftelsesmelding vises.
- Ved `OK` tømmes køen som før.
- Den eksisterende `save()`-funksjonens returverdi brukes nå til å avgjøre om handlingen faktisk ble lagret.
- Grønn statusmelding vises bare når lagringen lykkes: `Nattoppgave-køen er tømt og lagret lokalt.`
- Ved lagringsfeil brukes eksisterende feilhåndtering, og suksessmeldingen vises ikke.
- En tidligere suksessmelding skjules når en ny `Tøm kø`-handling starter, slik at gammel status ikke kan mistolkes som resultat av den nye handlingen.
- Ingen annen kontrollflyt, rommodell, enhetsregister, filterlogikk, skjermstatus eller node-status er endret.
- Eksisterende lagringsnøkler beholdes: `rah-home-control-v03` og `rah-home-control-filters-v01`.
- Versjonsvisningen er oppdatert til `v1.6`.

## Slik testes oppgaven

1. Åpne `RAH-HOME-CONTROL.html`.
2. Trykk `+ Testoppgave` minst én gang.
3. Trykk `Tøm kø` og velg `Avbryt`.
4. Kontroller at køen fortsatt inneholder oppgaven og at ingen grønn tømmingsmelding vises.
5. Trykk `Tøm kø` igjen og velg `OK`.
6. Kontroller at køen blir tom, telleren viser `0 i kø`, og meldingen `Nattoppgave-køen er tømt og lagret lokalt.` vises.
7. Last siden på nytt og kontroller at køen fortsatt er tom.
8. For feilsti: blokker eller simuler feil i `localStorage.setItem`, legg til en oppgave og forsøk `Tøm kø` med `OK`.
9. Kontroller at eksisterende lagringsfeil vises, og at den grønne suksessmeldingen ikke vises.
10. Kontroller at romkontroller, enhetsregister, filtre, skjermer og noder fortsatt oppfører seg som før.

## Neste avgrensede oppgave

Gjør `Tøm kø` transaksjonssikrere ved å beholde den eksisterende nattoppgave-køen i minnet dersom lokal lagring feiler. Da skal en lagringsfeil ikke etterlate grensesnittet med tom kø før siden lastes på nytt.

## Senere veikart – ikke implementert ennå

- Oppdagelse og søk etter alle Wi‑Fi-enheter.
- Enkel sammenkobling og godkjenning av enheter.
- Clustering mellom hoved-PC, HP Omen og senere noder.
- Større eller flere AI-hjerner.
- Alternative konfigurasjoner for ledernode, delt arbeid og uavhengige noder.
