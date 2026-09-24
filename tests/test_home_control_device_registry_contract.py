from __future__ import annotations

"""Regression contract for the local RAH Home Control device registry schema."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HOME = ROOT / "RAH-HOME-CONTROL.html"


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise AssertionError(f"Mangler enhetsregister-kontrakt: {label}: {needle!r}")


def main() -> None:
    text = HOME.read_text(encoding="utf-8")

    # One stable local registry record must retain the seven MVP fields.
    for marker, label in (
        ("name:'RAH Hoved-PC'", "navn"),
        ("room:'Datarom'", "rom"),
        ("type:'PC'", "type"),
        ("ip:'127.0.0.1'", "IPv4"),
        ("connection:'Lokal'", "forbindelse"),
        ("role:'Hovednode'", "rolle"),
        ("online:true", "lokal status"),
    ):
        require(text, marker, label)

    # The editable registry must keep the canonical local choice sets.
    require(text, "ROOM_OPTIONS=['Datarom','Stue 1','Stue 2','Soverom','Ikke valgt']", "romvalg")
    require(text, "CONNECTION_OPTIONS=['Ethernet','Wi-Fi','Bluetooth','USB','Lokal']", "forbindelsesvalg")
    require(text, "ROLE_OPTIONS=['Arbeidsnode','Hovednode','spacedesk-skjerm','Medieenhet','Kontrollpanel','Ubestemt']", "rollevalg")

    # Existing integrity rules are part of the registry contract.
    require(text, "function uniqueDeviceIds(x)", "unik ID")
    require(text, "function uniqueDeviceNames(x)", "unikt navn")
    require(text, "function validDeviceIPv4s(x)", "gyldig/unik IPv4")
    require(text, "knownRoomReference(x,d.room)", "gyldig romreferanse")

    print("PASS: Home Control device registry schema contract")


if __name__ == "__main__":
    main()
