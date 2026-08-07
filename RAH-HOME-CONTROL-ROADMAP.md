# RAH Home Control – punkt 1

## Fullført i denne oppgaven

**Avgrenset oppgave:** nullstill bare statusfilter og romfilter.

- En ny knapp, `Nullstill bare filtre`, er lagt til under filterkontrollene.
- Knappen setter statusfilteret til `Alle` og romfilteret til `Alle rom`.
- Filtervalgene lagres fortsatt under `rah-home-control-filters-v01`.
- Eventuell åpen enhetsredigering lukkes når filtrene nullstilles.
- Registrerte enheter, romstatus, skjermer, noder og nattoppgaver endres ikke.
- Eksisterende enhetsdata bruker fortsatt nøkkelen `rah-home-control-v03`.
- Versjonsvisningen er oppdatert til `v1.1`.

## Slik testes oppgaven

1. Åpne `RAH-HOME-CONTROL.html`.
2. Registrer eventuelt en ekstra test-enhet eller endre status på en eksisterende enhet.
3. Velg statusfilteret `Lagrede / frakoblede`.
4. Velg romfilteret `Datarom`.
5. Trykk `Nullstill bare filtre`.
6. Kontroller at `Alle` og `Alle rom` blir aktive.
7. Kontroller at alle registrerte enheter vises igjen.
8. Last siden på nytt og kontroller at de nullstilte filtervalgene er bevart.
9. Kontroller at enheter, romstatus, skjermer, noder og nattoppgaver ikke er endret.
10. Åpne en enhet for redigering, trykk deretter `Nullstill bare filtre`, og kontroller at redigeringen lukkes uten at enhetsdata endres.

## Neste avgrensede oppgave

Vis en kort, tydelig bekreftelse når bare filtrene nullstilles, uten å bruke feilmeldingsfeltet og uten å endre øvrige data.

## Senere veikart – ikke implementert ennå

- Oppdagelse og søk etter alle Wi‑Fi-enheter.
- Enkel sammenkobling og godkjenning av enheter.
- Clustering mellom hoved-PC, HP Omen og senere noder.
- Større eller flere AI-hjerner.
- Alternative konfigurasjoner for ledernode, delt arbeid og uavhengige noder.
