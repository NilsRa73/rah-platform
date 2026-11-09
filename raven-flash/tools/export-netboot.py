#!/usr/bin/env python3
"""Export the exact image's boot components, without starting any server."""
import hashlib
import pathlib
import shutil
import sys

binary, target = map(pathlib.Path, sys.argv[1:])
target.mkdir(parents=True, exist_ok=True)
for pattern, name in [('vmlinuz*', 'vmlinuz'), ('initrd.img*', 'initrd.img'),
                       ('filesystem.squashfs', 'filesystem.squashfs')]:
    files = sorted(p for p in (binary / 'live').glob(pattern) if p.is_file())
    if not files:
        raise SystemExit(f'No {pattern} in {binary}/live')
    shutil.copyfile(files[-1], target / name)
shutil.copyfile(binary / 'boot/raven/menu.ipxe', target / 'menu.ipxe')
shutil.copyfile(binary / 'boot/raven/ipxe.efi', target / 'ipxe.efi')
shutil.copyfile(binary / 'boot/raven/ipxe.lkrn', target / 'ipxe.lkrn')
with (target / 'SHA256SUMS').open('w') as sums:
    for path in sorted(target.iterdir()):
        if path.name == 'SHA256SUMS':
            continue
        with path.open('rb') as stream:
            digest = hashlib.file_digest(stream, 'sha256').hexdigest()
        sums.write(f'{digest}  {path.name}\n')
