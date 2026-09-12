from __future__ import annotations

"""Read-only local-only server for RAH Observer Live Wall.

The stable Observer server remains untouched on port 18766. This companion
server serves local previews and read-only surface discovery on 127.0.0.1:18767.
It exposes GET endpoints only and cannot launch apps, connect peers, store
credentials, or execute commands.
"""

import pathlib
import sys

from flask import Flask, Response, jsonify, request, send_file

import observer_displays
import observer_network_discovery
import observer_preview
import observer_surface_apps
import observer_wall

HOST = "127.0.0.1"
PORT = 18767
OBSERVER_PORT = 18766


def _project_root() -> pathlib.Path:
    if getattr(sys, "frozen", False) and hasattr(sys, "_MEIPASS"):
        return pathlib.Path(sys._MEIPASS).resolve()
    return pathlib.Path(__file__).resolve().parent.parent


PROJECT_ROOT = _project_root()
LIVE_UI = PROJECT_ROOT / "RAH-OBSERVER-LIVE-WALL.html"
LOCAL_ORIGINS = {
    "null",
    f"http://127.0.0.1:{PORT}",
    f"http://localhost:{PORT}",
}

app = Flask(__name__)


@app.before_request
def local_origin_only():
    if request.method != "GET":
        return jsonify({"ok": False, "error": "Live Wall is read-only."}), 405
    if request.path in {"/", "/live", "/health"}:
        return None
    origin = (request.headers.get("Origin") or "").rstrip("/")
    if origin and origin not in LOCAL_ORIGINS:
        return jsonify({"ok": False, "error": "Live Wall API is local-only."}), 403
    return None


@app.get("/")
@app.get("/live")
def live_ui():
    if not LIVE_UI.exists():
        return jsonify({"ok": False, "error": f"Missing {LIVE_UI.name}"}), 404
    return send_file(LIVE_UI, mimetype="text/html", conditional=False, max_age=0)


@app.get("/health")
def health():
    return jsonify({
        "ok": True,
        "live_wall": True,
        "version": "1.0.0",
        "host": HOST,
        "port": PORT,
        "stable_observer_port": OBSERVER_PORT,
        "screen_preview": True,
        "surface_apps": True,
        "read_only": True,
        "automatic_remote_connect": False,
        "credentials_stored": False,
        "arbitrary_commands": False,
    })


@app.get("/devices")
def devices():
    try:
        result = observer_wall.discover_all()
        ssdp = observer_network_discovery.discover_ssdp()
        existing = {str(item.get("id")) for item in result.get("devices", [])}
        for item in ssdp:
            if str(item.get("id")) not in existing:
                result["devices"].append(item)
                existing.add(str(item.get("id")))
        result.setdefault("counts", {})["ssdp"] = len(ssdp)
        return jsonify(result)
    except Exception as exc:
        return jsonify({"ok": False, "error": str(exc)}), 500


@app.get("/displays")
def displays():
    try:
        return jsonify(observer_displays.discover_displays())
    except Exception as exc:
        return jsonify({"ok": False, "error": str(exc)}), 500


@app.get("/surfaces")
def surfaces():
    try:
        return jsonify(observer_surface_apps.discover_surface_apps())
    except Exception as exc:
        return jsonify({"ok": False, "error": str(exc)}), 500


@app.get("/display-preview/<int:index>.jpg")
def display_preview(index: int):
    try:
        data = observer_preview.capture_display_jpeg(index)
        response = Response(data, mimetype="image/jpeg")
        response.headers["Cache-Control"] = "no-store, max-age=0"
        return response
    except ValueError as exc:
        return jsonify({"ok": False, "error": str(exc)}), 404
    except Exception as exc:
        return jsonify({"ok": False, "error": str(exc)}), 500


if __name__ == "__main__":
    print(f"RAH Observer Live Wall (read-only): http://{HOST}:{PORT}/live")
    print(f"Stable Observer remains: http://127.0.0.1:{OBSERVER_PORT}/observer/ui")
    app.run(host=HOST, port=PORT, debug=False, threaded=True)
