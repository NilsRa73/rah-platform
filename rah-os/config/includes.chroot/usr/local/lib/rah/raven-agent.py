#!/usr/bin/env python3
import json
import os
import platform
import shutil
import socket
import subprocess
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

VERSION = "0.2"
HOST = "127.0.0.1"
PORT = 18765


def run_text(argv, timeout=2):
    try:
        result = subprocess.run(
            argv,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            timeout=timeout,
            check=False,
        )
        return result.stdout.strip()
    except (OSError, subprocess.TimeoutExpired):
        return ""


def read_text(path):
    try:
        return Path(path).read_text(encoding="utf-8", errors="replace").strip()
    except OSError:
        return ""


def system_payload():
    mem_kb = None
    try:
        with open("/proc/meminfo", "r", encoding="utf-8") as f:
            for line in f:
                if line.startswith("MemTotal:"):
                    mem_kb = int(line.split()[1])
                    break
    except OSError:
        pass

    root = shutil.disk_usage("/")
    return {
        "hostname": socket.gethostname(),
        "os": "RAH OS Raven",
        "rah_version": VERSION,
        "base": "Debian 13 (trixie)",
        "kernel": platform.release(),
        "architecture": platform.machine(),
        "cpu_threads": os.cpu_count(),
        "memory_total_mb": round(mem_kb / 1024) if mem_kb else None,
        "root_total_gb": round(root.total / (1024**3), 1),
        "root_free_gb": round(root.free / (1024**3), 1),
        "boot_mode": "UEFI" if Path("/sys/firmware/efi").exists() else "Legacy/BIOS",
    }


def check(state, key, title, detail):
    return {"state": state, "key": key, "title": title, "detail": detail}


def network_check():
    base = Path("/sys/class/net")
    if not base.exists():
        return check("WARN", "network", "Network", "Network interfaces were not visible.")

    items = []
    for p in sorted(base.iterdir()):
        if p.name == "lo":
            continue
        state = read_text(p / "operstate") or "unknown"
        kind = "Wi-Fi" if (p / "wireless").exists() else "Network"
        items.append((p.name, state, kind))

    if not items:
        return check("WARN", "network", "Network", "No non-loopback network adapter detected.")

    up = [x for x in items if x[1] == "up"]
    detail = ", ".join(f"{name} ({kind}, {state})" for name, state, kind in items[:8])
    return check("PASS" if up else "INFO", "network", "Network", detail)


def display_check():
    drm = Path("/sys/class/drm")
    connected = []
    if drm.exists():
        for status_file in sorted(drm.glob("card*-*/status")):
            if read_text(status_file) == "connected":
                connected.append(status_file.parent.name)
    if connected:
        return check("PASS", "display", "Display", f"Connected output(s): {', '.join(connected)}")
    return check("INFO", "display", "Display", "No DRM connector reported as connected yet.")


def gpu_check():
    text = run_text(["lspci", "-nn"], 2)
    lines = [
        line for line in text.splitlines()
        if any(token in line.lower() for token in ("vga compatible", "3d controller", "display controller"))
    ]
    if lines:
        return check("PASS", "gpu", "Graphics", " | ".join(lines[:2]))
    return check("INFO", "gpu", "Graphics", "No GPU line returned by lspci.")


def audio_check():
    cards = read_text("/proc/asound/cards")
    if cards and "no soundcards" not in cards.lower():
        first = next((line.strip() for line in cards.splitlines() if line.strip()), "Sound device detected")
        return check("PASS", "audio", "Audio", first[:180])
    return check("INFO", "audio", "Audio", "No ALSA sound card detected yet.")


def bluetooth_check():
    out = run_text(["bluetoothctl", "show"], 2)
    if "Controller " in out:
        name = next((line.strip() for line in out.splitlines() if line.strip().startswith("Name:")), "")
        return check("PASS", "bluetooth", "Bluetooth", name or "Bluetooth controller detected.")
    return check("INFO", "bluetooth", "Bluetooth", "No Bluetooth controller detected or service not ready.")


def usb_check():
    base = Path("/sys/bus/usb/devices")
    devices = []
    if base.exists():
        for p in sorted(base.iterdir()):
            vendor = read_text(p / "idVendor")
            product = read_text(p / "idProduct")
            if vendor and product:
                devices.append(f"{vendor}:{product}")
    if devices:
        preview = ", ".join(devices[:8])
        suffix = "" if len(devices) <= 8 else f" +{len(devices)-8} more"
        return check("PASS", "usb", "USB", f"{len(devices)} USB device(s): {preview}{suffix}")
    return check("INFO", "usb", "USB", "No enumerated USB device found in sysfs.")


def storage_check():
    root = shutil.disk_usage("/")
    free_gb = root.free / (1024**3)
    total_gb = root.total / (1024**3)
    state = "PASS" if free_gb >= 2 else "WARN"
    return check(state, "storage", "Storage", f"Root filesystem: {free_gb:.1f} GB free of {total_gb:.1f} GB.")


def boot_check():
    if Path("/sys/firmware/efi").exists():
        return check("PASS", "boot", "Boot mode", "UEFI boot detected.")
    return check("INFO", "boot", "Boot mode", "Legacy/BIOS boot detected.")


