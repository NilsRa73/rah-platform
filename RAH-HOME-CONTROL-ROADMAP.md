# RAH Home Control – punkt 1

## Fullført i denne oppgaven

**Avgrenset oppgave:** gjør `+ Legg til enhet` transaksjonssikker ved lokal lagringsfeil.

- Før en ny enhet legges til tas en kopi av den eksisterende enhetslisten.
- Validering av navn og IPv4-adresse beholdes som før.
- Ved normal drift legges den nye enheten til og lagres lokalt.
- Registreringsfeltene for navn og IP tømmes først etter at `save()` har lykkes.
- Dersom `save()` feiler, gjenopprettes den tidligere enhetslisten umiddelbart i minnet.
- Ved lagringsfeil beholdes innskrevet navn, IP og valgte felt slik at brukeren kan prøve igjen uten å skrive inn alt på nytt.
- Eksisterende lagringsfeilmelding beholdes.
- Ingen annen rommodell, filterlogikk, skjermstatus, node-status eller nattoppgave-logikk er endret.
- Eksisterende lagringsnøkler beholdes: `rah-home-control-v03` og `rah-home-control-filters-v01`.
- Versjonsvisningen skal oppdateres til `v1.11` sammen med kodeendringen.

## Slik testes oppgaven

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

Gjør `Fjern` for en registrert enhet transaksjonssikker: dersom lokal lagring feiler etter sletting, skal enheten gjenopprettes i minnet på samme plass og redigeringsstatus ikke mistes unødvendig.

## Senere veikart – ikke implementert ennå

- Oppdagelse og søk etter alle Wi‑Fi-enheter.
- Enkel sammenkobling og godkjenning av enheter.
- Clustering mellom hoved-PC, HP Omen og senere noder.
- Større eller flere AI-hjerner.
- Alternative konfigurasjoner for ledernode, delt arbeid og uavhengige noder.
