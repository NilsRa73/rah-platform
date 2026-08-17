#!/usr/bin/env python3
from __future__ import annotations
import hashlib,hmac,importlib.util,queue,secrets,sys,threading,time
from http.server import ThreadingHTTPServer
from pathlib import Path

STABLE_PATH=Path(__file__).with_name('rah-node-agent-v1.1.py')
_spec=importlib.util.spec_from_file_location('rah_node_agent_stable_v11_for_candidate_v12',STABLE_PATH)
if _spec is None or _spec.loader is None:raise RuntimeError('Unable to load Stable Node Agent 1.1')
_stable=importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_stable)
_base=_stable._impl._base

AGENT_VERSION='1.2.0-candidate'
ACTIONS_PROTOCOL='rah-node-actions-v6'
ALLOWLIST_POLICY_ID='rah-capability-allowlist-v1'
APPROVAL_MODE='command-center-ephemeral-plus-node-local-context'
APPROVAL_ACTION_HEADER=_stable.APPROVAL_ACTION_HEADER
APPROVAL_TARGET_HEADER=_stable.APPROVAL_TARGET_HEADER
LOCAL_APPROVAL_HEADER=_stable.LOCAL_APPROVAL_HEADER
ACTION_CHALLENGE_HEADER=_stable.ACTION_CHALLENGE_HEADER
REQUESTER_CONTEXT_HEADER='X-RAH-Requester-Context'
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
canonical_input_digest=_stable.canonical_input_digest
normalize_requester_source=_stable.normalize_requester_source


def valid_requester_context(value):
    return isinstance(value,str) and value.isascii() and 32<=len(value)<=128 and all(ch.isalnum() or ch in '_-' for ch in value)


def requester_context_digest(value):
    if not valid_requester_context(value):return ''
    return hashlib.sha256(value.encode('ascii')).hexdigest()


def _safe_equal(left,right):
    return isinstance(left,str) and isinstance(right,str) and bool(left) and bool(right) and hmac.compare_digest(left,right)


def _token():return secrets.token_urlsafe(24)


def build_health_payload(node_name='',node_role='',capabilities=None,session_id=''):
    payload=_stable.build_health_payload(node_name,node_role,capabilities,session_id)
    payload['agentVersion']=AGENT_VERSION
    return payload


def build_actions_payload(capabilities=None,app_paths=None,session_id=''):
    payload=_stable.build_actions_payload(capabilities,app_paths,session_id)
    payload['protocol']=ACTIONS_PROTOCOL
    payload['policyId']=ALLOWLIST_POLICY_ID
    payload['approvalMode']=APPROVAL_MODE
    rows=[]
    for raw in payload.get('actions',[]):
        item=dict(raw)
        if item.get('id') in MUTATING_ACTION_IDS:
            item['localApprovalRequired']=True
            item['requesterContextRequired']=True
        else:item.pop('requesterContextRequired',None)
        rows.append(item)
    payload['actions']=rows
    return payload


