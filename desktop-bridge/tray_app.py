"""RAH Raven Vision Windows tray controller.

Runs the canonical localhost Raven Desktop Bridge in-process and provides:
- tray status
- open local Raven Vision / Command Center
- run Raven Doctor
- view logs
- clean shutdown
"""
from __future__ import annotations

import logging
import os
import sys
import threading
import time
import webbrowser
from pathlib import Path
from typing import Callable

import pystray
from PIL import Image, ImageDraw
from werkzeug.serving import make_server

import raven_bridge as bridge_server

APP_NAME = "RAH Raven Vision"
APP_VERSION = bridge_server.APP_VERSION
COMMAND_CENTER_URL = "https://nilsra73.github.io/rah-platform/#vision"
VISION_URL = f"http://{bridge_server.HOST}:{bridge_server.PORT}/vision/ui"
BASE_DIR = Path(getattr(sys, "_MEIPASS", Path(__file__).resolve().parent))
DATA_DIR = Path(os.getenv("LOCALAPPDATA", Path.home())) / "RAH Raven"
LOG_FILE = DATA_DIR / "raven-vision.log"

DATA_DIR.mkdir(parents=True, exist_ok=True)
logging.basicConfig(
    filename=LOG_FILE,
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
)
logger = logging.getLogger(APP_NAME)


class BridgeThread(threading.Thread):
    def __init__(self) -> None:
        super().__init__(name="RAH-Desktop-Bridge", daemon=True)
        self.httpd = make_server(bridge_server.HOST, bridge_server.PORT, bridge_server.app, threaded=True)
        self.ctx = bridge_server.app.app_context()
        self.ctx.push()

    def run(self) -> None:
        logger.info("Desktop Bridge starting on http://%s:%s", bridge_server.HOST, bridge_server.PORT)
        self.httpd.serve_forever()

    def stop(self) -> None:
        logger.info("Desktop Bridge stopping")
        self.httpd.shutdown()
        self.ctx.pop()


def make_icon(ready: bool = True) -> Image.Image:
    image = Image.new("RGBA", (64, 64), (7, 7, 7, 255))
    draw = ImageDraw.Draw(image)
    gold = (255, 226, 138, 255)
    green = (102, 227, 163, 255)
    red = (255, 131, 131, 255)
    draw.ellipse((7, 8, 57, 58), outline=gold, width=4)
    draw.polygon([(18, 38), (31, 15), (46, 38), (32, 32)], fill=gold)
    draw.ellipse((43, 43, 58, 58), fill=green if ready else red)
    return image


def open_path(path: Path) -> None:
    try:
        os.startfile(path)  # type: ignore[attr-defined]
    except Exception:
        webbrowser.open(path.as_uri())


def run_doctor() -> None:
    python = sys.executable
    doctor_path = BASE_DIR / "doctor.py"
    if getattr(sys, "frozen", False):
        webbrowser.open(f"http://{bridge_server.HOST}:{bridge_server.PORT}/health")
        logger.info("Doctor requested from packaged app; opened local health endpoint")
        return
    os.spawnv(os.P_NOWAIT, python, [python, str(doctor_path)])


def safe_action(action: Callable[[], None]) -> Callable:
    def wrapped(icon=None, item=None):
        try:
            action()
        except Exception:
            logger.exception("Tray action failed")
    return wrapped


def self_test() -> int:
    """Validate the bundled canonical Bridge without opening sockets or GUI."""
    if bridge_server.__name__ != "raven_bridge":
        return 21
    if bridge_server.HOST not in {"127.0.0.1", "localhost", "::1"}:
        return 22
    if bridge_server.PORT != 18765:
        return 23

    client = bridge_server.app.test_client()
    health = client.get("/health")
    if health.status_code != 200:
        return 24
    health_data = health.get_json(silent=True) or {}
    if health_data.get("ok") is not True or health_data.get("council_proxy") is not True:
        return 25

    local_pages = {
        "/vision/ui": b"RAH Raven Vision",
        "/chronicle/ui": b"Raven Chronicle Live",
        "/chronicle/insights-ui": b"Raven Insights",
        "/chronicle/brief-ui": b"Raven Daily Brief",
    }
    for route, marker in local_pages.items():
        response = client.get(route)
        if response.status_code != 200 or marker not in response.data:
            return 26
    return 0


def main() -> int:
    if "--self-test" in sys.argv[1:]:
        return self_test()

    logger.info("%s v%s starting", APP_NAME, APP_VERSION)
    bridge = BridgeThread()
    try:
        bridge.start()
        time.sleep(0.25)
    except OSError:
        logger.exception("Could not bind Desktop Bridge port")
        return 1

    icon = pystray.Icon(
        "rah-raven-vision",
        make_icon(True),
        APP_NAME,
        menu=pystray.Menu(
            pystray.MenuItem("Open Raven Vision", safe_action(lambda: webbrowser.open(VISION_URL)), default=True),
            pystray.MenuItem("Open Command Center", safe_action(lambda: webbrowser.open(COMMAND_CENTER_URL))),
            pystray.Menu.SEPARATOR,
            pystray.MenuItem("Run Raven Doctor", safe_action(run_doctor)),
            pystray.MenuItem("Open log", safe_action(lambda: open_path(LOG_FILE))),
            pystray.MenuItem("Open local health", safe_action(lambda: webbrowser.open(f"http://{bridge_server.HOST}:{bridge_server.PORT}/health"))),
            pystray.Menu.SEPARATOR,
            pystray.MenuItem("Exit Raven", lambda tray, item: tray.stop()),
        ),
    )

    webbrowser.open(VISION_URL)
    try:
        icon.run()
    finally:
        bridge.stop()
        bridge.join(timeout=5)
        logger.info("%s stopped", APP_NAME)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
