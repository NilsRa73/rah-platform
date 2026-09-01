# RAH Home Control — veikart

## Punkt 1: stabil lokal kontroll

Prioritet i denne fasen:
1. rommodell for Datarom, Stue 1, Stue 2 og Soverom
2. enhetsregister
3. statusvisning
4. kontrollknapper
5. lokal lagring
6. enkel feilhåndtering

GUI-finpolering og Raven Vision er utenfor denne fasen.

## Status

- Rommodellen for Datarom, Stue 1, Stue 2 og Soverom er etablert.
- Enhetsregisteret har lokal validering og lokal status.
- Statusvisningen viser totalt, synlige og lagrede/frakoblede enheter.
- `Aktiver / Slå av` bekrefter eksplisitt lokal sluttstatus og har rollback ved lagringsfeil.
- `Hovedrom` gjør valgt rom eksklusivt aktivt, har rollback ved lagringsfeil og bekrefter nå eksplisitt at rommet er **eneste aktive hovedrom** i lokal Home Control-tilstand.
- Stable-regresjonstesten låser denne kontrakten.

## Neste avgrensede oppgave

Lokal lagring: legg en eksplisitt Stable-test rundt fallback ved ugyldige eller korrupte lagrede Home Control-data, slik at standarddata brukes og synlig feilstatus beholdes. Ikke legg til nye funksjoner samtidig.

## Senere krav — bevares, men implementeres ikke ennå

- oppdagelse og søk etter alle Wi-Fi-enheter
- enkel sammenkobling av enheter
- clustering
- større eller flere AI-hjerner
- alternative konfigurasjoner

Disse punktene skal forbli utsatt til den stabile lokale Home Control-kjernen over er ferdig og testet.
