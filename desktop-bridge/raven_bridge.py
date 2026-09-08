from __future__ import annotations

"""Canonical RAH Raven Desktop Bridge entrypoint.

Loads Vision, Case Center, Chronicle, Insights, Daily Brief, Council, Agent
Runner, Download Manager and the local-only Device Adapter, serves local Raven
pages, and blocks sensitive APIs from foreign browser origins.
"""

import base64
import io
import pathlib
import sys

from flask import jsonify, request, send_file
from PIL import Image
import mss

from server_v16 import MAX_WIDTH, _lm_chat
from server_v17 import APP_VERSION, HOST, PORT, app
import chronicle_insights
import chronicle_ai
import agent_runner
import download_manager
import local_device_adapter


def _project_root() -> pathlib.Path:
    if getattr(sys, "frozen", False) and hasattr(sys, "_MEIPASS"):
        return pathlib.Path(sys._MEIPASS).resolve()
    return pathlib.Path(__file__).resolve().parent.parent


PROJECT_ROOT = _project_root()
VISION_UI = PROJECT_ROOT / "RAH-RAVEN-VISION-LOCAL.html"
CHATGPT_USERSCRIPT = PROJECT_ROOT / "RAH-RAVEN-CHATGPT.user.js"
HOME_CONTROL_UI = PROJECT_ROOT / "RAH-HOME-CONTROL.html"
CHRONICLE_UI = PROJECT_ROOT / "RAH-RAVEN-CHRONICLE-LIVE.html"
INSIGHTS_UI = PROJECT_ROOT / "RAH-RAVEN-INSIGHTS.html"
DAILY_BRIEF_UI = PROJECT_ROOT / "RAH-RAVEN-DAILY-BRIEF.html"
LOCAL_ORIGINS = {
    "null",  # Local file:// Raven pages and privileged userscript requests.
    f"http://127.0.0.1:{PORT}",
    f"http://localhost:{PORT}",
}
LOCAL_UI_PATHS = {
    "/vision/ui",
    "/home-control/ui",
    "/chronicle/ui",
    "/chronicle/insights-ui",
    "/chronicle/brief-ui",
    "/downloads/ui",
}
PROTECTED_LOCAL_PREFIXES = (
    "/capture/",
    "/lm/",
    "/case",
    "/chronicle",
    "/agent/",
    "/device/",
    "/downloads/",
)
MAX_AREA_EDGE = 16_384
MAX_AREA_PIXELS = 80_000_000


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


def _send_local_script(path: pathlib.Path):
    if not path.exists():
        return jsonify(
            {
                "ok": False,
                "error": f"{path.name} ble ikke funnet ved siden av prosjektet.",
                "expected": str(path),
            }
        ), 404
    return send_file(path, mimetype="text/javascript", conditional=False, max_age=0)


def _encode_capture(image: Image.Image, metadata: dict) -> tuple[str, dict]:
    source_width = image.width
    source_height = image.height
    if image.width > MAX_WIDTH:
        target_height = max(1, round(image.height * MAX_WIDTH / image.width))
        image = image.resize((MAX_WIDTH, target_height), Image.Resampling.LANCZOS)

    buffer = io.BytesIO()
    image.save(buffer, format="PNG", optimize=True)
    encoded = base64.b64encode(buffer.getvalue()).decode("ascii")
    metadata = {
        **metadata,
        "source_width": source_width,
        "source_height": source_height,
        "width": image.width,
        "height": image.height,
    }
    return f"data:image/png;base64,{encoded}", metadata


def _monitor_catalog() -> list[dict[str, int]]:
    with mss.mss() as sct:
        monitors = []
        for index, monitor in enumerate(sct.monitors[1:], start=1):
            monitors.append(
                {
                    "index": index,
                    "left": int(monitor["left"]),
                    "top": int(monitor["top"]),
                    "width": int(monitor["width"]),
                    "height": int(monitor["height"]),
                }
            )
        return monitors


def _virtual_desktop(sct: mss.mss) -> dict[str, int]:
    desktop = sct.monitors[0]
    return {
        "left": int(desktop["left"]),
        "top": int(desktop["top"]),
        "width": int(desktop["width"]),
        "height": int(desktop["height"]),
    }


def _capture_monitor(index: int) -> tuple[str, dict]:
    with mss.mss() as sct:
        count = max(0, len(sct.monitors) - 1)
        if index < 1 or index > count:
            raise ValueError(f"Skjerm {index} finnes ikke. Tilgjengelige skjermer: {count}.")
        monitor = sct.monitors[index]
        rect = {
            "left": int(monitor["left"]),
            "top": int(monitor["top"]),
            "width": int(monitor["width"]),
            "height": int(monitor["height"]),
        }
        shot = sct.grab(rect)
        image = Image.frombytes("RGB", shot.size, shot.rgb)

    return _encode_capture(
        image,
        {
            "capture": f"monitor-{index}",
            "monitor_index": index,
            "monitors_available": count,
            "rect": rect,
        },
    )


def _validate_area(sct: mss.mss, left: int, top: int, width: int, height: int) -> dict[str, int]:
    if width < 2 or height < 2:
        raise ValueError("Området må være minst 2×2 piksler.")
    if width > MAX_AREA_EDGE or height > MAX_AREA_EDGE or width * height > MAX_AREA_PIXELS:
        raise ValueError("Området er for stort for Raven Vision.")

    desktop = _virtual_desktop(sct)
    desktop_right = desktop["left"] + desktop["width"]
    desktop_bottom = desktop["top"] + desktop["height"]
    area_right = left + width
    area_bottom = top + height

    if (
        left < desktop["left"]
        or top < desktop["top"]
        or area_right > desktop_right
        or area_bottom > desktop_bottom
    ):
        raise ValueError(
            "Området ligger utenfor det virtuelle skrivebordet "
            f"({desktop['left']},{desktop['top']} {desktop['width']}×{desktop['height']})."
        )
    return {"left": left, "top": top, "width": width, "height": height}


