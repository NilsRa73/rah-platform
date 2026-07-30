"""RAH Raven Desktop Bridge v1.3.

Small localhost-only HTTP service used by vision.html to capture the active window.
Designed for Windows, with a full-screen fallback on other platforms.
"""
from __future__ import annotations

import base64
import io
import os
import platform
import sys
from typing import Any

from flask import Flask, jsonify
from flask_cors import CORS
from PIL import Image
import mss

APP_VERSION = "1.3.0"
HOST = os.getenv("RAH_BRIDGE_HOST", "127.0.0.1")
PORT = int(os.getenv("RAH_BRIDGE_PORT", "8765"))
MAX_WIDTH = int(os.getenv("RAH_BRIDGE_MAX_WIDTH", "2200"))

app = Flask(__name__)
CORS(
    app,
    resources={r"/*": {"origins": [
        "https://nilsra73.github.io",
        "http://localhost:*",
        "http://127.0.0.1:*",
        "null",
    ]}},
)


def _active_window_rect() -> dict[str, int] | None:
    """Return active-window coordinates on Windows, otherwise None."""
    if sys.platform != "win32":
        return None

    import ctypes
    from ctypes import wintypes

    user32 = ctypes.windll.user32
    hwnd = user32.GetForegroundWindow()
    if not hwnd:
        return None

    rect = wintypes.RECT()
    if not user32.GetWindowRect(hwnd, ctypes.byref(rect)):
        return None

    width = rect.right - rect.left
    height = rect.bottom - rect.top
    if width < 2 or height < 2:
        return None

    return {
        "left": int(rect.left),
        "top": int(rect.top),
        "width": int(width),
        "height": int(height),
    }


def _fallback_monitor(sct: mss.mss) -> dict[str, int]:
    monitor = sct.monitors[1] if len(sct.monitors) > 1 else sct.monitors[0]
    return {
        "left": int(monitor["left"]),
        "top": int(monitor["top"]),
        "width": int(monitor["width"]),
        "height": int(monitor["height"]),
    }


def capture_active_window() -> tuple[str, dict[str, Any]]:
    """Capture active window and return PNG data URL plus metadata."""
    with mss.mss() as sct:
        rect = _active_window_rect() or _fallback_monitor(sct)
        shot = sct.grab(rect)
        image = Image.frombytes("RGB", shot.size, shot.rgb)

    if image.width > MAX_WIDTH:
        target_height = max(1, round(image.height * MAX_WIDTH / image.width))
        image = image.resize((MAX_WIDTH, target_height), Image.Resampling.LANCZOS)

    buffer = io.BytesIO()
    image.save(buffer, format="PNG", optimize=True)
    encoded = base64.b64encode(buffer.getvalue()).decode("ascii")
    return f"data:image/png;base64,{encoded}", {
        "width": image.width,
        "height": image.height,
        "capture": "active-window" if _active_window_rect() else "primary-monitor",
    }


@app.after_request
def add_security_headers(response):
    response.headers["Cache-Control"] = "no-store"
    response.headers["X-Content-Type-Options"] = "nosniff"
    return response


@app.get("/health")
def health():
    return jsonify({
        "ok": True,
        "name": "RAH Raven Desktop Bridge",
        "version": APP_VERSION,
        "platform": platform.platform(),
        "host": HOST,
        "port": PORT,
    })


@app.get("/capture/active-window")
def active_window():
    try:
        image, metadata = capture_active_window()
        return jsonify({"ok": True, "image": image, "metadata": metadata})
    except Exception as exc:  # return a useful UI error instead of HTML
        app.logger.exception("Screenshot capture failed")
        return jsonify({"ok": False, "error": str(exc)}), 500


@app.get("/")
def root():
    return jsonify({
        "service": "RAH Raven Desktop Bridge",
        "health": "/health",
        "capture": "/capture/active-window",
    })


if __name__ == "__main__":
    print(f"RAH Raven Desktop Bridge v{APP_VERSION}")
    print(f"Listening on http://{HOST}:{PORT}")
    app.run(host=HOST, port=PORT, debug=False, threaded=True)
