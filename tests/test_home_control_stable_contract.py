from __future__ import annotations

"""Static regression gate for RAH Home Control v1.25 Stable.

Uses only the Python standard library. The test intentionally checks a small,
explicit contract instead of executing the browser UI.
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
    require(text, "stabil lokal kontroll v1.25", "v1.25 Stable-versjon")
    for room in ("Datarom", "Stue 1", "Stue 2", "Soverom"):
        require(text, f"name:'{room}'", f"rommodell {room}")
        require(text, f"'{room}'", f"lagret rommodell {room}")

    require(text, "function knownRoomReference(x,roomName)", "felles romreferanse-validering")
    require(text, "knownRoomReference(x,d.room)", "enhetsrom bruker felles romvalidering")
    require(text, "knownRoomReference(x,s.room)", "skjermrom bruker felles romvalidering")
    require(text, "function uniqueRoomNames(x)", "unik romnavn-validering")
    require(text, "function uniqueRoomIds(x)", "unik rom-ID-validering")
    require(text, "function uniqueDeviceIds(x)", "unik enhets-ID-validering")
    require(text, "function uniqueDeviceNames(x)", "unik normalisert enhetsnavn-validering")
    require(text, "normalizeName(d.name)", "lagrede/importerte enhetsnavn normaliseres")
    require(text, "function validDeviceIPv4s(x)", "felles IPv4-validering")
    require(text, ".filter(ip=>ip!=='Ikke satt')", "Ikke satt kan gjentas")
    require(text, "ips.every(ip=>typeof ip==='string'&&isValidIPv4(ip))", "satte IPv4 må være gyldige")
    require(text, "new Set(ips).size===ips.length", "satte IPv4 må være unike")
    require(text, "uniqueDeviceNames(x)&&validDeviceIPv4s(x)&&", "backupvalidering krever enhetskontrakt")
    require(text, "if(!validStoredState(parsed))throw Error()", "lagret tilstand valideres")
    require(text, "validBackupState(x.state)", "import bruker samme validering")

    require(text, "function isValidIPv4(v)", "IPv4-validator")
    require(text, "function normalizeName(v)", "navnenormalisering")
    require(text, "function createUniqueDeviceId()", "unik enhets-ID-generator")
    require(text, "while(state.devices.some(d=>d.id===id))", "ID-kollisjonssjekk")
    require(text, "normalizeName(d.name)===normalizeName(name)", "duplikatnavn avvises")
    require(text, "const duplicateIp=ip&&state.devices.find(d=>d.ip===ip)", "duplikat-IP avvises")
    require(text, "ip:ip||'Ikke satt'", "tom IP normaliseres")

    # Statusvisning: én enkel lokal oversikt, uten discovery/polling.
    require(text, "state.devices.filter(d=>d.online).length", "antall synlige enheter")
    require(text, "state.devices.filter(d=>!d.online).length", "antall lagrede/frakoblede enheter")
    require(text, "totalt", "status viser totalantall")
    require(text, "synlige", "status viser synlige")
    require(text, "lagrede/frakoblede", "status viser lagrede/frakoblede")

    # Enhetsstatus er en eksplisitt lokal markering, ikke fysisk device-control.
    require(text, "d.online?'Marker frakoblet':'Marker synlig'", "tydelig lokal statusknapp")
    require(text, "const previousOnline=d.online;d.online=!d.online", "statusendring tar rollback-kopi")
    require(text, "if(!save()){d.online=previousOnline", "statusendring rulles tilbake ved lagringsfeil")
    require(text, "Statusendringen ble rullet tilbake fordi lokal lagring feilet.", "status rollback-melding")
    require(text, "er nå markert ${d.online?'synlig':'frakoblet'} og lagret lokalt", "statusbekreftelse sier ny lokal status")

    # Kontrollknapp: lokal Aktiver / Slå av skal bare endre romstatus og være rollback-sikret.
    require(text, "${r.active?'Slå av':'Aktiver'}", "romknapp viser eksplisitt lokal handling")
    require(text, "document.querySelectorAll('[data-room]')", "romstatus-klikkbinding")
    require(text, "const previousActive=r.active;r.active=!r.active", "romstatus tar rollback-kopi og toggler lokalt")
    require(text, "if(!save()){r.active=previousActive", "romstatus rulles tilbake ved lagringsfeil")
    require(text, "Romstatusen ble rullet tilbake fordi lokal lagring feilet.", "romstatus rollback-melding")
    require(text, "er nå ${r.active?'aktivt':'av'} og lagret lokalt", "romstatusbekreftelse sier eksplisitt aktivt eller av")

    # Kontrollknapp: Hovedrom skal være en eksklusiv, lokal og rollback-sikret handling.
    require(text, 'data-main="${r.id}"', "Hovedrom-knapp per rom")
    require(text, "document.querySelectorAll('[data-main]')", "Hovedrom-klikkbinding")
    require(text, "const previousRooms=clone(state.rooms)", "Hovedrom tar rollback-kopi")
    require(text, "state.rooms.forEach(r=>r.active=r.id===b.dataset.main)", "Hovedrom gjør valgt rom eksklusivt aktivt")
    require(text, "state.rooms=previousRooms", "Hovedrom rulles tilbake ved lagringsfeil")
    require(text, "er nå eneste aktive hovedrom og lagret lokalt", "Hovedrom bekrefter eksklusiv lokal sluttstatus")

    require(text, "const KEY='rah-home-control-v03'", "hovedlagringsnøkkel")
    require(text, "FILTER_KEY='rah-home-control-filters-v01'", "filterlagringsnøkkel")
    require(text, "localStorage.setItem(KEY,JSON.stringify(state))", "lokal hovedlagring")
    require(text, "localStorage.setItem(FILTER_KEY", "lokal filterlagring")

    # Enkel feilhåndtering: korrupt eller ugyldig hovedtilstand skal aldri rendres.
    require(text, "const parsed=JSON.parse(raw);if(!validStoredState(parsed))throw Error()", "JSON parses og valideres før bruk")
    require(text, "storageStatus.textContent='Lagringsfeil · standarddata brukes midlertidig'", "fallback-status ved korrupt lagring")
    require(text, "Lagrede Home Control-data kunne ikke leses eller valideres. Standarddata er lastet.", "tydelig fallback-feilmelding")
    require(text, "return clone(defaults)", "fallback bruker frisk kopi av standarddata")

    # Filterlagring er isolert fra hovedtilstanden og har sin egen defensive fallback.
    require(text, "function loadFilters()", "egen filter-loader")
    require(text, "localStorage.getItem(FILTER_KEY)", "filter-loader leser bare filter-nøkkelen")
    require(text, "STATUS_FILTERS.includes(parsed&&parsed.status)", "lagret statusfilter valideres")
    require(text, "ROOM_FILTERS.includes(parsed&&parsed.room)", "lagret romfilter valideres")
    require(text, "status:statusValid?parsed.status:'all'", "ugyldig statusfilter faller tilbake til Alle")
    require(text, "room:roomValid?parsed.room:'all'", "ugyldig romfilter faller tilbake til Alle rom")
    require(text, "Ugyldige valg bruker standardverdi; gyldige valg beholdes.", "delvis gyldige filtre beholdes")
    require(text, "Lagrede filtervalg kunne ikke leses. Standardfiltrene Alle / Alle rom brukes midlertidig.", "korrupt filter-JSON gir tydelig fallback")
    require(text, "return{status:'all',room:'all'}", "korrupt filterlagring bruker standardfiltre")
    require(text, "let state=loadState(),editingDeviceId=null,filters=loadFilters()", "hovedtilstand og filtertilstand lastes separat")

    # Filterendringer skal også være transaksjonelle: lagringsfeil må beholde tidligere filter og redigering.
    require(text, "const previousStatusFilter=statusFilter,previousEditingDeviceId=editingDeviceId", "statusfilter tar rollback-kopi")
    require(text, "if(!saveFilters()){statusFilter=previousStatusFilter;editingDeviceId=previousEditingDeviceId", "statusfilter rulles tilbake")
    require(text, "Statusfilteret ble rullet tilbake fordi lokal lagring feilet. Tidligere filter og redigering er beholdt.", "statusfilter rollback-melding")
    require(text, "const previousRoomFilter=roomFilter,previousEditingDeviceId=editingDeviceId", "romfilter tar rollback-kopi")
    require(text, "if(!saveFilters()){roomFilter=previousRoomFilter;editingDeviceId=previousEditingDeviceId", "romfilter rulles tilbake")
    require(text, "Romfilteret ble rullet tilbake fordi lokal lagring feilet. Tidligere filter og redigering er beholdt.", "romfilter rollback-melding")
    require(text, "const previousStatusFilter=statusFilter,previousRoomFilter=roomFilter,previousEditingDeviceId=editingDeviceId", "filter-nullstilling tar full rollback-kopi")
    require(text, "statusFilter=previousStatusFilter;roomFilter=previousRoomFilter;editingDeviceId=previousEditingDeviceId", "filter-nullstilling rulles tilbake")
    require(text, "Filter-nullstillingen ble rullet tilbake fordi lokal lagring feilet. Tidligere filtre er beholdt.", "filter-nullstilling rollback-melding")

    for message, label in (
        ("Romstatusen ble rullet tilbake fordi lokal lagring feilet.", "romstatus rollback"),
        ("Valg av hovedrom ble rullet tilbake fordi lokal lagring feilet.", "hovedrom rollback"),
        ("Enheten ble ikke lagt til fordi lokal lagring feilet.", "legg til enhet rollback"),
        ("Fjerningen ble rullet tilbake fordi lokal lagring feilet.", "fjern enhet rollback"),
    ):
        require(text, message, label)

    for token, label in (
        ("RTCPeerConnection", "WebRTC discovery"),
        ("navigator.bluetooth", "Bluetooth discovery"),
        ("navigator.usb", "USB discovery"),
        ("WebSocket(", "network socket discovery"),
        ("new EventSource(", "network event stream"),
    ):
        forbid(text, token, label)

    print("PASS: RAH Home Control v1.25 Stable contract")

if __name__ == "__main__":
    main()
