# RAH Home Control Stable Gate

Status: **Stable — local-control contract v1.24**

## Stable scope

RAH Home Control v1.24 er Stable for den lokale kontrollkontrakten:

- rommodell: Datarom, Stue 1, Stue 2 og Soverom,
- entydige romnavn og rom-ID-er,
- enhetsregister med lokal validering,
- statusvisning og lokale kontrollknapper,
- rollback ved lagringsfeil,
- lokal lagring og filterlagring,
- validert JSON-backup og gjenoppretting,
- trygg fallback ved ugyldig lagret tilstand.

`tests/test_home_control_stable_contract.py` er Stable-gaten for denne kontrakten og skal gi:

`PASS: RAH Home Control v1.24 Stable contract`

## Freeze

v1.24 behandles som bugfix-only for dette scope-et. Ny fysisk device-control, nettverksoppdagelse eller annen utvidelse skal utvikles som en separat Candidate og skal ikke endre v1.24-kontrakten uten eksplisitt gjenåpning.

## Ikke del av Stable-scope

Følgende står fortsatt i senere veikart og er ikke implementert:

- oppdagelse og søk etter alle Wi-Fi-enheter,
- enkel sammenkobling og godkjenning av enheter,
- clustering,
- større eller flere AI-hjerner,
- alternative node- og AI-konfigurasjoner,
- Raven Vision.

Merk: Stable-gaten her er en statisk kode-/kontraktgate. Fysisk nettverks- og enhetskontroll krever senere adaptere og miljøspesifikke smoke-tester.
