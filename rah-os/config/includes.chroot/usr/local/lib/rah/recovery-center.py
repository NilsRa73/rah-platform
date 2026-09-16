#!/usr/bin/env python3
import argparse
import html
import json
import os
import platform
import shutil
import socket
import subprocess
import tempfile
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

VERSION = "1.0"
RAVEN_HEALTH = "http://127.0.0.1:18765/health"


def run_text(argv, timeout=4):
    try:
        p = subprocess.run(
            argv,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            timeout=timeout,
            check=False,
        )
        return p.returncode, p.stdout.strip()
    except (OSError, subprocess.TimeoutExpired):
        return 127, ""


def read_text(path):
    try:
        return Path(path).read_text(encoding="utf-8", errors="replace").strip()
    except OSError:
        return ""


def item(state, key, title, detail, suggestion=""):
    return {
        "state": state,
        "key": key,
        "title": title,
        "detail": detail,
        "suggestion": suggestion,
    }


def root_storage_check():
    usage = shutil.disk_usage("/")
    free_gb = usage.free / (1024 ** 3)
    total_gb = usage.total / (1024 ** 3)
    pct_free = (usage.free / usage.total * 100) if usage.total else 0
    if free_gb < 1 or pct_free < 5:
        return item(
            "WARN",
            "root-storage",
            "Root storage",
            f"Only {free_gb:.1f} GB free of {total_gb:.1f} GB.",
            "Free space before updates or installation. Review large files and package caches first.",
        )
    return item(
        "PASS",
        "root-storage",
        "Root storage",
        f"{free_gb:.1f} GB free of {total_gb:.1f} GB.",
    )


def root_mount_check():
    rc, out = run_text(["findmnt", "-n", "-o", "SOURCE,FSTYPE,OPTIONS", "/"])
    if rc != 0 or not out:
        return item("INFO", "root-mount", "Root mount", "Unable to query root mount details.")
    state = "WARN" if ",ro" in f",{out}," or " ro," in f" {out}," else "PASS"
    suggestion = "Boot from the RAH OS Live USB and inspect the filesystem before attempting repairs." if state == "WARN" else ""
    return item(state, "root-mount", "Root mount", out[:260], suggestion)


def live_mode_check():
    markers = [Path("/run/live/medium"), Path("/lib/live/mount/medium")]
    live = any(p.exists() for p in markers)
    if live:
        return item(
            "INFO",
            "live-mode",
            "Boot mode",
            "RAH OS appears to be running as a Live USB session.",
            "Keep internal disks untouched until diagnostics are satisfactory. Session changes may be temporary without persistence.",
        )
    return item("PASS", "live-mode", "Boot mode", "No Debian Live marker detected; system appears installed or running from another layout.")


def persistence_check():
    rc, out = run_text(["findmnt", "-rn", "-o", "TARGET,SOURCE,FSTYPE,LABEL"])
    text = out.lower()
    if rc == 0 and ("persistence" in text or "/live/persistence" in text):
        return item("PASS", "persistence", "Persistence", "A persistence-related mount or label was detected.")
    if Path("/run/live/medium").exists() or Path("/lib/live/mount/medium").exists():
        return item(
            "INFO",
            "persistence",
            "Persistence",
            "No persistence mount was detected in this Live session.",
            "Treat changes as temporary unless the USB was explicitly created with persistence.",
        )
    return item("INFO", "persistence", "Persistence", "Persistence is not relevant to the detected installed-style session.")


def raven_check():
    try:
        with urllib.request.urlopen(RAVEN_HEALTH, timeout=2) as r:
            data = json.loads(r.read().decode("utf-8"))
        if data.get("status") == "ok":
            return item("PASS", "raven", "Raven Core", f"Raven health endpoint is online (version {data.get('version', 'unknown')}).")
    except Exception:
        pass

    rc, out = run_text(["systemctl", "is-active", "rah-raven-agent.service"], timeout=2)
    detail = out or "No response from Raven health endpoint."
    return item(
        "WARN",
        "raven",
        "Raven Core",
        f"Raven is not responding normally. systemd state: {detail}",
        "Suggested command only: sudo systemctl restart rah-raven-agent.service, then re-open Recovery Center.",
    )


def package_check():
    if not shutil.which("dpkg"):
        return item("INFO", "packages", "Package database", "dpkg is not available in this environment.")
    rc, out = run_text(["dpkg", "--audit"], timeout=8)
    if rc == 0 and not out.strip():
        return item("PASS", "packages", "Package database", "dpkg reports no incomplete package state.")
    if out.strip():
        return item(
            "WARN",
            "packages",
            "Package database",
            out[:500],
            "Suggested command only after review: sudo dpkg --configure -a",
        )
    return item("INFO", "packages", "Package database", "Package audit could not be completed.")


