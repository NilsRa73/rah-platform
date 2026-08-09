# RAH Home Control – punkt 1

## Fullført i denne oppgaven

**Avgrenset oppgave:** krev bekreftelse før en registrert enhet fjernes.

- `Fjern` sletter ikke lenger enheten umiddelbart.
- Før sletting vises nettleserens bekreftelsesdialog med navnet på enheten som skal fjernes.
- `Avbryt` i dialogen lar enheten og lokal lagring være uendret.
- `OK` fjerner bare den valgte enheten og lagrer den oppdaterte enhetslisten.
- Dersom enheten ikke finnes lenger, brukes eksisterende feilmelding i stedet for å forsøke sletting.
- Etter vellykket sletting vises en kort statusmelding med navnet på enheten som ble fjernet.
- Eventuell redigering av samme enhet avsluttes når slettingen fullføres.
- Ingen annen kontrollflyt, filterlogikk, rommodell, skjermstatus, node-status eller nattoppgave-logikk er endret.
- Eksisterende lagringsnøkler beholdes: `rah-home-control-v03` og `rah-home-control-filters-v01`.
- Versjonsvisningen er oppdatert til `v1.3`.

## Slik testes oppgaven

1. Åpne `RAH-HOME-CONTROL.html`.
2. Finn en registrert enhet og trykk `Fjern`.
3. Kontroller at en bekreftelsesdialog vises og at enhetsnavnet står i dialogen.
4. Velg `Avbryt` og kontroller at enheten fortsatt finnes i registeret.
5. Last siden på nytt og kontroller at enheten fortsatt er lagret.
6. Trykk `Fjern` på samme enhet igjen og velg `OK`.
7. Kontroller at bare denne enheten forsvinner fra registeret.
8. Kontroller at statusmeldingen bekrefter hvilken enhet som ble fjernet.
9. Last siden på nytt og kontroller at slettingen er bevart i lokal lagring.
10. Kontroller at rom, filtre, skjermer, noder og nattoppgaver ellers er uendret.

## Neste avgrensede oppgave

Legg inn en enkel bekreftelse før `Gjenopprett standarddata` kjøres, slik at registrerte data ikke nullstilles ved et feilklikk. Ingen annen kontrollflyt skal endres.

## Senere veikart – ikke implementert ennå

- Oppdagelse og søk etter alle Wi‑Fi-enheter.
- Enkel sammenkobling og godkjenning av enheter.
- Clustering mellom hoved-PC, HP Omen og senere noder.
- Større eller flere AI-hjerner.
- Alternative konfigurasjoner for ledernode, delt arbeid og uavhengige noder.
