from __future__ import annotations

"""Static regression contract for local room status in RAH Home Control v1.25."""
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

    for room_id, room_name in (
        ("datarom", "Datarom"),
        ("stue1", "Stue 1"),
        ("stue2", "Stue 2"),
        ("soverom", "Soverom"),
    ):
        require(text, f"id:'{room_id}',name:'{room_name}'", f"kanonisk rom {room_name}")

    require(text, "function renderRooms()", "lokal romstatus-renderer")
    require(text, "${r.active?'AKTIV':'KLAR'}", "eksplisitt lokal romstatus")
    require(text, "${r.active?'Slå av':'Aktiver'}", "lokal Aktiver/Slå av-kontroll")
    require(text, ">Hovedrom</button>", "lokal Hovedrom-kontroll")
    require(text, "const previousActive=r.active;r.active=!r.active", "romstatus tar rollback-kopi")
    require(text, "if(!save()){r.active=previousActive", "Aktiver/Slå av rulles tilbake ved lagringsfeil")
    require(text, "Romstatusen ble rullet tilbake fordi lokal lagring feilet.", "tydelig romstatus rollback-feedback")
    require(text, "«${r.name}» er nå ${r.active?'aktivt':'av'} og lagret lokalt.", "tydelig romstatus suksess-feedback")
    require(text, "const previousRooms=clone(state.rooms)", "Hovedrom tar full rollback-kopi")
    require(text, "state.rooms.forEach(r=>r.active=r.id===b.dataset.main)", "Hovedrom gjør valgt rom eksklusivt aktivt")
    require(text, "if(!save()){state.rooms=previousRooms", "Hovedrom rulles tilbake ved lagringsfeil")
    require(text, "Valg av hovedrom ble rullet tilbake fordi lokal lagring feilet.", "tydelig Hovedrom rollback-feedback")
    require(text, "«${target.name}» er nå eneste aktive hovedrom og lagret lokalt.", "tydelig Hovedrom suksess-feedback")
    require(text, "localStorage.setItem(KEY,JSON.stringify(state))", "romstatus bruker lokal hovedlagring")

    for token, label in (
        ("RTCPeerConnection", "WebRTC discovery"),
        ("navigator.bluetooth", "Bluetooth discovery"),
        ("navigator.usb", "USB discovery"),
        ("WebSocket(", "network socket discovery"),
        ("new EventSource(", "network event stream"),
    ):
        forbid(text, token, label)

    print("PASS: RAH Home Control local room status feedback and rollback contract")


if __name__ == "__main__":
    main()
