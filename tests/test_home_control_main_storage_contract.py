from __future__ import annotations

"""Static regression contract for RAH Home Control v1.25 main local-storage feedback."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HOME = ROOT / "RAH-HOME-CONTROL.html"


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise AssertionError(f"Mangler kontrakt: {label}: {needle!r}")


def main() -> None:
    text = HOME.read_text(encoding="utf-8")

    require(text, "KEY='rah-home-control-v03'", "egen nøkkel for hovedtilstand")
    require(text, "function save(){try{localStorage.setItem(KEY,JSON.stringify(state))", "save skriver hovedtilstanden lokalt")

    save_block = text.split("function save(){", 1)[1].split("function saveFilters()", 1)[0]
    require(save_block, "storageStatus.textContent='Lokal lagring klar · endringer lagret'", "vellykket lagring setter korrekt status")
    require(save_block, "hideError();return true", "vellykket lagring returnerer true")
    require(save_block, "catch{storageStatus.textContent='Lagringsfeil · siste endring er ikke lagret'", "lagringsfeil setter eksplisitt feilstatus")
    require(save_block, "showError('Endringen kunne ikke lagres lokalt.');return false", "lagringsfeil varsles og returnerer false")

    # Feilbanen må ikke kunne rapportere vellykket lagring.
    catch_block = save_block.split("catch{", 1)[1]
    if "Lokal lagring klar · endringer lagret" in catch_block or "return true" in catch_block:
        raise AssertionError("Lagringsfeil må aldri rapporteres som vellykket hovedlagring")

    # Hovedlagring og filterlagring skal fortsatt være isolert.
    if "FILTER_KEY" in save_block:
        raise AssertionError("save() skal bare skrive hovedtilstanden, ikke filterlagringen")

    print("PASS: RAH Home Control main storage failure feedback contract")


if __name__ == "__main__":
    main()
