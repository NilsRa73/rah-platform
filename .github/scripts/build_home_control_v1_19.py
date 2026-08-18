from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HTML = ROOT / "RAH-HOME-CONTROL.html"
MANIFEST = ROOT / "RAH-HOME-CONTROL-VERSION.json"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly 1 match, found {count}")
    return text.replace(old, new, 1)


html = HTML.read_text(encoding="utf-8")
html = replace_once(
    html,
    "Punkt 1 · stabil lokal kontroll v1.18",
    "Punkt 1 · stabil lokal kontroll v1.19",
    "header version",
)
html = replace_once(
    html,
    "v1.18: uleselige lagrede filtervalg gir synlig feilmelding og trygg fallback til standardfiltre. Senere nettverksoppdagelse og clustering står fortsatt i veikartet.",
    "v1.19: delvis ugyldige, men lesbare filtervalg gir synlig feilmelding og trygg normalisering. Senere nettverksoppdagelse og clustering står fortsatt i veikartet.",
    "footer version",
)
old_load_filters = "function loadFilters(){try{const raw=localStorage.getItem(FILTER_KEY);if(!raw)return{status:'all',room:'all'};const parsed=JSON.parse(raw);return{status:STATUS_FILTERS.includes(parsed.status)?parsed.status:'all',room:ROOM_FILTERS.includes(parsed.room)?parsed.room:'all'}}catch{showError('Lagrede filtervalg kunne ikke leses. Standardfiltrene Alle / Alle rom brukes midlertidig.');return{status:'all',room:'all'}}}"
new_load_filters = "function loadFilters(){try{const raw=localStorage.getItem(FILTER_KEY);if(!raw)return{status:'all',room:'all'};const parsed=JSON.parse(raw),statusValid=STATUS_FILTERS.includes(parsed&&parsed.status),roomValid=ROOM_FILTERS.includes(parsed&&parsed.room);if(!statusValid||!roomValid)showError('Lagrede filtervalg inneholdt verdier som ikke støttes. Ugyldige valg bruker standardverdi; gyldige valg beholdes.');return{status:statusValid?parsed.status:'all',room:roomValid?parsed.room:'all'}}catch{showError('Lagrede filtervalg kunne ikke leses. Standardfiltrene Alle / Alle rom brukes midlertidig.');return{status:'all',room:'all'}}}"
html = replace_once(html, old_load_filters, new_load_filters, "loadFilters implementation")
HTML.write_text(html, encoding="utf-8", newline="")

manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
if manifest.get("product") != "RAH Home Control":
    raise SystemExit("unexpected manifest product")
if manifest.get("version") != "1.18.0":
    raise SystemExit(f"expected Home Control 1.18.0 baseline, got {manifest.get('version')}")
features = manifest.get("features", {})
if features.get("filter_load_parse_error_visible") is not True:
    raise SystemExit("v1.18 parse-error visibility baseline missing")
if features.get("filter_load_parse_error_safe_fallback") is not True:
    raise SystemExit("v1.18 safe fallback baseline missing")
if features.get("filter_load_partial_invalid_visible") is not False:
    raise SystemExit("expected partial-invalid visibility to be false before v1.19")
if manifest.get("stable") is not True:
    raise SystemExit("Home Control baseline must remain Stable")
if manifest.get("release_gate", {}).get("change_policy") != "bugfix-only-until-explicit-reopen":
    raise SystemExit("Home Control bugfix-only boundary changed")

manifest["version"] = "1.19.0"
manifest["released_at"] = "2026-08-18"
features["filter_load_partial_invalid_visible"] = True
manifest["features"] = features
MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

print("Home Control v1.19 deterministic transform complete")
