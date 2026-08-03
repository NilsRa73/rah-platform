# RAH Home Control – punkt 1

## Fullført i denne oppgaven

**Avgrenset oppgave:** redigere rom, tilkobling og rolle for en allerede registrert enhet.

- Hvert enhetskort har nå en `Rediger`-knapp.
- Redigeringsmodus viser tre felt: rom, tilkobling og rolle.
- `Lagre` oppdaterer enheten og skriver endringen til eksisterende lokal lagring.
- `Avbryt` lukker redigeringen uten å endre data.
- Bare én enhet kan være i redigeringsmodus om gangen.
- `Lukk redigering` lukker det åpne skjemaet uten lagring.
- Dersom enheten ikke lenger finnes ved lagring, vises en enkel feilmelding.
- Fjerning av en enhet lukker eventuell aktiv redigering for samme enhet.
- Navn, type og IPv4-adresse redigeres ikke i denne oppgaven, slik at endringen forblir tydelig avgrenset.
- Eksisterende lagringsnøkkel `rah-home-control-v03` er beholdt, så tidligere registrerte data lastes fortsatt.
- JavaScript-koden er kontrollert med `node --check` uten syntaksfeil.

## Slik testes oppgaven

1. Åpne `RAH-HOME-CONTROL.html`.
2. Finn `HP Omen` og trykk `Rediger`.
3. Endre rom fra `Datarom` til `Stue 1`.
4. Endre tilkobling fra `Ethernet` til `Wi-Fi`.
5. Endre rolle fra `Arbeidsnode` til `Medieenhet`.
6. Trykk `Avbryt`. Kortet skal fortsatt vise de opprinnelige verdiene.
7. Trykk `Rediger` igjen, gjør de samme endringene og trykk `Lagre`.
8. Kortet skal nå vise `Stue 1`, `Wi-Fi` og `Medieenhet`.
9. Last siden på nytt. De nye verdiene skal fortsatt være lagret.
10. Åpne redigering på én enhet og deretter på en annen. Bare den siste skal ha åpent redigeringsskjema.

## Neste avgrensede oppgave

Legge til et enkelt statusfilter for enhetsregisteret: vis alle, bare synlige eller bare lagrede/frakoblede enheter. Filteret skal ikke endre lagrede data.

## Senere veikart – ikke implementert ennå

- Oppdagelse og søk etter alle Wi‑Fi-enheter.
- Enkel sammenkobling og godkjenning av enheter.
- Clustering mellom hoved-PC, HP Omen og senere noder.
- Større eller flere AI-hjerner.
- Alternative konfigurasjoner for ledernode, delt arbeid og uavhengige noder.
