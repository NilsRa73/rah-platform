#!/usr/bin/env python3
"""Render real loader configs, syntax-check GRUB and exercise netboot export."""
import importlib.util
import json
import pathlib
import shutil
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('render', ROOT / 'config/raven-boot/render.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class SlimMenu(unittest.TestCase):
    def test_rendered_grub_parses_and_netboot_bytes_match(self):
        with tempfile.TemporaryDirectory() as d:
            root = pathlib.Path(d)
            binary, ipxe = root/'binary', root/'ipxe'
            for p in ['live', 'boot/grub', 'isolinux']:
                (binary / p).mkdir(parents=True)
            ipxe.mkdir()
            for name in ['ipxe.efi', 'ipxe.lkrn']:
                (ipxe / name).write_bytes(b'fixture ipxe')
            for name in ['vmlinuz-6-test', 'initrd.img-6-test', 'filesystem.squashfs']:
                (binary / 'live' / name).write_bytes(name.encode())
            for name in ['menu.c32', 'libcom32.c32', 'libutil.c32']:
                (ipxe / name).write_bytes(b'fixture module')
            module.render(binary, ROOT/'config/raven-boot', ipxe, ipxe)
            self.assertEqual((binary/'isolinux/menu.c32').read_bytes(), b'fixture module')
            grub = binary/'boot/grub/grub.cfg'
            text = grub.read_text()
            self.assertNotIn('@KERNEL@', text)
            self.assertIn('findiso=${iso_path}', text)
            self.assertIn('linux /live/vmlinuz-6-test boot=live', text)
            self.assertLess(text.index("menuentry 'Raven Flash"), text.index('submenu'))
            checker = shutil.which('grub-script-check')
            if not checker:
                self.fail('grub-script-check is required for real loader syntax validation')
            subprocess.run([checker, str(grub)], check=True)
            subprocess.run(['python3', str(ROOT/'tools/export-netboot.py'),
                            str(binary), str(root/'netboot')], check=True)
            for source, output in [('vmlinuz-6-test', 'vmlinuz'),
                                    ('initrd.img-6-test', 'initrd.img'),
                                    ('filesystem.squashfs', 'filesystem.squashfs')]:
                self.assertEqual((binary/'live'/source).read_bytes(),
                                 (root/'netboot'/output).read_bytes())
            subprocess.run(['sha256sum', '-c', 'SHA256SUMS'], cwd=root/'netboot', check=True)

    def test_missing_kernel_fails_before_menu_write(self):
        with tempfile.TemporaryDirectory() as d:
            with self.assertRaisesRegex(RuntimeError, 'Missing live/vmlinuz'):
                module.render(pathlib.Path(d), ROOT/'config/raven-boot')

    def test_metrics_uses_file_bytes_and_no_fabricated_speed(self):
        with tempfile.TemporaryDirectory() as d:
            root = pathlib.Path(d)
            (root/'old.iso').write_bytes(b'0'*200)
            (root/'new.iso').write_bytes(b'0'*150)
            subprocess.run(['python3', str(ROOT/'tools/image-metrics.py'),
                            str(root/'new.iso'), str(root/'result.json'),
                            '--baseline', str(root/'old.iso')], check=True)
            result = json.loads((root/'result.json').read_text())
            self.assertEqual(result['saved_percent'], 25)
            self.assertEqual(result['size_bytes'], 150)
            self.assertIsNone(result['physical_boot_seconds'])


if __name__ == '__main__':
    unittest.main()
