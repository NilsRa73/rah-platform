#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import json
import secrets
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

STABLE_PATH = Path(__file__).with_name('rah-node-agent-v1.3.py')
_spec = importlib.util.spec_from_file_location('rah_node_agent_v13_stable_for_v14', STABLE_PATH)
if _spec is None or _spec.loader is None:
    raise RuntimeError('Unable to load Stable Node Agent 1.3')
_stable = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_stable)
_impl = _stable._impl
_base = _impl._base

AGENT_VERSION = '1.4.0-candidate'
RAVEN_STATUS_PROTOCOL = 'rah-node-raven-status-v1'
RAVEN_STATUS_ROUTE = '/raven/status'
RAVEN_LOCAL_BASE = 'http://127.0.0.1:18765'
RAVEN_FIXED_CAPABILITY = 'system-inventory'
RAVEN_REQUEST_TIMEOUT_SECONDS = 3.0
RAVEN_JOB_WAIT_SECONDS = 25.0
RAVEN_MAX_RESPONSE_BYTES = 256 * 1024
ROUTES = tuple(_stable.ROUTES) + (RAVEN_STATUS_ROUTE,)

ACTIONS_PROTOCOL = _stable.ACTIONS_PROTOCOL
AUTH_PROTOCOL = _stable.AUTH_PROTOCOL
ALLOWLIST_POLICY_ID = _stable.ALLOWLIST_POLICY_ID
AUTH_INIT_HEADER = _stable.AUTH_INIT_HEADER
AUTH_NONCE_HEADER = _stable.AUTH_NONCE_HEADER
AUTH_PROOF_HEADER = _stable.AUTH_PROOF_HEADER
REQUESTER_CONTEXT_HEADER = _stable.REQUESTER_CONTEXT_HEADER
APPROVAL_ACTION_HEADER = _stable.APPROVAL_ACTION_HEADER
APPROVAL_TARGET_HEADER = _stable.APPROVAL_TARGET_HEADER
LOCAL_APPROVAL_HEADER = _stable.LOCAL_APPROVAL_HEADER
ACTION_CHALLENGE_HEADER = _stable.ACTION_CHALLENGE_HEADER
PORT = _stable.PORT
ALLOWED_CAPABILITIES = _stable.ALLOWED_CAPABILITIES
ACTION_CATALOG = _stable.ACTION_CATALOG
sanitize_capabilities = _stable.sanitize_capabilities
build_app_paths = _stable.build_app_paths
_proof = _stable._proof


def canonical_request(session_id, nonce, method, path, body_bytes=b'', headers=None):
    if path != RAVEN_STATUS_ROUTE:
        return _stable.canonical_request(session_id, nonce, method, path, body_bytes, headers)

    session = _base.sanitize_session_id(session_id)
    safe_nonce = nonce if _impl._safe_token(nonce) else ''
    verb = method.upper() if isinstance(method, str) else ''
    fields = _impl._security_fields(headers or {})
    if not session or not safe_nonce or fields is None:
        return ''
    if verb != 'GET' or body_bytes or '?' in path or '#' in path:
        return ''
    if any(fields.values()):
        return ''
    return '\n'.join([
        _impl.AUTH_CANONICAL_VERSION,
        session,
        safe_nonce,
        verb,
        path,
        _impl._body_sha256(body_bytes),
        fields['approvalAction'],
        fields['approvalTarget'],
        fields['requesterContext'],
        fields['actionChallenge'],
        fields['nodeLocalApprovalProof'],
    ])


# The Stable v1.3 handler resolves canonical_request through its candidate
# module globals. Patch only this in-memory module instance; stable files on
# disk are never modified.
_impl.canonical_request = canonical_request


def _read_json_response(response):
    raw = response.read(RAVEN_MAX_RESPONSE_BYTES + 1)
    if len(raw) > RAVEN_MAX_RESPONSE_BYTES:
        raise RuntimeError('local_raven_response_too_large')
    value = json.loads(raw.decode('utf-8'))
    if not isinstance(value, dict):
        raise RuntimeError('local_raven_response_not_object')
    return value


def _request_json(url, method='GET', payload=None, timeout=RAVEN_REQUEST_TIMEOUT_SECONDS, opener=None):
    if not isinstance(url, str) or not url.startswith(RAVEN_LOCAL_BASE + '/'):
        raise RuntimeError('local_raven_url_not_allowed')
    data = None
    headers = {'Accept': 'application/json'}
    if payload is not None:
        data = json.dumps(payload, separators=(',', ':')).encode('utf-8')
        headers['Content-Type'] = 'application/json'
    request = urllib.request.Request(url, data=data, headers=headers, method=method)
    open_fn = urllib.request.urlopen if opener is None else opener
    with open_fn(request, timeout=timeout) as response:
        return _read_json_response(response)


