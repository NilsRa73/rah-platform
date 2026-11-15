#!/usr/bin/env python3
"""Run as rah inside the ISO: real Chromium close/reopen with two local tabs."""
import json
import os
import pathlib
import re
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
        # wmctrl -lx can segfault while a newly mapped window lacks WM_CLASS.
        # Read EWMH and each class separately; a tool crash must not mean closed.
        result = subprocess.run(['xprop', '-root', '_NET_CLIENT_LIST'],
                                env=env, text=True, capture_output=True, check=True)
        handles = re.findall(r'0x[0-9a-fA-F]+', result.stdout)
        found = []
        for handle in handles:
            info = subprocess.run(['xprop', '-id', handle, 'WM_CLASS'],
                                  env=env, text=True, capture_output=True)
            if info.returncode == 0 and 'chromium' in info.stdout.lower():
                found.append(handle)
        return found

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

    browser_log = pathlib.Path.home() / '.local/state/raven-flash/acceptance-browser.log'
    browser_log.parent.mkdir(parents=True, exist_ok=True)

    def start(*args):
        log = browser_log.open('ab')
        try:
            return subprocess.Popen(
                ["/usr/local/bin/raven-flash-browser", "--remote-debugging-port=9222",
                 "--remote-debugging-address=127.0.0.1", *args],
                env=env, stdout=log, stderr=subprocess.STDOUT)
        finally:
            log.close()

    def page_targets():
        try:
            with urllib.request.urlopen("http://127.0.0.1:9222/json/list", timeout=2) as response:
                return [tab for tab in json.load(response) if tab['type'] == 'page']
        except (urllib.error.URLError, OSError):
            return []

    def tabs():
        return {tab['url'] for tab in page_targets()}

    def loaded_test_tabs():
        # Target URLs can appear before file navigation commits. Require the
        # actual local documents' titles, not merely newly created targets.
        return {tab['url'] for tab in page_targets()
                if tab.get('title') in {'Raven acceptance A', 'Raven acceptance B'}}

    # The QEMU fixture has no NIC. The real local launcher must still open.
    local_url = 'file:///opt/raven-flash/start.html'
    probe = start(local_url)
    wait_for(lambda: local_url in tabs(), "Offline Raven start page did not open")
    print("PASS: local Raven start page opens in Chromium with no NIC", flush=True)
    close_browser()
    probe.wait(timeout=30)
    process = start(*sorted(urls))
    wait_for(lambda: urls <= loaded_test_tabs(), "Two real test documents did not finish loading")
    time.sleep(3)  # Let the startup/session state settle before a user-style close.
    close_browser()
    process.wait(timeout=30)
    time.sleep(2)
    restored = start()
    try:
        wait_for(lambda: urls <= loaded_test_tabs(), "Closed tabs were not restored from the same profile")
    except Exception:
        print('DIAGNOSTIC restored URLs:', sorted(tabs()), flush=True)
        profile = pathlib.Path.home() / '.local/share/raven-flash/chromium/Default'
        prefs = profile / 'Preferences'
        if prefs.exists():
            data = json.loads(prefs.read_text())
            print('DIAGNOSTIC session preferences:', data.get('session'), flush=True)
        print('DIAGNOSTIC session files:', [p.name for p in (profile / 'Sessions').glob('*')], flush=True)
        raise
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
                     pathlib.Path.home() / '.local/state/raven-flash/browser.log',
                     pathlib.Path.home() / '.local/state/raven-flash/acceptance-browser.log']:
            if path.exists():
                print(f"DIAGNOSTIC {path}:\n{path.read_text(errors='replace')[-10000:]}", flush=True)
        raise
