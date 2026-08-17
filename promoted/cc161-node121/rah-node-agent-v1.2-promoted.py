#!/usr/bin/env python3
from __future__ import annotations
import hashlib,importlib.util,secrets,sys
from http.server import ThreadingHTTPServer
from pathlib import Path

STABLE_PATH=Path(__file__).with_name('rah-node-agent-v1.1.py')
_spec=importlib.util.spec_from_file_location('rah_node_agent_stable_v11_for_candidate_v12',STABLE_PATH)
if _spec is None or _spec.loader is None:raise RuntimeError('Unable to load Stable Node Agent 1.1')
_stable=importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_stable)
_v11_impl=_stable._impl
_v10_stable=_v11_impl._stable
_v10_impl=_v10_stable._impl
_base=_v11_impl._base

AGENT_VERSION='1.2.0-candidate'
ACTIONS_PROTOCOL='rah-node-actions-v6'
ALLOWLIST_POLICY_ID='rah-capability-allowlist-v1'
REQUESTER_CONTEXT_HEADER='X-RAH-Requester-Context'
APPROVAL_ACTION_HEADER=_stable.APPROVAL_ACTION_HEADER
APPROVAL_TARGET_HEADER=_stable.APPROVAL_TARGET_HEADER
LOCAL_APPROVAL_HEADER=_stable.LOCAL_APPROVAL_HEADER
ACTION_CHALLENGE_HEADER=_stable.ACTION_CHALLENGE_HEADER
ACTION_CHALLENGE_TTL_SECONDS=_stable.ACTION_CHALLENGE_TTL_SECONDS
LOCAL_APPROVAL_TTL_SECONDS=_stable.LOCAL_APPROVAL_TTL_SECONDS
PORT=_stable.PORT
ALLOWED_CAPABILITIES=_stable.ALLOWED_CAPABILITIES
ACTION_CATALOG=_stable.ACTION_CATALOG
MUTATING_ACTION_IDS=_stable.MUTATING_ACTION_IDS
ROUTES=_stable.ROUTES

sanitize_capabilities=_stable.sanitize_capabilities
build_permissions=_stable.build_permissions
build_app_paths=_stable.build_app_paths
is_authorized=_stable.is_authorized
is_valid_rustdesk_peer_id=_stable.is_valid_rustdesk_peer_id
canonical_input_digest=_stable.canonical_input_digest
normalize_requester_source=_stable.normalize_requester_source

_original_build_actions_payload=_v10_impl.build_actions_payload
_original_issue_catalog=_v10_impl.issue_catalog

def build_actions_payload(capabilities=None,app_paths=None,session_id=''):
    payload=_original_build_actions_payload(capabilities,app_paths,session_id)
    payload['protocol']=ACTIONS_PROTOCOL
    payload['policyId']=ALLOWLIST_POLICY_ID
    payload['approvalMode']='command-center-ephemeral-plus-node-local'
    return payload

def issue_catalog(base_payload,challenge_state,challenge_lock,grant=None,ttl_seconds=ACTION_CHALLENGE_TTL_SECONDS,now=None):
    payload=_original_issue_catalog(base_payload,challenge_state,challenge_lock,grant,ttl_seconds,now)
    payload['protocol']=ACTIONS_PROTOCOL
    payload['policyId']=ALLOWLIST_POLICY_ID
    payload['approvalMode']='command-center-ephemeral-plus-node-local'
    return payload

# Patch only the private v1.0 Candidate module instance loaded inside this v1.2 process.
# Stable files on disk remain untouched; Parent handlers therefore keep their existing logic while emitting v6.
_v10_impl.build_actions_payload=build_actions_payload
_v10_impl.issue_catalog=issue_catalog


def valid_requester_context(value):
    if not isinstance(value,str) or value!=value.strip() or not value.isascii() or len(value)<32 or len(value)>128:return False
    return all(ch.isalnum() or ch in '_-' for ch in value)

def requester_context_digest(value):
    if not valid_requester_context(value):return ''
    return hashlib.sha256(value.encode('ascii')).hexdigest()


def build_health_payload(node_name='',node_role='',capabilities=None,session_id=''):
    payload=_stable.build_health_payload(node_name,node_role,capabilities,session_id)
    payload['agentVersion']=AGENT_VERSION
    return payload