def raven_check():
    return check("PASS", "raven", "Raven Core", f"Local Raven agent v{VERSION} is responding on 127.0.0.1:{PORT}.")


def battery_check():
    base = Path("/sys/class/power_supply")
    bats = sorted(base.glob("BAT*")) if base.exists() else []
    if not bats:
        return check("INFO", "battery", "Battery", "No battery detected (normal on desktops).")
    b = bats[0]
    cap = read_text(b / "capacity")
    status = read_text(b / "status")
    detail = status or "Unknown"
    if cap:
        detail += f", {cap}%"
    return check("PASS", "battery", "Battery", detail)


def diagnostics_payload():
    checks = [
        raven_check(),
        boot_check(),
        storage_check(),
        network_check(),
        display_check(),
        gpu_check(),
        audio_check(),
        bluetooth_check(),
        usb_check(),
        battery_check(),
    ]
    counts = {state: sum(1 for item in checks if item["state"] == state) for state in ("PASS", "WARN", "INFO")}
    return {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "rah_version": VERSION,
        "system": system_payload(),
        "summary": counts,
        "checks": checks,
        "note": "Read-only Live USB acceptance diagnostics. No privileged actions are performed.",
    }


HOME = r"""<!doctype html>
<html>
<head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>RAH Command Center</title>
<style>
:root{color-scheme:dark;--bg:#080808;--panel:#111;--gold:#e3b94e;--line:#8d6b25;--ok:#86d27a;--warn:#ffcf5a;--muted:#aaa}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:#eee;font:16px system-ui,Segoe UI,sans-serif}
main{max-width:1180px;margin:5vh auto;padding:28px}.brand{color:#d8aa42;letter-spacing:.18em}
h1{font-size:48px;margin:.2em 0 0.5em}.hero,.card{border:1px solid var(--line);background:var(--panel);border-radius:16px;padding:22px;margin:16px 0}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(230px,1fr));gap:14px}.card{margin:0;min-height:125px}
.state{font-weight:800}.PASS{color:var(--ok)}.WARN{color:var(--warn)}.INFO{color:#9ecbff}
button,a.btn{display:inline-block;background:#171717;color:#fff;border:1px solid var(--gold);border-radius:10px;padding:11px 16px;margin:5px 8px 5px 0;text-decoration:none;cursor:pointer}
small,.muted{color:var(--muted)}code{color:var(--gold)}#stamp{color:var(--muted)}
</style>
</head>
<body><main>
<div class="brand">RAH OS • RAVEN v0.2</div>
<h1>Raven Command Center</h1>
<section class="hero">
<h2 class="PASS">● Raven Core online</h2>
<p>Local service: <code>127.0.0.1:18765</code>. v0.2 is the first <b>Desktop Candidate</b>: boot from USB, use the GUI, and validate hardware without opening Terminal.</p>
<button onclick="runCheck()">RUN HARDWARE CHECK</button>
<a class="btn" href="/report">DOWNLOAD REPORT</a>
<a class="btn" href="/system">SYSTEM JSON</a>
<p id="stamp">Ready.</p>
</section>
<div id="grid" class="grid"></div>
<section class="hero">
<h2>Safety boundary</h2>
<p class="muted">This build is still read-only at the Raven system layer. No authenticated privilege broker or destructive disk/system action is enabled in v0.2.</p>
</section>
<script>
function esc(v){return String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]))}
async function runCheck(){
  const stamp=document.getElementById('stamp'); stamp.textContent='Checking hardware…';
  try{
    const r=await fetch('/api/diagnostics',{cache:'no-store'});
    const d=await r.json();
    document.getElementById('grid').innerHTML=d.checks.map(x=>`
      <div class="card"><div class="state ${esc(x.state)}">${esc(x.state)}</div>
      <h3>${esc(x.title)}</h3><div class="muted">${esc(x.detail)}</div></div>`).join('');
    stamp.textContent=`PASS ${d.summary.PASS} · WARN ${d.summary.WARN} · INFO ${d.summary.INFO} · ${new Date().toLocaleTimeString()}`;
  }catch(e){stamp.textContent='Hardware check failed: '+e}
}
runCheck();
</script>
</main></body></html>"""


class Handler(BaseHTTPRequestHandler):
    def send_json(self, data, status=200, attachment=None):
        raw = json.dumps(data, indent=2).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        if attachment:
            self.send_header("Content-Disposition", f'attachment; filename="{attachment}"')
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def send_html(self, text, status=200):
        raw = text.encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def do_GET(self):
        path = self.path.split("?", 1)[0]
        if path == "/health":
            return self.send_json({"status": "ok", "service": "rah-raven-agent", "version": VERSION})
        if path == "/system":
            return self.send_json(system_payload())
        if path in ("/api/diagnostics", "/diagnostics.json"):
            return self.send_json(diagnostics_payload())
        if path == "/report":
            return self.send_json(diagnostics_payload(), attachment=f"RAH-OS-v{VERSION}-hardware-report.json")
        if path in ("/", "/diagnostics"):
            return self.send_html(HOME)
        return self.send_json({"error": "not_found"}, 404)

    def log_message(self, fmt, *args):
        pass


if __name__ == "__main__":
    ThreadingHTTPServer((HOST, PORT), Handler).serve_forever()
