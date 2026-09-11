from __future__ import annotations

import importlib.util
import io
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / 'rah-node-agent-v1.4-candidate.py'
spec = importlib.util.spec_from_file_location('rah_node14_raven_status_candidate', MODULE_PATH)
if spec is None or spec.loader is None:
    raise RuntimeError('Unable to load Node 1.4 candidate')
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
            {'ok': True, 'accepted': True, 'job': {'id': 'job-fixed-1', 'status': 'queued'}},
            {'ok': True, 'job': {'id': 'job-fixed-1', 'status': 'running'}},
            {'ok': True, 'job': {
                'id': 'job-fixed-1',
                'status': 'succeeded',
                'result': {
                    'ok': True,
                    'read_only': True,
                    'files_modified': False,
                    'arbitrary_commands': False,
                    'stdout': 'inventory-ok',
                },
            }},
        ]
    def __call__(self, request, timeout=None):
        self.calls.append({
            'url': request.full_url,
            'method': request.get_method(),
            'data': request.data,
            'timeout': timeout,
        })
        if not self.responses:
            raise AssertionError('Unexpected extra local Raven request')
        return FakeResponse(self.responses.pop(0))


def test_canonical_route_boundary():
    session = 'Session_ABCDEFGHIJKLMNOPQRSTUVWXYZ1234'
    nonce = 'Nonce_ABCDEFGHIJKLMNOPQRSTUVWXYZ1234'
    good = mod.canonical_request(session, nonce, 'GET', '/raven/status', b'', {})
    assert good.startswith('RAH-AUTH-V2\n')
    assert '\nGET\n/raven/status\n' in good
    assert mod.canonical_request(session, nonce, 'POST', '/raven/status', b'', {}) == ''
    assert mod.canonical_request(session, nonce, 'GET', '/raven/status', b'x', {}) == ''
    assert mod.canonical_request(session, nonce, 'GET', '/raven/status?x=1', b'', {}) == ''
    assert mod.canonical_request(session, nonce, 'GET', '/raven/status', b'', {
        mod.REQUESTER_CONTEXT_HEADER: 'A' * 40,
    }) == ''


def test_proxy_is_fixed_local_read_only_job():
    opener = FakeOpener()
    ticks = iter([0.0, 0.0, 0.1, 0.2, 0.3])
    result = mod.read_local_raven_status(
        opener=opener,
        sleep_fn=lambda _seconds: None,
        clock=lambda: next(ticks, 0.4),
    )
    assert result['ok'] is True
    assert result['protocol'] == 'rah-node-raven-status-v1'
    assert result['capability'] == 'system-inventory'
    assert result['arbitraryCommands'] is False
    assert result['argumentsAllowed'] is False
    assert result['localOnlyHop'] is True
    assert len(opener.calls) == 3

    first = opener.calls[0]
    assert first['url'] == 'http://127.0.0.1:18765/agent/jobs'
    assert first['method'] == 'POST'
    body = json.loads(first['data'].decode('utf-8'))
    assert body == {
        'capability': 'system-inventory',
        'confirm': True,
        'client_request_id': 'node-raven-status-v1',
    }

    for call in opener.calls:
        assert call['url'].startswith('http://127.0.0.1:18765/')
        assert 'localhost' not in call['url']
        assert not call['url'].startswith('http://0.0.0.0')


def test_non_local_url_is_rejected():
    try:
        mod._request_json('http://192.168.0.1:18765/agent/jobs')
    except RuntimeError as exc:
        assert str(exc) == 'local_raven_url_not_allowed'
    else:
        raise AssertionError('Non-local Raven URL was accepted')


if __name__ == '__main__':
    test_canonical_route_boundary()
    test_proxy_is_fixed_local_read_only_job()
    test_non_local_url_is_rejected()
    print('RAH Node Agent 1.4 Raven status candidate boundary tests: OK')
