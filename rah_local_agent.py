#!/usr/bin/env python3
"""RAH Local Agent v0.1

Local Windows tool bus for RAH Raven/AI. Standard-library only.

Default security model:
- Binds to 127.0.0.1 only.
- Bearer token stored in %LOCALAPPDATA%\RAH\LocalAgent\token.txt.
- Broad filesystem/process/system access is limited by the Windows account that runs it.
- Destructive system-level shell commands require dangerous=true.
- Every tool call is written to an append-only JSONL audit log.
"""

from __future__ import annotations

import base64
import ctypes
import datetime as dt
import fnmatch
import hashlib
import json
import os
import platform
import secrets
import shutil
import signal
import socket
import subprocess
import sys
import time
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any, Callable

VERSION = "0.1.0"
HOST = os.environ.get("RAH_AGENT_HOST", "127.0.0.1")
PORT = int(os.environ.get("RAH_AGENT_PORT", "18779"))
BASE = Path(os.environ.get("LOCALAPPDATA", str(Path.home() / "AppData" / "Local"))) / "RAH" / "LocalAgent"
TOKEN_FILE = BASE / "token.txt"
AUDIT_FILE = BASE / "audit.jsonl"
STATE_FILE = BASE / "state.json"
MAX_BODY = 16 * 1024 * 1024
MAX_TEXT_READ = 8 * 1024 * 1024
MAX_SEARCH_RESULTS = 2000

BASE.mkdir(parents=True, exist_ok=True)


def now_iso() -> str:
    return dt.datetime.now(dt.timezone.utc).astimezone().isoformat()


def get_or_create_token() -> str:
    env = os.environ.get("RAH_AGENT_TOKEN")
    if env:
        return env.strip()
    if TOKEN_FILE.exists():
        token = TOKEN_FILE.read_text(encoding="utf-8").strip()
        if token:
            return token
    token = secrets.token_urlsafe(48)
    TOKEN_FILE.write_text(token, encoding="utf-8")
    try:
        os.chmod(TOKEN_FILE, 0o600)
    except OSError:
        pass
    return token


TOKEN = get_or_create_token()


def audit(tool: str, args: dict[str, Any], ok: bool, duration_ms: int, error: str | None = None) -> None:
    safe_args = dict(args or {})
    for key in list(safe_args):
        if any(x in key.lower() for x in ("token", "password", "secret", "key")):
            safe_args[key] = "<redacted>"
    rec = {
        "ts": now_iso(), "tool": tool, "args": safe_args, "ok": ok,
        "duration_ms": duration_ms, "error": error, "pid": os.getpid(),
        "user": os.environ.get("USERNAME") or os.environ.get("USER"),
        "host": socket.gethostname(),
    }
    with AUDIT_FILE.open("a", encoding="utf-8") as f:
        f.write(json.dumps(rec, ensure_ascii=False, default=str) + "\n")


