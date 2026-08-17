import json
import os
import platform
import shutil
import socket
from datetime import datetime
from pathlib import Path


SAFE_JOBS = {"health_check", "sync_metadata", "open_module"}


class DeviceRegistry:
    def __init__(self, path):
        self.path = Path(path)
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

    def snapshot(self):
        total, used, free = shutil.disk_usage(Path.home().anchor or "/")
        result = []
        for device in self.data.get("devices", []):
            item = dict(device)
            local = device.get("host") in {"127.0.0.1", "localhost"}
            item["online"] = self._online(device.get("host", ""))
            item["cpu"] = os.cpu_count() if local else None
            item["storage"] = {
                "total_gb": round(total / (1024**3), 1),
                "free_gb": round(free / (1024**3), 1),
            } if local else {}
            result.append(item)
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
