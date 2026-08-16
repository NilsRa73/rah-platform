#!/usr/bin/env python3
from __future__ import annotations
import importlib.util,ipaddress,secrets,sys
from pathlib import Path

STABLE_PATH=Path(__file__).with_name('rah-node-agent-v1.0.py')
_spec=importlib.util.spec_from_file_location('rah_node_agent_stable_v10_for_candidate_v11',STABLE_PATH)
if _spec is None or _spec.loader is None:raise RuntimeError('Unable to load Stable Node Agent 1.0')
_stable=importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_stable)
_impl=_stable._impl
_base=_impl._base

AGENT_VERSION='1.1.0-candidate'
ACTIONS_PROTOCOL=_stable.ACTIONS_PROTOCOL
ALLOWLIST_POLICY_ID=_stable.ALLOWLIST_POLICY_ID
APPROVAL_ACTION_HEADER=_stable.APPROVAL_ACTION_HEADER
APPROVAL_TARGET_HEADER=_stable.APPROVAL_TARGET_HEADER
LOCAL_APPROVAL_HEADER=_stable.LOCAL_APPROVAL_HEADER
ACTION_CHALLENGE_HEADER=_stable.ACTION_CHALLENGE_HEADER
ACTION_CHALLENGE_TTL_SECONDS=_stable.ACTION_CHALLENGE_TTL_SECONDS
LOCAL_APPROVAL_TTL_SECONDS=_stable.LOCAL_APPROVAL_TTL_SECONDS
LOCAL_CONFIRMATION_WAIT_SECONDS=_stable.LOCAL_CONFIRMATION_WAIT_SECONDS
LOCAL_CONFIRMATION_COOLDOWN_SECONDS=_stable.LOCAL_CONFIRMATION_COOLDOWN_SECONDS
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
build_actions_payload=_stable.build_actions_payload
canonical_input_digest=_stable.canonical_input_digest
issue_catalog=_stable.issue_catalog
consume_read_challenge=_stable.consume_read_challenge


def normalize_requester_source(value):
    if not isinstance(value,str) or not value:return ''
    try:addr=ipaddress.ip_address(value.strip())
    except ValueError:return ''
    if addr.version!=4:return ''
    if addr.is_loopback:return str(addr)
    private_ranges=(
        ipaddress.ip_network('10.0.0.0/8'),
        ipaddress.ip_network('172.16.0.0/12'),
        ipaddress.ip_network('192.168.0.0/16'),
    )
    return str(addr) if any(addr in network for network in private_ranges) else ''


def build_health_payload(node_name='',node_role='',capabilities=None,session_id=''):
    payload=_stable.build_health_payload(node_name,node_role,capabilities,session_id)
    payload['agentVersion']=AGENT_VERSION
    return payload


class SourceBoundConfirmationCoordinator(_impl.LocalConfirmationCoordinator):
    def _fixed_prompt(self,action_id,target,requester_source=''):
        source=normalize_requester_source(requester_source)
        if not source:return ''
        prefix=f'RAH local approval from {source}: '
        if action_id=='rustdesk.launch':return prefix+'Launch RustDesk? [y/N] '
        if action_id=='rustdesk.connect' and is_valid_rustdesk_peer_id(target):return prefix+f'Connect RustDesk to {target}? [y/N] '
        return ''

    def request(self,action_id,target='',requester_source=''):
        source=normalize_requester_source(requester_source)
        if not source:return {'ok':False,'error':'requester_source_not_allowed'}
        if not self.interactive or self._thread is None:return {'ok':False,'error':'local_confirmation_unavailable'}
        input_digest=canonical_input_digest(action_id,target)
        if not input_digest:return {'ok':False,'error':'invalid_fixed_action_input'}
        now=float(self.clock())
        event=_impl.threading.Event()
        intent={
            'actionId':action_id,
            'inputDigest':input_digest,
            'displayTarget':target if action_id=='rustdesk.connect' else '',
            'requesterSource':source,
            'event':event,
            'result':None,
            'cancelled':False,
            'expires':now+self.wait_seconds,
        }
        with self._lock:
            if self._pending is not None:return {'ok':False,'error':'local_confirmation_busy'}
            if now<self._cooldown_until:return {'ok':False,'error':'local_confirmation_rate_limited'}
            self._pending=intent
            try:self._queue.put_nowait(intent)
            except _impl.queue.Full:
                self._pending=None
                return {'ok':False,'error':'local_confirmation_busy'}
        if not event.wait(self.wait_seconds):
            with self._lock:
                if self._pending is intent:intent['cancelled']=True
            return {'ok':False,'error':'local_confirmation_timeout'}
        result=intent.get('result')
        return result if isinstance(result,dict) else {'ok':False,'error':'local_confirmation_denied'}

    def _reader_loop(self):
        while True:
            intent=self._queue.get()
            if intent is None:return
            prompt=self._fixed_prompt(intent.get('actionId',''),intent.get('displayTarget',''),intent.get('requesterSource',''))
            approved=False
            if prompt:
                try:approved=str(self.input_func(prompt)).strip().lower() in ('y','yes')
                except Exception:approved=False
            self._finish(intent,approved)

    def _finish(self,intent,approved):
        super()._finish(intent,approved)
        with self._lock:
            if isinstance(self._active_pair,dict) and intent.get('result',{}).get('ok') is True:
                self._active_pair['requesterSource']=intent.get('requesterSource','')

    def consume(self,action_id,target,challenge,proof,requester_source=''):
        source=normalize_requester_source(requester_source)
        if not source:return 'requester_source_not_allowed'
        now=float(self.clock())
        input_digest=canonical_input_digest(action_id,target)
        with self._lock:
            pair=self._active_pair
            if pair is None:return 'missing'
            if now>float(pair.get('expires',0)):
                self._active_pair=None
                return 'expired'
            if source!=pair.get('requesterSource'):return 'requester_mismatch'
            if action_id!=pair.get('actionId'):return 'action_mismatch'
            if self.session_id!=pair.get('sessionId'):return 'session_mismatch'
            if not input_digest or input_digest!=pair.get('inputDigest'):return 'input_mismatch'
            if not _impl._safe_equal(challenge,pair.get('challenge','')):return 'challenge_invalid'
            if not _impl._safe_equal(proof,pair.get('proof','')):return 'proof_invalid'
            self._active_pair=None
            return 'ok'

    def snapshot(self):
        snapshot=super().snapshot()
        with self._lock:
            pending=self._pending
            pair=self._active_pair
            if pending is not None and snapshot.get('pending') is not None:
                snapshot['pending']['requesterSource']=pending.get('requesterSource','')
            if pair is not None and snapshot.get('activePair') is not None:
                snapshot['activePair']['requesterSource']=pair.get('requesterSource','')
        return snapshot


