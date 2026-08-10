# RAH Home Control – punkt 1

## Fullført i denne oppgaven

**Avgrenset oppgave:** krev bekreftelse før `Gjenopprett standarddata` kjøres.

- `Gjenopprett standarddata` nullstiller ikke lenger Home Control-data umiddelbart.
- Før nullstilling vises nettleserens bekreftelsesdialog.
- Dialogen forklarer at registrerte Home Control-data og lagrede filtervalg vil bli nullstilt.
- `Avbryt` lar eksisterende data og filtervalg være urørt.
- `OK` kjører den eksisterende gjenopprettingen av standarddata og standardfiltre.
- Ingen annen kontrollflyt, filterlogikk, rommodell, enhetsregister, skjermstatus, node-status eller nattoppgave-logikk er endret.
- Eksisterende lagringsnøkler beholdes: `rah-home-control-v03` og `rah-home-control-filters-v01`.
- Versjonsvisningen er oppdatert til `v1.4`.

## Slik testes oppgaven

1. Åpne `RAH-HOME-CONTROL.html`.
2. Legg til en test-enhet og velg et annet status- eller romfilter enn standard.
3. Fremprovoser eller bruk en tilstand der knappen `Gjenopprett standarddata` er synlig, og trykk knappen.
4. Kontroller at en bekreftelsesdialog vises før noen data endres.
5. Velg `Avbryt` og kontroller at test-enheten og filtervalgene fortsatt er beholdt.
6. Last siden på nytt og kontroller at de fortsatt finnes i lokal lagring.
7. Trykk `Gjenopprett standarddata` igjen og velg `OK`.
8. Kontroller at standarddata lastes og filtrene settes tilbake til `Alle` og `Alle rom`.
9. Last siden på nytt og kontroller at standardtilstanden er lagret.
10. Kontroller at øvrige knapper og visninger oppfører seg som før.

## Neste avgrensede oppgave

Legg inn en enkel bekreftelse før `Tøm kø` for nattoppgaver kjøres, slik at en eksisterende lokal oppgavekø ikke slettes ved et feilklikk. Ingen annen kontrollflyt skal endres.

## Senere veikart – ikke implementert ennå

- Oppdagelse og søk etter alle Wi‑Fi-enheter.
- Enkel sammenkobling og godkjenning av enheter.
- Clustering mellom hoved-PC, HP Omen og senere noder.
- Større eller flere AI-hjerner.
- Alternative konfigurasjoner for ledernode, delt arbeid og uavhengige noder.
