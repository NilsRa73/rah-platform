# RAH Home Control – vedlikehold 2026-09-11

## Utført oppgave

Én avgrenset oppgave: lås eksisterende lokal romstatus og rollback for `Aktiver`, `Slå av` og `Hovedrom` uten runtime-utvidelse.

## Endringer

- Opprettet `tests/test_home_control_room_status_contract.py`.
- Testen krever de fire kanoniske rommene: `Datarom`, `Stue 1`, `Stue 2` og `Soverom`.
- Testen låser lokal status `AKTIV` / `KLAR` og kontrolltekstene `Aktiver` / `Slå av`.
- Testen låser rollback av enkeltrom dersom lokal hovedlagring feiler.
- Testen låser at `Hovedrom` gjør valgt rom til eneste aktive rom, tar full kopi av romlisten før mutasjon og gjenoppretter denne ved lagringsfeil.
- Testen krever tydelig lokal suksess- og rollback-feedback.
- Stable-workflowen er utvidet til å kjøre romstatus-kontrakten.
- `RAH-HOME-CONTROL.html` er ikke endret; eksisterende v1.25-adferd var allerede korrekt.

## Bevisst ikke implementert

Følgende senere krav beholdes i `RAH-HOME-CONTROL-ROADMAP.md` og er ikke implementert i denne kjøringen:

- oppdagelse og søk etter alle Wi-Fi-enheter
- enkel sammenkobling av enheter
- clustering
- større eller flere AI-hjerner
- alternative konfigurasjoner
- Raven Vision
- GUI-finpolering

## Neste avgrensede oppgave

Lås enhetsregisterets eksisterende lokale `Marker synlig` / `Marker frakoblet`-rollback og tilhørende status-teller i en egen liten regresjonstest, uten runtime- eller nettverksutvidelse.
