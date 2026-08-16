#!/usr/bin/env python3
from __future__ import annotations
import importlib.util
from pathlib import Path

BASE_PATH=Path(__file__).with_name('rah-node-agent.py')
_spec=importlib.util.spec_from_file_location('rah_node_agent_stable',BASE_PATH)
if _spec is None or _spec.loader is None:raise RuntimeError('Unable to load Stable Node Agent')
_base=importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_base)

AGENT_VERSION='0.9.0-candidate'
ACTIONS_PROTOCOL='rah-node-actions-v4'
ALLOWLIST_POLICY_ID='rah-capability-allowlist-v1'

ALLOWED_CAPABILITIES=_base.ALLOWED_CAPABILITIES
ACTION_CATALOG=_base.ACTION_CATALOG
ACTION_CHALLENGE_HEADER=_base.ACTION_CHALLENGE_HEADER
ACTION_CHALLENGE_TTL_SECONDS=_base.ACTION_CHALLENGE_TTL_SECONDS
PORT=_base.PORT

_original_build_actions_payload=_base.build_actions_payload
_original_issue_action_challenges=_base.issue_action_challenges

def build_actions_payload(capabilities=None,app_paths=None,session_id=''):
    payload=_original_build_actions_payload(capabilities,app_paths,session_id)
    payload['protocol']=ACTIONS_PROTOCOL
    payload['policyId']=ALLOWLIST_POLICY_ID
    return payload

def issue_action_challenges(base_payload,state,lock,ttl_seconds=ACTION_CHALLENGE_TTL_SECONDS,now=None):
    payload=_original_issue_action_challenges(base_payload,state,lock,ttl_seconds,now)
    payload['protocol']=ACTIONS_PROTOCOL
    payload['policyId']=ALLOWLIST_POLICY_ID
    return payload

# Patch only the candidate module instance. The Stable source file is never modified.
_base.AGENT_VERSION=AGENT_VERSION
_base.ACTIONS_PROTOCOL=ACTIONS_PROTOCOL
_base.build_actions_payload=build_actions_payload
_base.issue_action_challenges=issue_action_challenges

sanitize_capabilities=_base.sanitize_capabilities
build_health_payload=_base.build_health_payload
build_permissions=_base.build_permissions
build_app_paths=_base.build_app_paths
create_server=_base.create_server
make_handler=_base.make_handler
consume_action_challenge=_base.consume_action_challenge
is_authorized=_base.is_authorized
is_valid_rustdesk_peer_id=_base.is_valid_rustdesk_peer_id


def main():
    args=_base.parse_args()
    host='0.0.0.0' if args.allow_lan else '127.0.0.1'
    token=_base.secrets.token_urlsafe(32)
    capabilities=sanitize_capabilities(args.capability)
    paths=build_app_paths()
    server=create_server(host,PORT,token,args.name,args.role,capabilities,paths)
    actions=build_actions_payload(capabilities,paths)['actions']
    print(f'RAH Node Agent v{AGENT_VERSION}')
    print('Stage: Candidate')
    print(f'Allowlist policy: {ALLOWLIST_POLICY_ID}')
    print(f'Actions protocol: {ACTIONS_PROTOCOL}')
    print('Mode: '+('LAN enrollment enabled' if args.allow_lan else 'loopback only'))
    print(f'Port: {PORT}')
    print('Capabilities: '+(', '.join(capabilities) if capabilities else 'identity-only'))
    print('Advertised actions: '+(', '.join(a['id'] for a in actions) if actions else 'none'))
    print('Token: '+token)
    print('Boundary: fixed actions only; no shell/files/generic process/native remote-control API')
    try:server.serve_forever()
    except KeyboardInterrupt:pass
    finally:server.server_close()

if __name__=='__main__':main()
