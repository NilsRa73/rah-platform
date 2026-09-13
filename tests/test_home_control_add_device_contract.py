from __future__ import annotations

"""Static regression contract for local add-device validation and rollback in RAH Home Control v1.25."""
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

    require(text, "addDevice.onclick=()=>", "Legg til enhet-handler")
    handler = text.split("addDevice.onclick=()=>", 1)[1].split(";devName.oninput=", 1)[0]

    require(handler, "const name=devName.value.trim(),ip=devIp.value.trim()", "trimmet navn og IPv4")
    require(handler, "if(!name)", "tomt navn avvises")
    require(handler, "if(ip&&!isValidIPv4(ip))", "ugyldig IPv4 avvises")
    require(handler, "const duplicateName=state.devices.find(d=>normalizeName(d.name)===normalizeName(name))", "normalisert duplikatnavn avvises")
    require(handler, "const duplicateIp=ip&&state.devices.find(d=>d.ip===ip)", "duplikat-IPv4 avvises")
    require(handler, "const previousDevices=clone(state.devices)", "rollback-kopi før mutasjon")
    require(handler, "state.devices.push(candidate)", "lokal registermutasjon")
    require(handler, "if(!save()){state.devices=previousDevices", "rollback ved lagringsfeil")
    require(handler, "Skjemaet er beholdt slik at du kan prøve igjen.", "feil beholder skjema")
    require(handler, "devName.value='';devIp.value=''", "skjema tømmes først etter vellykket lagring")
    require(handler, "Enheten «${candidate.name}» er lagt til og lagret lokalt.", "tydelig suksess-feedback")
    require(text, "localStorage.setItem(KEY,JSON.stringify(state))", "enhetsregister bruker lokal hovedlagring")

    mutation = "state.devices.push(candidate)"
    before(handler, "if(!name)", mutation, "tomt navn avvises før state-mutasjon")
    before(handler, "if(ip&&!isValidIPv4(ip))", mutation, "ugyldig IPv4 avvises før state-mutasjon")
    before(handler, "const duplicateName=state.devices.find", mutation, "duplikatnavn sjekkes før state-mutasjon")
    before(handler, "const duplicateIp=ip&&state.devices.find", mutation, "duplikat-IP sjekkes før state-mutasjon")
    before(handler, "const previousDevices=clone(state.devices)", mutation, "rollback-kopi tas før state-mutasjon")
    before(handler, "if(!save())", "devName.value='';devIp.value=''", "skjema tømmes ikke før lagring er bekreftet")

    for token, label in (
        ("RTCPeerConnection", "WebRTC discovery"),
        ("navigator.bluetooth", "Bluetooth discovery"),
        ("navigator.usb", "USB discovery"),
        ("WebSocket(", "network socket discovery"),
        ("new EventSource(", "network event stream"),
    ):
        forbid(text, token, label)

    print("PASS: RAH Home Control add-device validation and rollback contract")


if __name__ == "__main__":
    main()
