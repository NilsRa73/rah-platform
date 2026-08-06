from __future__ import annotations

"""Derived Chronicle summaries.

The source event log stays append-only. Insights are recalculated from events,
and completing an item writes a new completion event instead of rewriting history.
"""

from collections import defaultdict
from datetime import datetime, timezone
from typing import Any

from flask import jsonify, request

from server_v17 import _append_event, _read_events, app

MAX_SEGMENT_SECONDS = 2 * 60 * 60
OPEN_LOOP_CATEGORIES = {"task", "deadline", "appointment", "error"}

CATEGORY_RULES: list[tuple[str, tuple[str, ...]]] = [
    ("utvikling", ("visual studio", "vscode", "code.exe", "github", "powershell", "terminal", "cmd.exe", "python", "lovable", "lm studio", "cursor")),
    ("gaming", ("steam", "epic games", "xbox", "playstation", "mame", "batocera", "chess", "lichess", "backgammon", "game")),
    ("media", ("youtube", "spotify", "netflix", "vlc", "twitch", "music")),
    ("kommunikasjon", ("whatsapp", "messenger", "discord", "slack", "teams", "mail", "outlook", "gmail")),
    ("helse", ("helsenorge", "unn", "raven care", "case center", "fristvakt", "journal", "fastlege")),
    ("nettleser", ("firefox", "chrome", "msedge", "edge")),
    ("system", ("explorer.exe", "task manager", "settings", "innstillinger")),
]


def _parse_time(value: Any) -> datetime | None:
    if not value:
        return None
    try:
        parsed = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except ValueError:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(timezone.utc)


def _classify(app_name: str, title: str) -> str:
    text = f"{app_name} {title}".casefold()
    for category, keywords in CATEGORY_RULES:
        if any(keyword.casefold() in text for keyword in keywords):
            return category
    return "annet"


def _completed_ids(events: list[dict[str, Any]]) -> set[str]:
    return {
        str(event.get("target_id"))
        for event in events
        if event.get("type") == "complete" and event.get("target_id")
    }


def _open_loops(events: list[dict[str, Any]], completed: set[str]) -> list[dict[str, Any]]:
    loops: list[dict[str, Any]] = []
    for event in reversed(events):
        if event.get("type") != "manual":
            continue
        if str(event.get("category") or "") not in OPEN_LOOP_CATEGORIES:
            continue
        event_id = str(event.get("id") or "")
        if not event_id or event_id in completed:
            continue
        loops.append(
            {
                "id": event_id,
                "timestamp": event.get("timestamp"),
                "category": event.get("category"),
                "title": event.get("title"),
                "note": event.get("note"),
                "project": event.get("project"),
            }
        )
    return loops[:30]


def build_summary(limit: int = 2000) -> dict[str, Any]:
    newest_first = _read_events(limit)
    events = list(reversed(newest_first))
    now = datetime.now(timezone.utc)
    app_seconds: dict[str, float] = defaultdict(float)
    category_seconds: dict[str, float] = defaultdict(float)
    focus_count = 0

    for index, event in enumerate(events):
        if event.get("type") != "focus":
            continue
        started = _parse_time(event.get("timestamp"))
        if not started:
            continue
        ended = now
        for later in events[index + 1 :]:
            if later.get("type") in {"focus", "pause", "session-stop"}:
                candidate = _parse_time(later.get("timestamp"))
                if candidate:
                    ended = candidate
                break
        seconds = max(0.0, min(MAX_SEGMENT_SECONDS, (ended - started).total_seconds()))
        app_name = str(event.get("app") or "Ukjent program")
        title = str(event.get("title") or "")
        category = _classify(app_name, title)
        app_seconds[app_name] += seconds
        category_seconds[category] += seconds
        focus_count += 1

    def ranked(mapping: dict[str, float], take: int = 10) -> list[dict[str, Any]]:
        return [
            {"name": name, "seconds": round(seconds), "minutes": round(seconds / 60, 1)}
            for name, seconds in sorted(mapping.items(), key=lambda item: item[1], reverse=True)[:take]
        ]

    completed = _completed_ids(events)
    return {
        "ok": True,
        "generated_at": now.isoformat(timespec="seconds"),
        "estimated_seconds": round(sum(app_seconds.values())),
        "estimated_minutes": round(sum(app_seconds.values()) / 60, 1),
        "focus_events": focus_count,
        "top_apps": ranked(app_seconds),
        "categories": ranked(category_seconds),
        "open_loops": _open_loops(events, completed),
        "completed_count": len(completed),
        "method_note": "Tid er estimert mellom vindusbytter. Ett sammenhengende segment begrenses til to timer for å redusere feil ved dvale eller glemt stopp.",
    }


@app.get("/chronicle/summary")
def chronicle_summary():
    try:
        limit = int(request.args.get("limit", "2000"))
    except ValueError:
        limit = 2000
    return jsonify(build_summary(max(1, min(5000, limit))))


@app.post("/chronicle/complete")
def chronicle_complete():
    payload = request.get_json(silent=True) or {}
    target_id = str(payload.get("event_id") or "").strip()
    if not target_id:
        return jsonify({"ok": False, "error": "event_id mangler."}), 400
    events = _read_events(5000)
    target = next((event for event in events if str(event.get("id")) == target_id), None)
    if not target:
        return jsonify({"ok": False, "error": "Hendelsen ble ikke funnet."}), 404
    event = _append_event(
        "complete",
        target_id=target_id,
        target_title=target.get("title"),
        target_category=target.get("category"),
        project=target.get("project"),
    )
    return jsonify({"ok": True, "event": event, "summary": build_summary()})
