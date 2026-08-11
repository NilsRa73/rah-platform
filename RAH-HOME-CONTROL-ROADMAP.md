# RAH Home Control – punkt 1

## Fullført i denne oppgaven

**Avgrenset oppgave:** krev bekreftelse før `Tøm kø` for nattoppgaver kjøres.

- `Tøm kø` sletter ikke lenger nattoppgavene umiddelbart.
- Før tømming vises nettleserens bekreftelsesdialog.
- Dialogen viser hvor mange oppgaver som vil bli fjernet.
- `Avbryt` lar hele den eksisterende nattoppgave-køen være urørt.
- `OK` bruker den eksisterende kontrollflyten til å tømme køen og lagre den tomme køen lokalt.
- Ingen annen kontrollflyt, rommodell, enhetsregister, filterlogikk, skjermstatus eller node-status er endret.
- Eksisterende lagringsnøkler beholdes: `rah-home-control-v03` og `rah-home-control-filters-v01`.
- Versjonsvisningen er oppdatert til `v1.5`.

## Slik testes oppgaven

1. Åpne `RAH-HOME-CONTROL.html`.
2. Trykk `+ Testoppgave` minst to ganger og kontroller at oppgavene vises i køen.
3. Trykk `Tøm kø`.
4. Kontroller at bekreftelsesdialogen vises før noen oppgaver fjernes, og at antallet oppgaver i meldingen stemmer.
5. Velg `Avbryt` og kontroller at alle oppgavene fortsatt ligger i køen.
6. Last siden på nytt og kontroller at oppgavene fortsatt finnes i lokal lagring.
7. Trykk `Tøm kø` igjen og velg `OK`.
8. Kontroller at køen blir tom og at telleren viser `0 i kø`.
9. Last siden på nytt og kontroller at den tomme køen er lagret.
10. Kontroller at `+ Testoppgave`, `Stopp alle`, romkontroller og enhetsregister fortsatt oppfører seg som før.

## Neste avgrensede oppgave

Vis en kort, ikke-forstyrrende bekreftelsesmelding etter at `Tøm kø` er gjennomført og lagringen lykkes. Meldingen skal ikke vises dersom brukeren velger `Avbryt` eller dersom lokal lagring feiler.

## Senere veikart – ikke implementert ennå

- Oppdagelse og søk etter alle Wi‑Fi-enheter.
- Enkel sammenkobling og godkjenning av enheter.
- Clustering mellom hoved-PC, HP Omen og senere noder.
- Større eller flere AI-hjerner.
- Alternative konfigurasjoner for ledernode, delt arbeid og uavhengige noder.
