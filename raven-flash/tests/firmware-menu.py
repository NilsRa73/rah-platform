#!/usr/bin/env python3
"""Boot the actual ISO via BIOS/UEFI; this is not a hardware speed test."""
import argparse
import pathlib
import shutil
import tempfile
import time
import pexpect

p = argparse.ArgumentParser()
p.add_argument('iso', type=pathlib.Path)
p.add_argument('log', type=pathlib.Path)
p.add_argument('--uefi', action='store_true')
a = p.parse_args()
with tempfile.TemporaryDirectory(prefix='raven-menu-') as d:
    args = ['-accel', 'tcg', '-m', '1024', '-smp', '2', '-display', 'none',
            '-monitor', 'none', '-serial', 'stdio', '-nic', 'none', '-no-reboot',
            '-cdrom', str(a.iso.resolve()), '-boot', 'd']
    if a.uefi:
        code = pathlib.Path('/usr/share/OVMF/OVMF_CODE_4M.fd')
        variables = pathlib.Path(d)/'vars.fd'
        shutil.copyfile('/usr/share/OVMF/OVMF_VARS_4M.fd', variables)
        args += ['-drive', f'if=pflash,format=raw,readonly=on,file={code}',
                 '-drive', f'if=pflash,format=raw,file={variables}']
    a.log.parent.mkdir(parents=True, exist_ok=True)
    with a.log.open('w') as log:
        child = pexpect.spawn('qemu-system-x86_64', args, encoding='utf-8',
                              codec_errors='replace', timeout=180)
        child.logfile_read = log
        try:
            child.expect('Raven Flash')
            if a.uefi:
                # GRUB's n hotkey must open the actual network submenu.
                time.sleep(.2)
                child.send('n')
                child.expect('Start iPXE')
                print('PASS: actual UEFI ISO opens network submenu; no NIC or disk', flush=True)
            else:
                child.expect('nettleser')
                print('PASS: actual BIOS ISO renders Raven boot menu', flush=True)
        finally:
            child.close(force=True)
