from __future__ import annotations

"""RAH Observer Doctor v1.0.

Read-only diagnostics for Raven Core, Observer Control Wall, Live Wall and
surface capabilities. Writes deterministic local reports under C:\\RAH\\AgentWork.
It does not install software, pair devices, connect remote peers or change
Windows configuration.
"""

import json
import os
import pathlib
import shutil
import subprocess
import time
import urllib.error
import urllib.request
from typing import Any

DOCTOR_VERSION = "1.0.0"
ROOT = pathlib.Path(r"C:\RAH\AgentWork")
REPORT = ROOT / "OBSERVER-LATEST.txt"
JSON_REPORT = ROOT / "OBSERVER-LATEST.json"
CORE = "http://127.0.0.1:18765"
CONTROL = "http://127.0.0.1:18766"
LIVE = "http://127.0.0.1:18767"


def _get_json(url: str, timeout: float = 5.0) -> dict[str, Any] | None:
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "RAH-Observer-Doctor/1.0"})
        with urllib.request.urlopen(req, timeout=timeout) as response:
            data = json.loads(response.read().decode("utf-8", errors="replace"))
        return data if isinstance(data, dict) else None
    except (OSError, urllib.error.URLError, json.JSONDecodeError, TimeoutError):
        return None


def _get_bytes(url: str, timeout: float = 7.0) -> bytes:
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "RAH-Observer-Doctor/1.0"})
        with urllib.request.urlopen(req, timeout=timeout) as response:
            return response.read(2_000_000)
    except (OSError, urllib.error.URLError, TimeoutError):
        return b""


def _run(args: list[str], timeout: float = 7.0) -> subprocess.CompletedProcess[str] | None:
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


