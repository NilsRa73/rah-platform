from __future__ import annotations

"""RAH Observer Wall v1.2.0.

Local device discovery for Raven's visual "The Wall". Discovery is read-only:
Windows Bluetooth/PnP, audio endpoints, Windows network-neighbor cache and ADB
when already installed. Connection buttons only launch explicit allowlisted
Windows settings/apps; this module never runs arbitrary shell input.

v1.2 adds:
- local display destinations on The Wall
- Android screen launch through scrcpy only when scrcpy is already installed
- strict ADB target validation against currently discovered devices
"""

import json
import os
import platform
import shutil
import socket
import subprocess
import time
from typing import Any

OBSERVER_VERSION = "1.2.0"
POWERSHELL = shutil.which("powershell.exe") or shutil.which("pwsh.exe") or "powershell.exe"

ALLOWED_ACTIONS = frozenset({
    "OPEN_BLUETOOTH",
    "OPEN_CONNECTED_DEVICES",
    "OPEN_PHONE_LINK",
    "OPEN_PROJECTING",
    "OPEN_DISPLAY_SETTINGS",
    "OPEN_SOUND",
    "OPEN_NETWORK",
    "OPEN_REMOTE_DESKTOP",
    "BLUETOOTH_TRANSFER",
    "OPEN_MULTIROOM",
    "OPEN_ANDROID_SCREEN",
})

SETTINGS_URIS = {
    "OPEN_BLUETOOTH": "ms-settings:bluetooth",
    "OPEN_CONNECTED_DEVICES": "ms-settings:connecteddevices",
    "OPEN_PHONE_LINK": "ms-settings:mobile-devices-addphone-direct",
    "OPEN_PROJECTING": "ms-settings:project",
    "OPEN_DISPLAY_SETTINGS": "ms-settings:display",
    "OPEN_SOUND": "ms-settings:sound",
    "OPEN_NETWORK": "ms-settings:network-status",
    "OPEN_REMOTE_DESKTOP": "ms-settings:remotedesktop",
}


def _run(args: list[str], timeout: float = 4.0) -> subprocess.CompletedProcess[str] | None:
    try:
        return subprocess.run(
            args,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=timeout,
            check=False,
            creationflags=(getattr(subprocess, "CREATE_NO_WINDOW", 0) if os.name == "nt" else 0),
        )
    except (OSError, subprocess.TimeoutExpired):
        return None


def _ps_json(script: str, timeout: float = 5.0) -> list[dict[str, Any]]:
    if os.name != "nt":
        return []
    result = _run([
        POWERSHELL,
        "-NoLogo",
        "-NoProfile",
        "-NonInteractive",
        "-ExecutionPolicy",
        "Bypass",
        "-Command",
        script,
    ], timeout=timeout)
    if not result or result.returncode != 0 or not result.stdout.strip():
        return []
    try:
        data = json.loads(result.stdout)
    except json.JSONDecodeError:
        return []
    if isinstance(data, dict):
        return [data]
    if isinstance(data, list):
        return [item for item in data if isinstance(item, dict)]
    return []


def _clean(value: Any, limit: int = 180) -> str:
    text = str(value or "").replace("\r", " ").replace("\n", " ").strip()
    return text[:limit]


def _classify(name: str, source: str = "") -> str:
    n = name.lower()
    if source == "display":
        return "display"
    if any(token in n for token in ("iphone", "ipad", "apple")):
        return "iphone"
    if any(token in n for token in ("android", "pixel", "galaxy", "moto ", "motorola", "oneplus", "xiaomi", "redmi")):
        return "android"
    if any(token in n for token in ("tv", "chromecast", "bravia", "webos", "roku", "shield", "google tv", "android tv")):
        return "tv"
    if any(token in n for token in ("speaker", "headphone", "headset", "denon", "receiver", "audio", "sound", "buds")):
        return "audio"
    if source == "audio":
        return "audio"
    if source == "bluetooth":
        return "bluetooth"
    if source == "adb":
        return "android"
    if any(token in n for token in ("desktop", "laptop", "pc", "omen", "lenovo")):
        return "pc"
    return "device"


def _recommended_actions(kind: str, source: str) -> list[str]:
    actions: list[str] = []
    if source == "display" or kind == "display":
        actions.extend(["OPEN_DISPLAY_SETTINGS", "OPEN_PROJECTING"])
    if source == "bluetooth" or kind in {"bluetooth", "audio"}:
        actions.extend(["OPEN_BLUETOOTH", "BLUETOOTH_TRANSFER"])
    if kind == "iphone":
        actions.extend(["OPEN_PHONE_LINK", "OPEN_BLUETOOTH"])
    if kind == "android":
        if source == "adb":
            actions.append("OPEN_ANDROID_SCREEN")
        actions.extend(["OPEN_PROJECTING", "OPEN_CONNECTED_DEVICES"])
    if kind == "tv":
        actions.extend(["OPEN_PROJECTING", "OPEN_CONNECTED_DEVICES"])
    if kind == "audio":
        actions.extend(["OPEN_MULTIROOM", "OPEN_SOUND"])
    if kind == "pc":
        actions.extend(["OPEN_CONNECTED_DEVICES", "OPEN_REMOTE_DESKTOP", "OPEN_NETWORK"])
    if source == "lan" and "OPEN_NETWORK" not in actions:
        actions.append("OPEN_NETWORK")
    if not actions:
        actions.append("OPEN_CONNECTED_DEVICES")
    return list(dict.fromkeys(actions))


