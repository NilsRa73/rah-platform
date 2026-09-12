from __future__ import annotations

"""Bounded local display thumbnails for RAH Observer Live Surfaces.

Only local Windows display rectangles returned by observer_displays are captured.
The function validates the requested display index, downsizes the image, caches
briefly, and never captures arbitrary screen coordinates supplied by a client.
"""

import io
import threading
import time
from typing import Any

from PIL import Image
import mss

import observer_displays

PREVIEW_VERSION = "1.0.0"
CACHE_SECONDS = 0.8
MAX_WIDTH = 520
JPEG_QUALITY = 58
_lock = threading.Lock()
_cache: dict[int, tuple[float, bytes]] = {}


def _validated_display(index: int) -> dict[str, Any]:
    result = observer_displays.discover_displays()
    displays = result.get("displays") if isinstance(result, dict) else []
    if not isinstance(displays, list):
        raise ValueError("Display catalog is unavailable.")
    for display in displays:
        try:
            if int(display.get("index")) == int(index):
                return display
        except (TypeError, ValueError, AttributeError):
            continue
    raise ValueError("Display index is not currently available.")


def capture_display_jpeg(index: int) -> bytes:
    index = int(index)
    if index < 1 or index > 32:
        raise ValueError("Display index is outside the supported range.")

    now = time.monotonic()
    with _lock:
        cached = _cache.get(index)
        if cached and now - cached[0] <= CACHE_SECONDS:
            return cached[1]

    display = _validated_display(index)
    left = int(display.get("x") or 0)
    top = int(display.get("y") or 0)
    width = int(display.get("width") or 0)
    height = int(display.get("height") or 0)
    if width <= 0 or height <= 0 or width > 20000 or height > 12000:
        raise ValueError("Display bounds are invalid.")

    with mss.mss() as sct:
        shot = sct.grab({"left": left, "top": top, "width": width, "height": height})
        image = Image.frombytes("RGB", shot.size, shot.rgb)

    if image.width > MAX_WIDTH:
        target_height = max(1, round(image.height * (MAX_WIDTH / image.width)))
        image = image.resize((MAX_WIDTH, target_height), Image.Resampling.LANCZOS)

    output = io.BytesIO()
    image.save(output, format="JPEG", quality=JPEG_QUALITY, optimize=True)
    data = output.getvalue()
    with _lock:
        _cache[index] = (time.monotonic(), data)
    return data
