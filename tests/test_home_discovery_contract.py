from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "RAH-HOME-DISCOVERY.ps1"


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise AssertionError(f"Mangler discovery-kontrakt: {label}: {needle!r}")


def forbid(text: str, needle: str, label: str) -> None:
    if needle.lower() in text.lower():
        raise AssertionError(f"Aktiv nettverksmekanisme er ikke tillatt i passiv foundation: {label}: {needle!r}")


def main() -> None:
    text = SCRIPT.read_text(encoding="utf-8")

    require(text, "Get-NetNeighbor -AddressFamily IPv4", "leser Windows IPv4 neighbor-cache")
    require(text, "Get-NetAdapter", "registrerer lokale adaptermetadata")
    require(text, "schema      = 'rah-home-discovery-cache'", "stabilt JSON-schema")
    require(text, "version     = 1", "schema-versjon")
    require(text, "mode        = 'passive-neighbor-cache'", "eksplisitt passiv modus")
    require(text, "passive     = $true", "dokumentet merkes passivt")
    require(text, "source           = 'windows-neighbor-cache'", "hver kandidat har kilde")
    require(text, "ipAddress", "kandidat inneholder IPv4")
    require(text, "macAddress", "kandidat inneholder MAC når Windows kjenner den")
    require(text, "ifIndex", "kandidat knyttes til lokalt interface")
    require(text, "state", "neighbor-state bevares")
    require(text, "ConvertTo-Json -Depth 6", "maskinlesbart JSON-resultat")
    require(text, "Passive foundation only", "begrensning dokumenteres i output")

    for token, label in (
        ("Test-Connection", "PowerShell ping"),
        ("ping.exe", "ping executable"),
        ("Invoke-WebRequest", "HTTP probing"),
        ("Invoke-RestMethod", "HTTP/API probing"),
        ("Test-NetConnection", "port/network probe"),
        ("System.Net.Sockets.TcpClient", "TCP port probe"),
        ("nmap", "aktiv nettverksskanner"),
    ):
        forbid(text, token, label)

    print("PASS: RAH Home Discovery passive foundation contract")


if __name__ == "__main__":
    main()
