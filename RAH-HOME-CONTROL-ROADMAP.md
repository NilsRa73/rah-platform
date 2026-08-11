# RAH Home Control – punkt 1

## Fullført i denne oppgaven

**Avgrenset oppgave:** gjør fjerning av én enkelt nattoppgave transaksjonssikker ved lokal lagringsfeil.

- Før `Fjern` endrer køen tas en kopi av den eksisterende nattoppgave-køen.
- Valgt oppgave fjernes fortsatt umiddelbart ved normal drift.
- Dersom `save()` lykkes, beholdes den oppdaterte køen.
- Dersom `save()` feiler, gjenopprettes hele den tidligere køen i minnet, slik at den fjernede oppgaven kommer tilbake på samme plass med samme navn og status.
- Eksisterende lagringsfeilmelding beholdes.
- Ingen grønn suksessmelding er lagt til for denne handlingen.
- Ingen annen kontrollflyt, rommodell, enhetsregister, filterlogikk, skjermstatus eller node-status er endret.
- Eksisterende lagringsnøkler beholdes: `rah-home-control-v03` og `rah-home-control-filters-v01`.
- Versjonsvisningen er oppdatert til `v1.8`.

## Slik testes oppgaven

1. Åpne `RAH-HOME-CONTROL.html`.
2. Trykk `+ Testoppgave` minst tre ganger.
3. Trykk `Fjern` på oppgaven i midten og kontroller normal drift: bare valgt oppgave forsvinner.
4. Last siden på nytt og kontroller at den fjernede oppgaven fortsatt er borte.
5. Legg inn minst tre testoppgaver på nytt.
6. For feilsti: blokker eller simuler feil i `localStorage.setItem`.
7. Trykk `Fjern` på oppgaven i midten.
8. Kontroller at lagringsfeilen vises og at alle opprinnelige oppgaver fortsatt vises i samme rekkefølge med samme navn og status.
9. Kontroller at telleren fortsatt viser korrekt antall oppgaver etter tilbakeføring.
10. Kontroller at `Tøm kø`, `Stopp alle`, romkontroller, enhetsregister, filtre, skjermer og noder fortsatt oppfører seg som før.

## Neste avgrensede oppgave

Gjør `Stopp alle` transaksjonssikker: dersom lokal lagring feiler, skal de tidligere statusverdiene på nattoppgavene gjenopprettes i minnet i stedet for å bli stående som `Stoppet` i grensesnittet.

## Senere veikart – ikke implementert ennå

- Oppdagelse og søk etter alle Wi‑Fi-enheter.
- Enkel sammenkobling og godkjenning av enheter.
- Clustering mellom hoved-PC, HP Omen og senere noder.
- Større eller flere AI-hjerner.
- Alternative konfigurasjoner for ledernode, delt arbeid og uavhengige noder.
