# RAH Home Control – vedlikehold 2026-09-13

## Avgrenset oppgave

Lås eksisterende validering og rollback for `Legg til enhet` med en egen regresjonstest, uten runtime-utvidelse, discovery eller fysisk sammenkobling.

## Utført

- Opprettet `tests/test_home_control_add_device_contract.py`.
- Testen krever at tomt enhetsnavn avvises før lokal tilstand muteres.
- Testen krever at ugyldig IPv4-adresse avvises før lokal tilstand muteres.
- Testen krever at normalisert duplikatnavn avvises før lokal tilstand muteres.
- Testen krever at duplisert IPv4-adresse avvises før lokal tilstand muteres.
- Testen krever rollback-kopi av enhetsregisteret før `state.devices.push(candidate)`.
- Testen krever at registeret gjenopprettes dersom lokal lagring feiler.
- Testen krever at skjemaet beholdes ved lagringsfeil og først tømmes etter vellykket lagring.
- Testen låser tydelig suksess- og feilfeedback.
- Testen bekrefter at hovedtilstanden lagres med lokal `localStorage`.
- Stable-workflowen kjører nå også denne kontrakttesten.
- `RAH-HOME-CONTROL.html` er ikke endret; eksisterende v1.25-runtime hadde allerede korrekt oppførsel.

## Avgrensning

Ingen GUI-finpolering, Raven Vision, Wi-Fi-discovery, nettverkspolling, fysisk enhetspairing eller clustering er implementert i denne oppgaven.

Eksisterende senere veikart i `RAH-HOME-CONTROL-ROADMAP.md` er bevisst bevart:

- oppdagelse og søk etter alle Wi-Fi-enheter,
- enkel sammenkobling og godkjenning av enheter,
- clustering,
- større eller flere AI-hjerner,
- alternative konfigurasjoner.

## Neste avgrensede oppgave

Lås eksisterende validering og rollback for redigering via `Lagre enhet` i en egen liten regresjonstest. Verifiser spesielt at normalisert duplikatnavn og duplisert IPv4-adresse avvises for andre enheter før lokal tilstand muteres, samtidig som den redigerte enhetens egne verdier fortsatt er tillatt. Ikke implementer discovery eller fysisk sammenkobling.