class RequesterContextConfirmationCoordinator(_stable.SourceBoundConfirmationCoordinator):
    def request(self,action_id,target='',requester_source='',requester_context=''):
        source=normalize_requester_source(requester_source)
        context_digest=requester_context_digest(requester_context)
        if not source:return {'ok':False,'error':'requester_source_not_allowed'}
        if not context_digest:return {'ok':False,'error':'requester_context_invalid'}
        if not self.interactive or self._thread is None:return {'ok':False,'error':'local_confirmation_unavailable'}
        input_digest=canonical_input_digest(action_id,target)
        if not input_digest:return {'ok':False,'error':'invalid_fixed_action_input'}
        now=float(self.clock());event=threading.Event()
        intent={'actionId':action_id,'inputDigest':input_digest,'displayTarget':target if action_id=='rustdesk.connect' else '','requesterSource':source,'requesterContextDigest':context_digest,'event':event,'result':None,'cancelled':False,'expires':now+self.wait_seconds}
        with self._lock:
            if self._pending is not None:return {'ok':False,'error':'local_confirmation_busy'}
            if now<self._cooldown_until:return {'ok':False,'error':'local_confirmation_rate_limited'}
            self._pending=intent
            try:self._queue.put_nowait(intent)
            except queue.Full:self._pending=None;return {'ok':False,'error':'local_confirmation_busy'}
        if not event.wait(self.wait_seconds):
            with self._lock:
                if self._pending is intent:intent['cancelled']=True
            return {'ok':False,'error':'local_confirmation_timeout'}
        result=intent.get('result')
        return result if isinstance(result,dict) else {'ok':False,'error':'local_confirmation_denied'}

    def _finish(self,intent,approved):
        now=float(self.clock())
        with self._lock:
            if self._pending is not intent:return
            self._pending=None;self._cooldown_until=now+self.cooldown_seconds
            if intent.get('cancelled') or now>float(intent.get('expires',0)):
                intent['result']={'ok':False,'error':'local_confirmation_timeout'};intent['event'].set();return
            if approved is not True:
                intent['result']={'ok':False,'error':'local_confirmation_denied'};intent['event'].set();return
            source=normalize_requester_source(intent.get('requesterSource',''));context_digest=str(intent.get('requesterContextDigest',''))
            if not source:
                intent['result']={'ok':False,'error':'requester_source_not_allowed'};intent['event'].set();return
            if len(context_digest)!=64 or any(ch not in '0123456789abcdef' for ch in context_digest):
                intent['result']={'ok':False,'error':'requester_context_invalid'};intent['event'].set();return
            challenge=str(self.token_func() or '');proof=str(self.token_func() or '');attempts=0
            while (not challenge or not proof or _safe_equal(challenge,proof)) and attempts<4:
                if not challenge:challenge=str(self.token_func() or '')
                proof=str(self.token_func() or '');attempts+=1
            if not challenge or not proof or _safe_equal(challenge,proof):
                intent['result']={'ok':False,'error':'local_confirmation_failed'};intent['event'].set();return
            self._active_pair={'actionId':intent['actionId'],'sessionId':self.session_id,'inputDigest':intent['inputDigest'],'requesterSource':source,'requesterContextDigest':context_digest,'challenge':challenge,'proof':proof,'expires':now+self.proof_ttl_seconds}
            intent['result']={'ok':True,'grant':{'actionId':intent['actionId'],'challenge':challenge,'challengeTtlSeconds':int(self.proof_ttl_seconds),'localApprovalProof':proof,'localApprovalProofTtlSeconds':int(self.proof_ttl_seconds)}}
            intent['event'].set()

    def consume(self,action_id,target,challenge,proof,requester_source='',requester_context=''):
        source=normalize_requester_source(requester_source);context_digest=requester_context_digest(requester_context)
        if not source:return 'requester_source_not_allowed'
        if not context_digest:return 'requester_context_invalid'
        now=float(self.clock());input_digest=canonical_input_digest(action_id,target)
        with self._lock:
            pair=self._active_pair
            if pair is None:return 'missing'
            if now>float(pair.get('expires',0)):self._active_pair=None;return 'expired'
            if source!=pair.get('requesterSource'):return 'requester_mismatch'
            if context_digest!=pair.get('requesterContextDigest'):return 'requester_context_mismatch'
            if action_id!=pair.get('actionId'):return 'action_mismatch'
            if self.session_id!=pair.get('sessionId'):return 'session_mismatch'
            if not input_digest or input_digest!=pair.get('inputDigest'):return 'input_mismatch'
            if not _safe_equal(challenge,pair.get('challenge','')):return 'challenge_invalid'
            if not _safe_equal(proof,pair.get('proof','')):return 'proof_invalid'
            self._active_pair=None;return 'ok'

    def snapshot(self):
        snapshot=super().snapshot()
        with self._lock:
            if self._pending is not None and snapshot.get('pending') is not None:snapshot['pending']['requesterContextDigest']=self._pending.get('requesterContextDigest','')
            if self._active_pair is not None and snapshot.get('activePair') is not None:snapshot['activePair']['requesterContextDigest']=self._active_pair.get('requesterContextDigest','')
        return snapshot


