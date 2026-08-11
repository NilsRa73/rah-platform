# RAH Home Control – punkt 1

## Fullført i denne oppgaven

**Avgrenset oppgave:** gjør `Stopp alle` for nattoppgaver transaksjonssikker ved lokal lagringsfeil.

- Før statusene endres tas en kopi av hele nattoppgave-køen.
- Ved normal drift settes alle nattoppgaver fortsatt til `Stoppet`.
- Dersom `save()` lykkes, beholdes de nye statusverdiene.
- Dersom `save()` feiler, gjenopprettes hele den tidligere køen i minnet med opprinnelige statusverdier, navn og rekkefølge.
- Eksisterende lagringsfeilmelding beholdes.
- Ingen ny suksessmelding eller bekreftelsesdialog er lagt til.
- Ingen annen kontrollflyt, rommodell, enhetsregister, filterlogikk, skjermstatus eller node-status er endret.
- Eksisterende lagringsnøkler beholdes: `rah-home-control-v03` og `rah-home-control-filters-v01`.
- Versjonsvisningen er oppdatert til `v1.9`.

## Slik testes oppgaven

1. Åpne `RAH-HOME-CONTROL.html`.
2. Legg til minst to testoppgaver og kontroller at de står som `Venter`.
3. Trykk `Stopp alle` og kontroller normal drift: alle statusene blir `Stoppet`.
4. Last siden på nytt og kontroller at `Stoppet` er lagret.
5. Opprett nye testoppgaver slik at køen igjen inneholder minst én oppgave med status `Venter`.
6. For feilsti: blokker eller simuler feil i `localStorage.setItem`.
7. Trykk `Stopp alle`.
8. Kontroller at lagringsfeilen vises og at oppgavenes tidligere statusverdier kommer tilbake i grensesnittet.
9. Kontroller at navn, rekkefølge og antall oppgaver er uendret etter tilbakeføring.
10. Kontroller at `Fjern`, `Tøm kø`, romkontroller, enhetsregister, filtre, skjermer og noder fortsatt oppfører seg som før.

## Neste avgrensede oppgave

Gjør `+ Testoppgave` transaksjonssikker: dersom lokal lagring feiler etter at en testoppgave er lagt til, skal den nye oppgaven fjernes igjen fra minnet slik at grensesnittet samsvarer med det som faktisk er lagret.

## Senere veikart – ikke implementert ennå

- Oppdagelse og søk etter alle Wi‑Fi-enheter.
- Enkel sammenkobling og godkjenning av enheter.
- Clustering mellom hoved-PC, HP Omen og senere noder.
- Større eller flere AI-hjerner.
- Alternative konfigurasjoner for ledernode, delt arbeid og uavhengige noder.
