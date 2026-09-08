from __future__ import annotations

"""Regression contract for rollback-safe RAH Home Control backup restore.

Static by design: this locks the current local-only restore transaction without
browser automation or expanding runtime scope.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HOME = ROOT / "RAH-HOME-CONTROL.html"


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise AssertionError(f"Mangler backup-restore-kontrakt: {label}: {needle!r}")


def main() -> None:
    text = HOME.read_text(encoding="utf-8")

    require(text, "if(file.size>1000000)", "1 MB størrelsesgrense før parsing")
    require(text, "payload=JSON.parse(await file.text())", "lokal JSON-parsing")
    require(text, "if(!validConfigBackup(payload))", "schema- og tilstandsvalidering før mutasjon")
    require(
        text,
        "const candidate=clone(payload.state),previousState=clone(state),previousEditingDeviceId=editingDeviceId",
        "rollback-kopi av tilstand og aktiv redigering",
    )
    require(
        text,
        "Gjenopprett Home Control-backup? Dette erstatter dagens lokale Home Control-konfigurasjon",
        "eksplisitt bekreftelse før gjenoppretting",
    )
    require(
        text,
        "Gjenoppretting avbrutt. Ingen data ble endret.",
        "avbrutt import bekrefter at ingen data ble endret",
    )
    require(text, "state=candidate;editingDeviceId=null;if(!save())", "kandidat lagres først etter validering og bekreftelse")
    require(
        text,
        "state=previousState;editingDeviceId=previousEditingDeviceId",
        "in-memory rollback ved lokal lagringsfeil",
    )
    require(
        text,
        "Gjenoppretting ble rullet tilbake fordi lokal lagring feilet. Den forrige konfigurasjonen er beholdt.",
        "tydelig rollback-melding",
    )
    require(
        text,
        "Home Control-konfigurasjonen er gjenopprettet og lagret lokalt.",
        "tydelig suksessmelding",
    )

    forbidden = ["RTCPeerConnection", "navigator.bluetooth", "navigator.usb", "new WebSocket", "new EventSource"]
    for needle in forbidden:
        if needle in text:
            raise AssertionError(f"Backup-restore-testen oppdaget senere nettverksfunksjon i Stable runtime: {needle}")

    print("PASS: RAH Home Control backup restore rollback contract")


if __name__ == "__main__":
    main()
