# RAH Home Control – punkt 1

## Fullført i denne oppgaven

**Avgrenset oppgave:** gjør `+ Testoppgave` transaksjonssikker ved lokal lagringsfeil.

- Før en ny testoppgave legges til tas en kopi av den eksisterende nattoppgave-køen.
- Ved normal drift legges testoppgaven til som før med status `Venter`.
- Dersom `save()` lykkes, beholdes den nye oppgaven.
- Dersom `save()` feiler, gjenopprettes den tidligere køen umiddelbart i minnet slik at grensesnittet ikke viser en oppgave som ikke faktisk ble lagret.
- Eksisterende lagringsfeilmelding beholdes.
- Ingen ny suksessmelding eller bekreftelsesdialog er lagt til.
- Ingen annen kontrollflyt, rommodell, enhetsregister, filterlogikk, skjermstatus eller node-status er endret.
- Eksisterende lagringsnøkler beholdes: `rah-home-control-v03` og `rah-home-control-filters-v01`.
- Versjonsvisningen er oppdatert til `v1.10`.

## Slik testes oppgaven

1. Åpne `RAH-HOME-CONTROL.html`.
2. Trykk `+ Testoppgave` og kontroller normal drift: én ny oppgave vises med status `Venter`.
3. Last siden på nytt og kontroller at oppgaven fortsatt finnes.
4. For feilsti: blokker eller simuler feil i `localStorage.setItem`.
5. Noter hvor mange nattoppgaver som vises før testen.
6. Trykk `+ Testoppgave`.
7. Kontroller at lagringsfeilen vises.
8. Kontroller at antallet oppgaver etter handlingen er det samme som før, og at ingen ny testoppgave blir stående i grensesnittet.
9. Kontroller at eksisterende oppgavenavn, statusverdier og rekkefølge er uendret.
10. Kontroller at `Fjern`, `Tøm kø`, `Stopp alle`, romkontroller, enhetsregister, filtre, skjermer og noder fortsatt oppfører seg som før.

## Neste avgrensede oppgave

Gjør `+ Legg til enhet` transaksjonssikker: dersom lokal lagring feiler etter at en ny enhet er lagt til, skal enhetslisten og registreringsfeltene håndteres slik at grensesnittet ikke later som enheten er lagret.

## Senere veikart – ikke implementert ennå

- Oppdagelse og søk etter alle Wi‑Fi-enheter.
- Enkel sammenkobling og godkjenning av enheter.
- Clustering mellom hoved-PC, HP Omen og senere noder.
- Større eller flere AI-hjerner.
- Alternative konfigurasjoner for ledernode, delt arbeid og uavhengige noder.
