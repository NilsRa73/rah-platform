#!/usr/bin/env python3
from __future__ import annotations
import importlib.util,secrets,sys
from pathlib import Path

CANDIDATE_PATH=Path(__file__).with_name('rah-node-agent-v1.2-candidate.py')
_spec=importlib.util.spec_from_file_location('rah_node_agent_v12_candidate_pinned',CANDIDATE_PATH)
if _spec is None or _spec.loader is None:raise RuntimeError('Unable to load pinned Node Agent 1.2 Candidate implementation')
_impl=importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_impl)

_impl.AGENT_VERSION='1.2.0'
AGENT_VERSION='1.2.0'
ACTIONS_PROTOCOL=_impl.ACTIONS_PROTOCOL
ALLOWLIST_POLICY_ID=_impl.ALLOWLIST_POLICY_ID
REQUESTER_CONTEXT_HEADER=_impl.REQUESTER_CONTEXT_HEADER
APPROVAL_ACTION_HEADER=_impl.APPROVAL_ACTION_HEADER
APPROVAL_TARGET_HEADER=_impl.APPROVAL_TARGET_HEADER
LOCAL_APPROVAL_HEADER=_impl.LOCAL_APPROVAL_HEADER
ACTION_CHALLENGE_HEADER=_impl.ACTION_CHALLENGE_HEADER
ACTION_CHALLENGE_TTL_SECONDS=_impl.ACTION_CHALLENGE_TTL_SECONDS
LOCAL_APPROVAL_TTL_SECONDS=_impl.LOCAL_APPROVAL_TTL_SECONDS
PORT=_impl.PORT
ALLOWED_CAPABILITIES=_impl.ALLOWED_CAPABILITIES
ACTION_CATALOG=_impl.ACTION_CATALOG
MUTATING_ACTION_IDS=_impl.MUTATING_ACTION_IDS
ROUTES=_impl.ROUTES
ContextBoundConfirmationCoordinator=_impl.ContextBoundConfirmationCoordinator
LocalConfirmationCoordinator=_impl.ContextBoundConfirmationCoordinator
valid_requester_context=_impl.valid_requester_context
requester_context_digest=_impl.requester_context_digest
normalize_requester_source=_impl.normalize_requester_source
sanitize_capabilities=_impl.sanitize_capabilities
build_permissions=_impl.build_permissions
build_app_paths=_impl.build_app_paths
is_authorized=_impl.is_authorized
is_valid_rustdesk_peer_id=_impl.is_valid_rustdesk_peer_id
build_actions_payload=_impl.build_actions_payload
canonical_input_digest=_impl.canonical_input_digest
issue_catalog=_impl.issue_catalog


def build_health_payload(node_name='',node_role='',capabilities=None,session_id=''):
    payload=_impl.build_health_payload(node_name,node_role,capabilities,session_id)
    payload['agentVersion']=AGENT_VERSION
    return payload


def make_handler(*args,**kwargs):
    handler=_impl.make_handler(*args,**kwargs)
    handler.server_version='RAHNodeAgent/1.2'
    return handler


def create_server(host,port,token,node_name='',node_role='',capabilities=None,app_paths=None,app_launcher=None,handoff_launcher=None,challenge_ttl_seconds=ACTION_CHALLENGE_TTL_SECONDS,session_id=None,coordinator=None,interactive_console=None,local_input=None,clock=None,token_func=None):
    handler=make_handler(token,node_name,node_role,capabilities,app_paths,app_launcher,handoff_launcher,challenge_ttl_seconds,session_id,coordinator,interactive_console,local_input,clock,token_func)
    server=_impl.ThreadingHTTPServer((host,port),handler)
    server.local_confirmation_coordinator=handler.local_confirmation_coordinator
    return server


def main():
    args=_impl._base.parse_args()
    host='0.0.0.0' if args.allow_lan else '127.0.0.1'
    token=secrets.token_urlsafe(32)
    capabilities=sanitize_capabilities(args.capability)
    paths=build_app_paths()
    server=create_server(host,PORT,token,args.name,args.role,capabilities,paths,interactive_console=sys.stdin.isatty())
    actions=build_actions_payload(capabilities,paths)['actions']
    print(f'RAH Node Agent v{AGENT_VERSION}')
    print('Stage: Stable')
    print(f'Allowlist policy: {ALLOWLIST_POLICY_ID}')
    print(f'Actions protocol: {ACTIONS_PROTOCOL}')
    print('Requester source binding: actual IPv4 socket peer only; forwarding headers ignored')
    print('Requester context: Node stores only SHA-256 digest in active pair; raw context is transient')
    print('Mode: '+('LAN enrollment enabled' if args.allow_lan else 'loopback only'))
    print(f'Port: {PORT}')
    print('Capabilities: '+(', '.join(capabilities) if capabilities else 'identity-only'))
    print('Advertised actions: '+(', '.join(a['id'] for a in actions) if actions else 'none'))
    print('Node-local confirmation: '+('interactive console enabled' if sys.stdin.isatty() else 'unavailable; mutating actions fail closed'))
    print('Token: '+token)
    print('Boundary: fixed 4 capabilities / 3 actions / 5 routes; no shell/files/generic process/native remote-control API')
    try:server.serve_forever()
    except KeyboardInterrupt:pass
    finally:server.server_close()

if __name__=='__main__':main()