def read_local_raven_status(opener=None, sleep_fn=None, clock=None):
    sleep = time.sleep if sleep_fn is None else sleep_fn
    monotonic = time.monotonic if clock is None else clock
    payload = {
        'capability': RAVEN_FIXED_CAPABILITY,
        'confirm': True,
        'client_request_id': 'node-raven-status-v1',
    }
    try:
        accepted = _request_json(
            RAVEN_LOCAL_BASE + '/agent/jobs',
            method='POST',
            payload=payload,
            opener=opener,
        )
        job = accepted.get('job') if isinstance(accepted.get('job'), dict) else {}
        job_id = str(job.get('id') or '')
        if not accepted.get('ok') or not accepted.get('accepted') or not job_id:
            return {'ok': False, 'protocol': RAVEN_STATUS_PROTOCOL, 'error': 'local_raven_job_rejected'}

        deadline = monotonic() + RAVEN_JOB_WAIT_SECONDS
        while monotonic() < deadline:
            status = _request_json(
                RAVEN_LOCAL_BASE + '/agent/jobs/' + job_id,
                method='GET',
                opener=opener,
            )
            current = status.get('job') if isinstance(status.get('job'), dict) else {}
            state = str(current.get('status') or '')
            if state == 'succeeded':
                result = current.get('result') if isinstance(current.get('result'), dict) else {}
                return {
                    'ok': bool(result.get('ok')),
                    'protocol': RAVEN_STATUS_PROTOCOL,
                    'source': 'local-raven-job-executor',
                    'capability': RAVEN_FIXED_CAPABILITY,
                    'nodeJobId': job_id,
                    'result': result,
                    'arbitraryCommands': False,
                    'argumentsAllowed': False,
                    'localOnlyHop': True,
                }
            if state == 'failed':
                result = current.get('result') if isinstance(current.get('result'), dict) else {}
                return {
                    'ok': False,
                    'protocol': RAVEN_STATUS_PROTOCOL,
                    'error': 'local_raven_job_failed',
                    'nodeJobId': job_id,
                    'result': result,
                }
            sleep(0.15)
        return {'ok': False, 'protocol': RAVEN_STATUS_PROTOCOL, 'error': 'local_raven_job_timeout'}
    except (OSError, urllib.error.URLError, ValueError, RuntimeError, json.JSONDecodeError) as exc:
        return {
            'ok': False,
            'protocol': RAVEN_STATUS_PROTOCOL,
            'error': 'local_raven_unavailable',
            'detail': str(exc)[:240],
        }


def build_health_payload(node_name='', node_role='', capabilities=None, session_id=''):
    payload = _stable.build_health_payload(node_name, node_role, capabilities, session_id)
    payload['agentVersion'] = AGENT_VERSION
    payload['ravenStatusProtocol'] = RAVEN_STATUS_PROTOCOL
    payload['ravenStatusRoute'] = RAVEN_STATUS_ROUTE
    payload['ravenStatusFixedCapability'] = RAVEN_FIXED_CAPABILITY
    payload['ravenStatusLocalOnlyHop'] = True
    return payload


def make_handler(*args, raven_status_reader=None, **kwargs):
    capabilities = kwargs.get('capabilities')
    if capabilities is None and len(args) >= 4:
        capabilities = args[3]
    caps = sanitize_capabilities(capabilities)
    Parent = _stable.make_handler(*args, **kwargs)
    reader = read_local_raven_status if raven_status_reader is None else raven_status_reader

    class Handler(Parent):
        server_version = 'RAHNodeAgent/1.4-candidate'

        def do_GET(self):
            if self.path != RAVEN_STATUS_ROUTE:
                return super().do_GET()
            if not self._prepare_auth('GET'):
                return
            if 'compute' not in caps:
                self._json(403, {'error': 'compute_capability_not_enabled'})
                return
            result = reader()
            self._json(200 if result.get('ok') else 503, result)

    Handler.local_confirmation_coordinator = Parent.local_confirmation_coordinator
    Handler.auth_nonce_store = Parent.auth_nonce_store
    return Handler


def create_server(host, port, token, node_name='', node_role='', capabilities=None, app_paths=None,
                  app_launcher=None, handoff_launcher=None, challenge_ttl_seconds=_impl.ACTION_CHALLENGE_TTL_SECONDS,
                  session_id=None, coordinator=None, interactive_console=None, local_input=None, clock=None,
                  token_func=None, auth_nonce_store=None, raven_status_reader=None):
    handler = make_handler(
        token, node_name, node_role, capabilities, app_paths, app_launcher, handoff_launcher,
        challenge_ttl_seconds, session_id, coordinator, interactive_console, local_input, clock,
        token_func, auth_nonce_store, raven_status_reader=raven_status_reader,
    )
    server = _impl._v12.ThreadingHTTPServer((host, port), handler)
    server.local_confirmation_coordinator = handler.local_confirmation_coordinator
    server.auth_nonce_store = handler.auth_nonce_store
    return server


def main():
    args = _impl._base.parse_args()
    host = '0.0.0.0' if args.allow_lan else '127.0.0.1'
    token = secrets.token_urlsafe(32)
    capabilities = sanitize_capabilities(args.capability)
    paths = build_app_paths()
    server = create_server(host, PORT, token, args.name, args.role, capabilities, paths,
                           interactive_console=sys.stdin.isatty())
    print(f'RAH Node Agent v{AGENT_VERSION}')
    print('Stage: Candidate')
    print(f'Auth protocol: {AUTH_PROTOCOL}')
    print(f'Raven status protocol: {RAVEN_STATUS_PROTOCOL}')
    print(f'Raven status route: {RAVEN_STATUS_ROUTE}')
    print(f'Raven fixed job: {RAVEN_FIXED_CAPABILITY}')
    print('Raven hop: localhost 127.0.0.1:18765 only')
    print('Boundary: authenticated fixed read-only Raven status; no arbitrary shell/path/arguments')
    print('Fresh local token: ' + token)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == '__main__':
    main()
