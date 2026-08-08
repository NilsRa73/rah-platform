# RAH Home Control – punkt 1

## Fullført i denne oppgaven

**Avgrenset oppgave:** vis en kort og tydelig bekreftelse når bare filtrene nullstilles.

- `Nullstill bare filtre` viser nå en egen grønn statusmelding etter vellykket nullstilling.
- Meldingen sier eksplisitt at filtrene er satt til `Alle` og `Alle rom`.
- Meldingen bekrefter også at ingen enhetsdata ble endret.
- Bekreftelsen bruker et eget `role="status"` / `aria-live="polite"`-felt og bruker ikke feilmeldingsfeltet.
- Bekreftelsen vises bare dersom filtervalgene faktisk kunne lagres lokalt.
- Ved lagringsfeil brukes fortsatt eksisterende feilhåndtering.
- Bekreftelsen ryddes bort når brukeren velger et nytt filter, legger til en enhet eller gjenoppretter standarddata.
- Registrerte enheter, romstatus, skjermer, noder og nattoppgaver endres ikke av filter-nullstillingen.
- Eksisterende lagringsnøkler beholdes: `rah-home-control-v03` og `rah-home-control-filters-v01`.
- Versjonsvisningen er oppdatert til `v1.2`.

## Slik testes oppgaven

1. Åpne `RAH-HOME-CONTROL.html`.
2. Velg statusfilteret `Lagrede / frakoblede`.
3. Velg romfilteret `Datarom`.
4. Trykk `Nullstill bare filtre`.
5. Kontroller at `Alle` og `Alle rom` blir aktive.
6. Kontroller at en grønn bekreftelse vises med teksten om at filtrene er nullstilt og at ingen enhetsdata ble endret.
7. Kontroller at det røde feilmeldingsfeltet ikke brukes for denne bekreftelsen.
8. Kontroller at registrerte enheter og øvrig Home Control-status er uendret.
9. Velg et nytt filter og kontroller at bekreftelsen forsvinner.
10. Last siden på nytt og kontroller at de nullstilte filtrene fortsatt er lagret.

## Neste avgrensede oppgave

Legg inn en enkel bekreftelse før en registrert enhet fjernes, slik at et feilklikk ikke sletter enheten umiddelbart. Ingen annen kontrollflyt skal endres.

## Senere veikart – ikke implementert ennå

- Oppdagelse og søk etter alle Wi‑Fi-enheter.
- Enkel sammenkobling og godkjenning av enheter.
- Clustering mellom hoved-PC, HP Omen og senere noder.
- Større eller flere AI-hjerner.
- Alternative konfigurasjoner for ledernode, delt arbeid og uavhengige noder.
