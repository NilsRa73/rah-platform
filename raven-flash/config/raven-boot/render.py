#!/usr/bin/env python3
"""Render menus inside live-build's binary tree; never writes host EFI/BCD."""
import pathlib
import shutil
import sys

ARGS = ('boot=live components quiet username=rah hostname=raven-flash '
        'locales=nb_NO.UTF-8 keyboard-layouts=no timezone=Europe/Oslo')


def render(binary, templates, ipxe_dir=pathlib.Path('/usr/lib/ipxe')):
    binary, templates, ipxe_dir = map(pathlib.Path, (binary, templates, ipxe_dir))
    names = {}
    for token, prefix in [('KERNEL', 'vmlinuz'), ('INITRD', 'initrd.img')]:
        files = sorted(p for p in (binary / 'live').glob(prefix + '*') if p.is_file())
        if not files:
            raise RuntimeError(f'Missing live/{prefix}*')
        names[token] = files[-1].name
    names['ARGS'] = ARGS
    destination = binary / 'boot/raven'
    destination.mkdir(parents=True, exist_ok=True)
    for name in ['ipxe.efi', 'ipxe.lkrn']:
        shutil.copyfile(ipxe_dir / name, destination / name)
    copyright_file = ipxe_dir.parent.parent / 'share/doc/ipxe/copyright'
    if copyright_file.exists():
        shutil.copyfile(copyright_file, destination / 'ipxe-copyright')
    for template, relative in [('grub.cfg.in', 'boot/grub/grub.cfg'),
                               ('isolinux.cfg.in', 'isolinux/isolinux.cfg')]:
        result = (templates / template).read_text()
        replacements = dict(names)
        if template == 'grub.cfg.in':
            replacements['ARGS'] += ' findiso=${iso_path}'
        for key, value in replacements.items():
            result = result.replace('@' + key + '@', value)
        target = binary / relative
        if not target.parent.is_dir():
            raise RuntimeError(f'Expected live-build loader directory: {target.parent}')
        target.write_text(result)
    # Keep live-build's original loopback.cfg for ISO-chainloading support.
    shutil.copyfile(templates / 'menu.ipxe', destination / 'menu.ipxe')
    print('PASS: BIOS/UEFI menus rendered with existing kernel and initrd')


if __name__ == '__main__':
    render(*sys.argv[1:])