def make_handler(token,node_name='',node_role='',capabilities=None,app_paths=None,app_launcher=None,handoff_launcher=None,challenge_ttl_seconds=ACTION_CHALLENGE_TTL_SECONDS,session_id=None,coordinator=None,interactive_console=None,local_input=None,clock=None,token_func=None):
    caps=sanitize_capabilities(capabilities)
    paths=build_app_paths(app_paths)
    session=_base.sanitize_session_id(session_id) or secrets.token_urlsafe(18)
    local=coordinator or SourceBoundConfirmationCoordinator(session,interactive=interactive_console,input_func=local_input,clock=clock,token_func=token_func)
    Parent=_stable.make_handler(token,node_name,node_role,caps,paths,app_launcher,handoff_launcher,challenge_ttl_seconds,session,local,interactive_console,local_input,clock,token_func)

    class Handler(Parent):
        server_version='RAHNodeAgent/1.1-candidate'
        def _requester_source(self):
            try:return normalize_requester_source(self.client_address[0])
            except Exception:return ''
        def _approval_intent(self):
            if not self._approval_headers_valid():return False,None
            action=self.headers.get(APPROVAL_ACTION_HEADER)
            target=self.headers.get(APPROVAL_TARGET_HEADER)
            if action is None:
                if target is not None:
                    self._json(400,{'error':'approval_action_required_for_target'});return False,None
                return True,None
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
            result=local.request(action,target,source)
            if not result.get('ok'):
                error=result.get('error','local_confirmation_denied')
                status=503 if error=='local_confirmation_unavailable' else 409 if error in ('local_confirmation_busy','local_confirmation_rate_limited') else 408 if error=='local_confirmation_timeout' else 403
                self._json(status,{'error':error});return False,None
            return True,result.get('grant')
        def _require_local_pair(self,action_id,target=''):
            challenge=self.headers.get(ACTION_CHALLENGE_HEADER,'')
            proof=self.headers.get(LOCAL_APPROVAL_HEADER,'')
            if not challenge:
                self._json(428,{'error':'action_challenge_required'});return False
            if not proof:
                self._json(428,{'error':'local_approval_proof_required'});return False
            source=self._requester_source()
            if not source:
                self._json(403,{'error':'requester_source_not_allowed'});return False
            result=local.consume(action_id,target,challenge,proof,source)
            errors={
                'missing':(428,'local_approval_proof_required'),
                'expired':(409,'local_approval_proof_expired'),
                'requester_source_not_allowed':(403,'requester_source_not_allowed'),
                'requester_mismatch':(409,'local_approval_requester_mismatch'),
                'action_mismatch':(409,'local_approval_action_mismatch'),
                'session_mismatch':(409,'local_approval_session_mismatch'),
                'input_mismatch':(409,'local_approval_input_mismatch'),
                'challenge_invalid':(409,'action_challenge_invalid_or_expired'),
                'proof_invalid':(409,'local_approval_proof_invalid'),
            }
            if result=='ok':return True
            status,error=errors.get(result,(409,'local_approval_proof_invalid'))
            self._json(status,{'error':error});return False
    Handler.local_confirmation_coordinator=local
    return Handler


def create_server(host,port,token,node_name='',node_role='',capabilities=None,app_paths=None,app_launcher=None,handoff_launcher=None,challenge_ttl_seconds=ACTION_CHALLENGE_TTL_SECONDS,session_id=None,coordinator=None,interactive_console=None,local_input=None,clock=None,token_func=None):
    handler=make_handler(token,node_name,node_role,capabilities,app_paths,app_launcher,handoff_launcher,challenge_ttl_seconds,session_id,coordinator,interactive_console,local_input,clock,token_func)
    server=_impl.ThreadingHTTPServer((host,port),handler)
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
