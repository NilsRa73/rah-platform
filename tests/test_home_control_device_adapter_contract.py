from __future__ import annotations

"""Static contract for the first visible Home Control -> Bridge -> Adapter flow.

This test intentionally fails until RAH-HOME-CONTROL.html exposes an explicit
per-device PING_DEVICE test action. It does not require network access.
"""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HOME = ROOT / "RAH-HOME-CONTROL.html"
BRIDGE = ROOT / "desktop-bridge" / "raven_bridge.py"
ADAPTER = ROOT / "desktop-bridge" / "local_device_adapter.py"


def require(text: str, needle: str, label: str) -> None:
    assert needle in text, f"Mangler {label}: {needle}"


def main() -> None:
    home = HOME.read_text(encoding="utf-8")
    bridge = BRIDGE.read_text(encoding="utf-8")
    adapter = ADAPTER.read_text(encoding="utf-8")

    require(bridge, '@app.post("/device/action")', "Bridge device action endpoint")
    require(adapter, '"PING_DEVICE"', "adapter PING_DEVICE allowlist")

    require(home, "Test forbindelse", "synlig per-enhet testknapp")
    require(home, "PING_DEVICE", "Home Control PING_DEVICE request")
    require(home, "/device/action", "Home Control Bridge endpoint")
    require(home, "fetch(", "eksplisitt lokal Bridge-kall")
    require(home, "showActionNotice", "synlig PASS/ERROR-resultat")

    forbidden = ("network scan", "wifi scan", "navigator.bluetooth.requestDevice")
    lowered = home.lower()
    for marker in forbidden:
        assert marker.lower() not in lowered, f"Utsatt discovery/pairing ble introdusert: {marker}"

    print("PASS: Home Control -> Raven Bridge -> Local Device Adapter contract")


if __name__ == "__main__":
    main()
