from __future__ import annotations

"""Read-only local-only server for RAH Observer Live Wall.

The stable Observer server remains untouched on port 18766. This companion
server serves local previews, fixed Raven diagnostic reports and read-only
surface discovery on 127.0.0.1:18767. It exposes GET endpoints only and cannot
launch apps, connect peers, store credentials, execute commands, or read an
arbitrary path supplied by a browser.
"""

import json
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
MAX_REPORT_CHARS = 120_000
AGENT_WORK = pathlib.Path(r"C:\RAH\AgentWork")
AUTOPILOT_HANDOFF = AGENT_WORK / "AUTOPILOT-LATEST.txt"
OBSERVER_HANDOFF = AGENT_WORK / "OBSERVER-LATEST.txt"
OBSERVER_JSON = AGENT_WORK / "OBSERVER-LATEST.json"


def _project_root() -> pathlib.Path:
    if getattr(sys, "frozen", False) and hasattr(sys, "_MEIPASS"):
        return pathlib.Path(sys._MEIPASS).resolve()
    return pathlib.Path(__file__).resolve().parent.parent


PROJECT_ROOT = _project_root()
LIVE_UI = PROJECT_ROOT / "RAH-OBSERVER-LIVE-WALL.html"
HANDOFF_USERSCRIPT = PROJECT_ROOT / "RAH-RAVEN-CHATGPT-HANDOFF.user.js"
LOCAL_ORIGINS = {
    "null",
    f"http://127.0.0.1:{PORT}",
    f"http://localhost:{PORT}",
}

app = Flask(__name__)


def _read_fixed_text(path: pathlib.Path) -> str:
    if not path.exists() or not path.is_file():
        return ""
    text = path.read_text(encoding="utf-8", errors="replace")
    if len(text) > MAX_REPORT_CHARS:
        text = text[-MAX_REPORT_CHARS:]
    return text


def _mtime(path: pathlib.Path) -> float | None:
    try:
        return path.stat().st_mtime
    except OSError:
        return None


def _doctor_summary() -> dict:
    if OBSERVER_JSON.exists() and OBSERVER_JSON.is_file():
        try:
            payload = json.loads(OBSERVER_JSON.read_text(encoding="utf-8", errors="replace"))
            if isinstance(payload, dict):
                overall = str(payload.get("overall") or payload.get("status") or "UNKNOWN").upper()[:40]
                checks = payload.get("checks") if isinstance(payload.get("checks"), list) else []
                counts = {"PASS": 0, "WARN": 0, "PLAN": 0, "FAIL": 0}
                for item in checks[:200]:
                    if not isinstance(item, dict):
                        continue
                    state = str(item.get("status") or item.get("state") or "").upper()
                    if state in counts:
                        counts[state] += 1
                return {
                    "ok": True,
                    "overall": overall,
                    "counts": counts,
                    "mtime": _mtime(OBSERVER_JSON),
                    "source": "OBSERVER-LATEST.json",
                }
        except (OSError, json.JSONDecodeError):
            pass

    text = _read_fixed_text(OBSERVER_HANDOFF)
    if not text:
        return {"ok": True, "overall": "NO REPORT", "counts": {}, "mtime": None, "source": None}
    upper = text.upper()
    overall = "PASS"
    if "OVERALL: FAIL" in upper or "[FAIL]" in upper:
        overall = "FAIL"
    elif "OVERALL: PASS WITH WARNING" in upper or "[WARN]" in upper:
        overall = "WARN"
    elif "[PLAN]" in upper:
        overall = "PLAN"
    return {
        "ok": True,
        "overall": overall,
        "counts": {
            "PASS": upper.count("[PASS]"),
            "WARN": upper.count("[WARN]"),
            "PLAN": upper.count("[PLAN]"),
            "FAIL": upper.count("[FAIL]"),
        },
        "mtime": _mtime(OBSERVER_HANDOFF),
        "source": "OBSERVER-LATEST.txt",
    }


