# RAH Home Control – vedlikehold 2026-09-18

## Avgrenset oppgave

Lås grensen mellom **punkt 1 Stable/MVP** og senere Home Control-milepæler i en automatisk regresjonstest. Ingen runtime- eller GUI-funksjoner er lagt til.

## Gjort

- Lagt til `tests/test_home_control_deferred_scope_contract.py`.
- Testen krever at veikartet fortsatt bevarer: oppdagelse/søk etter alle Wi‑Fi-enheter, enkel sammenkobling/godkjenning, clustering, større/flere AI-hjerner og alternative nodekonfigurasjoner.
- Testen krever at Raven Vision fortsatt er eksplisitt utsatt fra punkt 1.
- Testen avviser kjente nettverks-/discovery-mekanismer i Stable/MVP-runtime (`RTCPeerConnection`, Web Bluetooth, Web USB, WebSocket og EventSource).
- `tests/run_home_control_stable.py` er oppdatert slik at den nye kontrakten er del av den samlede FINAL/STABLE-gaten.

## Test

Kjør fra repo-roten:

```text
python tests/test_home_control_deferred_scope_contract.py
python tests/run_home_control_stable.py
```

Forventet delresultat:

```text
PASS: RAH Home Control deferred roadmap scope contract
```

Den samlede runneren skal nå registrere **16 kontrakter** og ende med `RAH HOME CONTROL FINAL/STABLE: PASS (16/16 kontrakter)` når alle eksisterende kontrakter består.

## Neste avgrensede oppgave

Synkroniser hovedveikartets Stable-testoversikt med den faktiske FINAL/STABLE-runneren (16 kontrakter), uten å endre runtime. Dette er dokumentasjonsvedlikehold; senere discovery, pairing, clustering, AI-utvidelser og Raven Vision skal fortsatt ikke implementeres før en ny milepæl startes eksplisitt.
