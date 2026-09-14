# RAH Home Control – vedlikeholdsnotat

## 2026-09-14 – enhetsredigering: lokal rollback-kontrakt låst

Én avgrenset oppgave ble utført: eksisterende `Lagre`-flyt ved enhetsredigering er nå låst med `tests/test_home_control_edit_device_contract.py`.

Testen verifiserer at redigering fortsatt:

- finner og oppdaterer samme enhet via ID,
- håndterer at enheten ikke lenger finnes,
- tar `previousDevice`-kopi før rom, forbindelse eller rolle muteres,
- lagrer via Home Controls lokale hovedlagring,
- lukker redigeringspanelet først etter vellykket lagring,
- viser eksplisitt suksessmelding,
- gjenoppretter den forrige enheten dersom lokal lagring feiler,
- beholder redigeringspanelet og viser tydelig rollback-feil ved lagringssvikt.

Runtime `RAH-HOME-CONTROL.html` ble ikke utvidet i denne oppgaven; eksisterende v1.25-adferd var allerede korrekt for feltene som faktisk kan redigeres i Stable/MVP. Ingen GUI-finpolering eller Raven Vision ble gjort.

Stable-workflowen kjører nå også denne kontraktstesten. Testen forbyr samtidig kjente discovery-/nettverksmekanismer i Stable-runtime, slik at oppgaven ikke introduserer Wi-Fi discovery, WebRTC, Web Bluetooth, Web USB, WebSocket eller EventSource.

## Neste avgrensede oppgave

Lås `Fjern` fra enhetsregisteret i en egen liten regresjonstest: bekreftelse før sletting, rollback av både enhetslisten og aktiv redigerings-ID ved lokal lagringsfeil, samt tydelig suksess-/feilfeedback. Ingen fysisk enhetskontakt eller discovery.

## Senere veikart – bevart, ikke implementert

Disse kravene forblir senere milepæler og skal ikke implementeres i Stable/MVP-vedlikeholdet:

- oppdagelse og søk etter alle Wi-Fi-enheter,
- enkel sammenkobling og godkjenning av enheter,
- clustering mellom noder,
- større eller flere AI-hjerner,
- alternative konfigurasjoner for ledernode, delt arbeid og uavhengige noder,
- Raven Vision.
