from __future__ import annotations

"""Static regression gate for RAH Home Control v1.20 Stable.

Uses only the Python standard library. The test intentionally checks a small,
explicit contract instead of executing the browser UI:
- required room model is present
- persisted main state is validated before render
- local storage keys remain stable
- rollback guards remain present for core local controls
- no active network-discovery implementation has slipped into Home Control

Run from the repository root:
    python tests/test_home_control_stable_contract.py
"""

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

    # Version / scope.
    require(text, "stabil lokal kontroll v1.20", "v1.20 Stable-versjon")

    # Required room model.
    for room in ("Datarom", "Stue 1", "Stue 2", "Soverom"):
        require(text, f"name:'{room}'", f"rommodell {room}")
        require(text, f"'{room}'", f"lagret rommodell {room}")

    # Persisted state must be structurally validated before it can render.
    require(text, "function validStoredState(x)", "streng validering av lagret hovedtilstand")
    require(text, "return validBackupState(x)&&requiredRooms.every", "felt- og romvalidering")
    require(text, "if(!validStoredState(parsed))throw Error()", "loadState bruker streng validering")
    require(text, "kunne ikke leses eller valideres", "synlig fallback-feil")

    # Stable local storage contract.
    require(text, "const KEY='rah-home-control-v03'", "hovedlagringsnøkkel")
    require(text, "FILTER_KEY='rah-home-control-filters-v01'", "filterlagringsnøkkel")
    require(text, "localStorage.setItem(KEY,JSON.stringify(state))", "lokal hovedlagring")
    require(text, "localStorage.setItem(FILTER_KEY", "lokal filterlagring")

    # Core rollback/error-handling contracts.
    require(text, "Romstatusen ble rullet tilbake fordi lokal lagring feilet.", "romstatus rollback")
    require(text, "Valg av hovedrom ble rullet tilbake fordi lokal lagring feilet.", "hovedrom rollback")
    require(text, "Enheten ble ikke lagt til fordi lokal lagring feilet.", "legg til enhet rollback")
    require(text, "Fjerningen ble rullet tilbake fordi lokal lagring feilet.", "fjern enhet rollback")
    require(text, "Statusfilteret ble rullet tilbake fordi lokal lagring feilet.", "statusfilter rollback")
    require(text, "Romfilteret ble rullet tilbake fordi lokal lagring feilet.", "romfilter rollback")

    # Deferred network/device-discovery features must remain unimplemented in this file.
    for token, label in (
        ("RTCPeerConnection", "WebRTC discovery"),
        ("navigator.bluetooth", "Bluetooth discovery"),
        ("navigator.usb", "USB discovery"),
        ("WebSocket(", "network socket discovery"),
        ("new EventSource(", "network event stream"),
    ):
        forbid(text, token, label)

    print("PASS: RAH Home Control v1.20 Stable contract")


if __name__ == "__main__":
    main()
