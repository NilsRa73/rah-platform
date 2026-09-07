from __future__ import annotations

"""Regression contract for rollback-safe reset of RAH Home Control defaults.

Static by design: this locks the current local-only reset transaction without
adding browser automation or expanding runtime scope.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HOME = ROOT / "RAH-HOME-CONTROL.html"


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise AssertionError(f"Mangler reset-kontrakt: {label}: {needle!r}")


def main() -> None:
    text = HOME.read_text(encoding="utf-8")

    require(
        text,
        "Gjenopprett standarddata? Registrerte Home Control-data og lagrede filtervalg nullstilles.",
        "eksplisitt bekreftelse før reset",
    )
    require(
        text,
        "const previousState=clone(state),previousEditingDeviceId=editingDeviceId,previousStatusFilter=statusFilter,previousRoomFilter=roomFilter",
        "full rollback-kopi av tilstand, redigering og filtre",
    )
    require(text, "state=clone(defaults)", "reset bruker frisk kopi av standarddata")
    require(text, "editingDeviceId=null;statusFilter='all';roomFilter='all'", "reset nullstiller lokal visningskontekst")
    require(text, "const stateSaved=save(),filtersSaved=saveFilters()", "hovedtilstand og filtre lagres separat")
    require(text, "if(stateSaved&&filtersSaved)", "suksess krever at begge lokale lagringer lykkes")
    require(
        text,
        "Standarddata og standardfiltre er gjenopprettet og lagret lokalt.",
        "tydelig suksessmelding",
    )
    require(
        text,
        "state=previousState;editingDeviceId=previousEditingDeviceId;statusFilter=previousStatusFilter;roomFilter=previousRoomFilter",
        "full in-memory rollback ved delvis eller full lagringsfeil",
    )
    require(
        text,
        "localStorage.setItem(KEY,JSON.stringify(state));localStorage.setItem(FILTER_KEY,JSON.stringify({status:statusFilter,room:roomFilter}))",
        "rollback forsøker å gjenopprette begge lokale lagringsnøkler",
    )
    require(
        text,
        "Gjenoppretting av standarddata ble rullet tilbake fordi lokal lagring feilet. Tidligere Home Control-data og filtre er beholdt.",
        "tydelig rollback-melding",
    )

    print("PASS: RAH Home Control reset defaults rollback contract")


if __name__ == "__main__":
    main()
