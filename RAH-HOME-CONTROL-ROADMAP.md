# RAH Home Control – punkt 1

## Fullført i denne oppgaven

**Avgrenset oppgave:** validere IPv4-adresser ved manuell registrering.

- IP-feltet kan fortsatt stå tomt.
- Når en adresse skrives inn, må den bestå av nøyaktig fire tallgrupper.
- Hver tallgruppe må være mellom 0 og 255.
- Ugyldige adresser blir ikke lagret.
- Feltet markeres tydelig og får fokus ved feil.
- Brukeren får en forståelig melding med et gyldig eksempel.
- Feilmarkeringen fjernes når brukeren begynner å rette adressen.
- Eksisterende lagringsnøkkel beholdes slik at tidligere registrerte data fortsatt lastes.

## Slik testes oppgaven

1. Åpne `RAH-HOME-CONTROL.html`.
2. Skriv et enhetsnavn og la IP-feltet stå tomt. Enheten skal kunne legges til med `Ikke satt`.
3. Prøv `192.168.0.83`. Enheten skal kunne legges til.
4. Prøv `192.168.0.999`. Enheten skal ikke legges til, IP-feltet skal markeres og en feilmelding skal vises.
5. Prøv `192.168.0`. Enheten skal ikke legges til.
6. Prøv `192.168.00.83`. Enheten skal ikke legges til fordi tallgrupper med unødvendige ledende nuller avvises.
7. Etter en gyldig registrering: last siden på nytt og kontroller at enheten fortsatt finnes.

## Neste avgrensede oppgave

Hindre duplikate enhets-ID-er og varsle når en ny enhet bruker samme navn eller samme IPv4-adresse som en eksisterende registrering.

## Senere veikart – ikke implementert ennå

- Oppdagelse og søk etter alle Wi‑Fi-enheter.
- Enkel sammenkobling og godkjenning av enheter.
- Clustering mellom hoved-PC, HP Omen og senere noder.
- Større eller flere AI-hjerner.
- Alternative konfigurasjoner for ledernode, delt arbeid og uavhengige noder.
