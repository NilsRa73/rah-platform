from __future__ import annotations

"""Static regression contract for local device-filter persistence in RAH Home Control v1.25."""
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

    require(text, "FILTER_KEY='rah-home-control-filters-v01'", "egen lokal lagringsnøkkel for filtre")
    require(text, "const STATUS_FILTERS=['all','online','offline']", "tillatte statusfiltre")
    require(text, "ROOM_FILTERS=['all',...ROOM_OPTIONS]", "tillatte romfiltre")
    require(text, "function loadFilters()", "kontrollert lasting av filtervalg")
    require(text, "STATUS_FILTERS.includes(parsed&&parsed.status)", "lagret statusfilter valideres")
    require(text, "ROOM_FILTERS.includes(parsed&&parsed.room)", "lagret romfilter valideres")
    require(text, "status:statusValid?parsed.status:'all'", "ugyldig statusfilter faller tilbake til all")
    require(text, "room:roomValid?parsed.room:'all'", "ugyldig romfilter faller tilbake til all")
    require(text, "Lagrede filtervalg kunne ikke leses. Standardfiltrene Alle / Alle rom brukes midlertidig.", "parse-/lesefeil gir kontrollert fallback")
    require(text, "localStorage.setItem(FILTER_KEY", "filtre lagres separat fra enhetsdata")

    status_handler = text.split("document.querySelectorAll('[data-status-filter]').forEach(b=>b.onclick=()=>", 1)[1].split("document.querySelectorAll('[data-room-filter]').forEach", 1)[0]
    require(status_handler, "const previousStatusFilter=statusFilter,previousEditingDeviceId=editingDeviceId", "statusfilter tar rollback-kopi")
    require(status_handler, "if(!saveFilters())", "statusfilter kontrollerer lagringsresultat")
    require(status_handler, "statusFilter=previousStatusFilter;editingDeviceId=previousEditingDeviceId", "statusfilter rulles tilbake")
    require(status_handler, "Statusfilteret ble rullet tilbake fordi lokal lagring feilet.", "statusfilter gir tydelig feilfeedback")

    room_handler = text.split("document.querySelectorAll('[data-room-filter]').forEach(b=>b.onclick=()=>", 1)[1].split("resetFilters.onclick", 1)[0]
    require(room_handler, "const previousRoomFilter=roomFilter,previousEditingDeviceId=editingDeviceId", "romfilter tar rollback-kopi")
    require(room_handler, "if(!saveFilters())", "romfilter kontrollerer lagringsresultat")
    require(room_handler, "roomFilter=previousRoomFilter;editingDeviceId=previousEditingDeviceId", "romfilter rulles tilbake")
    require(room_handler, "Romfilteret ble rullet tilbake fordi lokal lagring feilet.", "romfilter gir tydelig feilfeedback")

    reset_handler = text.split("resetFilters.onclick=()=>", 1)[1].split("addDevice.onclick", 1)[0]
    require(reset_handler, "previousStatusFilter=statusFilter,previousRoomFilter=roomFilter", "filter-nullstilling tar rollback-kopi")
    require(reset_handler, "statusFilter='all';roomFilter='all'", "filter-nullstilling bruker standardfiltre")
    require(reset_handler, "if(saveFilters())showActionNotice('Filtrene er nullstilt til Alle og Alle rom. Ingen enhetsdata ble endret.')", "nullstilling bekrefter at enhetsdata ikke endres")
    require(reset_handler, "statusFilter=previousStatusFilter;roomFilter=previousRoomFilter", "filter-nullstilling rulles tilbake")

    # Filterhandlingene skal ikke lagre/mutere hovedtilstanden.
    for handler, label in ((status_handler, "statusfilter"), (room_handler, "romfilter"), (reset_handler, "filter-nullstilling")):
        if "save()" in handler:
            raise AssertionError(f"{label} skal ikke skrive Home Control-hovedtilstanden")
        if "state.devices=" in handler or "state.devices." in handler:
            raise AssertionError(f"{label} skal ikke mutere enhetsregisteret")

    for token, label in (
        ("RTCPeerConnection", "WebRTC discovery"),
        ("navigator.bluetooth", "Bluetooth discovery"),
        ("navigator.usb", "USB discovery"),
        ("WebSocket(", "network socket discovery"),
    ):
        forbid(text, token, label)

    print("PASS: RAH Home Control local filter storage rollback contract")


if __name__ == "__main__":
    main()