class ContextBoundConfirmationCoordinator(_stable.SourceBoundConfirmationCoordinator):
    def request(self,action_id,target='',requester_source='',requester_context=''):
        digest=requester_context_digest(requester_context)
        if not digest:return {'ok':False,'error':'requester_context_invalid'}
        result=super().request(action_id,target,requester_source)
        if not isinstance(result,dict) or not result.get('ok'):return result
        source=normalize_requester_source(requester_source)
        input_digest=canonical_input_digest(action_id,target)
        with self._lock:
            pair=self._active_pair
            if pair is None or pair.get('actionId')!=action_id or pair.get('requesterSource')!=source or pair.get('inputDigest')!=input_digest:
                self._active_pair=None
                return {'ok':False,'error':'requester_context_binding_failed'}
            pair['requesterContextDigest']=digest
        return result

    def consume(self,action_id,target,challenge,proof,requester_source='',requester_context=''):
        digest=requester_context_digest(requester_context)
        if not digest:return 'requester_context_invalid'
        now=float(self.clock())
        with self._lock:
            pair=self._active_pair
            if pair is None:return 'missing'
            if now>float(pair.get('expires',0)):
                self._active_pair=None
                return 'expired'
            if pair.get('requesterContextDigest')!=digest:return 'requester_context_mismatch'
        return super().consume(action_id,target,challenge,proof,requester_source)

    def snapshot(self):
        # Stable v1.1 snapshot intentionally exposes only non-secret structural metadata.
        # Do not add requester-context raw values or digests to that surface.
        return super().snapshot()

LocalConfirmationCoordinator=ContextBoundConfirmationCoordinator


def make_handler(token,node_name='',node_role='',capabilities=None,app_paths=None,app_launcher=None,handoff_launcher=None,challenge_ttl_seconds=ACTION_CHALLENGE_TTL_SECONDS,session_id=None,coordinator=None,interactive_console=None,local_input=None,clock=None,token_func=None):
    caps=sanitize_capabilities(capabilities)
    paths=build_app_paths(app_paths)
    session=_base.sanitize_session_id(session_id) or secrets.token_urlsafe(18)
    local=coordinator or ContextBoundConfirmationCoordinator(session,interactive=interactive_console,input_func=local_input,clock=clock,token_func=token_func)
    Parent=_stable.make_handler(token,node_name,node_role,caps,paths,app_launcher,handoff_launcher,challenge_ttl_seconds,session,local,interactive_console,local_input,clock,token_func)
    health_payload=build_health_payload(node_name,node_role,caps,session)

    class Handler(Parent):
        server_version='RAHNodeAgent/1.2-candidate'
        def _requester_headers_valid(self):
            expected=REQUESTER_CONTEXT_HEADER.lower()
            for key in self.headers.keys():
                lowered=key.lower()
                if lowered.startswith('x-rah-requester-') and lowered!=expected:
                    self._json(400,{'error':'unknown_requester_header'});return False
            return True
        def _requester_context(self):
            value=self.headers.get(REQUESTER_CONTEXT_HEADER)
            return value if valid_requester_context(value) else ''
        def _cors(self):
            origin=self._origin()
            if origin in _base.ALLOWED_ORIGINS:
                self.send_header('Access-Control-Allow-Origin',origin)
                self.send_header('Vary','Origin')
                self.send_header('Access-Control-Allow-Methods','GET, POST, OPTIONS')
                self.send_header('Access-Control-Allow-Headers','Authorization, Content-Type, '+ACTION_CHALLENGE_HEADER+', '+APPROVAL_ACTION_HEADER+', '+APPROVAL_TARGET_HEADER+', '+LOCAL_APPROVAL_HEADER+', '+REQUESTER_CONTEXT_HEADER)
                if self.headers.get('Access-Control-Request-Private-Network','').lower()=='true':self.send_header('Access-Control-Allow-Private-Network','true')
        def _approval_intent(self):
            if not self._requester_headers_valid() or not self._approval_headers_valid():return False,None
            action=self.headers.get(APPROVAL_ACTION_HEADER)
            target=self.headers.get(APPROVAL_TARGET_HEADER)
            raw_context=self.headers.get(REQUESTER_CONTEXT_HEADER)
            if action is None:
                if target is not None:
                    self._json(400,{'error':'approval_action_required_for_target'});return False,None
                if raw_context is not None:
                    self._json(400,{'error':'requester_context_not_allowed'});return False,None
                return True,None
            context=self._requester_context()
            if not context:
                self._json(400,{'error':'requester_context_required'});return False,None
            if self.headers.get('Transfer-Encoding'):
                self._json(400,{'error':'approval_intent_body_not_allowed'});return False,None
            try:length=int(self.headers.get('Content-Length','0') or 0)
            except ValueError:
                self._json(400,{'error':'invalid_content_length'});return False,None
            if length!=0:
                self._json(400,{'error':'approval_intent_body_not_allowed'});return False,None
            if action not in MUTATING_ACTION_IDS:
                self._json(400,{'error':'invalid_approval_action'});return False,None
            advertised={row.get('id') for row in build_actions_payload(caps,paths,session).get('actions',[])}
            if action not in advertised:
                self._json(403,{'error':'action_not_advertised'});return False,None
            if 'remote-desktop' not in caps:
                self._json(403,{'error':'remote_desktop_capability_not_enabled'});return False,None
            if action=='rustdesk.launch':
                if target is not None:
                    self._json(400,{'error':'approval_target_not_allowed'});return False,None
                target=''
            elif not is_valid_rustdesk_peer_id(target):
                self._json(400,{'error':'invalid_peer_id'});return False,None
            source=self._requester_source()
            if not source:
                self._json(403,{'error':'requester_source_not_allowed'});return False,None
            result=local.request(action,target,source,context)
            if not result.get('ok'):
                error=result.get('error','local_confirmation_denied')
                status=503 if error=='local_confirmation_unavailable' else 409 if error in ('local_confirmation_busy','local_confirmation_rate_limited','requester_context_binding_failed') else 408 if error=='local_confirmation_timeout' else 403
                self._json(status,{'error':error});return False,None
            return True,result.get('grant')
        def _require_local_pair(self,action_id,target=''):
            context=self._requester_context()
            if not context:
                self._json(428,{'error':'requester_context_required'});return False
            challenge=self.headers.get(ACTION_CHALLENGE_HEADER,'')
            proof=self.headers.get(LOCAL_APPROVAL_HEADER,'')
            if not challenge:
                self._json(428,{'error':'action_challenge_required'});return False
            if not proof:
                self._json(428,{'error':'local_approval_proof_required'});return False
            source=self._requester_source()
            if not source:
                self._json(403,{'error':'requester_source_not_allowed'});return False
            result=local.consume(action_id,target,challenge,proof,source,context)
            errors={
                'missing':(428,'local_approval_proof_required'),
                'expired':(409,'local_approval_proof_expired'),
                'requester_source_not_allowed':(403,'requester_source_not_allowed'),
                'requester_mismatch':(409,'local_approval_requester_mismatch'),
                'requester_context_invalid':(400,'requester_context_invalid'),
                'requester_context_mismatch':(409,'requester_context_mismatch'),
                'action_mismatch':(409,'local_approval_action_mismatch'),
                'session_mismatch':(409,'local_approval_session_mismatch'),
                'input_mismatch':(409,'local_approval_input_mismatch'),
                'challenge_invalid':(409,'action_challenge_invalid_or_expired'),
                'proof_invalid':(409,'local_approval_proof_invalid'),
            }
            if result=='ok':return True
            status,error=errors.get(result,(409,'local_approval_proof_invalid'))
            self._json(status,{'error':error});return False
        def do_GET(self):
            if not self._requester_headers_valid():return
            raw_context=self.headers.get(REQUESTER_CONTEXT_HEADER)
            if self.path=='/health':
                if raw_context is not None:
                    self._json(400,{'error':'requester_context_not_allowed'});return
                if not self._authorized():return
                self._json(200,health_payload);return
            if self.path=='/storage' and raw_context is not None:
                self._json(400,{'error':'requester_context_not_allowed'});return
            if self.path=='/actions' and self.headers.get(APPROVAL_ACTION_HEADER) is None and raw_context is not None:
                self._json(400,{'error':'requester_context_not_allowed'});return
            return super().do_GET()
        def do_POST(self):
            if not self._requester_headers_valid():return
            raw_context=self.headers.get(REQUESTER_CONTEXT_HEADER)
            if self.path in ('/launch/rustdesk','/handoff/rustdesk'):
                if raw_context is None:
                    self._json(428,{'error':'requester_context_required'});return
                if not self._requester_context():
                    self._json(400,{'error':'requester_context_invalid'});return
            elif raw_context is not None:
                self._json(400,{'error':'requester_context_not_allowed'});return
            return super().do_POST()
    Handler.local_confirmation_coordinator=local
    return Handler


