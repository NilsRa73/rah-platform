from __future__ import annotations

"""Regression contract that keeps later RAH Home Control milestones deferred."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HOME = ROOT / "RAH-HOME-CONTROL.html"
ROADMAP = ROOT / "RAH-HOME-CONTROL-ROADMAP.md"


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise AssertionError(f"Mangler utsatt veikartkrav: {label}: {needle!r}")


def forbid(text: str, needle: str, label: str) -> None:
    if needle in text:
        raise AssertionError(f"Utsatt funksjon ser ut til å være implementert i Stable/MVP: {label}: {needle!r}")


def main() -> None:
    home = HOME.read_text(encoding="utf-8")
    roadmap = ROADMAP.read_text(encoding="utf-8")

    for needle, label in (
        ("Oppdagelse og søk etter alle Wi‑Fi-enheter.", "Wi-Fi discovery"),
        ("Enkel sammenkobling og godkjenning av enheter.", "pairing"),
        ("Clustering mellom hoved-PC, HP Omen og senere noder.", "clustering"),
        ("Større eller flere AI-hjerner.", "flere AI-hjerner"),
        ("Alternative konfigurasjoner for ledernode, delt arbeid og uavhengige noder.", "alternative konfigurasjoner"),
        ("Raven Vision er ikke del av punkt 1 nå.", "Raven Vision utsatt"),
    ):
        require(roadmap, needle, label)

    require(roadmap, "Punkt 1 regnes som ferdig som Stable/MVP.", "Stable/MVP-grense")

    for token, label in (
        ("RTCPeerConnection", "WebRTC discovery"),
        ("navigator.bluetooth", "Bluetooth discovery"),
        ("navigator.usb", "USB discovery"),
        ("WebSocket(", "network socket/discovery"),
        ("new EventSource(", "network event stream"),
    ):
        forbid(home, token, label)

    print("PASS: RAH Home Control deferred roadmap scope contract")


if __name__ == "__main__":
    main()
