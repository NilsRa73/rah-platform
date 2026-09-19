# RAH Home Control – FINAL/STABLE test inventory

Status: **Stable/MVP v1.25**

Denne filen synkroniserer dokumentasjonen med den faktiske FINAL/STABLE-runneren `tests/run_home_control_stable.py`. Runtime endres ikke i denne oppgaven.

## Kanonisk acceptance gate

Kjør fra repo-roten:

```text
python tests/run_home_control_stable.py
```

Forventet sluttresultat:

```text
RAH HOME CONTROL FINAL/STABLE: PASS (16/16 kontrakter)
```

Runneren utfører precheck av runtime, roadmap, Python-syntaks og registrerte kontrakter før alle kontraktene kjøres.

## 16 registrerte kontrakter

1. `tests/test_home_control_stable_contract.py`
2. `tests/test_home_control_task_queue_contract.py`
3. `tests/test_home_control_reset_defaults_contract.py`
4. `tests/test_home_control_restore_backup_contract.py`
5. `tests/test_home_control_screen_status_contract.py`
6. `tests/test_home_control_node_status_contract.py`
7. `tests/test_home_control_room_status_contract.py`
8. `tests/test_home_control_device_status_contract.py`
9. `tests/test_home_control_add_device_contract.py`
10. `tests/test_home_control_edit_device_contract.py`
11. `tests/test_home_control_remove_device_contract.py`
12. `tests/test_home_control_filter_storage_contract.py`
13. `tests/test_home_control_main_storage_contract.py`
14. `tests/test_home_control_load_state_contract.py`
15. `tests/test_home_control_device_adapter_contract.py`
16. `tests/test_home_control_deferred_scope_contract.py`

Dette erstatter den utdaterte formuleringen i hovedveikartet om at Stable-workflowen bare kjører seks kontraktstester. Workflowen bruker nå den samlede runneren og dermed alle 16 registrerte kontrakter.

## Scope som fortsatt er utsatt

Følgende krav bevares i senere veikart og er uttrykkelig **ikke implementert** i denne oppgaven:

- oppdagelse og søk etter alle Wi-Fi-enheter,
- enkel sammenkobling og godkjenning av enheter,
- clustering,
- større eller flere AI-hjerner,
- alternative node- og AI-konfigurasjoner,
- Raven Vision.

## Vedlikeholdslogg

### 2026-09-19 – testinventar synkronisert

Én avgrenset oppgave utført: dokumentert den faktiske 16-kontrakters FINAL/STABLE-gaten som allerede er registrert i `tests/run_home_control_stable.py`. Ingen runtime-, GUI-, discovery-, pairing-, clustering-, AI- eller Raven Vision-funksjoner ble lagt til.

**Neste avgrensede oppgave:** rett den utdaterte seks-testers teksten i `RAH-HOME-CONTROL-ROADMAP.md` slik at hovedveikartet peker på `python tests/run_home_control_stable.py` og 16/16-kontraktsgaten, uten runtime-utvidelse.