def powershell_json(script: str, timeout: int = 30) -> Any:
    wrapped = f"$ProgressPreference='SilentlyContinue'; $ErrorActionPreference='Stop'; {script} | ConvertTo-Json -Depth 8 -Compress"
    cp = subprocess.run(["powershell.exe", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-Command", wrapped], capture_output=True, text=True, timeout=timeout, encoding="utf-8", errors="replace")
    if cp.returncode != 0:
        raise RuntimeError((cp.stderr or cp.stdout or f"PowerShell exit {cp.returncode}").strip())
    text = cp.stdout.strip()
    return json.loads(text) if text else None


def run_process(argv: list[str], timeout: int = 60, cwd: str | None = None, env: dict[str, str] | None = None) -> dict[str, Any]:
    cp = subprocess.run(argv, cwd=cwd, env=env, capture_output=True, text=True, timeout=max(1, min(int(timeout), 3600)), encoding="utf-8", errors="replace")
    return {"returncode": cp.returncode, "stdout": cp.stdout, "stderr": cp.stderr}


def p(value: str) -> Path:
    if not isinstance(value, str) or not value.strip():
        raise ValueError("path is required")
    return Path(os.path.expandvars(os.path.expanduser(value))).resolve(strict=False)


def is_admin() -> bool:
    if os.name != "nt":
        return os.geteuid() == 0 if hasattr(os, "geteuid") else False
    try:
        return bool(ctypes.windll.shell32.IsUserAnAdmin())
    except Exception:
        return False


def drive_list() -> list[str]:
    if os.name != "nt": return ["/"]
    mask = ctypes.windll.kernel32.GetLogicalDrives()
    return [f"{chr(65+i)}:\\" for i in range(26) if mask & (1 << i)]


def tool_system_cpu(args: dict[str, Any]) -> Any:
    return powershell_json("Get-CimInstance Win32_Processor | Select-Object Name,Manufacturer,NumberOfCores,NumberOfLogicalProcessors,MaxClockSpeed,LoadPercentage")


def tool_system_memory(args: dict[str, Any]) -> Any:
    return powershell_json("$os=Get-CimInstance Win32_OperatingSystem; [pscustomobject]@{TotalGB=[math]::Round($os.TotalVisibleMemorySize/1MB,2); FreeGB=[math]::Round($os.FreePhysicalMemory/1MB,2); UsedGB=[math]::Round(($os.TotalVisibleMemorySize-$os.FreePhysicalMemory)/1MB,2)}")


def tool_system_gpu(args: dict[str, Any]) -> Any:
    return powershell_json("Get-CimInstance Win32_VideoController | Select-Object Name,DriverVersion,AdapterRAM,VideoModeDescription,CurrentHorizontalResolution,CurrentVerticalResolution")


def tool_system_disks(args: dict[str, Any]) -> Any:
    return powershell_json("Get-CimInstance Win32_LogicalDisk | Select-Object DeviceID,VolumeName,FileSystem,DriveType,@{N='SizeGB';E={[math]::Round($_.Size/1GB,2)}},@{N='FreeGB';E={[math]::Round($_.FreeSpace/1GB,2)}}")


def tool_system_network(args: dict[str, Any]) -> Any:
    return powershell_json("Get-NetAdapter | Select-Object Name,InterfaceDescription,Status,LinkSpeed,MacAddress,ifIndex")


def tool_system_displays(args: dict[str, Any]) -> Any:
    script = "Get-CimInstance -Namespace root\\wmi -ClassName WmiMonitorID -ErrorAction SilentlyContinue | ForEach-Object { [pscustomobject]@{InstanceName=$_.InstanceName; Manufacturer=([Text.Encoding]::ASCII.GetString($_.ManufacturerName)).Trim([char]0); ProductCode=([Text.Encoding]::ASCII.GetString($_.ProductCodeID)).Trim([char]0); Serial=([Text.Encoding]::ASCII.GetString($_.SerialNumberID)).Trim([char]0); UserFriendlyName=([Text.Encoding]::ASCII.GetString($_.UserFriendlyName)).Trim([char]0) } }"
    return powershell_json(script)


def tool_system_snapshot(args: dict[str, Any]) -> dict[str, Any]:
    return {"agent": {"version": VERSION, "host": HOST, "port": PORT, "admin": is_admin()}, "machine": {"hostname": socket.gethostname(), "platform": platform.platform(), "python": sys.version.split()[0]}, "cpu": tool_system_cpu({}), "memory": tool_system_memory({}), "gpu": tool_system_gpu({}), "disks": tool_system_disks({}), "network": tool_system_network({}), "drives": drive_list()}


def tool_fs_list(args: dict[str, Any]) -> Any:
    root = p(args.get("path", ".")); recursive = bool(args.get("recursive", False)); limit = max(1, min(int(args.get("limit", 500)), 10000))
    if not root.exists(): raise FileNotFoundError(str(root))
    paths = root.rglob("*") if recursive else root.iterdir(); out = []
    for child in paths:
        try:
            st = child.stat(); out.append({"name": child.name, "path": str(child), "type": "dir" if child.is_dir() else "file", "size": st.st_size, "modified": dt.datetime.fromtimestamp(st.st_mtime).isoformat()})
        except OSError as e: out.append({"name": child.name, "path": str(child), "error": str(e)})
        if len(out) >= limit: break
    return out


def tool_fs_read_text(args: dict[str, Any]) -> Any:
    path = p(args["path"]); max_bytes = max(1, min(int(args.get("max_bytes", MAX_TEXT_READ)), 64 * 1024 * 1024))
    with path.open("rb") as f: data = f.read(max_bytes + 1)
    truncated = len(data) > max_bytes
    if truncated: data = data[:max_bytes]
    encoding = args.get("encoding", "utf-8")
    return {"path": str(path), "text": data.decode(encoding, errors="replace"), "truncated": truncated, "bytes": len(data)}


def tool_fs_read_bytes(args: dict[str, Any]) -> Any:
    path = p(args["path"]); max_bytes = max(1, min(int(args.get("max_bytes", 16 * 1024 * 1024)), 64 * 1024 * 1024))
    with path.open("rb") as f: data = f.read(max_bytes + 1)
    truncated = len(data) > max_bytes
    if truncated: data = data[:max_bytes]
    return {"path": str(path), "base64": base64.b64encode(data).decode("ascii"), "truncated": truncated, "bytes": len(data)}


def tool_fs_write_text(args: dict[str, Any]) -> Any:
    path = p(args["path"]); path.parent.mkdir(parents=True, exist_ok=True); mode = "a" if args.get("append") else "w"; encoding = args.get("encoding", "utf-8"); text = str(args.get("text", ""))
    with path.open(mode, encoding=encoding, newline="") as f: f.write(text)
    return {"path": str(path), "bytes": len(text.encode(encoding, errors="replace")), "append": mode == "a"}


def tool_fs_write_bytes(args: dict[str, Any]) -> Any:
    path = p(args["path"]); path.parent.mkdir(parents=True, exist_ok=True); data = base64.b64decode(args.get("base64", ""), validate=True); mode = "ab" if args.get("append") else "wb"
    with path.open(mode) as f: f.write(data)
    return {"path": str(path), "bytes": len(data), "append": mode == "ab"}


def tool_fs_mkdir(args: dict[str, Any]) -> Any:
    path = p(args["path"]); path.mkdir(parents=bool(args.get("parents", True)), exist_ok=bool(args.get("exist_ok", True))); return {"path": str(path), "created": True}


def tool_fs_copy(args: dict[str, Any]) -> Any:
    src, dst = p(args["src"]), p(args["dst"]); dst.parent.mkdir(parents=True, exist_ok=True)
    result = shutil.copytree(src, dst, dirs_exist_ok=bool(args.get("overwrite", False))) if src.is_dir() else shutil.copy2(src, dst)
    return {"src": str(src), "dst": str(result)}


def tool_fs_move(args: dict[str, Any]) -> Any:
    src, dst = p(args["src"]), p(args["dst"]); dst.parent.mkdir(parents=True, exist_ok=True)
    if dst.exists() and not args.get("overwrite"): raise FileExistsError(str(dst))
    if dst.exists() and args.get("overwrite"):
        if dst.is_dir(): shutil.rmtree(dst)
        else: dst.unlink()
    result = shutil.move(str(src), str(dst)); return {"src": str(src), "dst": str(result)}


def _root_like(path: Path) -> bool:
    if path.parent == path: return True
    return bool(os.name == "nt" and path.drive and str(path).rstrip("\\/").lower() == path.drive.lower())


def tool_fs_delete(args: dict[str, Any]) -> Any:
    path = p(args["path"]); recursive = bool(args.get("recursive", False)); dangerous = bool(args.get("dangerous", False))
    windir = Path(os.environ.get("WINDIR", "C:\\Windows")).resolve(strict=False) if os.name == "nt" else None
    program_files = [Path(x).resolve(strict=False) for x in (os.environ.get("ProgramFiles", ""), os.environ.get("ProgramFiles(x86)", "")) if x]
    if _root_like(path): raise PermissionError("refusing to delete filesystem root")
    if not dangerous and os.name == "nt":
        protected = [windir] + program_files if windir else program_files
        if any(path == z or z in path.parents for z in protected): raise PermissionError("system-area delete requires dangerous=true")
    if path.is_dir():
        if not recursive: path.rmdir()
        else: shutil.rmtree(path)
    else: path.unlink()
    return {"path": str(path), "deleted": True}


def tool_fs_search(args: dict[str, Any]) -> Any:
    root = p(args.get("path", ".")); pattern = str(args.get("pattern", "*")); text = args.get("text"); case_sensitive = bool(args.get("case_sensitive", False)); limit = max(1, min(int(args.get("limit", 200)), MAX_SEARCH_RESULTS)); out = []
    for fp in root.rglob("*"):
        if len(out) >= limit: break
        if not fp.is_file() or not fnmatch.fnmatch(fp.name, pattern): continue
        if text is None: out.append({"path": str(fp)}); continue
        try: hay = fp.read_text(encoding=args.get("encoding", "utf-8"), errors="replace")
        except (OSError, UnicodeError): continue
        needle, target = str(text), hay
        if not case_sensitive: needle, target = needle.lower(), target.lower()
        if needle in target: out.append({"path": str(fp), "match": True})
    return out


def tool_fs_hash(args: dict[str, Any]) -> Any:
    path = p(args["path"]); alg = str(args.get("algorithm", "sha256")).lower(); h = hashlib.new(alg)
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""): h.update(chunk)
    return {"path": str(path), "algorithm": alg, "digest": h.hexdigest()}


def tool_process_list(args: dict[str, Any]) -> Any:
    return powershell_json("Get-Process | Sort-Object CPU -Descending | Select-Object Id,ProcessName,CPU,WorkingSet64,Path -First 500")


def tool_process_start(args: dict[str, Any]) -> Any:
    exe = str(args["file"]); argv = [exe] + [str(x) for x in args.get("args", [])]; proc = subprocess.Popen(argv, cwd=args.get("cwd") or None); return {"pid": proc.pid, "argv": argv}


def tool_process_stop(args: dict[str, Any]) -> Any:
    pid = int(args["pid"])
    if pid == os.getpid(): raise PermissionError("agent cannot stop itself through process.stop")
    if os.name == "nt":
        cmd = ["taskkill", "/PID", str(pid), "/T"] + (["/F"] if args.get("force", False) else [])
        cp = subprocess.run(cmd, capture_output=True, text=True); return {"pid": pid, "returncode": cp.returncode, "stdout": cp.stdout, "stderr": cp.stderr}
    os.kill(pid, signal.SIGKILL if args.get("force") else signal.SIGTERM); return {"pid": pid, "stopped": True}


def tool_service_list(args: dict[str, Any]) -> Any:
    return powershell_json("Get-Service | Select-Object Name,DisplayName,Status,StartType")


def tool_service_start(args: dict[str, Any]) -> Any:
    name = str(args["name"]).replace("'", "''"); return powershell_json(f"Start-Service -Name '{name}'; Get-Service -Name '{name}' | Select-Object Name,Status,StartType")


def tool_service_stop(args: dict[str, Any]) -> Any:
    name = str(args["name"]).replace("'", "''"); return powershell_json(f"Stop-Service -Name '{name}' -Force:$false; Get-Service -Name '{name}' | Select-Object Name,Status,StartType")


def _looks_dangerous(command: str) -> bool:
    s = command.lower(); markers = ["format ", "diskpart", "clear-disk", "remove-partition", "initialize-disk", "bcdedit", "bootrec", "manage-bde", "reg delete", "remove-item -recurse c:\\windows", "shutdown /s", "shutdown /r", "restart-computer", "stop-computer", "disable-computerrestore", "set-mppreference -disablerealtimemonitoring"]
    return any(x in s for x in markers)


def tool_shell_powershell(args: dict[str, Any]) -> Any:
    command = str(args.get("command", ""))
    if not command: raise ValueError("command is required")
    if _looks_dangerous(command) and not args.get("dangerous", False): raise PermissionError("high-risk command requires dangerous=true")
    timeout = int(args.get("timeout", 120)); cp = subprocess.run(["powershell.exe", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-Command", command], capture_output=True, text=True, timeout=max(1, min(timeout, 3600)), encoding="utf-8", errors="replace")
    return {"returncode": cp.returncode, "stdout": cp.stdout, "stderr": cp.stderr}


def tool_shell_exec(args: dict[str, Any]) -> Any:
    argv = args.get("argv")
    if not isinstance(argv, list) or not argv: raise ValueError("argv must be a non-empty array")
    text = " ".join(str(x) for x in argv)
    if _looks_dangerous(text) and not args.get("dangerous", False): raise PermissionError("high-risk command requires dangerous=true")
    return run_process([str(x) for x in argv], int(args.get("timeout", 120)), args.get("cwd"))


def tool_agent_status(args: dict[str, Any]) -> Any:
    return {"version": VERSION, "host": HOST, "port": PORT, "hostname": socket.gethostname(), "pid": os.getpid(), "admin": is_admin(), "base": str(BASE), "audit": str(AUDIT_FILE), "started": STARTED_AT}


TOOLS: dict[str, Callable[[dict[str, Any]], Any]] = {
    "agent.status": tool_agent_status, "system.snapshot": tool_system_snapshot, "system.cpu": tool_system_cpu, "system.memory": tool_system_memory, "system.gpu": tool_system_gpu, "system.disks": tool_system_disks, "system.network": tool_system_network, "system.displays": tool_system_displays,
    "fs.list": tool_fs_list, "fs.read_text": tool_fs_read_text, "fs.read_bytes": tool_fs_read_bytes, "fs.write_text": tool_fs_write_text, "fs.write_bytes": tool_fs_write_bytes, "fs.mkdir": tool_fs_mkdir, "fs.copy": tool_fs_copy, "fs.move": tool_fs_move, "fs.delete": tool_fs_delete, "fs.search": tool_fs_search, "fs.hash": tool_fs_hash,
    "process.list": tool_process_list, "process.start": tool_process_start, "process.stop": tool_process_stop, "service.list": tool_service_list, "service.start": tool_service_start, "service.stop": tool_service_stop, "shell.powershell": tool_shell_powershell, "shell.exec": tool_shell_exec,
}

STARTED_AT = now_iso()


def tool_manifest() -> dict[str, Any]:
    return {"version": VERSION, "tools": sorted(TOOLS), "filesystem_scope": "OS-account permissions (broad/local)", "dangerous_flag": "Required for selected destructive system-level shell/delete operations"}


class Handler(BaseHTTPRequestHandler):
    server_version = "RAHLocalAgent/0.1"
    def log_message(self, fmt: str, *args: Any) -> None: return
    def _json(self, status: int, obj: Any) -> None:
        data = json.dumps(obj, ensure_ascii=False, default=str).encode("utf-8"); self.send_response(status); self.send_header("Content-Type", "application/json; charset=utf-8"); self.send_header("Content-Length", str(len(data))); self.send_header("Cache-Control", "no-store"); self.end_headers(); self.wfile.write(data)
    def _authorized(self) -> bool:
        return secrets.compare_digest(self.headers.get("Authorization", ""), f"Bearer {TOKEN}")
    def do_GET(self) -> None:
        path = urllib.parse.urlparse(self.path).path
        if path == "/health": self._json(200, {"ok": True, "service": "RAH Local Agent", "version": VERSION, "host": socket.gethostname()}); return
        if not self._authorized(): self._json(401, {"ok": False, "error": "unauthorized"}); return
        if path in ("/capabilities", "/v1/capabilities"): self._json(200, {"ok": True, "result": tool_manifest()}); return
        if path in ("/status", "/v1/status"): self._json(200, {"ok": True, "result": tool_agent_status({})}); return
        self._json(404, {"ok": False, "error": "not found"})
    def do_POST(self) -> None:
        path = urllib.parse.urlparse(self.path).path
        if path not in ("/tool", "/v1/tool"): self._json(404, {"ok": False, "error": "not found"}); return
        if not self._authorized(): self._json(401, {"ok": False, "error": "unauthorized"}); return
        try: length = int(self.headers.get("Content-Length", "0"))
        except ValueError: self._json(400, {"ok": False, "error": "invalid content length"}); return
        if length <= 0 or length > MAX_BODY: self._json(413, {"ok": False, "error": "invalid request size"}); return
        try:
            body = json.loads(self.rfile.read(length).decode("utf-8")); tool = str(body.get("tool", "")); args = body.get("args") or {}
            if tool not in TOOLS: self._json(404, {"ok": False, "error": f"unknown tool: {tool}", "available": sorted(TOOLS)}); return
            if not isinstance(args, dict): raise ValueError("args must be an object")
            start = time.perf_counter()
            try:
                result = TOOLS[tool](args); ms = int((time.perf_counter() - start) * 1000); audit(tool, args, True, ms); self._json(200, {"ok": True, "tool": tool, "result": result, "duration_ms": ms})
            except Exception as e:
                ms = int((time.perf_counter() - start) * 1000); audit(tool, args, False, ms, str(e)); self._json(500, {"ok": False, "tool": tool, "error": f"{type(e).__name__}: {e}", "duration_ms": ms})
        except Exception as e: self._json(400, {"ok": False, "error": f"{type(e).__name__}: {e}"})


def main() -> int:
    STATE_FILE.write_text(json.dumps({"version": VERSION, "host": HOST, "port": PORT, "pid": os.getpid(), "started": STARTED_AT, "token_file": str(TOKEN_FILE), "audit_file": str(AUDIT_FILE)}, indent=2), encoding="utf-8")
    print("=" * 68); print(" RAH LOCAL AGENT v%s" % VERSION); print("=" * 68); print(f" Endpoint : http://{HOST}:{PORT}"); print(f" Admin    : {is_admin()}"); print(f" Token    : {TOKEN_FILE}"); print(f" Audit    : {AUDIT_FILE}"); print(f" Tools    : {len(TOOLS)}"); print(" RAH agent is ready."); print("=" * 68)
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    try: server.serve_forever(poll_interval=0.25)
    except KeyboardInterrupt: pass
    finally: server.server_close()
    return 0


if __name__ == "__main__": raise SystemExit(main())