def _ps(script: str, timeout: float = 8.0) -> str:
    exe = shutil.which("powershell.exe") or shutil.which("pwsh.exe")
    if not exe:
        return ""
    result = _run([exe, "-NoLogo", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-Command", script], timeout)
    return (result.stdout or "").strip() if result and result.returncode == 0 else ""


def _phone_link() -> dict[str, Any]:
    text = _ps("$p=Get-AppxPackage -ErrorAction SilentlyContinue | Where-Object {$_.Name -match 'YourPhone|CrossDevice'} | Select-Object -First 1 Name,Version; if($p){$p|ConvertTo-Json -Compress}")
    if not text:
        return {"installed": False}
    try:
        data = json.loads(text)
        return {"installed": True, "name": str(data.get("Name") or ""), "version": str(data.get("Version") or "")}
    except json.JSONDecodeError:
        return {"installed": True, "name": "Phone Link / Cross Device"}


def _bluetooth_count() -> int:
    text = _ps("@(Get-PnpDevice -Class Bluetooth -PresentOnly -ErrorAction SilentlyContinue).Count")
    try:
        return int(text.strip())
    except (ValueError, AttributeError):
        return 0


def _wireless_display() -> dict[str, Any]:
    text = _ps("$c=Get-WindowsCapability -Online -Name 'App.WirelessDisplay.Connect~~~~0.0.1.0' -ErrorAction SilentlyContinue; if($c){$c.State}", timeout=12.0)
    state = text.strip() or "Unknown"
    return {"state": state, "installed": state.lower() == "installed"}


def _adb_state() -> dict[str, Any]:
    adb = shutil.which("adb.exe") or shutil.which("adb")
    if not adb:
        return {"available": False, "authorized": 0, "total": 0}
    result = _run([adb, "devices", "-l"], timeout=5.0)
    authorized = 0
    total = 0
    if result and result.returncode == 0:
        for line in result.stdout.splitlines()[1:]:
            line = line.strip()
            if not line or "\t" not in line:
                continue
            total += 1
            if line.split("\t", 1)[1].split()[0] == "device":
                authorized += 1
    return {"available": True, "authorized": authorized, "total": total}


def _multiroom_present() -> bool:
    candidates = [
        pathlib.Path(r"C:\RAH\RAH-MultiRoom\RAH MultiRoom.cmd"),
        pathlib.Path(os.environ.get("USERPROFILE", "")) / "Desktop" / "RAH MultiRoom.cmd",
    ]
    return any(path.is_file() for path in candidates if str(path))


def diagnose() -> tuple[dict[str, Any], int]:
    started = time.strftime("%Y-%m-%d %H:%M:%S")
    core = _get_json(CORE + "/health") or {}
    control = _get_json(CONTROL + "/health") or {}
    live = _get_json(LIVE + "/health") or {}
    displays = _get_json(LIVE + "/displays") or {}
    surfaces = _get_json(LIVE + "/surfaces") or {}
    devices = _get_json(CONTROL + "/observer/devices") or _get_json(LIVE + "/devices") or {}

    display_list = displays.get("displays") if isinstance(displays.get("displays"), list) else []
    first_index = None
    if display_list and isinstance(display_list[0], dict):
        first_index = display_list[0].get("index")
    preview_bytes = _get_bytes(f"{LIVE}/display-preview/{first_index}.jpg") if first_index is not None else b""
    preview_ok = len(preview_bytes) > 1000 and preview_bytes[:2] == b"\xff\xd8"

    rustdesk = surfaces.get("rustdesk") if isinstance(surfaces.get("rustdesk"), dict) else {}
    spacedesk = surfaces.get("spacedesk") if isinstance(surfaces.get("spacedesk"), dict) else {}
    adb = _adb_state()
    phone = _phone_link()
    wireless = _wireless_display()
    bluetooth = _bluetooth_count()
    scrcpy = bool(shutil.which("scrcpy.exe") or shutil.which("scrcpy"))
    multiroom = _multiroom_present()

    critical_failures: list[str] = []
    warnings: list[str] = []
    plans: list[str] = []
    passes: list[str] = []

    core_green = bool(core.get("ok") and core.get("council_proxy") and core.get("vision_monitor_capture") and core.get("local_device_adapter") and core.get("agent_runner") and core.get("download_manager"))
    if core_green:
        passes.append("Raven Core TRUE GREEN")
    else:
        critical_failures.append("Raven Core is not TRUE GREEN")

    if control.get("ok") and control.get("observer_wall"):
        passes.append("Observer Control Wall online on 127.0.0.1:18766")
    else:
        critical_failures.append("Observer Control Wall offline or unhealthy on 127.0.0.1:18766")

    if live.get("ok") and live.get("live_wall") and live.get("read_only"):
        passes.append("Observer Live Wall online/read-only on 127.0.0.1:18767")
    else:
        critical_failures.append("Observer Live Wall offline or unhealthy on 127.0.0.1:18767")

    display_count = int(displays.get("count") or len(display_list) or 0)
    if display_count > 0:
        passes.append(f"Windows displays detected: {display_count}")
    else:
        warnings.append("No Windows displays were returned by Live Wall display discovery")

    if preview_ok:
        passes.append("Live JPEG display preview verified")
    elif display_count > 0:
        warnings.append("Display exists but Live JPEG preview could not be proven")

    device_list = devices.get("devices") if isinstance(devices.get("devices"), list) else []
    passes.append(f"Observer device fabric entries: {len(device_list)}")

    if rustdesk.get("available"):
        passes.append("RustDesk detected" + (" and running" if rustdesk.get("running") else ""))
    else:
        plans.append("RustDesk not detected; optional for PC-to-PC remote control")

    if spacedesk.get("available"):
        passes.append("spacedesk detected" + (" and running" if spacedesk.get("running") else ""))
    else:
        plans.append("spacedesk not detected; optional for turning phones/PCs into Windows displays")

    if adb.get("available"):
        passes.append(f"ADB available; authorized devices: {adb['authorized']}/{adb['total']}")
        if adb["total"] and not adb["authorized"]:
            warnings.append("ADB device found but none are authorized")
    else:
        plans.append("ADB not detected; optional for Android screen/control integration")

    if scrcpy:
        passes.append("scrcpy detected")
    else:
        plans.append("scrcpy not detected; optional for authorized Android screen control")

    if phone.get("installed"):
        passes.append("Phone Link / Cross Device package detected")
    else:
        plans.append("Phone Link not detected; optional for supported iPhone/Android integration")

    if bluetooth > 0:
        passes.append(f"Bluetooth PnP devices present: {bluetooth}")
    else:
        warnings.append("No present Bluetooth PnP devices detected")

    if wireless.get("installed"):
        passes.append("Windows Wireless Display capability installed")
    elif wireless.get("state") == "Unknown":
        plans.append("Wireless Display capability state could not be read")
    else:
        plans.append(f"Windows Wireless Display capability state: {wireless.get('state')}")

    if multiroom:
        passes.append("RAH MultiRoom launcher detected")
    else:
        plans.append("RAH MultiRoom launcher not detected")

    overall = "PASS"
    rc = 0
    if critical_failures:
        overall = "FAIL"
        rc = 5
    elif warnings:
        overall = "PASS WITH WARNING"
        rc = 6

    result = {
        "ok": not critical_failures,
        "version": DOCTOR_VERSION,
        "started": started,
        "overall": overall,
        "passes": passes,
        "warnings": warnings,
        "plans": plans,
        "failures": critical_failures,
        "facts": {
            "display_count": display_count,
            "preview_ok": preview_ok,
            "device_count": len(device_list),
            "rustdesk": rustdesk,
            "spacedesk": spacedesk,
            "adb": adb,
            "scrcpy": scrcpy,
            "phone_link": phone,
            "bluetooth_present_count": bluetooth,
            "wireless_display": wireless,
            "multiroom": multiroom,
        },
        "policy": "Read-only diagnosis. Missing optional integrations are PLAN, not FAIL.",
    }
    return result, rc


def write_reports(result: dict[str, Any]) -> None:
    ROOT.mkdir(parents=True, exist_ok=True)
    JSON_REPORT.write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")
    lines = [
        "RAH OBSERVER DOCTOR v1.0",
        "========================================================================",
        f"Started: {result['started']}",
        f"Overall: {result['overall']}",
        "Policy: Read-only diagnosis. Missing optional integrations are PLAN, not FAIL.",
        "",
    ]
    for item in result["passes"]:
        lines.append(f"[PASS] {item}")
    for item in result["warnings"]:
        lines.append(f"[WARN] {item}")
    for item in result["plans"]:
        lines.append(f"[PLAN] {item}")
    for item in result["failures"]:
        lines.append(f"[FAIL] {item}")
    lines += ["", f"JSON: {JSON_REPORT}"]
    REPORT.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    result, rc = diagnose()
    write_reports(result)
    print(REPORT.read_text(encoding="utf-8"), end="")
    return rc


if __name__ == "__main__":
    raise SystemExit(main())
