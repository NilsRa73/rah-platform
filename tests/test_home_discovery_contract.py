from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "RAH-HOME-DISCOVERY.ps1"


def require(text: str, pattern: str, label: str) -> None:
    if not re.search(pattern, text, flags=re.IGNORECASE | re.MULTILINE):
        raise AssertionError(f"Mangler discovery-kontrakt: {label}: {pattern!r}")


def forbid(text: str, pattern: str, label: str) -> None:
    if re.search(pattern, text, flags=re.IGNORECASE | re.MULTILINE):
        raise AssertionError(
            f"Aktiv nettverksmekanisme er ikke tillatt i passiv foundation: {label}: {pattern!r}"
        )


def main() -> None:
    text = SCRIPT.read_text(encoding="utf-8")

    require(text, r"Get-NetNeighbor\s+-AddressFamily\s+IPv4", "leser Windows IPv4 neighbor-cache")
    require(text, r"Get-NetAdapter\b", "registrerer lokale adaptermetadata")
    require(text, r"Get-NetIPAddress\s+-AddressFamily\s+IPv4", "kan filtrere ut lokal maskins egne IPv4-adresser")

    # Stable JSON contract. Formatting/spacing is deliberately irrelevant.
    require(text, r"schema\s*=\s*['\"]rah-home-discovery-cache['\"]", "stabilt JSON-schema")
    require(text, r"version\s*=\s*1\b", "schema-versjon")
    require(text, r"scriptVersion\s*=\s*\$script:RahDiscoveryVersion", "script-versjon i output")
    require(text, r"mode\s*=\s*['\"]passive-neighbor-cache['\"]", "eksplisitt passiv modus")
    require(text, r"passive\s*=\s*\$true", "dokumentet merkes passivt")
    require(text, r"scope\s*=\s*['\"]rfc1918-active-adapters-only['\"]", "lokal RFC1918-scope")
    require(text, r"source\s*=\s*['\"]windows-neighbor-cache['\"]", "hver kandidat har kilde")

    for field, label in (
        (r"\bipAddress\b", "kandidat inneholder IPv4"),
        (r"\bmacAddress\b", "kandidat inneholder MAC når Windows kjenner den"),
        (r"\bifIndex\b", "kandidat knyttes til lokalt interface"),
        (r"\bstate\b", "neighbor-state bevares"),
    ):
        require(text, field, label)

    require(text, r"ConvertTo-Json\s+-Depth\s+[6-9]", "maskinlesbart JSON-resultat")
    require(text, r"does not ping, probe, resolve names, scan ports, or contact discovered devices", "begrensning dokumenteres i output")
    require(text, r"function\s+Invoke-RahDiscoverySelfTest\b", "innebygd self-test finnes")

    # Passive discovery must never add active probing primitives.
    for pattern, label in (
        (r"\bTest-Connection\b", "PowerShell ping"),
        (r"\bping\.exe\b", "ping executable"),
        (r"\bInvoke-WebRequest\b", "HTTP probing"),
        (r"\bInvoke-RestMethod\b", "HTTP/API probing"),
        (r"\bTest-NetConnection\b", "port/network probe"),
        (r"System\.Net\.Sockets\.TcpClient", "TCP port probe"),
        (r"\bnmap\b", "aktiv nettverksskanner"),
    ):
        forbid(text, pattern, label)

    print("PASS: RAH Home Discovery v1 passive foundation contract")


if __name__ == "__main__":
    main()
