import json
import os
import platform
import shutil
import socket
from datetime import datetime
from pathlib import Path


SAFE_JOBS = {"health_check", "sync_metadata", "open_module"}


class DeviceRegistry:
    def __init__(self, path, hardware_registry_path=None):
        self.path = Path(path)
        self.hardware_registry_path = (
            Path(hardware_registry_path)
            if hardware_registry_path
            else Path(r"C:\RAH\HardwareRegistry\registry.json")
            if os.name == "nt"
            else self.path.parent / "hardware-registry.json"
        )
        self.path.parent.mkdir(parents=True, exist_ok=True)
        if not self.path.exists():
            self.data = {
                "devices": [
                    {
                        "id": "main-pc",
                        "name": platform.node() or "Main PC",
                        "kind": "windows-main",
                        "host": "127.0.0.1",
                        "display": "local",
                        "agents": ["daily-driver"],
                        "services": ["command-center", "chronicle", "investigator"],
                    },
                    {
                        "id": "kali-laptop",
                        "name": "Kali Laptop",
                        "kind": "kali-node",
                        "host": "",
                        "display": "remote",
                        "agents": [],
                        "services": [],
                    },
                    {
                        "id": "phone-1",
                        "name": "Phone",
                        "kind": "phone",
                        "host": "",
                        "display": "mobile",
                        "agents": [],
                        "services": [],
                    },
                    {
                        "id": "display-tv-1",
                        "name": "TV / Extended Display",
                        "kind": "display",
                        "host": "",
                        "display": "extended",
                        "agents": [],
                        "services": ["display"],
                    },
                    {
                        "id": "storage-pool",
                        "name": "RAH Storage Pool",
                        "kind": "storage",
                        "host": "",
                        "display": "none",
                        "agents": [],
                        "services": ["storage"],
                    },
                    {
                        "id": "remote-agent-pool",
                        "name": "Remote Agent Pool",
                        "kind": "remote-agents",
                        "host": "",
                        "display": "none",
                        "agents": [],
                        "services": ["agent-dispatch"],
                    },
                ]
            }
            self.save()
        else:
            self.data = json.loads(self.path.read_text(encoding="utf-8"))

    def save(self):
        self.path.write_text(json.dumps(self.data, ensure_ascii=False, indent=2), encoding="utf-8")

    def _online(self, host):
        if not host:
            return False
        if host in {"127.0.0.1", "localhost"}:
            return True
        try:
            socket.getaddrinfo(host, None)
            return True
        except OSError:
            return False

    def _hardware_registry(self):
        path = self.hardware_registry_path
        if not path.is_file():
            return {"schema": "rah-hardware-registry-v1", "devices": []}
        try:
            if path.stat().st_size > 2 * 1024 * 1024:
                return {"schema": "rah-hardware-registry-v1", "devices": []}
            value = json.loads(path.read_text(encoding="utf-8"))
            if not isinstance(value, dict) or value.get("schema") != "rah-hardware-registry-v1":
                return {"schema": "rah-hardware-registry-v1", "devices": []}
            if not isinstance(value.get("devices"), list):
                value["devices"] = []
            return value
        except (OSError, json.JSONDecodeError):
            return {"schema": "rah-hardware-registry-v1", "devices": []}

    def snapshot(self):
        total, used, free = shutil.disk_usage(Path.home().anchor or "/")
        hardware_records = self._hardware_registry().get("devices", [])
        by_id = {}
        by_host = {}
        for record in hardware_records:
            if not isinstance(record, dict):
                continue
            record_id = str(record.get("id") or "").strip().lower()
            hostname = str(record.get("hostname") or "").strip().lower()
            if record_id:
                by_id[record_id] = record
            if hostname:
                by_host[hostname] = record

        result = []
        represented = set()
        local_hostname = (platform.node() or "").strip().lower()
        for device in self.data.get("devices", []):
            item = dict(device)
            local = device.get("host") in {"127.0.0.1", "localhost"}
            item["online"] = self._online(device.get("host", ""))
            item["cpu"] = os.cpu_count() if local else None
            item["storage"] = {
                "total_gb": round(total / (1024**3), 1),
                "free_gb": round(free / (1024**3), 1),
            } if local else {}

            candidates = [
                str(device.get("id") or "").strip().lower(),
                str(device.get("name") or "").strip().lower(),
                str(device.get("host") or "").strip().lower(),
            ]
            if local and local_hostname:
                candidates.insert(0, local_hostname)
            hardware = None
            for candidate in candidates:
                if not candidate:
                    continue
                hardware = by_id.get(candidate) or by_host.get(candidate)
                if hardware:
                    break
            if hardware:
                represented.add(str(hardware.get("id") or "").lower())
                item["hardware_registry"] = {
                    "profile_hash": hardware.get("profileHash"),
                    "last_seen": hardware.get("lastSeen"),
                    "summary": hardware.get("summary") or {},
                    "profile": hardware.get("profile") or {},
                }
            result.append(item)

        for record in hardware_records:
            if not isinstance(record, dict):
                continue
            record_id = str(record.get("id") or "").strip().lower()
            if not record_id or record_id in represented:
                continue
            hostname = str(record.get("hostname") or record_id)
            result.append({
                "id": f"hardware:{record_id}",
                "name": hostname,
                "kind": "hardware-node",
                "host": hostname,
                "display": "remote",
                "agents": [],
                "services": ["hardware-registry"],
                "online": self._online(hostname),
                "cpu": None,
                "storage": {},
                "hardware_registry": {
                    "profile_hash": record.get("profileHash"),
                    "last_seen": record.get("lastSeen"),
                    "summary": record.get("summary") or {},
                    "profile": record.get("profile") or {},
                },
            })
        return result

    def dispatch(self, device_id, job, payload=None, approved=False):
        if job not in SAFE_JOBS:
            raise PermissionError("job is not allowlisted")
        if not approved:
            raise PermissionError("explicit local approval required")
        device = next((d for d in self.data.get("devices", []) if d.get("id") == device_id), None)
        if not device:
            raise KeyError(device_id)
        return {
            "device_id": device_id,
            "job": job,
            "payload": payload or {},
            "mode": "simulated-local-dispatch",
            "accepted": True,
            "timestamp": datetime.now().isoformat(timespec="seconds"),
        }
