#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import secrets
import sys
from pathlib import Path

CANDIDATE_PATH = Path(__file__).with_name('rah-node-agent-v1.4-candidate.py')
_spec = importlib.util.spec_from_file_location('rah_node_agent_v14_candidate_pinned', CANDIDATE_PATH)
if _spec is None or _spec.loader is None:
    raise RuntimeError('Unable to load pinned Node Agent 1.4 Candidate implementation')
_impl = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_impl)

AGENT_VERSION = '1.4.0'
RAVEN_STATUS_PROTOCOL = _impl.RAVEN_STATUS_PROTOCOL
RAVEN_STATUS_ROUTE = _impl.RAVEN_STATUS_ROUTE
RAVEN_FIXED_CAPABILITY = _impl.RAVEN_FIXED_CAPABILITY
ACTIONS_PROTOCOL = _impl.ACTIONS_PROTOCOL
AUTH_PROTOCOL = _impl.AUTH_PROTOCOL
ALLOWLIST_POLICY_ID = _impl.ALLOWLIST_POLICY_ID
PORT = _impl.PORT
ALLOWED_CAPABILITIES = _impl.ALLOWED_CAPABILITIES
ACTION_CATALOG = _impl.ACTION_CATALOG
ROUTES = _impl.ROUTES
sanitize_capabilities = _impl.sanitize_capabilities
build_app_paths = _impl.build_app_paths
canonical_request = _impl.canonical_request
read_local_raven_status = _impl.read_local_raven_status

# Promote only the loaded Candidate module instance in this process.
# Candidate and earlier Stable files on disk remain unchanged.
_impl.AGENT_VERSION = AGENT_VERSION

_original_build_health_payload = _impl.build_health_payload

def build_health_payload(node_name='', node_role='', capabilities=None, session_id=''):
    payload = _original_build_health_payload(node_name, node_role, capabilities, session_id)
    payload['agentVersion'] = AGENT_VERSION
    payload['ravenStatusProtocol'] = RAVEN_STATUS_PROTOCOL
    payload['ravenStatusRoute'] = RAVEN_STATUS_ROUTE
    payload['ravenStatusFixedCapability'] = RAVEN_FIXED_CAPABILITY
    payload['ravenStatusLocalOnlyHop'] = True
    return payload

_impl.build_health_payload = build_health_payload


def make_handler(*args, **kwargs):
    handler = _impl.make_handler(*args, **kwargs)
    handler.server_version = 'RAHNodeAgent/1.4'
    return handler


def create_server(host, port, token, node_name='', node_role='', capabilities=None, app_paths=None,
                  app_launcher=None, handoff_launcher=None, challenge_ttl_seconds=None, session_id=None,
                  coordinator=None, interactive_console=None, local_input=None, clock=None, token_func=None,
                  auth_nonce_store=None, raven_status_reader=None):
    kwargs = {
        'session_id': session_id,
        'coordinator': coordinator,
        'interactive_console': interactive_console,
        'local_input': local_input,
        'clock': clock,
        'token_func': token_func,
        'auth_nonce_store': auth_nonce_store,
        'raven_status_reader': raven_status_reader,
    }
    if challenge_ttl_seconds is not None:
        kwargs['challenge_ttl_seconds'] = challenge_ttl_seconds
    handler = make_handler(
        token, node_name, node_role, capabilities, app_paths, app_launcher, handoff_launcher, **kwargs
    )
    server = _impl._impl._v12.ThreadingHTTPServer((host, port), handler)
    server.local_confirmation_coordinator = handler.local_confirmation_coordinator
    server.auth_nonce_store = handler.auth_nonce_store
    return server


def main():
    args = _impl._impl._base.parse_args()
    host = '0.0.0.0' if args.allow_lan else '127.0.0.1'
    token = secrets.token_urlsafe(32)
    capabilities = sanitize_capabilities(args.capability)
    paths = build_app_paths()
    server = create_server(
        host, PORT, token, args.name, args.role, capabilities, paths,
        interactive_console=sys.stdin.isatty(),
    )
    print(f'RAH Node Agent v{AGENT_VERSION}')
    print('Stage: Stable')
    print(f'Allowlist policy: {ALLOWLIST_POLICY_ID}')
    print(f'Actions protocol: {ACTIONS_PROTOCOL}')
    print(f'Auth protocol: {AUTH_PROTOCOL}')
    print(f'Raven status protocol: {RAVEN_STATUS_PROTOCOL}')
    print(f'Raven status route: {RAVEN_STATUS_ROUTE}')
    print(f'Raven fixed job: {RAVEN_FIXED_CAPABILITY}')
    print('Authentication: source-bound single-use nonce + HMAC-SHA256 proof; Bearer transport remains forbidden')
    print('Raven hop: localhost 127.0.0.1:18765 only')
    print('Boundary: fixed read-only Raven system status; no arbitrary shell/path/arguments')
    print('Mode: ' + ('LAN enrollment enabled' if args.allow_lan else 'loopback only'))
    print(f'Port: {PORT}')
    print('Capabilities: ' + (', '.join(capabilities) if capabilities else 'identity-only'))
    print('Fresh local token: ' + token)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == '__main__':
    main()