def issue_catalog(base_payload,challenge_state,challenge_lock,grant=None,ttl_seconds=ACTION_CHALLENGE_TTL_SECONDS,now=None):
    ts=time.monotonic() if now is None else float(now);ttl=max(1,int(ttl_seconds));actions=[]
    with challenge_lock:
        challenge_state.clear()
        for raw in base_payload.get('actions',[]):
            item=dict(raw);action_id=item.get('id','')
            if action_id=='storage-summary.read':
                challenge=_token();challenge_state[action_id]={'value':challenge,'expires':ts+ttl};item['challenge']=challenge;item['challengeTtlSeconds']=ttl;item.pop('requesterContextRequired',None)
            elif action_id in MUTATING_ACTION_IDS:
                item['localApprovalRequired']=True;item['requesterContextRequired']=True
                if isinstance(grant,dict) and grant.get('actionId')==action_id:
                    item['challenge']=grant.get('challenge','');item['challengeTtlSeconds']=grant.get('challengeTtlSeconds',LOCAL_APPROVAL_TTL_SECONDS);item['localApprovalProof']=grant.get('localApprovalProof','');item['localApprovalProofTtlSeconds']=grant.get('localApprovalProofTtlSeconds',LOCAL_APPROVAL_TTL_SECONDS)
            actions.append(item)
    return {'protocol':ACTIONS_PROTOCOL,'status':'ready','sessionId':base_payload.get('sessionId',''),'policyId':ALLOWLIST_POLICY_ID,'actions':actions,'approvalMode':APPROVAL_MODE}


def consume_read_challenge(state,lock,action_id,value,now=None):return _stable.consume_read_challenge(state,lock,action_id,value,now)


