# RAH Home Control – punkt 1

## Status for denne kjøringen

**Avgrenset oppgave:** gjør `+ Legg til enhet` transaksjonssikker ved lokal lagringsfeil.

Kodeendringen er spesifisert og testet lokalt for JavaScript-syntaks, men skriving av `RAH-HOME-CONTROL.html` ble stoppet av GitHub-connectorens sikkerhetskontroll før commit. Derfor er oppgaven **ikke markert som ferdig i kode ennå**.

Planlagt endring i `+ Legg til enhet`:

- Før en ny enhet legges til tas en kopi av den eksisterende enhetslisten.
- Validering av navn og IPv4-adresse beholdes som før.
- Ved normal drift legges den nye enheten til og lagres lokalt.
- Registreringsfeltene for navn og IP tømmes først etter at `save()` har lykkes.
- Dersom `save()` feiler, gjenopprettes den tidligere enhetslisten umiddelbart i minnet.
- Ved lagringsfeil beholdes innskrevet navn, IP og øvrige valgte felt slik at brukeren kan prøve igjen uten å skrive inn alt på nytt.
- Eksisterende lagringsnøkler skal beholdes: `rah-home-control-v03` og `rah-home-control-filters-v01`.

## Test når kodeendringen er committed

1. Åpne `RAH-HOME-CONTROL.html`.
2. Fyll inn et unikt enhetsnavn og eventuelt en gyldig IPv4-adresse.
3. Velg rom, type, forbindelse og rolle.
4. Trykk `+ Legg til enhet` og kontroller normal drift: enheten vises og navn/IP-feltene tømmes.
5. Last siden på nytt og kontroller at enheten fortsatt finnes.
6. For feilsti: blokker eller simuler feil i `localStorage.setItem`.
7. Fyll inn en ny unik enhet og trykk `+ Legg til enhet`.
8. Kontroller at lagringsfeilen vises og at den nye enheten ikke blir stående i registeret.
9. Kontroller at navn, IP og øvrige valgte registreringsfelt fortsatt står i skjemaet etter feilen.
10. Kontroller at eksisterende enheter, romkontroller, filtre, skjermer, noder og nattoppgaver er uendret.

## Neste avgrensede oppgave

Fullfør commit av den transaksjonssikre `+ Legg til enhet`-flyten i `RAH-HOME-CONTROL.html`. Etter at den er verifisert, er neste funksjonelle oppgave å gjøre `Fjern` for en registrert enhet transaksjonssikker ved lagringsfeil.

## Senere veikart – ikke implementert ennå

- Oppdagelse og søk etter alle Wi‑Fi-enheter.
- Enkel sammenkobling og godkjenning av enheter.
- Clustering mellom hoved-PC, HP Omen og senere noder.
- Større eller flere AI-hjerner.
- Alternative konfigurasjoner for ledernode, delt arbeid og uavhengige noder.