def _device(*, device_id: str, name: str, source: str, detail: str = "", status: str = "seen", address: str = "") -> dict[str, Any]:
    kind = _classify(name, source)
    return {
        "id": _clean(device_id, 220),
        "name": _clean(name) or "Unknown device",
        "kind": kind,
        "source": source,
        "detail": _clean(detail, 260),
        "status": _clean(status, 60),
        "address": _clean(address, 120),
        "actions": _recommended_actions(kind, source),
    }


def discover_local() -> list[dict[str, Any]]:
    hostname = socket.gethostname() or platform.node() or "This PC"
    return [_device(
        device_id="local-pc",
        name=hostname,
        source="local",
        detail=f"{platform.system()} {platform.release()} · Raven host",
        status="online",
    )]


def discover_displays() -> list[dict[str, Any]]:
    rows = _ps_json(
        "Get-CimInstance Win32_DesktopMonitor -ErrorAction SilentlyContinue | "
        "Where-Object {$_.PNPDeviceID} | "
        "Select-Object Name,PNPDeviceID,ScreenWidth,ScreenHeight,Status | ConvertTo-Json -Compress",
        timeout=5.0,
    )
    devices: list[dict[str, Any]] = []
    for index, row in enumerate(rows, start=1):
        pnp = _clean(row.get("PNPDeviceID"), 220)
        if not pnp:
            continue
        name = _clean(row.get("Name")) or f"Display {index}"
        width = _clean(row.get("ScreenWidth"), 20)
        height = _clean(row.get("ScreenHeight"), 20)
        geometry = f"{width}×{height}" if width and height else "Windows display destination"
        devices.append(_device(
            device_id=f"display:{pnp}",
            name=name,
            source="display",
            detail=geometry,
            status=_clean(row.get("Status")) or "online",
        ))
    return devices


def discover_bluetooth() -> list[dict[str, Any]]:
    rows = _ps_json(
        "Get-PnpDevice -Class Bluetooth -PresentOnly -ErrorAction SilentlyContinue | "
        "Select-Object FriendlyName,InstanceId,Status | ConvertTo-Json -Compress"
    )
    devices: list[dict[str, Any]] = []
    for row in rows:
        name = _clean(row.get("FriendlyName"))
        instance = _clean(row.get("InstanceId"), 220)
        if not name or not instance:
            continue
        devices.append(_device(
            device_id=f"bt:{instance}",
            name=name,
            source="bluetooth",
            detail="Windows Bluetooth / PnP",
            status=_clean(row.get("Status")) or "present",
        ))
    return devices


def discover_audio() -> list[dict[str, Any]]:
    rows = _ps_json(
        "Get-PnpDevice -Class AudioEndpoint -PresentOnly -ErrorAction SilentlyContinue | "
        "Select-Object FriendlyName,InstanceId,Status | ConvertTo-Json -Compress"
    )
    devices: list[dict[str, Any]] = []
    for row in rows:
        name = _clean(row.get("FriendlyName"))
        instance = _clean(row.get("InstanceId"), 220)
        if not name or not instance:
            continue
        devices.append(_device(
            device_id=f"audio:{instance}",
            name=name,
            source="audio",
            detail="Windows audio endpoint",
            status=_clean(row.get("Status")) or "present",
        ))
    return devices


def discover_lan() -> list[dict[str, Any]]:
    rows = _ps_json(
        "Get-NetNeighbor -AddressFamily IPv4 -ErrorAction SilentlyContinue | "
        "Where-Object {$_.State -notin @('Unreachable','Incomplete') -and $_.IPAddress -notlike '224.*' -and $_.IPAddress -ne '255.255.255.255'} | "
        "Select-Object IPAddress,LinkLayerAddress,State,InterfaceAlias | ConvertTo-Json -Compress",
        timeout=6.0,
    )
    devices: list[dict[str, Any]] = []
    for row in rows:
        ip = _clean(row.get("IPAddress"), 80)
        mac = _clean(row.get("LinkLayerAddress"), 80)
        if not ip or ip.startswith("127.") or ip == "0.0.0.0":
            continue
        devices.append(_device(
            device_id=f"lan:{ip}",
            name=ip,
            source="lan",
            detail=f"{_clean(row.get('InterfaceAlias'))} · {mac}".strip(" ·"),
            status=_clean(row.get("State")) or "seen",
            address=ip,
        ))
    return devices


