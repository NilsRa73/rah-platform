from __future__ import annotations

import unittest
from unittest.mock import patch

import server


class DesktopBridgeTests(unittest.TestCase):
    def setUp(self):
        server.app.config.update(TESTING=True)
        self.client = server.app.test_client()

    def test_health(self):
        response = self.client.get('/health')
        self.assertEqual(response.status_code, 200)
        body = response.get_json()
        self.assertTrue(body['ok'])
        self.assertEqual(body['version'], server.APP_VERSION)

    @patch('server.capture_active_window')
    def test_capture_success(self, capture):
        capture.return_value = (
            'data:image/png;base64,ZmFrZQ==',
            {'width': 100, 'height': 50, 'capture': 'active-window'},
        )
        response = self.client.get('/capture/active-window')
        self.assertEqual(response.status_code, 200)
        body = response.get_json()
        self.assertTrue(body['ok'])
        self.assertTrue(body['image'].startswith('data:image/png;base64,'))
        self.assertEqual(body['metadata']['width'], 100)

    @patch('server.capture_active_window', side_effect=RuntimeError('capture failed'))
    def test_capture_error_is_json(self, _capture):
        response = self.client.get('/capture/active-window')
        self.assertEqual(response.status_code, 500)
        body = response.get_json()
        self.assertFalse(body['ok'])
        self.assertIn('capture failed', body['error'])


if __name__ == '__main__':
    unittest.main()
