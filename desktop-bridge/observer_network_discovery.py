from __future__ import annotations

"""Bounded SSDP discovery for RAH Observer Wall.

Sends standard multicast M-SEARCH requests only to the SSDP multicast address
and returns devices that voluntarily advertise themselves. No port sweep or
arbitrary target probing is performed.
"""

import re
import socket
import time
from typing import Any

SSDP_ADDR = ("239.255.255.250", 1900)
SEARCH_TARGETS = (
    "ssdp:all",
    "urn:schemas-upnp-org:device:MediaRenderer:1",
    "urn:dial-multiscreen-org:service:dial:1",
)


def _headers(text: str) -> dict[str, str]:
    out: dict[str, str] = {}
    for line in text.replace("\r\n", "\n").split("\n")[1:]:
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        out[key.strip().lower()] = value.strip()
    return out


def _name(headers: dict[str, str], ip: str) -> str:
    server = headers.get("server", "")
    usn = headers.get("usn", "")
    st = headers.get("st", "")
    raw = server or usn or st or ip
    raw = re.sub(r"\s+", " ", raw).strip()
    return raw[:120]


def discover_ssdp(timeout: float = 1.15) -> list[dict[str, Any]]:
    devices: dict[str, dict[str, Any]] = {}
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
    try:
        sock.settimeout(0.16)
        sock.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_TTL, 2)
        for target in SEARCH_TARGETS:
            payload = (
                "M-SEARCH * HTTP/1.1\r\n"
                "HOST: 239.255.255.250:1900\r\n"
                'MAN: "ssdp:discover"\r\n'
                "MX: 1\r\n"
                f"ST: {target}\r\n\r\n"
            ).encode("ascii")
            sock.sendto(payload, SSDP_ADDR)

        deadline = time.monotonic() + max(0.25, min(timeout, 2.0))
        while time.monotonic() < deadline:
            try:
                data, addr = sock.recvfrom(8192)
            except socket.timeout:
                continue
            except OSError:
                break
            ip = addr[0]
            text = data.decode("utf-8", errors="replace")
            headers = _headers(text)
            usn = headers.get("usn", "")
            location = headers.get("location", "")
            st = headers.get("st", "")
            key = usn or location or f"{ip}:{st}"
            if key in devices:
                continue
            joined = " ".join((headers.get("server", ""), st, usn)).lower()
            kind = "tv" if any(t in joined for t in ("media", "renderer", "dial", "tv", "roku", "google", "android", "chromecast")) else "device"
            devices[key] = {
                "id": f"ssdp:{key}"[:220],
                "name": _name(headers, ip),
                "kind": kind,
                "source": "ssdp",
                "detail": (st or headers.get("server", "SSDP/UPnP"))[:260],
                "status": "online",
                "address": ip,
                "location": location[:300],
                "actions": ["OPEN_PROJECTING", "OPEN_CONNECTED_DEVICES", "OPEN_NETWORK"],
            }
    finally:
        sock.close()
    return list(devices.values())
