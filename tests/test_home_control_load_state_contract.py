from __future__ import annotations

"""Static regression contract for RAH Home Control v1.25 loadState fallback behavior."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HOME = ROOT / "RAH-HOME-CONTROL.html"


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise AssertionError(f"Mangler kontrakt: {label}: {needle!r}")


def main() -> None:
    text = HOME.read_text(encoding="utf-8")
    block = text.split("function loadState(){", 1)[1].split("function loadFilters()", 1)[0]

    require(block, "const raw=localStorage.getItem(KEY)", "leser hovedtilstanden fra korrekt nøkkel")
    require(block, "if(!raw){storageStatus.textContent='Lokal lagring klar · standarddata lastet';return clone(defaults)}", "manglende lagring bruker standarddata uten feil")
    require(block, "const parsed=JSON.parse(raw)", "lagret JSON parses før bruk")
    require(block, "if(!validStoredState(parsed))throw Error()", "ugyldig lagret tilstand avvises")
    require(block, "storageStatus.textContent='Lokal lagring klar · lagrede data lastet';return parsed", "gyldig lagret tilstand brukes")
    require(block, "catch{storageStatus.textContent='Lagringsfeil · standarddata brukes midlertidig'", "korrupt eller ugyldig tilstand gir eksplisitt feilstatus")
    require(block, "showError('Lagrede Home Control-data kunne ikke leses eller valideres. Standarddata er lastet.')", "fallback forklares tydelig")
    require(block, "return clone(defaults)", "feil bruker trygg klonet standardtilstand")

    # loadState er en lesefunksjon: korrupt lagring skal ikke overskrives automatisk.
    forbidden = ("localStorage.setItem", "localStorage.removeItem", "localStorage.clear")
    for token in forbidden:
        if token in block:
            raise AssertionError(f"loadState() må ikke mutere lagringen automatisk: {token}")

    print("PASS: RAH Home Control loadState fallback contract")


if __name__ == "__main__":
    main()
