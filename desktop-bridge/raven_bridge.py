from __future__ import annotations

"""Canonical RAH Raven Desktop Bridge entrypoint.

Loads Vision, Case Center, Chronicle, Insights, Daily Brief, Council and the
read-only Agent Runner, serves local Raven pages, and blocks sensitive APIs
from foreign browser origins.
"""

import pathlib

from flask import jsonify, request, send_file

from server_v16 import _lm_chat
from server_v17 import APP_VERSION, HOST, PORT, app
import chronicle_insights  # Registers derived summary and completion endpoints.
import chronicle_ai  # Registers structured and local-LM Daily Brief endpoints.
import agent_runner  # Registers read-only allowlisted Agent Runner endpoints.

PROJECT_ROOT = pathlib.Path(__file__).resolve().parent.parent
CHRONICLE_UI = PROJECT_ROOT / "RAH-RAVEN-CHRONICLE-LIVE.html"
INSIGHTS_UI = PROJECT_ROOT / "RAH-RAVEN-INSIGHTS.html"
DAILY_BRIEF_UI = PROJECT_ROOT / "RAH-RAVEN-DAILY-BRIEF.html"
LOCAL_ORIGINS = {
    "null",  # Local file:// Raven pages.
    f"http://127.0.0.1:{PORT}",
    f"http://localhost:{PORT}",
}
LOCAL_UI_PATHS = {
    "/chronicle/ui",
    "/chronicle/insights-ui",
    "/chronicle/brief-ui",
}
PROTECTED_LOCAL_PREFIXES = (
    "/capture/",
    "/lm/",
    "/case",
    "/chronicle",
    "/agent/",
)


@app.before_request
def protect_local_apis_from_foreign_websites():
    path = request.path
    if not path.startswith(PROTECTED_LOCAL_PREFIXES):
        return None
    if path in LOCAL_UI_PATHS:
        return None

    origin = (request.headers.get("Origin") or "").rstrip("/")
    if origin and origin not in LOCAL_ORIGINS:
        return jsonify(
            {
                "ok": False,
                "error": "Dette lokale Raven-endepunktet er ikke tilgjengelig fra fremmede nettsteder.",
            }
        ), 403
    return None


def _send_local_page(path: pathlib.Path):
    if not path.exists():
        return jsonify(
            {
                "ok": False,
                "error": f"{path.name} ble ikke funnet ved siden av prosjektet.",
                "expected": str(path),
            }
        ), 404
    return send_file(path, mimetype="text/html", conditional=False, max_age=0)


@app.post("/lm/chat")
def local_lm_chat():
    """Small text-only LM Studio proxy for Raven Council.

    It accepts one system message and one or more text messages. It does not
    execute tools, open files or run commands. The caller remains responsible
    for explicit approval before any later action.
    """
    payload = request.get_json(silent=True) or {}
    raw_messages = payload.get("messages") or []
    if not isinstance(raw_messages, list) or not raw_messages:
        return jsonify({"ok": False, "error": "messages må være en ikke-tom liste."}), 400
    if len(raw_messages) > 20:
        return jsonify({"ok": False, "error": "For mange meldinger i én lokal forespørsel."}), 400

    system_parts: list[str] = []
    user_parts: list[str] = []
    for item in raw_messages:
        if not isinstance(item, dict):
            continue
        role = str(item.get("role") or "user").strip().lower()
        content = item.get("content")
        if not isinstance(content, str):
            return jsonify({"ok": False, "error": "Council-proxyen støtter bare tekstmeldinger."}), 400
        text = content.strip()
        if not text:
            continue
        if role == "system":
            system_parts.append(text)
        else:
            user_parts.append(f"[{role}]\n{text}")

    if not user_parts:
        return jsonify({"ok": False, "error": "Mangler brukertekst."}), 400

    system = "\n\n".join(system_parts) or "Du er RAH Raven. Svar kort og konkret på norsk."
    user = "\n\n".join(user_parts)
    model = str(payload.get("model") or "").strip()
    try:
        max_tokens = max(100, min(4000, int(payload.get("max_tokens") or 1400)))
    except (TypeError, ValueError):
        max_tokens = 1400

    try:
        answer, selected_model = _lm_chat(system, user, model=model, max_tokens=max_tokens)
        return jsonify(
            {
                "ok": True,
                "answer": answer,
                "model": selected_model,
                "tools_executed": False,
                "automatic_actions": False,
            }
        )
    except Exception as exc:
        return jsonify({"ok": False, "error": str(exc)}), 502


@app.get("/chronicle/ui")
def chronicle_local_ui():
    return _send_local_page(CHRONICLE_UI)


@app.get("/chronicle/insights-ui")
def chronicle_insights_ui():
    return _send_local_page(INSIGHTS_UI)


@app.get("/chronicle/brief-ui")
def chronicle_brief_ui():
    return _send_local_page(DAILY_BRIEF_UI)


_current_health = app.view_functions.get("health")
if _current_health:
    def health_raven_core():
        response = _current_health()
        data = response.get_json() if hasattr(response, "get_json") else {}
        data.update(
            {
                "council_proxy": True,
                "agent_runner": True,
                "agent_runner_version": agent_runner.AGENT_RUNNER_VERSION,
                "agent_runner_mode": "read-only-allowlist",
            }
        )
        return jsonify(data)

    app.view_functions["health"] = health_raven_core


if __name__ == "__main__":
    print(f"RAH Raven Desktop Bridge v{APP_VERSION}")
    print(f"Chronicle Live: http://127.0.0.1:{PORT}/chronicle/ui")
    print(f"Raven Insights: http://127.0.0.1:{PORT}/chronicle/insights-ui")
    print(f"Daily Brief: http://127.0.0.1:{PORT}/chronicle/brief-ui")
    print(f"Council text proxy: http://127.0.0.1:{PORT}/lm/chat")
    print(f"Agent Runner: http://127.0.0.1:{PORT}/agent/capabilities")
    print(f"Listening on http://{HOST}:{PORT}")
    app.run(host=HOST, port=PORT, debug=False, threaded=True)
