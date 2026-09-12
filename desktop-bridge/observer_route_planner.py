from __future__ import annotations

"""Deterministic, non-executing route plans for RAH Observer Screen Router."""

from typing import Any

ROUTER_VERSION = "1.0.0"


def plan_route(payload: dict[str, Any]) -> dict[str, Any]:
    if not isinstance(payload, dict):
        return {"ok": False, "error": "Route request must be JSON."}

    kind = str(payload.get("kind") or "device").strip().lower()
    name = str(payload.get("name") or "Device").strip()[:160]
    display = payload.get("display") if isinstance(payload.get("display"), dict) else {}
    display_name = str(display.get("name") or "selected screen")[:120]
    transports = payload.get("transports") if isinstance(payload.get("transports"), list) else []
    transports = [str(item).lower()[:40] for item in transports[:12]]

    action = "OPEN_CONNECTED_DEVICES"
    direction = "device-management"
    title = f"Manage {name}"
    note = "Windows will show the supported connection surface."

    if kind == "iphone":
        action = "OPEN_PHONE_LINK"
        direction = "phone-to-pc"
        title = f"Open {name} through Phone Link"
        note = "Phone Link can expose supported iPhone features, but does not provide generic full-screen iPhone mirroring."
    elif kind == "android":
        action = "OPEN_PROJECTING"
        direction = "phone-to-pc-display"
        title = f"Route {name} toward {display_name}"
        note = "Windows Projecting/Phone Link availability depends on the Android device and Windows features installed."
    elif kind == "pc":
        action = "OPEN_REMOTE_DESKTOP"
        direction = "pc-to-pc-display"
        title = f"Open a PC-to-PC route for {name}"
        note = "Remote Desktop is the default Windows route; Raven does not enter credentials or bypass approval."
    elif kind == "tv":
        action = "OPEN_PROJECTING"
        direction = "pc-to-tv"
        title = f"Project this PC toward {name}"
        note = "For TVs/boxes the useful direction is normally this PC to the remote display, using Windows Project/Cast."
    elif kind == "audio":
        action = "OPEN_MULTIROOM"
        direction = "audio-route"
        title = f"Route audio to {name}"
        note = "RAH MultiRoom is preferred for audio endpoints when installed."
    elif kind == "bluetooth":
        action = "OPEN_BLUETOOTH"
        direction = "bluetooth-pairing"
        title = f"Open Bluetooth route for {name}"
        note = "Bluetooth pairing remains under Windows approval."

    return {
        "ok": True,
        "version": ROUTER_VERSION,
        "title": title,
        "kind": kind,
        "device_name": name,
        "display": display_name,
        "display_id": str(display.get("id") or "")[:180],
        "transports": transports,
        "direction": direction,
        "action": action,
        "note": note,
        "executes": False,
        "automatic_pairing": False,
    }
