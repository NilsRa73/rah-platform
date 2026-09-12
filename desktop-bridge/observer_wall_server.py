from __future__ import annotations

"""Local-only web host for RAH Observer · The Wall."""

import pathlib
import sys

from flask import Flask, jsonify, request, send_file

import observer_network_discovery
import observer_wall

HOST = "127.0.0.1"
PORT = 18766


def _project_root() -> pathlib.Path:
    if getattr(sys, "frozen", False) and hasattr(sys, "_MEIPASS"):
        return pathlib.Path(sys._MEIPASS).resolve()
    return pathlib.Path(__file__).resolve().parent.parent


PROJECT_ROOT = _project_root()
WALL_UI = PROJECT_ROOT / "RAH-OBSERVER-WALL-V12.html"
LOCAL_ORIGINS = {
    "null",
    f"http://127.0.0.1:{PORT}",
    f"http://localhost:{PORT}",
}

app = Flask(__name__)


@app.before_request
def local_origin_only():
    if request.path in {"/", "/observer/ui", "/health"}:
        return None
    origin = (request.headers.get("Origin") or "").rstrip("/")
    if origin and origin not in LOCAL_ORIGINS:
        return jsonify({"ok": False, "error": "Observer API is local-only."}), 403
    return None


@app.get("/")
@app.get("/observer/ui")
def observer_ui():
    if not WALL_UI.exists():
        return jsonify({"ok": False, "error": f"Missing {WALL_UI.name}"}), 404
    return send_file(WALL_UI, mimetype="text/html", conditional=False, max_age=0)


@app.get("/health")
def health():
    return jsonify({
        "ok": True,
        "observer_wall": True,
        "version": observer_wall.OBSERVER_VERSION,
        "ui_version": "1.2",
        "host": HOST,
        "port": PORT,
        "automatic_pairing": False,
        "arbitrary_commands": False,
        "discovery": ["display", "bluetooth", "audio", "lan", "adb", "ssdp"],
    })


@app.get("/observer/devices")
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
        result["discovery"] = ["display", "bluetooth", "audio", "lan", "adb", "ssdp"]
        return jsonify(result)
    except Exception as exc:
        return jsonify({"ok": False, "error": str(exc)}), 500


@app.post("/observer/action")
def action():
    payload = request.get_json(silent=True)
    if not isinstance(payload, dict):
        return jsonify({"ok": False, "error": "Observer action must be JSON."}), 400
    result = observer_wall.execute_action(payload)
    return jsonify(result), (200 if result.get("ok") else 400)


if __name__ == "__main__":
    print(f"RAH Observer Wall v{observer_wall.OBSERVER_VERSION}")
    print(f"The Wall: http://{HOST}:{PORT}/observer/ui")
    app.run(host=HOST, port=PORT, debug=False, threaded=True)
