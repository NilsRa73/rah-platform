from __future__ import annotations

"""Static regression gate for RAH Home Control v1.24 Stable.

Uses only the Python standard library. The test intentionally checks a small,
explicit contract instead of executing the browser UI:
- required room model is present
- persisted/imported device and screen room references are validated
- persisted/imported room names, room IDs, device IDs and normalized device names are unique
- device registry preserves unique-name and unique-IPv4 guards
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
    require(text, "stabil lokal kontroll v1.24", "v1.24 Stable-versjon")

    # Required room model.
    for room in ("Datarom", "Stue 1", "Stue 2", "Soverom"):
        require(text, f"name:'{room}'", f"rommodell {room}")
        require(text, f"'{room}'", f"lagret rommodell {room}")

    # Persisted/imported state must validate room references and uniqueness.
    require(text, "function knownRoomReference(x,roomName)", "felles romreferanse-validering")
    require(text, "roomName==='Ikke valgt'||x.rooms.some", "kjent rom eller Ikke valgt")
    require(text, "knownRoomReference(x,d.room)", "enhetsrom bruker felles romvalidering")
    require(text, "knownRoomReference(x,s.room)", "skjermrom bruker felles romvalidering")
    require(text, "function uniqueRoomNames(x)", "unik romnavn-validering")
    require(text, "new Set(names).size===names.length", "ingen duplikate romnavn")
    require(text, "function uniqueRoomIds(x)", "unik rom-ID-validering")
    require(text, "new Set(ids).size===ids.length", "ingen duplikate rom-ID-er")
    require(text, "function uniqueDeviceIds(x)", "unik enhets-ID-validering")
    require(text, "const ids=x.devices.map(d=>d&&d.id)", "enhets-ID-er hentes fra lagret/importert tilstand")
    require(text, "function uniqueDeviceNames(x)", "unik normalisert enhetsnavn-validering")
    require(text, "normalizeName(d.name)", "lagrede/importerte enhetsnavn normaliseres")
    require(text, "uniqueDeviceIds(x)&&uniqueDeviceNames(x)&&", "backupvalidering krever unike enhets-ID-er og normaliserte navn")
    require(text, "function validStoredState(x)", "streng validering av lagret hovedtilstand")
    require(text, "if(!validStoredState(parsed))throw Error()", "loadState bruker streng validering")
    require(text, "validBackupState(x.state)", "import bruker samme referansevalidering")

    # Device registry contract: creation remains deterministic and ambiguity-safe.
    require(text, "function isValidIPv4(v)", "IPv4-validator finnes")
    require(text, "function normalizeName(v)", "navnenormalisering finnes")
    require(text, "function createUniqueDeviceId()", "unik enhets-ID-generator finnes")
    require(text, "while(state.devices.some(d=>d.id===id))", "genererte enhets-ID-er kollisjonssjekkes")
    require(text, "normalizeName(d.name)===normalizeName(name)", "duplikate enhetsnavn avvises normalisert")
    require(text, "const duplicateIp=ip&&state.devices.find(d=>d.ip===ip)", "duplikate IPv4-adresser oppdages")
    require(text, "Ugyldig IPv4-adresse.", "ugyldig IPv4 gir synlig feil")
    require(text, "bruker allerede dette navnet.", "duplikatnavn gir synlig feil")
    require(text, "er allerede registrert på", "duplikat-IP gir synlig feil")
    require(text, "ip:ip||'Ikke satt'", "tom IP lagres eksplisitt som Ikke satt")

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

    print("PASS: RAH Home Control v1.24 Stable contract")


if __name__ == "__main__":
    main()
