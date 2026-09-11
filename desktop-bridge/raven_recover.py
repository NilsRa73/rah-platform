from __future__ import annotations

import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.request

PORT = 18765
HOST = "127.0.0.1"
HEALTH_URL = f"http://{HOST}:{PORT}/health"
REQUIRED = ("ok", "council_proxy", "vision_monitor_capture", "local_device_adapter")
BRIDGE_DIR = Path(__file__).resolve().parent
RAH_ROOT = Path(os.environ.get("RAH_ROOT", r"C:\RAH"))
LOG_DIR = RAH_ROOT / "Logs" / "RavenBridge"
STATE_DIR = RAH_ROOT / "State" / "RavenBridge"
DATA_DIR = RAH_ROOT / "Data"


def get_json(url: str, timeout: float = 2.5) -> dict | None:
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "RAH-Raven-Recovery/1.0"})
        with urllib.request.urlopen(req, timeout=timeout) as response:
            value = json.loads(response.read().decode("utf-8"))
            return value if isinstance(value, dict) else None
    except (OSError, ValueError, urllib.error.URLError, json.JSONDecodeError):
        return None


def healthy() -> tuple[bool, dict | None]:
    data = get_json(HEALTH_URL)
    return bool(data and all(data.get(k) is True for k in REQUIRED)), data


def port_open() -> bool:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.settimeout(0.5)
        return sock.connect_ex((HOST, PORT)) == 0


def write_state(status: str, **extra: object) -> None:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    payload: dict[str, object] = {
        "status": status,
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
        "port": PORT,
        "bridge_dir": str(BRIDGE_DIR),
    }
    payload.update(extra)
    (STATE_DIR / "recovery.json").write_text(
        json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8"
    )


def bridge_python() -> Path:
    scripts = BRIDGE_DIR / ".venv" / "Scripts"
    for name in ("pythonw.exe", "python.exe"):
        candidate = scripts / name
        if candidate.exists():
            return candidate
    return Path(sys.executable)


def main() -> int:
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    for path in (DATA_DIR / "Chronicle", DATA_DIR / "Vault", DATA_DIR / "Incoming", DATA_DIR / "DownloadManager"):
        path.mkdir(parents=True, exist_ok=True)

    ok, health = healthy()
    if ok:
        print("RAVEN RECOVERY: HEALTHY")
        write_state("healthy", health=health)
        return 0

    if port_open():
        print("RAVEN RECOVERY: BLOCKED - port 18765 is occupied by a non-canonical or unhealthy process")
        print("No process was terminated.")
        write_state("blocked-port", health=health)
        return 2

    entrypoint = BRIDGE_DIR / "raven_bridge.py"
    if not entrypoint.exists():
        print(f"RAVEN RECOVERY: ERROR - missing {entrypoint}")
        write_state("missing-entrypoint")
        return 3

    env = os.environ.copy()
    env.update({
        "RAH_CHRONICLE_DIR": str(DATA_DIR / "Chronicle"),
        "RAH_DOWNLOAD_MANAGER_STATE": str(DATA_DIR / "DownloadManager" / "state.json"),
        "RAH_RAVEN_VAULT": str(DATA_DIR / "Vault"),
        "RAH_DOWNLOADS_DIR": str(DATA_DIR / "Incoming"),
    })

    out_log = (LOG_DIR / "bridge-recovery.out.log").open("ab")
    err_log = (LOG_DIR / "bridge-recovery.err.log").open("ab")
    try:
        process = subprocess.Popen(
            [str(bridge_python()), str(entrypoint)],
            cwd=str(BRIDGE_DIR),
            env=env,
            stdin=subprocess.DEVNULL,
            stdout=out_log,
            stderr=err_log,
            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
        )
    finally:
        out_log.close()
        err_log.close()

    deadline = time.monotonic() + 20
    while time.monotonic() < deadline:
        if process.poll() is not None:
            print(f"RAVEN RECOVERY: ERROR - Bridge exited with code {process.returncode}")
            write_state("start-failed", exit_code=process.returncode)
            return 4
        ok, health = healthy()
        if ok:
            print(f"RAVEN RECOVERY: GREEN - Bridge started as PID {process.pid}")
            write_state("recovered", bridge_pid=process.pid, health=health)
            return 0
        time.sleep(0.5)

    print("RAVEN RECOVERY: ERROR - Bridge did not become healthy within 20 seconds")
    write_state("start-timeout", bridge_pid=process.pid)
    return 5


if __name__ == "__main__":
    raise SystemExit(main())