def make_handler(token,node_name='',node_role='',capabilities=None,app_paths=None,app_launcher=None,handoff_launcher=None,challenge_ttl_seconds=ACTION_CHALLENGE_TTL_SECONDS,session_id=None,coordinator=None,interactive_console=None,local_input=None,clock=None,token_func=None):
    caps=sanitize_capabilities(capabilities);paths=build_app_paths(app_paths);session=_base.sanitize_session_id(session_id) or secrets.token_urlsafe(18)
    health_payload=build_health_payload(node_name,node_role,caps,session);actions_payload=build_actions_payload(caps,paths,session);challenge_state={};challenge_lock=threading.Lock()
    local=coordinator or RequesterContextConfirmationCoordinator(session,interactive=interactive_console,input_func=local_input,clock=clock,token_func=token_func)
    Parent=_stable.make_handler(token,node_name,node_role,caps,paths,app_launcher,handoff_launcher,challenge_ttl_seconds,session,local,interactive_console,local_input,clock,token_func)

    class Handler(Parent):
        server_version='RAHNodeAgent/1.2-candidate'
        def _cors(self):
            origin=self._origin()
            if origin in _base.ALLOWED_ORIGINS:
                self.send_header('Access-Control-Allow-Origin',origin);self.send_header('Vary','Origin');self.send_header('Access-Control-Allow-Methods','GET, POST, OPTIONS')
                self.send_header('Access-Control-Allow-Headers','Authorization, Content-Type, '+ACTION_CHALLENGE_HEADER+', '+APPROVAL_ACTION_HEADER+', '+APPROVAL_TARGET_HEADER+', '+LOCAL_APPROVAL_HEADER+', '+REQUESTER_CONTEXT_HEADER)
                if self.headers.get('Access-Control-Request-Private-Network','').lower()=='true':self.send_header('Access-Control-Allow-Private-Network','true')
        def _requester_header_valid(self):
            expected=REQUESTER_CONTEXT_HEADER.lower()
            for key in self.headers.keys():
                lowered=key.lower()
                if lowered.startswith('x-rah-requester-') and lowered!=expected:self._json(400,{'error':'unknown_requester_header'});return False
            return True
        def _requester_context(self):
            value=self.headers.get(REQUESTER_CONTEXT_HEADER);return value if valid_requester_context(value) else ''
        def _forbid_requester_context(self):
            if not self._requester_header_valid():return False
            if self.headers.get(REQUESTER_CONTEXT_HEADER) is not None:self._json(400,{'error':'requester_context_not_allowed'});return False
            return True
        def _approval_intent(self):
            if not self._approval_headers_valid() or not self._requester_header_valid():return False,None
            action=self.headers.get(APPROVAL_ACTION_HEADER);target=self.headers.get(APPROVAL_TARGET_HEADER);raw_context=self.headers.get(REQUESTER_CONTEXT_HEADER)
            if action is None:
                if target is not None:self._json(400,{'error':'approval_action_required_for_target'});return False,None
                if raw_context is not None:self._json(400,{'error':'requester_context_not_allowed'});return False,None
                return True,None
            context=self._requester_context()
            if not context:self._json(400,{'error':'requester_context_required'});return False,None
            if self.headers.get('Transfer-Encoding'):self._json(400,{'error':'approval_intent_body_not_allowed'});return False,None
            try:length=int(self.headers.get('Content-Length','0') or 0)
            except ValueError:self._json(400,{'error':'invalid_content_length'});return False,None
            if length!=0:self._json(400,{'error':'approval_intent_body_not_allowed'});return False,None
            if action not in MUTATING_ACTION_IDS:self._json(400,{'error':'invalid_approval_action'});return False,None
            advertised={row.get('id') for row in actions_payload.get('actions',[])}
            if action not in advertised:self._json(403,{'error':'action_not_advertised'});return False,None
            if 'remote-desktop' not in caps:self._json(403,{'error':'remote_desktop_capability_not_enabled'});return False,None
            if action=='rustdesk.launch':
                if target is not None:self._json(400,{'error':'approval_target_not_allowed'});return False,None
                target=''
            elif not is_valid_rustdesk_peer_id(target):self._json(400,{'error':'invalid_peer_id'});return False,None
            source=self._requester_source()
            if not source:self._json(403,{'error':'requester_source_not_allowed'});return False,None
            result=local.request(action,target,source,context)
            if not result.get('ok'):
                error=result.get('error','local_confirmation_denied');status=503 if error=='local_confirmation_unavailable' else 409 if error in ('local_confirmation_busy','local_confirmation_rate_limited') else 408 if error=='local_confirmation_timeout' else 403
                self._json(status,{'error':error});return False,None
            return True,result.get('grant')
        def _require_local_pair(self,action_id,target=''):
            if not self._requester_header_valid():return False
            challenge=self.headers.get(ACTION_CHALLENGE_HEADER,'');proof=self.headers.get(LOCAL_APPROVAL_HEADER,'');context=self._requester_context()
            if not challenge:self._json(428,{'error':'action_challenge_required'});return False
            if not proof:self._json(428,{'error':'local_approval_proof_required'});return False
            if not context:self._json(428,{'error':'requester_context_required'});return False
            source=self._requester_source()
            if not source:self._json(403,{'error':'requester_source_not_allowed'});return False
            result=local.consume(action_id,target,challenge,proof,source,context)
            errors={'missing':(428,'local_approval_proof_required'),'expired':(409,'local_approval_proof_expired'),'requester_source_not_allowed':(403,'requester_source_not_allowed'),'requester_mismatch':(409,'local_approval_requester_mismatch'),'requester_context_invalid':(400,'requester_context_invalid'),'requester_context_mismatch':(409,'local_approval_requester_context_mismatch'),'action_mismatch':(409,'local_approval_action_mismatch'),'session_mismatch':(409,'local_approval_session_mismatch'),'input_mismatch':(409,'local_approval_input_mismatch'),'challenge_invalid':(409,'action_challenge_invalid_or_expired'),'proof_invalid':(409,'local_approval_proof_invalid')}
            if result=='ok':return True
            status,error=errors.get(result,(409,'local_approval_proof_invalid'));self._json(status,{'error':error});return False
        def do_GET(self):
            if self.path in ('/launch/rustdesk','/handoff/rustdesk'):self._json(405,{'error':'method_not_allowed'});return
            if self.path not in ('/health','/actions','/storage'):self._json(404,{'error':'not_found'});return
            if not self._authorized():return
            if self.path=='/health':
                if not self._forbid_requester_context():return
                self._json(200,health_payload);return
            if self.path=='/actions':
                ok,grant=self._approval_intent()
                if not ok:return
                self._json(200,issue_catalog(actions_payload,challenge_state,challenge_lock,grant,challenge_ttl_seconds));return
            if not self._forbid_requester_context():return
            payload=_base.build_storage_payload(caps)
            if payload is None:self._json(403,{'error':'storage_capability_not_enabled'});return
            result=consume_read_challenge(challenge_state,challenge_lock,'storage-summary.read',self.headers.get(ACTION_CHALLENGE_HEADER,''))
            if result!='ok':self._json(428 if result=='missing' else 409,{'error':'action_challenge_required' if result=='missing' else 'action_challenge_invalid_or_expired'});return
            self._json(200,payload)
    Handler.local_confirmation_coordinator=local
    return Handler