def boot_check():
    if Path("/sys/firmware/efi").exists():
        return item("PASS", "firmware-boot", "Firmware boot", "UEFI boot detected.")
    return item("INFO", "firmware-boot", "Firmware boot", "Legacy/BIOS boot detected.")


def network_check():
    base = Path("/sys/class/net")
    if not base.exists():
        return item("WARN", "network", "Network", "Network interfaces are not visible.", "Run RAH Hardware Check and inspect adapter/driver detection.")
    adapters = []
    for p in sorted(base.iterdir()):
        if p.name == "lo":
            continue
        state = read_text(p / "operstate") or "unknown"
        adapters.append(f"{p.name}:{state}")
    if not adapters:
        return item("WARN", "network", "Network", "No non-loopback adapter detected.", "Run RAH Hardware Check and inspect adapter/driver detection.")
    return item("PASS" if any(x.endswith(":up") for x in adapters) else "INFO", "network", "Network", ", ".join(adapters[:10]))


def temp_write_check():
    try:
        fd, path = tempfile.mkstemp(prefix="rah-recovery-")
        os.close(fd)
        Path(path).write_text("RAH Recovery Center self-test\n", encoding="utf-8")
        Path(path).unlink(missing_ok=True)
        return item("PASS", "temp-write", "Temporary workspace", "Temporary workspace is writable.")
    except OSError as exc:
        return item("WARN", "temp-write", "Temporary workspace", f"Temporary write failed: {exc}", "Boot a Live USB or inspect filesystem mount state before making repairs.")


def error_log_check():
    if not shutil.which("journalctl"):
        return item("INFO", "boot-errors", "Boot errors", "journalctl is not available.")
    rc, out = run_text(["journalctl", "-p", "3", "-b", "--no-pager", "-n", "25"], timeout=5)
    cleaned = "\n".join(line for line in out.splitlines() if line.strip())
    if rc == 0 and cleaned and "-- No entries --" not in cleaned:
        return item(
            "INFO",
            "boot-errors",
            "Boot errors",
            cleaned[:1600],
            "Review these entries before applying any repair. Not every error-level journal line represents a current fault.",
        )
    return item("PASS", "boot-errors", "Boot errors", "No recent priority-3 boot journal entries were returned.")


def identity_payload():
    return {
        "hostname": socket.gethostname(),
        "kernel": platform.release(),
        "architecture": platform.machine(),
        "recovery_center_version": VERSION,
        "rah_release": read_text("/etc/rah-os-release"),
    }


def recovery_payload():
    checks = [
        raven_check(),
        boot_check(),
        live_mode_check(),
        persistence_check(),
        root_mount_check(),
        root_storage_check(),
        temp_write_check(),
        package_check(),
        network_check(),
        error_log_check(),
    ]
    counts = {state: sum(1 for c in checks if c["state"] == state) for state in ("PASS", "WARN", "INFO")}
    plan = [
        {
            "priority": i + 1,
            "title": c["title"],
            "reason": c["detail"],
            "suggestion": c["suggestion"],
        }
        for i, c in enumerate(c for c in checks if c["state"] == "WARN" and c["suggestion"])
    ]
    if not plan:
        plan = [{
            "priority": 1,
            "title": "No urgent repair action",
            "reason": "Recovery Center did not detect a warning that requires a repair suggestion.",
            "suggestion": "Continue with normal RAH OS acceptance testing and keep the generated report for reference.",
        }]
    return {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "identity": identity_payload(),
        "summary": counts,
        "checks": checks,
        "repair_plan": plan,
        "safety": "Recovery Center v1 is diagnostic and advisory only. It does not format disks, install packages, modify bootloaders, or execute suggested repair commands.",
    }


