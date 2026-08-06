from __future__ import annotations

"""Canonical RAH Raven Desktop Bridge entrypoint.

Loads Vision, Case Center, Chronicle and Insights, serves Chronicle pages
locally, and blocks browser requests to Chronicle APIs from non-local origins.
"""

import pathlib

from flask import jsonify, request, send_file

from server_v17 import APP_VERSION, HOST, PORT, app
import chronicle_insights  # Registers derived summary and completion endpoints.

PROJECT_ROOT = pathlib.Path(__file__).resolve().parent.parent
CHRONICLE_UI = PROJECT_ROOT / "RAH-RAVEN-CHRONICLE-LIVE.html"
INSIGHTS_UI = PROJECT_ROOT / "RAH-RAVEN-INSIGHTS.html"
LOCAL_ORIGINS = {
    f"http://127.0.0.1:{PORT}",
    f"http://localhost:{PORT}",
}
LOCAL_UI_PATHS = {"/chronicle/ui", "/chronicle/insights-ui"}


@app.before_request
def protect_chronicle_from_foreign_websites():
    path = request.path
    if not (path == "/chronicle" or path.startswith("/chronicle/")):
        return None
    if path in LOCAL_UI_PATHS:
        return None

    origin = (request.headers.get("Origin") or "").rstrip("/")
    if origin and origin not in LOCAL_ORIGINS:
        return jsonify(
            {
                "ok": False,
                "error": "Chronicle API er bare tilgjengelig fra den lokale Raven-siden.",
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


@app.get("/chronicle/ui")
def chronicle_local_ui():
    return _send_local_page(CHRONICLE_UI)


@app.get("/chronicle/insights-ui")
def chronicle_insights_ui():
    return _send_local_page(INSIGHTS_UI)


if __name__ == "__main__":
    print(f"RAH Raven Desktop Bridge v{APP_VERSION}")
    print(f"Chronicle Live: http://127.0.0.1:{PORT}/chronicle/ui")
    print(f"Raven Insights: http://127.0.0.1:{PORT}/chronicle/insights-ui")
    print(f"Listening on http://{HOST}:{PORT}")
    app.run(host=HOST, port=PORT, debug=False, threaded=True)
