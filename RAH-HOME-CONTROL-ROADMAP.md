# RAH Home Control – punkt 1

## Fullført i denne oppgaven

**Avgrenset oppgave:** hindre duplikate enhetsnavn, IPv4-adresser og genererte enhets-ID-er.

- Nye enhetsnavn sammenlignes uten hensyn til store og små bokstaver.
- Et navn som allerede finnes, blir avvist med tydelig melding og fokus på navnefeltet.
- En satt IPv4-adresse må fortsatt være gyldig og kan bare brukes av én registrert enhet.
- Tom IP-adresse / `Ikke satt` kan brukes på flere enheter.
- Ved duplikat-IP vises hvilken eksisterende enhet som allerede bruker adressen.
- Nye enhets-ID-er lages med tid, tilfeldig del og en sluttkontroll mot eksisterende ID-er.
- Feilmarkering fjernes når brukeren begynner å rette det aktuelle feltet.
- Eksisterende lagringsnøkkel beholdes, slik at tidligere registrerte data fortsatt lastes.

## Slik testes oppgaven

1. Åpne `RAH-HOME-CONTROL.html`.
2. Forsøk å legge til en enhet med navnet `HP Omen`. Registreringen skal avvises fordi navnet finnes.
3. Forsøk deretter med `hp omen`. Registreringen skal også avvises.
4. Legg til `Testskjerm` med tom IP. Registreringen skal lykkes.
5. Legg til `Testskjerm 2` med tom IP. Dette skal også lykkes.
6. Legg til `Nettbrett 1` med IP `192.168.0.83`. Registreringen skal lykkes dersom adressen ikke finnes fra før.
7. Legg til `Nettbrett 2` med samme IP. Registreringen skal avvises og meldingen skal nevne enheten som bruker adressen.
8. Legg til flere enheter raskt etter hverandre og kontroller at alle kan markeres synlige og fjernes separat. Dette bekrefter at ID-ene er unike.
9. Last siden på nytt og kontroller at godkjente registreringer fortsatt finnes.

## Neste avgrensede oppgave

Gjøre det mulig å redigere rom, rolle og tilkobling for en allerede registrert enhet, med lagring og en enkel avbryt-funksjon.

## Senere veikart – ikke implementert ennå

- Oppdagelse og søk etter alle Wi‑Fi-enheter.
- Enkel sammenkobling og godkjenning av enheter.
- Clustering mellom hoved-PC, HP Omen og senere noder.
- Større eller flere AI-hjerner.
- Alternative konfigurasjoner for ledernode, delt arbeid og uavhengige noder.
