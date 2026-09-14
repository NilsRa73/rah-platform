from __future__ import annotations

"""Static regression contract for local device editing and rollback in RAH Home Control v1.25."""
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

    require(text, "data-save-edit=\"${d.id}\"", "Lagre-knapp for enhetsredigering")
    require(text, "data-cancel-edit=\"${d.id}\"", "Avbryt-knapp for enhetsredigering")
    require(text, "document.querySelectorAll('[data-save-edit]')", "save-edit-handler")

    handler = text.split("document.querySelectorAll('[data-save-edit]').forEach", 1)[1].split(";document.querySelectorAll('[data-remove]')", 1)[0]

    require(handler, "const id=b.dataset.saveEdit,d=state.devices.find(x=>x.id===id)", "redigerer enheten med samme ID")
    require(handler, "if(!d){editingDeviceId=null;showError('Enheten finnes ikke lenger.')", "manglende enhet håndteres")
    require(handler, "const previousDevice=clone(d)", "rollback-kopi tas før endring")
    require(handler, "d.room=document.querySelector(`[data-edit-room=\"${id}\"]`).value", "rom kan redigeres lokalt")
    require(handler, "d.connection=document.querySelector(`[data-edit-connection=\"${id}\"]`).value", "forbindelse kan redigeres lokalt")
    require(handler, "d.role=document.querySelector(`[data-edit-role=\"${id}\"]`).value", "rolle kan redigeres lokalt")
    require(handler, "if(save()){editingDeviceId=null", "redigeringspanel lukkes først etter vellykket lagring")
    require(handler, "showActionNotice(`Endringene for «${d.name}» er lagret lokalt.`)", "tydelig suksess-feedback")
    require(handler, "Object.assign(d,previousDevice)", "enheten rulles tilbake ved lagringsfeil")
    require(handler, "Redigeringen ble rullet tilbake fordi lokal lagring feilet. Redigeringspanelet er beholdt.", "tydelig rollback-feedback")
    require(text, "localStorage.setItem(KEY,JSON.stringify(state))", "redigering bruker lokal hovedlagring")

    before(handler, "const previousDevice=clone(d)", "d.room=", "rollback-kopi tas før første state-mutasjon")
    before(handler, "d.room=", "if(save())", "romendring skjer før lagringsforsøk")
    before(handler, "d.connection=", "if(save())", "forbindelsesendring skjer før lagringsforsøk")
    before(handler, "d.role=", "if(save())", "rolleendring skjer før lagringsforsøk")

    for token, label in (
        ("RTCPeerConnection", "WebRTC discovery"),
        ("navigator.bluetooth", "Bluetooth discovery"),
        ("navigator.usb", "USB discovery"),
        ("WebSocket(", "network socket discovery"),
        ("new EventSource(", "network event stream"),
    ):
        forbid(text, token, label)

    print("PASS: RAH Home Control edit-device local rollback contract")


if __name__ == "__main__":
    main()
