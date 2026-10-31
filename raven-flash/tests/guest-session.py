#!/usr/bin/env python3
"""Run as rah inside the ISO: real Chromium close/reopen with two local tabs."""
import json
import os
import pathlib
import subprocess
import time
import urllib.error
import urllib.request


def wait_for(predicate, description, seconds=90):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        if predicate():
            return
        time.sleep(1)
    raise RuntimeError(description)


def main():
    window_manager = int(subprocess.check_output(
        ["pgrep", "-u", str(os.getuid()), "-x", "openbox"], text=True).split()[0])
    raw = pathlib.Path(f"/proc/{window_manager}/environ").read_bytes()
    env = os.environ.copy()
    env.update(dict(item.decode().split("=", 1) for item in raw.split(b"\0") if b"=" in item))

    def desktop_alive():
        return pathlib.Path(f"/proc/{window_manager}").exists()

    def windows():
        result = subprocess.run(["wmctrl", "-lx"], env=env, text=True,
                                capture_output=True)
        # A running Chromium/Openbox process is not yet a mapped window in TCG.
        # Missing EWMH client-list properties during startup mean not ready.
        if result.returncode:
            return []
        return [line.split()[0] for line in result.stdout.splitlines()
                if len(line.split()) > 2 and "chromium" in line.split()[2].lower()]

    def close_browser():
        handles = windows()
        if not handles:
            raise RuntimeError("No Chromium window to close")
        for handle in handles:
            subprocess.run(["wmctrl", "-ic", handle], env=env, check=True)
        wait_for(lambda: not windows(), "Chromium did not close cleanly")
        # Also wait for the main browser process, not just its X11 window.
        def browser_stopped():
            for path in pathlib.Path('/proc').glob('[0-9]*/cmdline'):
                try:
                    args = path.read_bytes().split(b'\0')
                    if (path.stat().st_uid == os.getuid() and args
                            and args[0].endswith(b'/chromium')
                            and not any(a.startswith(b'--type=') for a in args)):
                        return False
                except (FileNotFoundError, PermissionError, ProcessLookupError):
                    pass
            return True
        wait_for(browser_stopped, "Chromium process did not finish shutdown")
        if not desktop_alive():
            raise RuntimeError("Closing Chromium ended the desktop session")

    # Close the browser that LightDM autologin opened, without starting a new desktop.
    wait_for(lambda: bool(windows()), "Autostart Chromium never mapped a real X11 window", seconds=120)
    close_browser()
    print("PASS: closing the autostart browser leaves the same desktop alive", flush=True)
    pages = pathlib.Path.home() / ".local/share/raven-flash/acceptance-pages"
    pages.mkdir(parents=True, exist_ok=True)
    urls = set()
    for letter in "AB":
        page = pages / f"tab-{letter}.html"
        page.write_text(f"<title>Raven acceptance {letter}</title><h1>Tab {letter}</h1>")
        urls.add(page.as_uri())

    def start(*args):
        return subprocess.Popen(
            ["/usr/local/bin/raven-flash-browser", "--remote-debugging-port=9222",
             "--remote-debugging-address=127.0.0.1", *args],
            env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    def tabs():
        try:
            with urllib.request.urlopen("http://127.0.0.1:9222/json/list", timeout=2) as response:
                return {tab["url"] for tab in json.load(response) if tab["type"] == "page"}
        except (urllib.error.URLError, OSError):
            return set()

    # The QEMU fixture has no NIC. The real local launcher must still open.
    local_url = 'file:///opt/raven-flash/start.html'
    probe = start(local_url)
    wait_for(lambda: local_url in tabs(), "Offline Raven start page did not open")
    print("PASS: local Raven start page opens in Chromium with no NIC", flush=True)
    close_browser()
    probe.wait(timeout=30)
    process = start(*sorted(urls))
    wait_for(lambda: urls <= tabs(), "Two real test tabs did not open")
    close_browser()
    process.wait(timeout=30)
    time.sleep(2)
    restored = start()
    wait_for(lambda: urls <= tabs(), "Closed tabs were not restored from the same profile")
    if not desktop_alive():
        raise RuntimeError("Window manager changed during browser recovery")
    print("PASS: two real Chromium tabs restored after a clean window close", flush=True)
    close_browser()
    restored.wait(timeout=30)
    print("RAVEN_SESSION_OK", flush=True)


if __name__ == "__main__":
    try:
        main()
    except Exception:
        for path in [pathlib.Path.home() / '.xsession-errors',
                     pathlib.Path.home() / '.local/state/raven-flash/browser.log']:
            if path.exists():
                print(f"DIAGNOSTIC {path}:\n{path.read_text(errors='replace')[-10000:]}", flush=True)
        raise
