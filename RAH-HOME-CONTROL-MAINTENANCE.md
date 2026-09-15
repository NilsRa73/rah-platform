# RAH Home Control – vedlikeholdsnotat

## 2026-09-15 – enhetsregister: `Fjern` rollback-kontrakt låst

Én avgrenset oppgave ble utført: eksisterende `Fjern`-flyt i enhetsregisteret er nå låst med `tests/test_home_control_remove_device_contract.py`.

Testen verifiserer at sletting fortsatt:

- finner samme enhet via ID og håndterer at enheten ikke lenger finnes,
- krever eksplisitt bekreftelse før registeret muteres,
- tar kopi av både enhetslisten og aktiv `editingDeviceId` før sletting,
- fjerner enheten lokalt og lukker aktiv redigering når den slettede enheten var under redigering,
- lagrer via Home Controls lokale hovedlagring,
- viser eksplisitt suksessmelding etter vellykket lagring,
- gjenoppretter både enhetslisten og tidligere redigerings-ID dersom lokal lagring feiler,
- viser tydelig rollback-feil ved lagringssvikt.

Runtime `RAH-HOME-CONTROL.html` ble ikke utvidet; eksisterende v1.25-adferd var allerede korrekt. Stable-workflowen kjører nå også remove-device-kontrakten. Testen forbyr samtidig kjente discovery-/nettverksmekanismer, slik at oppgaven ikke introduserer Wi-Fi discovery, WebRTC, Web Bluetooth, Web USB, WebSocket eller EventSource.

## Neste avgrensede oppgave

Lås lokal filterlagring for enhetsregisteret i en egen liten regresjonstest: statusfilter og romfilter skal lagres separat fra hovedtilstanden, ugyldige lagrede filterverdier skal falle tilbake kontrollert, og lagringsfeil skal gi tydelig feedback uten å endre enhetsdata. Ingen discovery eller fysisk enhetskontakt.

## Senere veikart – bevart, ikke implementert

Disse kravene forblir senere milepæler og skal ikke implementeres i Stable/MVP-vedlikeholdet:

- oppdagelse og søk etter alle Wi-Fi-enheter,
- enkel sammenkobling og godkjenning av enheter,
- clustering mellom noder,
- større eller flere AI-hjerner,
- alternative konfigurasjoner for ledernode, delt arbeid og uavhengige noder,
- Raven Vision.
