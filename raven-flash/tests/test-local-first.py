#!/usr/bin/env python3
"""Offline startup contract: no remote assets, no mandatory network, build options."""
from html.parser import HTMLParser
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
INCLUDES = ROOT / 'config/includes.chroot'

class Resources(HTMLParser):
    def __init__(self):
        super().__init__(); self.external = []; self.csp = ''
    def handle_starttag(self, tag, attributes):
        attrs = dict(attributes)
        if tag in ('script', 'img', 'iframe', 'audio', 'video', 'source') and attrs.get('src'):
            self.external.append(attrs['src'])
        if tag == 'link' and attrs.get('href'):
            self.external.append(attrs['href'])
        if tag == 'meta' and attrs.get('http-equiv', '').lower() == 'content-security-policy':
            self.csp = attrs.get('content', '')

class LocalFirst(unittest.TestCase):
    def test_start_page_is_self_contained_and_blocks_network_fetches(self):
        parser = Resources()
        parser.feed((INCLUDES / 'opt/raven-flash/start.html').read_text())
        self.assertEqual(parser.external, [])
        self.assertIn("connect-src 'none'", parser.csp)
        self.assertIn("default-src 'none'", parser.csp)

    def test_first_browser_launch_is_local_and_retains_sandbox(self):
        launcher = (INCLUDES / 'usr/local/bin/raven-flash-browser').read_text()
        self.assertIn('file:///opt/raven-flash/start.html', launcher)
        self.assertNotIn('--no-sandbox', launcher)
        self.assertNotIn('curl ', launcher)

    def test_network_starts_without_a_required_wait_online(self):
        hook = (ROOT / 'config/hooks/live/0210-raven-local-first.hook.chroot').read_text()
        self.assertIn('systemctl mask NetworkManager-wait-online.service', hook)
        self.assertNotIn('mask NetworkManager.service', hook)
        session = (INCLUDES / 'usr/local/bin/raven-flash-session').read_text()
        self.assertNotIn('nm-online', session)
        self.assertNotIn('sleep ', session)

    def test_build_uses_documented_fast_decompression_candidate(self):
        build = (ROOT / 'build.sh').read_text()
        self.assertIn('--chroot-squashfs-compression-type zstd', build)
        self.assertIn('--chroot-squashfs-compression-level 3', build)
        self.assertNotIn('toram', build)  # Whole-image RAM copying is an A/B test later.

if __name__ == '__main__':
    unittest.main()
