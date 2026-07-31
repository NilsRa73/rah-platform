# RAH Home Control – punkt 1

## Fullført i denne oppgaven

**Avgrenset oppgave:** robust lokal lagring og enkel gjenoppretting.

- Kontrollerer at lagrede data har forventede lister for rom, enheter, skjermer, noder og oppgaver.
- Faller tilbake til standarddata dersom JSON eller datastrukturen er ødelagt.
- Viser en tydelig feilmelding i siden i stedet for å stoppe JavaScript.
- Fanger feil ved skriving til `localStorage`.
- Har knapp for **Gjenopprett standarddata**.
- Beholder eksisterende lagringsnøkkel slik at data fra v0.3 fortsatt kan lastes.

## Slik testes oppgaven

1. Åpne `RAH-HOME-CONTROL.html` og legg til en test-enhet.
2. Last siden på nytt og kontroller at enheten fortsatt finnes.
3. Åpne nettleserens utviklerverktøy og sett `rah-home-control-v03` til ugyldig tekst, for eksempel `{feil`.
4. Last siden på nytt.
5. Siden skal fortsatt åpne, vise standarddata og en tydelig melding om lagringsfeil.
6. Trykk **Gjenopprett standarddata** og last siden på nytt. Feilmeldingen skal være borte.

## Neste avgrensede oppgave

Validere IPv4-adresser ved manuell registrering og vise en forståelig melding når adressen er ugyldig.

## Senere veikart – ikke implementert ennå

- Oppdagelse og søk etter alle Wi‑Fi-enheter.
- Enkel sammenkobling og godkjenning av enheter.
- Clustering mellom hoved-PC, HP Omen og senere noder.
- Større eller flere AI-hjerner.
- Alternative konfigurasjoner for ledernode, delt arbeid og uavhengige noder.