def _capture_area(left: int, top: int, width: int, height: int) -> tuple[str, dict]:
    with mss.mss() as sct:
        rect = _validate_area(sct, left, top, width, height)
        desktop = _virtual_desktop(sct)
        shot = sct.grab(rect)
        image = Image.frombytes("RGB", shot.size, shot.rgb)

    return _encode_capture(
        image,
        {
            "capture": "area",
            "rect": rect,
            "virtual_desktop": desktop,
        },
    )


@app.get("/capture/monitors")
def capture_monitors():
    try:
        monitors = _monitor_catalog()
        return jsonify({"ok": True, "count": len(monitors), "monitors": monitors})
    except Exception as exc:
        return jsonify({"ok": False, "error": str(exc)}), 500


@app.get("/capture/monitor")
def capture_monitor():
    try:
        index = int(request.args.get("index", "1"))
        image, metadata = _capture_monitor(index)
        return jsonify({"ok": True, "image": image, "metadata": metadata})
    except ValueError as exc:
        return jsonify({"ok": False, "error": str(exc)}), 400
    except Exception as exc:
        return jsonify({"ok": False, "error": str(exc)}), 500


@app.get("/capture/area")
def capture_area():
    try:
        required = ("left", "top", "width", "height")
        missing = [name for name in required if request.args.get(name) is None]
        if missing:
            raise ValueError("Mangler områdeparameter: " + ", ".join(missing) + ".")
        left = int(request.args["left"])
        top = int(request.args["top"])
        width = int(request.args["width"])
        height = int(request.args["height"])
        image, metadata = _capture_area(left, top, width, height)
        return jsonify({"ok": True, "image": image, "metadata": metadata})
    except (TypeError, ValueError) as exc:
        return jsonify({"ok": False, "error": str(exc)}), 400
    except Exception as exc:
        return jsonify({"ok": False, "error": str(exc)}), 500


@app.post("/lm/chat")
def local_lm_chat():
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
        return jsonify({
            "ok": True,
            "answer": answer,
            "model": selected_model,
            "tools_executed": False,
            "automatic_actions": False,
        })
    except Exception as exc:
        return jsonify({"ok": False, "error": str(exc)}), 502


@app.get("/device/status")
def local_device_status():
    result = local_device_adapter.execute_device_request({
        "device_id": "local-adapter",
        "action": "GET_STATUS",
        "parameters": {},
    })
    return jsonify(result), (200 if result.get("ok") else 500)


@app.post("/device/action")
def local_device_action():
    payload = request.get_json(silent=True)
    if not isinstance(payload, dict):
        return jsonify({"ok": False, "error": "Forespørselen må være et JSON-objekt."}), 400
    result = local_device_adapter.execute_device_request(payload)
    return jsonify(result), (200 if result.get("ok") else 400)


@app.get("/vision/ui")
def vision_local_ui():
    return _send_local_page(VISION_UI)


@app.get("/vision/chatgpt.user.js")
def vision_chatgpt_userscript():
    return _send_local_script(CHATGPT_USERSCRIPT)


@app.get("/home-control/ui")
def home_control_local_ui():
    return _send_local_page(HOME_CONTROL_UI)


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
        data.update({
            "council_proxy": True,
            "agent_runner": True,
            "agent_runner_version": agent_runner.AGENT_RUNNER_VERSION,
            "agent_runner_mode": "read-only-allowlist",
            "download_manager": True,
            "download_manager_version": download_manager.DOWNLOAD_MANAGER_VERSION,
            "download_manager_mode": "chatgpt-expected-only",
            "local_device_adapter": True,
            "local_device_adapter_version": local_device_adapter.ADAPTER_VERSION,
            "local_device_adapter_mode": "local-only-allowlist",
            "home_control_ui": True,
            "vision_monitor_capture": True,
            "vision_area_capture": True,
            "vision_chatgpt_userscript": CHATGPT_USERSCRIPT.exists(),
        })
        return jsonify(data)

    app.view_functions["health"] = health_raven_core


if __name__ == "__main__":
    print(f"RAH Raven Desktop Bridge v{APP_VERSION}")
    print(f"Raven Vision: http://127.0.0.1:{PORT}/vision/ui")
    print(f"ChatGPT userscript: http://127.0.0.1:{PORT}/vision/chatgpt.user.js")
    print(f"Home Control: http://127.0.0.1:{PORT}/home-control/ui")
    print(f"Chronicle Live: http://127.0.0.1:{PORT}/chronicle/ui")
    print(f"Raven Insights: http://127.0.0.1:{PORT}/chronicle/insights-ui")
    print(f"Daily Brief: http://127.0.0.1:{PORT}/chronicle/brief-ui")
    print(f"Council text proxy: http://127.0.0.1:{PORT}/lm/chat")
    print(f"Agent Runner: http://127.0.0.1:{PORT}/agent/capabilities")
    print(f"Raven Vault: http://127.0.0.1:{PORT}/downloads/ui")
    print(f"Local Device Adapter: http://127.0.0.1:{PORT}/device/status")
    print(f"Listening on http://{HOST}:{PORT}")
    app.run(host=HOST, port=PORT, debug=False, threaded=True)