def render_html(data):
    def esc(v):
        return html.escape(str(v if v is not None else ""))

    cards = []
    for c in data["checks"]:
        suggestion = f'<div class="suggest">{esc(c["suggestion"])}</div>' if c["suggestion"] else ""
        cards.append(
            f'<article class="card"><div class="state {esc(c["state"])}">{esc(c["state"])}</div>'
            f'<h3>{esc(c["title"])}</h3><pre>{esc(c["detail"])}</pre>{suggestion}</article>'
        )

    plan = "".join(
        f'<li><b>{esc(p["title"])}</b><br><span>{esc(p["suggestion"])}</span></li>'
        for p in data["repair_plan"]
    )
    s = data["summary"]
    return f'''<!doctype html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>RAH Recovery Center</title>
<style>
:root{{--bg:#070707;--panel:#111;--gold:#d9ad45;--line:#785a21;--ok:#85d37a;--warn:#ffce5b;--info:#9ecbff;--muted:#aaa}}
*{{box-sizing:border-box}} body{{margin:0;background:radial-gradient(circle at top,#1c1608 0,#070707 42%);color:#eee;font:16px system-ui,Segoe UI,sans-serif}}
main{{max-width:1200px;margin:auto;padding:34px}} .brand{{color:var(--gold);letter-spacing:.18em}} h1{{font-size:46px;margin:.25em 0}}
.hero,.card,.plan{{border:1px solid var(--line);background:rgba(15,15,15,.96);border-radius:16px;padding:20px;margin:14px 0}}
.grid{{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:14px}} .card{{margin:0;min-height:160px}}
.state{{font-weight:900;letter-spacing:.08em}} .PASS{{color:var(--ok)}} .WARN{{color:var(--warn)}} .INFO{{color:var(--info)}}
pre{{white-space:pre-wrap;font:14px ui-monospace,Consolas,monospace;color:#ccc}} .suggest{{border-top:1px solid #333;margin-top:12px;padding-top:12px;color:#f2d989}}
.summary{{display:flex;gap:12px;flex-wrap:wrap}} .pill{{border:1px solid #444;border-radius:999px;padding:8px 14px}} li{{margin:12px 0}} .muted{{color:var(--muted)}}
</style></head><body><main>
<div class="brand">RAH OS • RECOVERY CENTER v{esc(VERSION)}</div>
<h1>Recovery Center</h1>
<section class="hero"><div class="summary"><span class="pill PASS">PASS {s['PASS']}</span><span class="pill WARN">WARN {s['WARN']}</span><span class="pill INFO">INFO {s['INFO']}</span></div>
<p>{esc(data['safety'])}</p><p class="muted">Host: {esc(data['identity']['hostname'])} · Kernel: {esc(data['identity']['kernel'])} · Generated: {esc(data['generated_at'])}</p></section>
<section class="plan"><h2>Prioritized repair plan</h2><ol>{plan}</ol></section>
<section><h2>System checks</h2><div class="grid">{''.join(cards)}</div></section>
</main></body></html>'''


def output_dir():
    downloads = Path.home() / "Downloads"
    try:
        downloads.mkdir(parents=True, exist_ok=True)
        test = downloads / ".rah-write-test"
        test.write_text("ok", encoding="utf-8")
        test.unlink(missing_ok=True)
        return downloads
    except OSError:
        return Path(tempfile.gettempdir())


def write_reports(data, directory=None):
    directory = Path(directory) if directory else output_dir()
    directory.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    base = directory / f"RAH-Recovery-{stamp}"
    json_path = base.with_suffix(".json")
    html_path = base.with_suffix(".html")
    json_path.write_text(json.dumps(data, indent=2), encoding="utf-8")
    html_path.write_text(render_html(data), encoding="utf-8")
    return html_path, json_path


def open_report(path):
    if shutil.which("xdg-open"):
        subprocess.Popen(["xdg-open", str(path)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def self_test():
    fake = {
        "generated_at": "2026-01-01T00:00:00+00:00",
        "identity": {"hostname": "test-host", "kernel": "test", "architecture": "x86_64", "recovery_center_version": VERSION, "rah_release": "test"},
        "summary": {"PASS": 1, "WARN": 1, "INFO": 0},
        "checks": [
            item("PASS", "a", "Healthy", "OK"),
            item("WARN", "b", "Needs review", "Problem", "Suggested command only: example"),
        ],
        "repair_plan": [{"priority": 1, "title": "Needs review", "reason": "Problem", "suggestion": "Suggested command only: example"}],
        "safety": "diagnostic only",
    }
    text = render_html(fake)
    assert "Recovery Center" in text
    assert "Needs review" in text
    with tempfile.TemporaryDirectory() as td:
        hp, jp = write_reports(fake, td)
        assert hp.exists() and jp.exists()
        parsed = json.loads(jp.read_text(encoding="utf-8"))
        assert parsed["summary"]["WARN"] == 1
    live = recovery_payload()
    assert len(live["checks"]) >= 8
    assert set(live["summary"]) == {"PASS", "WARN", "INFO"}
    assert live["repair_plan"]
    print("RAH_RECOVERY_SELFTEST=PASS")
    return 0


def main():
    parser = argparse.ArgumentParser(description="RAH OS Recovery Center")
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--no-open", action="store_true")
    parser.add_argument("--json", action="store_true", help="Print report JSON to stdout")
    args = parser.parse_args()

    if args.self_test:
        return self_test()

    data = recovery_payload()
    if args.json:
        print(json.dumps(data, indent=2))
    html_path, json_path = write_reports(data)
    print(f"HTML={html_path}")
    print(f"JSON={json_path}")
    if not args.no_open:
        open_report(html_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
