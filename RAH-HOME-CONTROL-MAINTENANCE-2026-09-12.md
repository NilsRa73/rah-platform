# RAH Home Control – vedlikehold 2026-09-12

## Avgrenset oppgave

Lås eksisterende lokal enhetsstatus for `Marker synlig` / `Marker frakoblet` med en egen regresjonstest, uten runtime-utvidelse.

## Utført

- Opprettet `tests/test_home_control_device_status_contract.py`.
- Testen krever lokal `SYNLIG` / `LAGRET`-visning og kontrolltekstene `Marker synlig` / `Marker frakoblet`.
- Testen låser statusoppsummeringen med totalt antall enheter, synlige, lagrede/frakoblede og antall vist etter filtre.
- Testen krever rollback-kopi av forrige `online`-verdi før statusendring.
- Testen krever at forrige verdi gjenopprettes dersom lokal hovedlagring feiler.
- Testen låser tydelig suksess- og rollback-feedback.
- Testen bekrefter at statusfilteret bygger på lokal `online`-markering og at hovedtilstanden lagres lokalt.
- Stable-workflowen kjører nå også denne kontrakttesten.
- `RAH-HOME-CONTROL.html` er ikke endret; eksisterende v1.25-runtime hadde allerede korrekt oppførsel.

## Avgrensning

Ingen GUI-finpolering, Raven Vision, fysisk enhetsstyring, nettverkspolling eller discovery er implementert i denne oppgaven.

Eksisterende senere veikart i `RAH-HOME-CONTROL-ROADMAP.md` er bevisst bevart og ikke flyttet inn i Stable/MVP:

- oppdagelse og søk etter alle Wi-Fi-enheter,
- enkel sammenkobling og godkjenning av enheter,
- clustering,
- større eller flere AI-hjerner,
- alternative konfigurasjoner.

## Neste avgrensede oppgave

Lås eksisterende rollback og feedback for `Legg til enhet` i en egen liten regresjonstest, inkludert at en ugyldig eller duplisert IPv4-adresse/navn avvises før lokal tilstand muteres. Ikke implementer discovery eller fysisk sammenkobling.
