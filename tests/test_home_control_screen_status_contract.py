from __future__ import annotations

"""Static regression contract for local spacedesk screen status in RAH Home Control v1.25."""
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

    require(text, "<h2>🖥️ spacedesk-skjermer</h2>", "spacedesk-seksjon")
    require(text, "name:'spacedesk Viewer 1'", "lokal standardoppføring for spacedesk")
    require(text, "mode:'Utvidet',active:false", "standardstatus er lokal og frakoblet")
    require(text, "function renderScreens()", "lokal skjermstatus-renderer")
    require(text, "${s.active?'AKTIV':'FRAKOBLET'}", "eksplisitt skjermstatus")
    require(text, "${s.active?'Deaktiver':'Aktiver teststatus'}", "kontroll er eksplisitt teststatus")
    require(text, "screenCount.textContent=`${state.screens.filter(s=>s.active).length} aktive`", "lokal aktiv-teller")
    require(text, "document.querySelectorAll('[data-screen]')", "lokal skjermknapp-binding")
    require(text, "const previousActive=s.active;s.active=!s.active", "statusendring tar rollback-kopi")
    require(text, "if(!save()){s.active=previousActive", "statusendring rulles tilbake ved lagringsfeil")
    require(text, "Skjermstatusen ble rullet tilbake fordi lokal lagring feilet.", "tydelig rollback-feedback")
    require(text, "Skjermstatus for «${s.name}» er lagret lokalt.", "tydelig lokal suksess-feedback")
    require(text, "localStorage.setItem(KEY,JSON.stringify(state))", "skjermstatus bruker lokal hovedlagring")

    for token, label in (
        ("RTCPeerConnection", "WebRTC discovery"),
        ("navigator.bluetooth", "Bluetooth discovery"),
        ("navigator.usb", "USB discovery"),
        ("WebSocket(", "network socket discovery"),
        ("new EventSource(", "network event stream"),
    ):
        forbid(text, token, label)

    print("PASS: RAH Home Control local spacedesk screen status contract")


if __name__ == "__main__":
    main()
