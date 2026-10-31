#!/usr/bin/env python3
"""Boot ISO userspace in diskless QEMU; verify PAM login and GUI autologin.

The ISO kernel/initrd are extracted to append a serial console for CI. This
tests runtime user creation, the password and the graphical session, not the
firmware boot menu or any physical computer. No host disk or network is exposed.
"""
import argparse
import pathlib
import shlex
import subprocess
import tempfile

import pexpect


def boot(iso, log_path):
    iso = pathlib.Path(iso).resolve(strict=True)
    log_path = pathlib.Path(log_path)
    log_path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="raven-boot-") as work:
        work = pathlib.Path(work)
        listing = subprocess.check_output(
            ["xorriso", "-indev", str(iso), "-ls", "/live"], text=True
        )
        names = shlex.split(listing)
        for prefix, output in [("vmlinuz", "kernel"), ("initrd.img", "initrd")]:
            candidates = sorted(n for n in names if n.startswith(prefix))
            if not candidates:
                raise RuntimeError(f"ISO has no /live/{prefix}*")
            # Prefer a versioned entry; an unversioned entry may be a symlink.
            name = candidates[-1]
            subprocess.run(
                ["xorriso", "-osirrox", "on", "-indev", str(iso),
                 "-extract", f"/live/{name}", str(work / output)], check=True
            )
        args = [
            "-accel", "tcg", "-m", "2048", "-smp", "2",
            "-display", "none", "-monitor", "none", "-serial", "stdio",
            "-nic", "none", "-no-reboot", "-snapshot",
            "-cdrom", str(iso), "-kernel", str(work / "kernel"),
            "-initrd", str(work / "initrd"), "-append",
            "boot=live components username=rah hostname=raven-flash "
            "locales=nb_NO.UTF-8 keyboard-layouts=no timezone=Europe/Oslo "
            "nottyautologin console=ttyS0,115200n8",
        ]
        with log_path.open("w", encoding="utf-8") as log:
            child = pexpect.spawn("qemu-system-x86_64", args, encoding="utf-8",
                                  codec_errors="replace", timeout=300)
            child.logfile_read = log
            try:
                child.expect(r"raven-flash (?:login|innlogging):")
                child.sendline("rah")
                child.expect(r"(?i)(?:password|passord):", timeout=30)
                child.sendline("live")
                result = child.expect(
                    [r"(?i)login incorrect", r"rah@raven-flash[^\r\n]*\$ "],
                    timeout=90,
                )
                if result == 0:
                    raise RuntimeError("Actual PAM login rejected rah/live")
                # Split marker arguments so terminal echo cannot fake success.
                child.sendline(
                    "if [ \"$(id -un)\" = rah ] && sudo -n true; then "
                    "printf '\\nRAVEN_%s\\n' AUTH_OK; "
                    "else printf '\\nRAVEN_%s\\n' AUTH_FAILED; fi"
                )
                result = child.expect(["RAVEN_AUTH_OK", "RAVEN_AUTH_FAILED"], timeout=30)
                if result:
                    raise RuntimeError("Live-user identity or passwordless sudo failed")
                print("PASS: real rah/live console login and sudo", flush=True)
                # No graphical command is started from this console. These
                # processes must come from LightDM's own autologin session.
                child.sendline(
                    "ready=0; for n in $(seq 1 90); do "
                    "if pgrep -u rah -x openbox >/dev/null && "
                    "pgrep -u rah -x chromium >/dev/null; then ready=1; break; fi; "
                    "sleep 2; done; sleep 5; "
                    "if [ \"$ready\" = 1 ] && pgrep -u rah -x openbox >/dev/null && "
                    "pgrep -u rah -x chromium >/dev/null; then "
                    "printf '\\nRAVEN_%s\\n' GUI_OK; else "
                    "sudo -n journalctl -u live-config -u lightdm --no-pager -n 80; "
                    "cat ~/.xsession-errors 2>/dev/null; "
                    "printf '\\nRAVEN_%s\\n' GUI_FAILED; fi"
                )
                result = child.expect(["RAVEN_GUI_OK", "RAVEN_GUI_FAILED"], timeout=240)
                if result:
                    raise RuntimeError("Graphical autologin did not keep Openbox/Chromium running")
                print("PASS: graphical autologin runs Openbox and Chromium", flush=True)
            finally:
                child.close(force=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("iso")
    parser.add_argument("log")
    args = parser.parse_args()
    boot(args.iso, args.log)