def create_server(host,port,token,node_name='',node_role='',capabilities=None,app_paths=None,app_launcher=None,handoff_launcher=None,challenge_ttl_seconds=ACTION_CHALLENGE_TTL_SECONDS,session_id=None,coordinator=None,interactive_console=None,local_input=None,clock=None,token_func=None):
    handler=make_handler(token,node_name,node_role,capabilities,app_paths,app_launcher,handoff_launcher,challenge_ttl_seconds,session_id,coordinator,interactive_console,local_input,clock,token_func)
    server=ThreadingHTTPServer((host,port),handler)
    server.local_confirmation_coordinator=handler.local_confirmation_coordinator
    return server


def main():
    args=_base.parse_args()
    host='0.0.0.0' if args.allow_lan else '127.0.0.1'
    token=secrets.token_urlsafe(32)
    capabilities=sanitize_capabilities(args.capability)
    paths=build_app_paths()
    server=create_server(host,PORT,token,args.name,args.role,capabilities,paths,interactive_console=sys.stdin.isatty())
    actions=build_actions_payload(capabilities,paths)['actions']
    print(f'RAH Node Agent v{AGENT_VERSION}')
    print('Stage: Candidate')
    print(f'Allowlist policy: {ALLOWLIST_POLICY_ID}')
    print(f'Actions protocol: {ACTIONS_PROTOCOL}')
    print('Requester source binding: actual IPv4 socket peer only; forwarding headers ignored')
    print('Requester context: CSPRNG flow value; Node stores only SHA-256 digest in active pair')
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