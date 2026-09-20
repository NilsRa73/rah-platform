# RAH Home Control – roadmap sync

Status: **Stable/MVP v1.25**

Denne korte vedlikeholdsfilen er den kanoniske korrigeringen av den utdaterte seks-testers formuleringen i `RAH-HOME-CONTROL-ROADMAP.md`. Runtime er ikke endret.

## FINAL/STABLE acceptance gate

Kjør fra repo-roten:

```text
python tests/run_home_control_stable.py
```

Forventet sluttresultat:

```text
RAH HOME CONTROL FINAL/STABLE: PASS (16/16 kontrakter)
```

Den samlede runneren er den kanoniske Stable/MVP-gaten. Den utfører precheck av runtime, roadmap og Python-syntaks før de 16 registrerte kontraktene kjøres. Den eldre teksten om at workflowen kjører seks Stable-tester skal derfor ikke brukes som gjeldende acceptance-kriterium.

Det komplette testinventaret ligger i `RAH-HOME-CONTROL-TEST-INVENTORY.md`.

## Scope som fortsatt er utsatt

Følgende krav bevares i senere veikart og er uttrykkelig **ikke implementert** her:

- oppdagelse og søk etter alle Wi-Fi-enheter,
- enkel sammenkobling og godkjenning av enheter,
- clustering,
- større eller flere AI-hjerner,
- alternative konfigurasjoner for noder og AI-hjerner,
- Raven Vision.

## Vedlikeholdslogg

### 2026-09-20 – Stable acceptance gate synkronisert

Én avgrenset og testbar dokumentasjonsoppgave er utført: den gjeldende acceptance-kommandoen og forventet `PASS (16/16 kontrakter)` er gjort eksplisitt, og den utdaterte seks-testers formuleringen er markert som ikke-kanonisk. Ingen runtime-, GUI-, discovery-, pairing-, clustering-, AI- eller Raven Vision-funksjoner er lagt til.

**Verifikasjon:** `python tests/run_home_control_stable.py` skal fortsatt avslutte med `RAH HOME CONTROL FINAL/STABLE: PASS (16/16 kontrakter)`.

**Neste avgrensede oppgave:** konsolider denne korrigeringen direkte inn i `RAH-HOME-CONTROL-ROADMAP.md` og fjern den gamle seks-testers teksten, uten å endre runtime eller utvide scope.
