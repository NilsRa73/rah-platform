from __future__ import annotations

"""RAH Observer Device Fabric v1.1.

Combines multiple passive discovery records into one visual device node and
keeps a small local presence cache so recently-seen devices do not disappear
from The Wall immediately.
"""

import ipaddress
import json
import os
import re
import time
from pathlib import Path
from typing import Any

FABRIC_VERSION = "1.1.0"
OFFLINE_AFTER_SECONDS = 18.0
FORGET_AFTER_SECONDS = 60.0 * 60.0 * 24.0 * 14.0
STATE_PATH = Path(os.environ.get("RAH_OBSERVER_STATE", r"C:\RAH\State\ObserverWall\presence.json"))

SOURCE_PRIORITY = {
    "local": 100,
    "adb": 90,
    "ssdp": 80,
    "bluetooth": 70,
    "audio": 60,
    "lan": 50,
}

GENERIC_WORDS = {
    "bluetooth", "device", "audio", "endpoint", "speaker", "headphones",
    "headset", "stereo", "handsfree", "hands", "free", "avrcp", "service",
}


def _clean(value: Any, limit: int = 300) -> str:
    return str(value or "").replace("\r", " ").replace("\n", " ").strip()[:limit]


def _ip(value: str) -> str:
    raw = _clean(value, 100)
    if not raw:
        return ""
    candidate = raw.split(":", 1)[0] if raw.count(":") == 1 and "." in raw else raw
    try:
        return str(ipaddress.ip_address(candidate))
    except ValueError:
        return ""


def _name_key(value: str) -> str:
    text = _clean(value, 180).lower()
    text = re.sub(r"\([^)]*\)", " ", text)
    tokens = [t for t in re.findall(r"[a-z0-9]+", text) if t not in GENERIC_WORDS]
    return "".join(tokens)


def _useful_name_key(item: dict[str, Any]) -> str:
    key = _name_key(str(item.get("name") or ""))
    if len(key) < 4 or _ip(str(item.get("name") or "")):
        return ""
    return key


def _compatible(a: dict[str, Any], b: dict[str, Any]) -> bool:
    ka = str(a.get("kind") or "device")
    kb = str(b.get("kind") or "device")
    if ka == kb:
        return True
    pair = {ka, kb}
    return bool(pair <= {"audio", "bluetooth", "device"} or pair <= {"android", "tv", "device"} or pair <= {"pc", "bluetooth", "device"})


def _same_device(a: dict[str, Any], b: dict[str, Any]) -> bool:
    if str(a.get("id")) == str(b.get("id")):
        return True

    ipa = _ip(str(a.get("address") or ""))
    ipb = _ip(str(b.get("address") or ""))
    if ipa and ipb and ipa == ipb:
        return True

    na = _useful_name_key(a)
    nb = _useful_name_key(b)
    if na and nb and _compatible(a, b):
        if na == nb:
            return True
        if min(len(na), len(nb)) >= 5 and (na in nb or nb in na):
            return True
    return False


def _primary(records: list[dict[str, Any]]) -> dict[str, Any]:
    return max(records, key=lambda r: (SOURCE_PRIORITY.get(str(r.get("source")), 0), len(_clean(r.get("name")))))


def _merge_cluster(records: list[dict[str, Any]]) -> dict[str, Any]:
    primary = dict(_primary(records))
    sources = list(dict.fromkeys(str(r.get("source") or "device") for r in records))
    actions: list[str] = []
    addresses: list[str] = []
    details: list[str] = []
    raw_ids: list[str] = []
    statuses: list[str] = []
    for record in records:
        raw_ids.append(_clean(record.get("id"), 240))
        address = _clean(record.get("address"), 120)
        detail = _clean(record.get("detail"), 260)
        status = _clean(record.get("status"), 80)
        if address and address not in addresses:
            addresses.append(address)
        if detail and detail not in details:
            details.append(detail)
        if status and status not in statuses:
            statuses.append(status)
        for action in record.get("actions") or []:
            action = _clean(action, 80)
            if action and action not in actions:
                actions.append(action)

    stable = next((f"ip:{_ip(a)}" for a in addresses if _ip(a)), "")
    if not stable:
        name_key = _useful_name_key(primary)
        stable = f"name:{name_key}" if name_key else f"id:{raw_ids[0]}"

    primary.update({
        "id": stable,
        "fabric_id": stable,
        "sources": sources,
        "transports": sources,
        "actions": actions,
        "addresses": addresses,
        "address": addresses[0] if addresses else _clean(primary.get("address"), 120),
        "detail": " · ".join(details[:3]) or _clean(primary.get("detail"), 260),
        "raw_ids": raw_ids,
        "status": statuses[0] if statuses else "seen",
        "presence": "online",
        "records": len(records),
    })
    return primary


