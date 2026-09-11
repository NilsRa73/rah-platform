from __future__ import annotations

import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / 'rah-node-agent-v1.4.py'
spec = importlib.util.spec_from_file_location('rah_node14_stable', MODULE_PATH)
if spec is None or spec.loader is None:
    raise RuntimeError('Unable to load Stable Node Agent 1.4')
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


class FakeResponse:
    def __init__(self, payload):
        self._raw = json.dumps(payload, separators=(',', ':')).encode('utf-8')
    def __enter__(self):
        return self
    def __exit__(self, exc_type, exc, tb):
        return False
    def read(self, size=-1):
        return self._raw if size < 0 else self._raw[:size]


class FakeOpener:
    def __init__(self):
        self.calls = []
        self.responses = [
            {'ok': True, 'accepted': True, 'job': {'id': 'job-stable-1', 'status': 'queued'}},
            {'ok': True, 'job': {'id': 'job-stable-1', 'status': 'succeeded', 'result': {
                'ok': True,
                'read_only': True,
                'files_modified': False,
                'arbitrary_commands': False,
                'stdout': 'inventory-stable-ok',
            }}},
        ]
    def __call__(self, request, timeout=None):
        self.calls.append((request.full_url, request.get_method(), request.data, timeout))
        if not self.responses:
            raise AssertionError('Unexpected extra Raven request')
        return FakeResponse(self.responses.pop(0))


def test_stable_identity_and_health_contract():
    assert mod.AGENT_VERSION == '1.4.0'
    assert mod.RAVEN_STATUS_PROTOCOL == 'rah-node-raven-status-v1'
    assert mod.RAVEN_STATUS_ROUTE == '/raven/status'
    assert mod.RAVEN_FIXED_CAPABILITY == 'system-inventory'
    health = mod.build_health_payload('NODE-STABLE', 'worker', ['compute'], 'Session_ABCDEFGHIJKLMNOPQRSTUVWXYZ1234')
    assert health['agentVersion'] == '1.4.0'
    assert health['ravenStatusProtocol'] == 'rah-node-raven-status-v1'
    assert health['ravenStatusRoute'] == '/raven/status'
    assert health['ravenStatusFixedCapability'] == 'system-inventory'
    assert health['ravenStatusLocalOnlyHop'] is True


def test_stable_handler_identity():
    handler = mod.make_handler(
        'Token_ABCDEFGHIJKLMNOPQRSTUVWXYZ1234',
        'NODE-STABLE',
        'worker',
        ['compute'],
        session_id='Session_ABCDEFGHIJKLMNOPQRSTUVWXYZ1234',
        interactive_console=False,
        raven_status_reader=lambda: {
            'ok': True,
            'protocol': 'rah-node-raven-status-v1',
            'source': 'local-raven-job-executor',
            'capability': 'system-inventory',
            'arbitraryCommands': False,
            'argumentsAllowed': False,
            'localOnlyHop': True,
            'result': {'ok': True, 'read_only': True, 'files_modified': False, 'arbitrary_commands': False},
        },
    )
    assert handler.server_version == 'RAHNodeAgent/1.4'


def test_fixed_local_raven_job_is_preserved():
    opener = FakeOpener()
    ticks = iter([0.0, 0.0, 0.1, 0.2])
    result = mod.read_local_raven_status(
        opener=opener,
        sleep_fn=lambda _seconds: None,
        clock=lambda: next(ticks, 0.3),
    )
    assert result['ok'] is True
    assert result['protocol'] == 'rah-node-raven-status-v1'
    assert result['capability'] == 'system-inventory'
    assert result['arbitraryCommands'] is False
    assert result['argumentsAllowed'] is False
    assert result['localOnlyHop'] is True
    assert opener.calls[0][0] == 'http://127.0.0.1:18765/agent/jobs'
    body = json.loads(opener.calls[0][2].decode('utf-8'))
    assert body == {
        'capability': 'system-inventory',
        'confirm': True,
        'client_request_id': 'node-raven-status-v1',
    }
    assert all(url.startswith('http://127.0.0.1:18765/') for url, *_ in opener.calls)


def test_existing_auth_boundary_is_preserved():
    session = 'Session_ABCDEFGHIJKLMNOPQRSTUVWXYZ1234'
    nonce = 'Nonce_ABCDEFGHIJKLMNOPQRSTUVWXYZ1234'
    good = mod.canonical_request(session, nonce, 'GET', '/raven/status', b'', {})
    assert good.startswith('RAH-AUTH-V2\n')
    assert '\nGET\n/raven/status\n' in good
    assert mod.canonical_request(session, nonce, 'POST', '/raven/status', b'', {}) == ''
    assert mod.canonical_request(session, nonce, 'GET', '/raven/status?x=1', b'', {}) == ''


if __name__ == '__main__':
    test_stable_identity_and_health_contract()
    test_stable_handler_identity()
    test_fixed_local_raven_job_is_preserved()
    test_existing_auth_boundary_is_preserved()
    print('Stable Node Agent 1.4 Raven status promotion tests: OK')