def discover_adb() -> list[dict[str, Any]]:
    adb = shutil.which("adb.exe") or shutil.which("adb")
    if not adb:
        return []
    result = _run([adb, "devices", "-l"], timeout=4.0)
    if not result or result.returncode != 0:
        return []
    devices: list[dict[str, Any]] = []
    for line in result.stdout.splitlines()[1:]:
        line = line.strip()
        if not line or "\t" not in line:
            continue
        serial, rest = line.split("\t", 1)
        fields = rest.split()
        state = fields[0] if fields else "unknown"
        model = next((part.split(":", 1)[1] for part in fields if part.startswith("model:")), serial)
        devices.append(_device(
            device_id=f"adb:{serial}",
            name=model.replace("_", " "),
            source="adb",
            detail=f"ADB · {serial}",
            status=state,
            address=serial,
        ))
    return devices


def _validated_adb_serial(payload: dict[str, Any]) -> str:
    requested = _clean(payload.get("device_id"), 220)
    if not requested.startswith("adb:"):
        raise ValueError("Android screen action requires a discovered ADB device id.")
    current = {item["id"]: item for item in discover_adb()}
    match = current.get(requested)
    if not match or match.get("status") != "device":
        raise ValueError("ADB device is not currently connected and authorized.")
    return requested.split(":", 1)[1]


def discover_all() -> dict[str, Any]:
    groups = {
        "local": discover_local(),
        "display": discover_displays(),
        "bluetooth": discover_bluetooth(),
        "audio": discover_audio(),
        "lan": discover_lan(),
        "adb": discover_adb(),
    }
    seen: set[tuple[str, str]] = set()
    devices: list[dict[str, Any]] = []
    for group in groups.values():
        for item in group:
            key = (item.get("source", ""), item.get("id", ""))
            if key in seen:
                continue
            seen.add(key)
            devices.append(item)
    counts: dict[str, int] = {}
    for item in devices:
        counts[item["source"]] = counts.get(item["source"], 0) + 1
    return {
        "ok": True,
        "version": OBSERVER_VERSION,
        "timestamp": time.time(),
        "devices": devices,
        "counts": counts,
        "automatic_pairing": False,
        "arbitrary_commands": False,
        "scrcpy_available": bool(shutil.which("scrcpy.exe") or shutil.which("scrcpy")),
    }


def execute_action(payload: dict[str, Any]) -> dict[str, Any]:
    if not isinstance(payload, dict):
        return {"ok": False, "error": "Observer action must be a JSON object."}
    action = str(payload.get("action") or "").strip().upper()
    if action not in ALLOWED_ACTIONS:
        return {"ok": False, "error": "Observer action is not allowlisted.", "allowed": sorted(ALLOWED_ACTIONS)}
    if os.name != "nt":
        return {"ok": False, "error": "Observer connection actions require Windows."}

    try:
        if action in SETTINGS_URIS:
            os.startfile(SETTINGS_URIS[action])  # type: ignore[attr-defined]
            return {"ok": True, "action": action, "mode": "windows-settings", "target": SETTINGS_URIS[action]}
        if action == "BLUETOOTH_TRANSFER":
            exe = shutil.which("fsquirt.exe") or os.path.join(os.environ.get("SystemRoot", r"C:\Windows"), "System32", "fsquirt.exe")
            if not os.path.exists(exe):
                return {"ok": False, "error": "Windows Bluetooth File Transfer (fsquirt.exe) was not found."}
            subprocess.Popen([exe], close_fds=True)
            return {"ok": True, "action": action, "mode": "windows-bluetooth-transfer"}
        if action == "OPEN_MULTIROOM":
            candidates = [
                r"C:\RAH\RAH-MultiRoom\RAH MultiRoom.cmd",
                os.path.join(os.environ.get("USERPROFILE", ""), "Desktop", "RAH MultiRoom.cmd"),
            ]
            target = next((p for p in candidates if p and os.path.exists(p)), "")
            if not target:
                return {"ok": False, "error": "RAH MultiRoom launcher was not found yet."}
            os.startfile(target)  # type: ignore[attr-defined]
            return {"ok": True, "action": action, "mode": "local-launcher", "target": target}
        if action == "OPEN_ANDROID_SCREEN":
            scrcpy = shutil.which("scrcpy.exe") or shutil.which("scrcpy")
            if not scrcpy:
                return {"ok": False, "error": "scrcpy is not installed or not on PATH yet."}
            serial = _validated_adb_serial(payload)
            subprocess.Popen([scrcpy, "--serial", serial], close_fds=True)
            return {"ok": True, "action": action, "mode": "scrcpy", "device_id": f"adb:{serial}"}
    except (OSError, ValueError) as exc:
        return {"ok": False, "error": str(exc)}

    return {"ok": False, "error": "Observer action did not resolve."}