def create_server(host,port,token,node_name='',node_role='',capabilities=None,app_paths=None,app_launcher=None,handoff_launcher=None,challenge_ttl_seconds=ACTION_CHALLENGE_TTL_SECONDS,session_id=None,coordinator=None,interactive_console=None,local_input=None,clock=None,token_func=None):
    handler=make_handler(token,node_name,node_role,capabilities,app_paths,app_launcher,handoff_launcher,challenge_ttl_seconds,session_id,coordinator,interactive_console,local_input,clock,token_func)
    server=ThreadingHTTPServer((host,port),handler);server.local_confirmation_coordinator=handler.local_confirmation_coordinator;return server


def main():
    args=_base.parse_args();host='0.0.0.0' if args.allow_lan else '127.0.0.1';token=secrets.token_urlsafe(32);capabilities=sanitize_capabilities(args.capability);paths=build_app_paths()
    server=create_server(host,PORT,token,args.name,args.role,capabilities,paths,interactive_console=sys.stdin.isatty());actions=build_actions_payload(capabilities,paths)['actions']
    print(f'RAH Node Agent v{AGENT_VERSION}');print('Stage: Candidate');print(f'Allowlist policy: {ALLOWLIST_POLICY_ID}');print(f'Actions protocol: {ACTIONS_PROTOCOL}')
    print('Requester context: fixed ephemeral header; Node stores SHA-256 digest only in active mutating pair');print('Requester source binding: actual IPv4 socket peer only; forwarding headers ignored')
    print('Mode: '+('LAN enrollment enabled' if args.allow_lan else 'loopback only'));print(f'Port: {PORT}');print('Capabilities: '+(', '.join(capabilities) if capabilities else 'identity-only'));print('Advertised actions: '+(', '.join(a['id'] for a in actions) if actions else 'none'))
    print('Node-local confirmation: '+('interactive console enabled' if sys.stdin.isatty() else 'unavailable; mutating actions fail closed'));print('Token: '+token);print('Boundary: fixed 4 capabilities / 3 actions / 5 routes; no shell/files/generic process/native remote-control API')
    try:server.serve_forever()
    except KeyboardInterrupt:pass
    finally:server.server_close()

if __name__=='__main__':main()