def _live_ui_html() -> str:
    html = LIVE_UI.read_text(encoding="utf-8", errors="replace")
    marker = "rah-observer-doctor-tile"
    if marker in html:
        return html
    injection = r'''
<style id="rah-observer-doctor-tile-style">
#rah-observer-doctor-tile{position:fixed;right:18px;bottom:18px;z-index:9999;background:#0b1017;border:1px solid #82621f;border-radius:14px;padding:10px 13px;box-shadow:0 8px 28px #0009;color:#f5d87a;font:700 11px/1.35 Segoe UI,Arial,sans-serif;min-width:180px}#rah-observer-doctor-tile small{display:block;color:#8fa1b8;font-weight:500;margin-top:3px}#rah-observer-doctor-tile[data-state="PASS"]{border-color:#287952;color:#75efa8}#rah-observer-doctor-tile[data-state="FAIL"]{border-color:#8d3540;color:#ff7d89}#rah-observer-doctor-tile[data-state="WARN"],#rah-observer-doctor-tile[data-state="PLAN"]{border-color:#8a6b25;color:#f2c14e}
</style>
<div id="rah-observer-doctor-tile" data-state="UNKNOWN">OBSERVER DOCTOR · CHECKING<small>read-only local status</small></div>
<script id="rah-observer-doctor-tile-script">
(async()=>{const t=document.getElementById('rah-observer-doctor-tile');if(!t)return;try{const r=await fetch('/doctor',{cache:'no-store'});const j=await r.json();const s=String(j.overall||'UNKNOWN').toUpperCase();t.dataset.state=s;t.firstChild.nodeValue='OBSERVER DOCTOR · '+s+' ';const c=j.counts||{};t.querySelector('small').textContent=`PASS ${c.PASS||0} · WARN ${c.WARN||0} · PLAN ${c.PLAN||0} · FAIL ${c.FAIL||0}`;}catch{t.dataset.state='FAIL';t.firstChild.nodeValue='OBSERVER DOCTOR · OFFLINE ';}})();
</script>
'''
    return html.replace("</body>", injection + "\n</body>") if "</body>" in html else html + injection


@app.before_request
def local_origin_only():
    if request.method != "GET":
        return jsonify({"ok": False, "error": "Live Wall is read-only."}), 405
    if request.path in {"/", "/live", "/health", "/handoff", "/doctor", "/userscript/RAH-RAVEN-CHATGPT-HANDOFF.user.js"}:
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
    return Response(_live_ui_html(), mimetype="text/html", headers={"Cache-Control": "no-store, max-age=0"})


@app.get("/health")
def health():
    return jsonify({
        "ok": True,
        "live_wall": True,
        "version": "1.1.0",
        "host": HOST,
        "port": PORT,
        "stable_observer_port": OBSERVER_PORT,
        "screen_preview": True,
        "surface_apps": True,
        "handoff": True,
        "doctor_status": True,
        "read_only": True,
        "automatic_remote_connect": False,
        "credentials_stored": False,
        "arbitrary_commands": False,
    })


@app.get("/handoff")
def handoff():
    for path, source in ((AUTOPILOT_HANDOFF, "AUTOPILOT-LATEST.txt"), (OBSERVER_HANDOFF, "OBSERVER-LATEST.txt")):
        text = _read_fixed_text(path)
        if text:
            return jsonify({
                "ok": True,
                "source": source,
                "text": text,
                "mtime": _mtime(path),
                "auto_send": False,
                "fixed_path": True,
            })
    return jsonify({"ok": False, "error": "No Raven handoff report exists yet.", "auto_send": False, "fixed_path": True}), 404


@app.get("/doctor")
def doctor():
    return jsonify(_doctor_summary())


@app.get("/userscript/RAH-RAVEN-CHATGPT-HANDOFF.user.js")
def handoff_userscript():
    if not HANDOFF_USERSCRIPT.exists():
        return jsonify({"ok": False, "error": f"Missing {HANDOFF_USERSCRIPT.name}"}), 404
    return send_file(HANDOFF_USERSCRIPT, mimetype="application/javascript", conditional=False, max_age=0)


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
    print(f"Raven handoff (fixed read-only): http://{HOST}:{PORT}/handoff")
    print(f"Stable Observer remains: http://127.0.0.1:{OBSERVER_PORT}/observer/ui")
    app.run(host=HOST, port=PORT, debug=False, threaded=True)
