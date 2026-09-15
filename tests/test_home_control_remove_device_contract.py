from __future__ import annotations

"""Static regression contract for local device removal and rollback in RAH Home Control v1.25."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HOME = ROOT / "RAH-HOME-CONTROL.html"


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise AssertionError(f"Mangler kontrakt: {label}: {needle!r}")


def forbid(text: str, needle: str, label: str) -> None:
    if needle in text:
        raise AssertionError(f"Utsatt funksjon ser ut til å være implementert: {label}: {needle!r}")


def before(text: str, first: str, second: str, label: str) -> None:
    first_pos = text.find(first)
    second_pos = text.find(second)
    if first_pos < 0 or second_pos < 0 or first_pos >= second_pos:
        raise AssertionError(f"Feil rekkefølge i kontrakt: {label}")


def main() -> None:
    text = HOME.read_text(encoding="utf-8")

    require(text, "data-remove=\"${d.id}\"", "Fjern-knapp i enhetsregisteret")
    require(text, "document.querySelectorAll('[data-remove]')", "remove-device-handler")

    handler = text.split("document.querySelectorAll('[data-remove]').forEach", 1)[1].split("function renderScreens()", 1)[0]

    require(handler, "const id=b.dataset.remove,d=state.devices.find(x=>x.id===id)", "sletting bruker samme enhets-ID")
    require(handler, "if(!d)return showError('Enheten finnes ikke lenger.')", "manglende enhet håndteres")
    require(handler, "if(!window.confirm(`Fjern «${d.name}» fra enhetsregisteret?`))return", "eksplisitt bekreftelse før sletting")
    require(handler, "const previousDevices=clone(state.devices),previousEditingDeviceId=editingDeviceId", "rollback-kopi av register og redigerings-ID")
    require(handler, "state.devices=state.devices.filter(x=>x.id!==id)", "enheten fjernes lokalt")
    require(handler, "if(editingDeviceId===id)editingDeviceId=null", "aktiv redigering lukkes for slettet enhet")
    require(handler, "if(save())showActionNotice(`Enheten «${d.name}» ble fjernet og endringen er lagret lokalt.`)", "tydelig suksess-feedback")
    require(handler, "state.devices=previousDevices;editingDeviceId=previousEditingDeviceId", "register og redigerings-ID rulles tilbake")
    require(handler, "showError('Fjerningen ble rullet tilbake fordi lokal lagring feilet.')", "tydelig rollback-feedback")
    require(text, "localStorage.setItem(KEY,JSON.stringify(state))", "sletting bruker lokal hovedlagring")

    before(handler, "window.confirm", "const previousDevices=clone(state.devices)", "bekreftelse skjer før rollback-kopi og mutasjon")
    before(handler, "const previousDevices=clone(state.devices)", "state.devices=state.devices.filter", "rollback-kopi tas før sletting")
    before(handler, "state.devices=state.devices.filter", "if(save())", "sletting skjer før lagringsforsøk")

    for token, label in (
        ("RTCPeerConnection", "WebRTC discovery"),
        ("navigator.bluetooth", "Bluetooth discovery"),
        ("navigator.usb", "USB discovery"),
        ("WebSocket(", "network socket discovery"),
        ("new EventSource(", "network event stream"),
    ):
        forbid(text, token, label)

    print("PASS: RAH Home Control remove-device local rollback contract")


if __name__ == "__main__":
    main()
