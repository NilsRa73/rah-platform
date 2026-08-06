from __future__ import annotations

"""Canonical RAH Raven Desktop Bridge entrypoint.

Loads Vision, Case Center and Chronicle, serves Chronicle Live locally, and
blocks browser requests to Chronicle APIs from non-local web origins.
"""

import pathlib

from flask import jsonify, request, send_file

from server_v17 import APP_VERSION, HOST, PORT, app

PROJECT_ROOT = pathlib.Path(__file__).resolve().parent.parent
CHRONICLE_UI = PROJECT_ROOT / "RAH-RAVEN-CHRONICLE-LIVE.html"
LOCAL_ORIGINS = {
    f"http://127.0.0.1:{PORT}",
    f"http://localhost:{PORT}",
}


@app.before_request
def protect_chronicle_from_foreign_websites():
    path = request.path
    if not (path == "/chronicle" or path.startswith("/chronicle/")):
        return None
    if path == "/chronicle/ui":
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


@app.get("/chronicle/ui")
def chronicle_local_ui():
    if not CHRONICLE_UI.exists():
        return jsonify(
            {
                "ok": False,
                "error": "RAH-RAVEN-CHRONICLE-LIVE.html ble ikke funnet ved siden av prosjektet.",
                "expected": str(CHRONICLE_UI),
            }
        ), 404
    return send_file(CHRONICLE_UI, mimetype="text/html", conditional=False, max_age=0)


if __name__ == "__main__":
    print(f"RAH Raven Desktop Bridge v{APP_VERSION}")
    print(f"Chronicle Live: http://127.0.0.1:{PORT}/chronicle/ui")
    print(f"Listening on http://{HOST}:{PORT}")
    app.run(host=HOST, port=PORT, debug=False, threaded=True)
