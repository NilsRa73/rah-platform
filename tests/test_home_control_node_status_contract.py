from __future__ import annotations

"""Static regression contract for local node status in RAH Home Control v1.25."""
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

    require(text, "<h2>🧠 RAH Cluster-noder</h2>", "eksisterende lokal node-seksjon")
    require(text, "name:'RAH Hoved-PC',role:'Leder',connection:'Lokal',ready:true", "lokal standardnode er klar")
    require(text, "name:'HP Omen',role:'Arbeidsnode',connection:'Ethernet senere',ready:false", "lokal standardnode venter")
    require(text, "function renderNodes()", "lokal node-status-renderer")
    require(text, "${n.ready?'KLAR':'VENTER'}", "eksplisitt lokal node-status")
    require(text, "${n.ready?'Ventemodus':'Marker klar'}", "lokal node-statuskontroll")
    require(text, "nodeCount.textContent=`${state.nodes.filter(n=>n.ready).length} klare`", "lokal klar-teller")
    require(text, "document.querySelectorAll('[data-node]')", "lokal nodeknapp-binding")
    require(text, "const previousReady=n.ready;n.ready=!n.ready", "statusendring tar rollback-kopi")
    require(text, "if(!save()){n.ready=previousReady", "statusendring rulles tilbake ved lagringsfeil")
    require(text, "Node-statusen ble rullet tilbake fordi lokal lagring feilet.", "tydelig rollback-feedback")
    require(text, "Node-status for «${n.name}» er lagret lokalt.", "tydelig lokal suksess-feedback")
    require(text, "localStorage.setItem(KEY,JSON.stringify(state))", "node-status bruker lokal hovedlagring")

    for token, label in (
        ("RTCPeerConnection", "WebRTC discovery"),
        ("navigator.bluetooth", "Bluetooth discovery"),
        ("navigator.usb", "USB discovery"),
        ("WebSocket(", "network socket discovery"),
        ("new EventSource(", "network event stream"),
    ):
        forbid(text, token, label)

    print("PASS: RAH Home Control local node status feedback and rollback contract")


if __name__ == "__main__":
    main()
