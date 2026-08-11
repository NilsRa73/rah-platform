# RAH Home Control – punkt 1

## Fullført i denne oppgaven

**Avgrenset oppgave:** behold nattoppgave-køen i minnet dersom lokal lagring feiler under `Tøm kø`.

- Før tømming tas en kopi av den eksisterende nattoppgave-køen.
- `Tøm kø` bruker fortsatt eksisterende bekreftelsesdialog.
- Ved `Avbryt` endres ingenting.
- Ved `OK` forsøkes den tomme køen lagret lokalt.
- Dersom `save()` lykkes, beholdes tom kø og eksisterende grønne bekreftelsesmelding vises.
- Dersom `save()` feiler, gjenopprettes den tidligere køen umiddelbart i minnet og grensesnittet viser oppgavene igjen.
- Eksisterende lagringsfeilmelding beholdes, og ingen falsk suksessmelding vises.
- Ingen annen kontrollflyt, rommodell, enhetsregister, filterlogikk, skjermstatus eller node-status er endret.
- Eksisterende lagringsnøkler beholdes: `rah-home-control-v03` og `rah-home-control-filters-v01`.
- Versjonsvisningen er oppdatert til `v1.7`.

## Slik testes oppgaven

1. Åpne `RAH-HOME-CONTROL.html`.
2. Trykk `+ Testoppgave` minst to ganger.
3. Trykk `Tøm kø`, velg `Avbryt`, og kontroller at køen er urørt.
4. Trykk `Tøm kø` igjen, velg `OK`, og kontroller normal suksess: køen blir tom og suksessmeldingen vises.
5. Legg deretter inn minst to nye testoppgaver.
6. For feilsti: blokker eller simuler feil i `localStorage.setItem`.
7. Trykk `Tøm kø` og velg `OK`.
8. Kontroller at lagringsfeilen vises og at de opprinnelige oppgavene fortsatt vises i køen med samme navn og status.
9. Kontroller at ingen grønn tømmingsmelding vises ved lagringsfeil.
10. Kontroller at romkontroller, enhetsregister, filtre, skjermer og noder fortsatt oppfører seg som før.

## Neste avgrensede oppgave

Gjør fjerning av én enkelt nattoppgave transaksjonssikker på samme måte: dersom lokal lagring feiler etter `Fjern`, skal den fjernede oppgaven gjenopprettes i minnet på samme plass.

## Senere veikart – ikke implementert ennå

- Oppdagelse og søk etter alle Wi‑Fi-enheter.
- Enkel sammenkobling og godkjenning av enheter.
- Clustering mellom hoved-PC, HP Omen og senere noder.
- Større eller flere AI-hjerner.
- Alternative konfigurasjoner for ledernode, delt arbeid og uavhengige noder.
