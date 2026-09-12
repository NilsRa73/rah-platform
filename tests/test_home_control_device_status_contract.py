from __future__ import annotations

"""Static regression contract for local device visibility status in RAH Home Control v1.25."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HOME = ROOT / "RAH-HOME-CONTROL.html"


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise AssertionError(f"Mangler kontrakt: {label}: {needle!r}")


def forbid(text: str, needle: str, label: str) -> None:
    if needle in text:
        raise AssertionError(f"Utsatt funksjon ser ut til å være implementert: {label}: {needle!r}")


def main() -> None:
    text = HOME.read_text(encoding="utf-8")

    require(text, "function renderDevices()", "lokal enhetsstatus-renderer")
    require(text, "${d.online?'SYNLIG':'LAGRET'}", "eksplisitt lokal enhetsstatus")
    require(text, "${d.online?'Marker frakoblet':'Marker synlig'}", "lokal statuskontroll")
    require(text, "const onlineCount=state.devices.filter(d=>d.online).length,offlineCount=state.devices.filter(d=>!d.online).length", "lokale statustellere")
    require(text, "${state.devices.length} totalt · ${onlineCount} synlige · ${offlineCount} lagrede/frakoblede · ${shown.length} vist", "statusoppsummering")
    require(text, "const previousOnline=d.online;d.online=!d.online", "statusendring tar rollback-kopi")
    require(text, "if(!save()){d.online=previousOnline", "statusendring rulles tilbake ved lagringsfeil")
    require(text, "Statusendringen ble rullet tilbake fordi lokal lagring feilet.", "tydelig rollback-feedback")
    require(text, "«${d.name}» er nå markert ${d.online?'synlig':'frakoblet'} og lagret lokalt.", "tydelig suksess-feedback")
    require(text, "localStorage.setItem(KEY,JSON.stringify(state))", "enhetsstatus bruker lokal hovedlagring")
    require(text, "statusFilter==='online'?d.online:!d.online", "statusfilter bygger på lokal online-markering")

    for token, label in (
        ("RTCPeerConnection", "WebRTC discovery"),
        ("navigator.bluetooth", "Bluetooth discovery"),
        ("navigator.usb", "USB discovery"),
        ("WebSocket(", "network socket discovery"),
        ("new EventSource(", "network event stream"),
    ):
        forbid(text, token, label)

    print("PASS: RAH Home Control local device visibility feedback and rollback contract")


if __name__ == "__main__":
    main()
