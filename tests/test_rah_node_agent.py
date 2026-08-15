import importlib.util
import json
import threading
import unittest
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('rah_node_agent', ROOT / 'rah-node-agent.py')
agent = importlib.util.module_from_spec(spec)
spec.loader.exec_module(agent)


class NodeAgentV08Tests(unittest.TestCase):
    def setUp(self):
        self.token = 'token-abcdefghijklmnopqrstuvwxyz'
        self.session = 'SessionId_abcdefghijklmnop'
        self.launched = []
        self.handoffs = []
        self.server = agent.create_server(
            '127.0.0.1',
            0,
            self.token,
            'Node',
            'Role',
            ['storage', 'remote-desktop'],
            {'rustdesk': '/fixed/rustdesk'},
            lambda path: self.launched.append(path) or True,
            lambda path, peer: self.handoffs.append((path, peer)) or True,
            session_id=self.session,
        )
        self.port = self.server.server_address[1]
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=2)

    def request(
        self,
        path='/health',
        *,
        token=None,
        method='GET',
        origin='null',
        port=None,
        data=None,
        content_type=None,
        challenge=None,
        private_network=False,
    ):
        headers = {'Origin': origin}
        if token is not None:
            headers['Authorization'] = 'Bearer ' + token
        if content_type is not None:
            headers['Content-Type'] = content_type
        if challenge is not None:
            headers[agent.ACTION_CHALLENGE_HEADER] = challenge
        if private_network:
            headers['Access-Control-Request-Private-Network'] = 'true'
        payload = data.encode() if isinstance(data, str) else data
        req = urllib.request.Request(
            f'http://127.0.0.1:{port or self.port}{path}',
            headers=headers,
            method=method,
            data=payload,
        )
        try:
            with urllib.request.urlopen(req, timeout=2) as res:
                raw = res.read()
                return res.status, dict(res.headers), json.loads(raw or b'{}')
        except urllib.error.HTTPError as exc:
            raw = exc.read()
            return exc.code, dict(exc.headers), json.loads(raw or b'{}')

    def catalog(self, *, token=None, port=None):
        status, _, payload = self.request('/actions', token=token or self.token, port=port)
        self.assertEqual(status, 200)
        return payload

    def challenge(self, action_id):
        payload = self.catalog()
        return next(row for row in payload['actions'] if row['id'] == action_id)['challenge']

    def health_from_new_server(self, server, token):
        port = server.server_address[1]
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            status, _, payload = self.request('/health', token=token, port=port)
            self.assertEqual(status, 200)
            return payload
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=2)

    def test_auth_health_and_actions_share_exact_session(self):
        self.assertEqual(self.request('/health')[0], 401)
        status, _, health = self.request('/health', token=self.token)
        self.assertEqual(status, 200)
        actions = self.catalog()
        self.assertEqual(health['protocol'], 'rah-node-health-v2')
        self.assertEqual(actions['protocol'], 'rah-node-actions-v3')
        self.assertEqual(health['sessionId'], self.session)
        self.assertEqual(actions['sessionId'], self.session)
        self.assertEqual(health['agentVersion'], '0.8.0')
        self.assertEqual([x['id'] for x in actions['actions']], ['storage-summary.read', 'rustdesk.launch', 'rustdesk.connect'])
        for row in actions['actions']:
            self.assertEqual(row['challengeTtlSeconds'], 60)
            self.assertRegex(row['challenge'], r'^[A-Za-z0-9_-]{24,64}$')
            for forbidden in ('url', 'command', 'arguments', 'executable', 'password', 'peerId'):
                self.assertNotIn(forbidden, row)

    def test_restart_rotates_actual_session_id(self):
        token1 = 'a' * 32
        token2 = 'b' * 32
        server1 = agent.create_server('127.0.0.1', 0, token1, capabilities=[])
        server2 = agent.create_server('127.0.0.1', 0, token2, capabilities=[])
        health1 = self.health_from_new_server(server1, token1)
        health2 = self.health_from_new_server(server2, token2)
        self.assertRegex(health1['sessionId'], r'^[A-Za-z0-9_-]{20,64}$')
        self.assertRegex(health2['sessionId'], r'^[A-Za-z0-9_-]{20,64}$')
        self.assertNotEqual(health1['sessionId'], health2['sessionId'])

    def test_storage_challenge_is_action_bound_single_use_and_refresh_invalidates(self):
        self.assertEqual(self.request('/storage', token=self.token)[0], 428)
        first = self.catalog()
        storage = next(x for x in first['actions'] if x['id'] == 'storage-summary.read')['challenge']
        launch = next(x for x in first['actions'] if x['id'] == 'rustdesk.launch')['challenge']
        self.assertEqual(self.request('/storage', token=self.token, challenge=launch)[0], 409)
        refreshed = self.catalog()
        new_storage = next(x for x in refreshed['actions'] if x['id'] == 'storage-summary.read')['challenge']
        self.assertNotEqual(storage, new_storage)
        self.assertEqual(self.request('/storage', token=self.token, challenge=storage)[0], 409)
        status, _, payload = self.request('/storage', token=self.token, challenge=new_storage)
        self.assertEqual(status, 200)
        self.assertEqual(payload['protocol'], 'rah-node-storage-v1')
        self.assertEqual(self.request('/storage', token=self.token, challenge=new_storage)[0], 409)

    def test_rustdesk_launch_requires_challenge_and_rejects_body(self):
        self.assertEqual(self.request('/launch/rustdesk', token=self.token, method='POST')[0], 428)
        challenge = self.challenge('rustdesk.launch')
        self.assertEqual(
            self.request(
                '/launch/rustdesk',
                token=self.token,
                method='POST',
                data='{}',
                content_type='application/json',
                challenge=challenge,
            )[0],
            400,
        )
        challenge = self.challenge('rustdesk.launch')
        status, _, payload = self.request('/launch/rustdesk', token=self.token, method='POST', challenge=challenge)
        self.assertEqual(status, 200)
        self.assertEqual(payload, {'protocol': 'rah-node-launch-v1', 'status': 'launched', 'app': 'rustdesk'})
        self.assertEqual(self.launched, ['/fixed/rustdesk'])
        self.assertEqual(self.request('/launch/rustdesk', token=self.token, method='POST', challenge=challenge)[0], 409)

    def test_handoff_is_peer_id_only_password_free_and_single_use(self):
        challenge = self.challenge('rustdesk.connect')
        self.assertEqual(
            self.request(
                '/handoff/rustdesk',
                token=self.token,
                method='POST',
                data='{"peerId":"123456789","password":"secret"}',
                content_type='application/json',
                challenge=challenge,
            )[0],
            400,
        )
        challenge = self.challenge('rustdesk.connect')
        self.assertEqual(
            self.request(
                '/handoff/rustdesk',
                token=self.token,
                method='POST',
                data='{"peerId":"123456789 --password secret"}',
                content_type='application/json',
                challenge=challenge,
            )[0],
            400,
        )
        challenge = self.challenge('rustdesk.connect')
        status, _, payload = self.request(
            '/handoff/rustdesk',
            token=self.token,
            method='POST',
            data='{"peerId":"123456789"}',
            content_type='application/json',
            challenge=challenge,
        )
        self.assertEqual(status, 200)
        self.assertEqual(payload, {'protocol': 'rah-node-handoff-v1', 'status': 'handoff-started', 'app': 'rustdesk'})
        self.assertEqual(self.handoffs, [('/fixed/rustdesk', '123456789')])
        self.assertEqual(
            self.request(
                '/handoff/rustdesk',
                token=self.token,
                method='POST',
                data='{"peerId":"123456789"}',
                content_type='application/json',
                challenge=challenge,
            )[0],
            409,
        )

    def test_capability_and_fixed_endpoint_boundaries(self):
        token = 'compute-only-token-abcdefghijklmnopqrstuvwxyz'
        session = 'ComputeSession_abcdefghijkl'
        server = agent.create_server(
            '127.0.0.1',
            0,
            token,
            'Compute',
            'Read only',
            ['compute'],
            {'rustdesk': '/fixed/rustdesk'},
            lambda path: True,
            lambda path, peer: True,
            session_id=session,
        )
        port = server.server_address[1]
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            actions = self.catalog(token=token, port=port)
            self.assertEqual(actions['sessionId'], session)
            self.assertEqual(actions['actions'], [])
            self.assertEqual(self.request('/storage', token=token, port=port)[0], 403)
            self.assertEqual(self.request('/launch/rustdesk', token=token, method='POST', port=port)[0], 403)
            self.assertEqual(
                self.request(
                    '/handoff/rustdesk',
                    token=token,
                    method='POST',
                    port=port,
                    data='{"peerId":"123456789"}',
                    content_type='application/json',
                )[0],
                403,
            )
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=2)
        for path in ('/command', '/action', '/action/run', '/files', '/shell', '/launch', '/launch/calc', '/handoff', '/connect', '/remote-control'):
            self.assertEqual(self.request(path, token=self.token)[0], 404, path)

    def test_origin_pna_and_cors_boundary(self):
        self.assertEqual(self.request('/health', token=self.token, origin='https://evil.example')[0], 403)
        for path in ('/health', '/actions', '/storage', '/launch/rustdesk', '/handoff/rustdesk'):
            status, headers, _ = self.request(path, method='OPTIONS', private_network=True)
            self.assertEqual(status, 204)
            self.assertIn(agent.ACTION_CHALLENGE_HEADER, headers.get('Access-Control-Allow-Headers', ''))
            self.assertEqual(headers.get('Access-Control-Allow-Private-Network'), 'true')

    def test_source_has_no_generic_authority(self):
        source = (ROOT / 'rah-node-agent.py').read_text()
        self.assertIn('secrets.token_urlsafe(18)', source)
        self.assertIn('subprocess.Popen([path,"--connect",peer_id]', source)
        self.assertIn('"shell":False', source)
        self.assertNotIn('os.system', source)
        self.assertNotIn('shell=True', source)
        self.assertNotIn('"--password"', source)
        self.assertNotIn('/action/run', source)


if __name__ == '__main__':
    unittest.main()
