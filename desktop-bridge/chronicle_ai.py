from __future__ import annotations

"""Local AI brief for Raven Chronicle.

The event log remains the source of truth. This module sends only redacted,
locally stored Chronicle data to the user's local LM Studio server.
"""

import json
from datetime import datetime, timedelta, timezone
from typing import Any

from flask import jsonify, request

from chronicle_insights import build_summary
from server_v16 import _lm_chat
from server_v17 import _read_events, app

MAX_BRIEF_EVENTS = 160
MAX_NOTE_CHARS = 1200


def _parse_timestamp(value: Any) -> datetime | None:
    if not value:
        return None
    try:
        parsed = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except ValueError:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(timezone.utc)


def _brief_events(hours: int) -> list[dict[str, Any]]:
    cutoff = datetime.now(timezone.utc) - timedelta(hours=hours)
    newest_first = _read_events(2000)
    selected: list[dict[str, Any]] = []
    for event in newest_first:
        timestamp = _parse_timestamp(event.get("timestamp"))
        if timestamp and timestamp < cutoff:
            continue
        selected.append(
            {
                "timestamp": event.get("timestamp"),
                "type": event.get("type"),
                "project": event.get("project"),
                "mode": event.get("mode"),
                "app": event.get("app"),
                "title": event.get("title"),
                "category": event.get("category"),
                "privacy": event.get("privacy"),
                "note": str(event.get("note") or "")[:MAX_NOTE_CHARS],
                "redacted": bool(event.get("redacted")),
                "target_title": event.get("target_title"),
            }
        )
        if len(selected) >= MAX_BRIEF_EVENTS:
            break
    return list(reversed(selected))


def _structured_brief(hours: int) -> dict[str, Any]:
    summary = build_summary()
    events = _brief_events(hours)
    decisions = [item for item in events if item.get("type") == "manual" and item.get("category") == "decision"]
    ideas = [item for item in events if item.get("type") == "manual" and item.get("category") == "idea"]
    return {
        "hours": hours,
        "generated_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "estimated_minutes": summary.get("estimated_minutes", 0),
        "top_apps": summary.get("top_apps", [])[:8],
        "categories": summary.get("categories", [])[:8],
        "open_loops": summary.get("open_loops", [])[:20],
        "decisions": decisions[-15:],
        "ideas": ideas[-15:],
        "events": events,
        "method_note": summary.get("method_note"),
    }


@app.get("/chronicle/brief")
def chronicle_structured_brief():
    try:
        hours = max(1, min(168, int(request.args.get("hours", "24"))))
    except ValueError:
        hours = 24
    return jsonify({"ok": True, "brief": _structured_brief(hours)})


@app.post("/chronicle/ai-brief")
def chronicle_ai_brief():
    payload = request.get_json(silent=True) or {}
    try:
        hours = max(1, min(168, int(payload.get("hours", 24))))
    except (TypeError, ValueError):
        hours = 24
    focus = str(payload.get("focus") or "").strip()[:1200]
    model = str(payload.get("model") or "").strip()
    brief = _structured_brief(hours)

    system = """Du er RAH Raven Daily Brief, en lokal arbeidsassistent.
Svar på norsk og bruk bare Chronicle-dataene som er levert.

Ufravikelige regler:
1. Ikke diagnostiser, vurder mental helse, personlighet, intelligens eller rus ut fra appbruk eller arbeidstempo.
2. Ikke gjett hva brukeren tenkte. Beskriv bare registrerte hendelser og forsiktige, tydelig merkede mønstre.
3. Tidstall er estimater. Skriv dette når de omtales.
4. En maskert vindustittel skal omtales som privat og aldri rekonstrueres.
5. Skill mellom gjort arbeid, brukerregistrerte ideer, beslutninger og åpne tråder.
6. Ikke anbefal medisinendring, juridisk konklusjon, kjøp, sending eller andre irreversible handlinger.
7. Foreslå maksimalt ett konkret neste steg som bygger videre på den viktigste åpne tråden.
8. Ikke presenter programbruk som moralsk bra eller dårlig.

Bruk disse overskriftene:
DAGEN I KORTE TREKK
DET SOM BLE GJORT
BESLUTNINGER OG IDEER
ÅPNE TRÅDER
OBSERVERTE ARBEIDSMØNSTRE
ETT NESTE STEG
SIKKERHET OG USIKKERHET
"""

    user = (
        f"Tidsrom: siste {hours} timer.\n"
        f"Brukerens ekstra fokus: {focus or 'Ingen ekstra instruksjon.'}\n\n"
        "Chronicle-data (lokalt registrert og personvernfiltrert):\n"
        + json.dumps(brief, ensure_ascii=False, indent=2)
    )

    try:
        answer, selected = _lm_chat(system, user, model=model, max_tokens=2200)
        return jsonify(
            {
                "ok": True,
                "answer": answer,
                "model": selected,
                "hours": hours,
                "event_count": len(brief["events"]),
                "human_review_required": True,
                "stored": False,
                "local_only": True,
            }
        )
    except Exception as exc:
        return jsonify({"ok": False, "error": str(exc), "structured_brief": brief}), 502