def merge_devices(devices: list[dict[str, Any]]) -> list[dict[str, Any]]:
    clusters: list[list[dict[str, Any]]] = []
    for raw in devices:
        if not isinstance(raw, dict):
            continue
        item = dict(raw)
        matched = None
        for cluster in clusters:
            if any(_same_device(item, other) for other in cluster):
                matched = cluster
                break
        if matched is None:
            clusters.append([item])
        else:
            matched.append(item)
    return [_merge_cluster(cluster) for cluster in clusters]


def _read_state() -> dict[str, dict[str, Any]]:
    try:
        data = json.loads(STATE_PATH.read_text(encoding="utf-8"))
        return data if isinstance(data, dict) else {}
    except (OSError, json.JSONDecodeError):
        return {}


def _write_state(state: dict[str, dict[str, Any]]) -> None:
    try:
        STATE_PATH.parent.mkdir(parents=True, exist_ok=True)
        temp = STATE_PATH.with_suffix(".tmp")
        temp.write_text(json.dumps(state, ensure_ascii=False, indent=2), encoding="utf-8")
        temp.replace(STATE_PATH)
    except OSError:
        pass


def apply_presence(devices: list[dict[str, Any]], *, now: float | None = None) -> list[dict[str, Any]]:
    ts = float(now if now is not None else time.time())
    state = _read_state()
    current_ids: set[str] = set()
    output: list[dict[str, Any]] = []

    for device in devices:
        item = dict(device)
        fabric_id = _clean(item.get("fabric_id") or item.get("id"), 260)
        if not fabric_id:
            continue
        current_ids.add(fabric_id)
        item["presence"] = "online"
        item["last_seen"] = ts
        state[fabric_id] = {
            "last_seen": ts,
            "device": item,
        }
        output.append(item)

    for fabric_id, saved in list(state.items()):
        if fabric_id in current_ids or not isinstance(saved, dict):
            continue
        last_seen = float(saved.get("last_seen") or 0.0)
        age = ts - last_seen
        if age > FORGET_AFTER_SECONDS:
            state.pop(fabric_id, None)
            continue
        cached = saved.get("device")
        if not isinstance(cached, dict):
            continue
        item = dict(cached)
        item["last_seen"] = last_seen
        item["presence"] = "offline" if age >= OFFLINE_AFTER_SECONDS else "recent"
        item["status"] = "offline" if age >= OFFLINE_AFTER_SECONDS else "recently seen"
        output.append(item)

    _write_state(state)
    output.sort(key=lambda d: (0 if d.get("presence") == "online" else 1, str(d.get("kind")), str(d.get("name"))))
    return output


def build_fabric(devices: list[dict[str, Any]]) -> dict[str, Any]:
    merged = merge_devices(devices)
    present = apply_presence(merged)
    counts: dict[str, int] = {}
    online = 0
    offline = 0
    for item in present:
        if item.get("presence") == "online":
            online += 1
        else:
            offline += 1
        for source in item.get("sources") or [item.get("source")]:
            source = str(source or "device")
            counts[source] = counts.get(source, 0) + 1
    return {
        "ok": True,
        "fabric_version": FABRIC_VERSION,
        "devices": present,
        "counts": counts,
        "online": online,
        "offline": offline,
        "physical_devices": len(present),
        "raw_records": len(devices),
    }
