#!/usr/bin/env python3
from __future__ import annotations
import hashlib,hmac,importlib.util,json,queue,secrets,sys,threading,time
from http.server import BaseHTTPRequestHandler,ThreadingHTTPServer
from pathlib import Path

STABLE_PATH=Path(__file__).with_name('rah-node-agent-v0.9.py')
_spec=importlib.util.spec_from_file_location('rah_node_agent_stable_v09_for_candidate_v10',STABLE_PATH)
if _spec is None or _spec.loader is None:raise RuntimeError('Unable to load Stable Node Agent 0.9')
_stable=importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_stable)
_base=_stable._base

AGENT_VERSION='1.0.0-candidate'
ACTIONS_PROTOCOL='rah-node-actions-v5'
ALLOWLIST_POLICY_ID='rah-capability-allowlist-v1'
APPROVAL_ACTION_HEADER='X-RAH-Approval-Action'
APPROVAL_TARGET_HEADER='X-RAH-Approval-Target'
LOCAL_APPROVAL_HEADER='X-RAH-Local-Approval'
ACTION_CHALLENGE_HEADER=_stable.ACTION_CHALLENGE_HEADER
ACTION_CHALLENGE_TTL_SECONDS=30
LOCAL_APPROVAL_TTL_SECONDS=30
LOCAL_CONFIRMATION_WAIT_SECONDS=30
LOCAL_CONFIRMATION_COOLDOWN_SECONDS=2
PORT=_stable.PORT

ALLOWED_CAPABILITIES=_stable.ALLOWED_CAPABILITIES
ACTION_CATALOG=_stable.ACTION_CATALOG
MUTATING_ACTION_IDS=('rustdesk.launch','rustdesk.connect')
ROUTES=('/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk')

sanitize_capabilities=_stable.sanitize_capabilities
build_permissions=_stable.build_permissions
build_app_paths=_stable.build_app_paths
is_authorized=_stable.is_authorized
is_valid_rustdesk_peer_id=_stable.is_valid_rustdesk_peer_id


def build_health_payload(node_name='',node_role='',capabilities=None,session_id=''):
    payload=_stable.build_health_payload(node_name,node_role,capabilities,session_id)
    payload['agentVersion']=AGENT_VERSION
    return payload


def build_actions_payload(capabilities=None,app_paths=None,session_id=''):
    payload=_stable.build_actions_payload(capabilities,app_paths,session_id)
    payload['protocol']=ACTIONS_PROTOCOL
    payload['policyId']=ALLOWLIST_POLICY_ID
    payload['approvalMode']='command-center-ephemeral-plus-node-local'
    return payload


def canonical_input_digest(action_id,target=''):
    if action_id=='rustdesk.launch':
        if target not in ('',None):return ''
        text='rustdesk.launch:none'
    elif action_id=='rustdesk.connect':
        if not is_valid_rustdesk_peer_id(target):return ''
        text='rustdesk.connect:peer:'+target
    else:
        return ''
    return hashlib.sha256(text.encode('utf-8')).hexdigest()


def _safe_equal(left,right):
    return isinstance(left,str) and isinstance(right,str) and bool(left) and bool(right) and hmac.compare_digest(left,right)


def _token():return secrets.token_urlsafe(24)


class LocalConfirmationCoordinator:
    def __init__(self,session_id,interactive=None,input_func=None,clock=None,token_func=None,wait_seconds=LOCAL_CONFIRMATION_WAIT_SECONDS,proof_ttl_seconds=LOCAL_APPROVAL_TTL_SECONDS,cooldown_seconds=LOCAL_CONFIRMATION_COOLDOWN_SECONDS,start_thread=True):
        session=_base.sanitize_session_id(session_id)
        if not session:raise ValueError('invalid session id')
        self.session_id=session
        self.interactive=bool(sys.stdin.isatty()) if interactive is None else bool(interactive)
        self.input_func=input if input_func is None else input_func
        self.clock=time.monotonic if clock is None else clock
        self.token_func=_token if token_func is None else token_func
        self.wait_seconds=max(0.01,float(wait_seconds))
        self.proof_ttl_seconds=max(1.0,float(proof_ttl_seconds))
        self.cooldown_seconds=max(0.0,float(cooldown_seconds))
        self._queue=queue.Queue(maxsize=1)
        self._lock=threading.Lock()
        self._pending=None
        self._active_pair=None
        self._cooldown_until=0.0
        self._thread=None
        if self.interactive and start_thread:
            self._thread=threading.Thread(target=self._reader_loop,name='RAHLocalApproval',daemon=True)
            self._thread.start()

    def _fixed_prompt(self,action_id,target):
        if action_id=='rustdesk.launch':return 'RAH local approval: Launch RustDesk? [y/N] '
        if action_id=='rustdesk.connect' and is_valid_rustdesk_peer_id(target):return f'RAH local approval: Connect RustDesk to {target}? [y/N] '
        return ''

    def request(self,action_id,target=''):
        if not self.interactive or self._thread is None:return {'ok':False,'error':'local_confirmation_unavailable'}
        input_digest=canonical_input_digest(action_id,target)
        if not input_digest:return {'ok':False,'error':'invalid_fixed_action_input'}
        now=float(self.clock())
        event=threading.Event()
        intent={
            'actionId':action_id,
            'inputDigest':input_digest,
            'displayTarget':target if action_id=='rustdesk.connect' else '',
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
            except queue.Full:
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
            prompt=self._fixed_prompt(intent.get('actionId',''),intent.get('displayTarget',''))
            approved=False
            if prompt:
                try:approved=str(self.input_func(prompt)).strip().lower() in ('y','yes')
                except Exception:approved=False
            self._finish(intent,approved)

    def _finish(self,intent,approved):
        now=float(self.clock())
        with self._lock:
            if self._pending is not intent:return
            self._pending=None
            self._cooldown_until=now+self.cooldown_seconds
            if intent.get('cancelled') or now>float(intent.get('expires',0)):
                intent['result']={'ok':False,'error':'local_confirmation_timeout'}
                intent['event'].set()
                return
            if approved is not True:
                intent['result']={'ok':False,'error':'local_confirmation_denied'}
                intent['event'].set()
                return
            challenge=str(self.token_func() or '')
            proof=str(self.token_func() or '')
            attempts=0
            while (not challenge or not proof or _safe_equal(challenge,proof)) and attempts<4:
                if not challenge:challenge=str(self.token_func() or '')
                proof=str(self.token_func() or '')
                attempts+=1
            if not challenge or not proof or _safe_equal(challenge,proof):
                intent['result']={'ok':False,'error':'local_confirmation_failed'}
                intent['event'].set()
                return
            self._active_pair={
                'actionId':intent['actionId'],
                'sessionId':self.session_id,
                'inputDigest':intent['inputDigest'],
                'challenge':challenge,
                'proof':proof,
                'expires':now+self.proof_ttl_seconds,
            }
            intent['result']={
                'ok':True,
                'grant':{
                    'actionId':intent['actionId'],
                    'challenge':challenge,
                    'challengeTtlSeconds':int(self.proof_ttl_seconds),
                    'localApprovalProof':proof,
                    'localApprovalProofTtlSeconds':int(self.proof_ttl_seconds),
                },
            }
            intent['event'].set()

    def consume(self,action_id,target,challenge,proof):
        now=float(self.clock())
        input_digest=canonical_input_digest(action_id,target)
        with self._lock:
            pair=self._active_pair
            if pair is None:return 'missing'
            if now>float(pair.get('expires',0)):
                self._active_pair=None
                return 'expired'
            if action_id!=pair.get('actionId'):return 'action_mismatch'
            if self.session_id!=pair.get('sessionId'):return 'session_mismatch'
            if not input_digest or input_digest!=pair.get('inputDigest'):return 'input_mismatch'
            if not _safe_equal(challenge,pair.get('challenge','')):return 'challenge_invalid'
            if not _safe_equal(proof,pair.get('proof','')):return 'proof_invalid'
            self._active_pair=None
            return 'ok'

    def snapshot(self):
        with self._lock:
            pending=self._pending
            pair=self._active_pair
            return {
                'interactive':self.interactive,
                'pending':None if pending is None else {
                    'actionId':pending['actionId'],
                    'inputDigest':pending['inputDigest'],
                    'cancelled':bool(pending.get('cancelled')),
                },
                'activePair':None if pair is None else {
                    'actionId':pair['actionId'],
                    'sessionId':pair['sessionId'],
                    'inputDigest':pair['inputDigest'],
                    'expires':pair['expires'],
                },
                'cooldownUntil':self._cooldown_until,
            }


def issue_catalog(base_payload,challenge_state,challenge_lock,grant=None,ttl_seconds=ACTION_CHALLENGE_TTL_SECONDS,now=None):
    ts=time.monotonic() if now is None else float(now)
    ttl=max(1,int(ttl_seconds))
    actions=[]
    with challenge_lock:
        challenge_state.clear()
        for raw in base_payload.get('actions',[]):
            item=dict(raw)
            action_id=item.get('id','')
            if action_id=='storage-summary.read':
                challenge=_token()
                challenge_state[action_id]={'value':challenge,'expires':ts+ttl}
                item['challenge']=challenge
                item['challengeTtlSeconds']=ttl
            elif action_id in MUTATING_ACTION_IDS:
                item['localApprovalRequired']=True
                if isinstance(grant,dict) and grant.get('actionId')==action_id:
                    item['challenge']=grant.get('challenge','')
                    item['challengeTtlSeconds']=grant.get('challengeTtlSeconds',LOCAL_APPROVAL_TTL_SECONDS)
                    item['localApprovalProof']=grant.get('localApprovalProof','')
                    item['localApprovalProofTtlSeconds']=grant.get('localApprovalProofTtlSeconds',LOCAL_APPROVAL_TTL_SECONDS)
            actions.append(item)
    return {
        'protocol':ACTIONS_PROTOCOL,
        'status':'ready',
        'sessionId':base_payload.get('sessionId',''),
        'policyId':ALLOWLIST_POLICY_ID,
        'actions':actions,
        'approvalMode':'command-center-ephemeral-plus-node-local',
    }


def consume_read_challenge(state,lock,action_id,value,now=None):
    return _base.consume_action_challenge(state,lock,action_id,value,now)


def make_handler(token,node_name='',node_role='',capabilities=None,app_paths=None,app_launcher=None,handoff_launcher=None,challenge_ttl_seconds=ACTION_CHALLENGE_TTL_SECONDS,session_id=None,coordinator=None,interactive_console=None,local_input=None,clock=None,token_func=None):
    caps=sanitize_capabilities(capabilities)
    paths=build_app_paths(app_paths)
    session=_base.sanitize_session_id(session_id) or secrets.token_urlsafe(18)
    health_payload=build_health_payload(node_name,node_role,caps,session)
    actions_payload=build_actions_payload(caps,paths,session)
    challenge_state={}
    challenge_lock=threading.Lock()
    launcher=app_launcher or _base.launch_executable
    handoff=handoff_launcher or _base.launch_rustdesk_connect
    local=coordinator or LocalConfirmationCoordinator(session,interactive=interactive_console,input_func=local_input,clock=clock,token_func=token_func)

    class Handler(BaseHTTPRequestHandler):
        server_version='RAHNodeAgent/1.0-candidate'
        sys_version=''
        def log_message(self,fmt,*args):return
        def _origin(self):return self.headers.get('Origin','')
        def _origin_allowed(self):return self._origin() in _base.ALLOWED_ORIGINS
        def _cors(self):
            origin=self._origin()
            if origin in _base.ALLOWED_ORIGINS:
                self.send_header('Access-Control-Allow-Origin',origin)
                self.send_header('Vary','Origin')
                self.send_header('Access-Control-Allow-Methods','GET, POST, OPTIONS')
                self.send_header('Access-Control-Allow-Headers','Authorization, Content-Type, '+ACTION_CHALLENGE_HEADER+', '+APPROVAL_ACTION_HEADER+', '+APPROVAL_TARGET_HEADER+', '+LOCAL_APPROVAL_HEADER)
                if self.headers.get('Access-Control-Request-Private-Network','').lower()=='true':self.send_header('Access-Control-Allow-Private-Network','true')
        def _json(self,status,body):
            data=json.dumps(body,separators=(',',':')).encode('utf-8')
            self.send_response(status)
            self._cors()
            self.send_header('Content-Type','application/json; charset=utf-8')
            self.send_header('Content-Length',str(len(data)))
            self.send_header('Cache-Control','no-store')
            self.send_header('X-Content-Type-Options','nosniff')
            self.end_headers()
            self.wfile.write(data)
        def _authorized(self):
            if not self._origin_allowed():
                self._json(403,{'error':'origin_not_allowed'})
                return False
            if not is_authorized(self.headers.get('Authorization'),token):
                self._json(401,{'error':'unauthorized'})
                return False
            return True
        def _read_challenge(self,action_id):
            result=consume_read_challenge(challenge_state,challenge_lock,action_id,self.headers.get(ACTION_CHALLENGE_HEADER,''))
            if result=='ok':return True
            self._json(428 if result=='missing' else 409,{'error':'action_challenge_required' if result=='missing' else 'action_challenge_invalid_or_expired'})
            return False
        def _handoff_peer_id(self):
            if self.headers.get('Transfer-Encoding'):
                self._json(400,{'error':'transfer_encoding_not_allowed'})
                return None
            content_type=self.headers.get('Content-Type','').split(';',1)[0].strip().lower()
            if content_type!='application/json':
                self._json(415,{'error':'json_content_type_required'})
                return None
            try:length=int(self.headers.get('Content-Length','0') or 0)
            except ValueError:
                self._json(400,{'error':'invalid_content_length'})
                return None
            if length<=0 or length>256:
                self._json(400,{'error':'invalid_handoff_body_size'})
                return None
            try:payload=json.loads(self.rfile.read(length).decode('utf-8'))
            except Exception:
                self._json(400,{'error':'invalid_json'})
                return None
            if not isinstance(payload,dict) or set(payload.keys())!={'peerId'}:
                self._json(400,{'error':'peer_id_only'})
                return None
            peer_id=payload.get('peerId')
            if not is_valid_rustdesk_peer_id(peer_id):
                self._json(400,{'error':'invalid_peer_id'})
                return None
            return peer_id
        def _approval_headers_valid(self):
            allowed={APPROVAL_ACTION_HEADER.lower(),APPROVAL_TARGET_HEADER.lower()}
            for key in self.headers.keys():
                lowered=key.lower()
                if lowered.startswith('x-rah-approval-') and lowered not in allowed:
                    self._json(400,{'error':'unknown_approval_header'})
                    return False
            if self.headers.get(LOCAL_APPROVAL_HEADER) is not None or self.headers.get(ACTION_CHALLENGE_HEADER) is not None:
                self._json(400,{'error':'approval_grant_header_not_allowed'})
                return False
            return True
        def _approval_intent(self):
            if not self._approval_headers_valid():return False,None
            action=self.headers.get(APPROVAL_ACTION_HEADER)
            target=self.headers.get(APPROVAL_TARGET_HEADER)
            if action is None:
                if target is not None:
                    self._json(400,{'error':'approval_action_required_for_target'})
                    return False,None
                return True,None
            if self.headers.get('Transfer-Encoding'):
                self._json(400,{'error':'approval_intent_body_not_allowed'})
                return False,None
            try:length=int(self.headers.get('Content-Length','0') or 0)
            except ValueError:
                self._json(400,{'error':'invalid_content_length'})
                return False,None
            if length!=0:
                self._json(400,{'error':'approval_intent_body_not_allowed'})
                return False,None
            if action not in MUTATING_ACTION_IDS:
                self._json(400,{'error':'invalid_approval_action'})
                return False,None
            advertised={row.get('id') for row in actions_payload.get('actions',[])}
            if action not in advertised:
                self._json(403,{'error':'action_not_advertised'})
                return False,None
            if 'remote-desktop' not in caps:
                self._json(403,{'error':'remote_desktop_capability_not_enabled'})
                return False,None
            if action=='rustdesk.launch':
                if target is not None:
                    self._json(400,{'error':'approval_target_not_allowed'})
                    return False,None
                target=''
            else:
                if not is_valid_rustdesk_peer_id(target):
                    self._json(400,{'error':'invalid_peer_id'})
                    return False,None
            result=local.request(action,target)
            if not result.get('ok'):
                error=result.get('error','local_confirmation_denied')
                status=503 if error=='local_confirmation_unavailable' else 409 if error in ('local_confirmation_busy','local_confirmation_rate_limited') else 408 if error=='local_confirmation_timeout' else 403
                self._json(status,{'error':error})
                return False,None
            return True,result.get('grant')
        def _require_local_pair(self,action_id,target=''):
            challenge=self.headers.get(ACTION_CHALLENGE_HEADER,'')
            proof=self.headers.get(LOCAL_APPROVAL_HEADER,'')
            if not challenge:
                self._json(428,{'error':'action_challenge_required'})
                return False
            if not proof:
                self._json(428,{'error':'local_approval_proof_required'})
                return False
            result=local.consume(action_id,target,challenge,proof)
            errors={
                'missing':(428,'local_approval_proof_required'),
                'expired':(409,'local_approval_proof_expired'),
                'action_mismatch':(409,'local_approval_action_mismatch'),
                'session_mismatch':(409,'local_approval_session_mismatch'),
                'input_mismatch':(409,'local_approval_input_mismatch'),
                'challenge_invalid':(409,'action_challenge_invalid_or_expired'),
                'proof_invalid':(409,'local_approval_proof_invalid'),
            }
            if result=='ok':return True
            status,error=errors.get(result,(409,'local_approval_proof_invalid'))
            self._json(status,{'error':error})
            return False
        def do_OPTIONS(self):
            if self.path not in ROUTES or not self._origin_allowed():
                self._json(403,{'error':'forbidden'})
                return
            self.send_response(204)
            self._cors()
            self.send_header('Content-Length','0')
            self.end_headers()
        def do_GET(self):
            if self.path in ('/launch/rustdesk','/handoff/rustdesk'):
                self._json(405,{'error':'method_not_allowed'})
                return
            if self.path not in ('/health','/actions','/storage'):
                self._json(404,{'error':'not_found'})
                return
            if not self._authorized():return
            if self.path=='/health':
                self._json(200,health_payload)
                return
            if self.path=='/actions':
                ok,grant=self._approval_intent()
                if not ok:return
                self._json(200,issue_catalog(actions_payload,challenge_state,challenge_lock,grant,challenge_ttl_seconds))
                return
            payload=_base.build_storage_payload(caps)
            if payload is None:
                self._json(403,{'error':'storage_capability_not_enabled'})
                return
            if not self._read_challenge('storage-summary.read'):return
            self._json(200,payload)
        def do_POST(self):
            if self.path in ('/health','/actions','/storage'):
                self._json(405,{'error':'method_not_allowed'})
                return
            if self.path not in ('/launch/rustdesk','/handoff/rustdesk'):
                self._json(404,{'error':'not_found'})
                return
            if not self._authorized():return
            if 'remote-desktop' not in caps:
                self._json(403,{'error':'remote_desktop_capability_not_enabled'})
                return
            path=paths.get('rustdesk','')
            if not path:
                self._json(503,{'error':'rustdesk_not_available'})
                return
            if self.path=='/launch/rustdesk':
                if self.headers.get('Transfer-Encoding'):
                    self._json(400,{'error':'request_body_not_allowed'})
                    return
                try:length=int(self.headers.get('Content-Length','0') or 0)
                except ValueError:
                    self._json(400,{'error':'invalid_content_length'})
                    return
                if length!=0:
                    self._json(400,{'error':'request_body_not_allowed'})
                    return
                if not self._require_local_pair('rustdesk.launch',''):return
                try:ok=bool(launcher(path))
                except Exception:ok=False
                if not ok:
                    self._json(503,{'error':'rustdesk_launch_failed'})
                    return
                self._json(200,{'protocol':_base.LAUNCH_PROTOCOL,'status':'launched','app':'rustdesk'})
                return
            peer_id=self._handoff_peer_id()
            if peer_id is None:return
            if not self._require_local_pair('rustdesk.connect',peer_id):return
            try:ok=bool(handoff(path,peer_id))
            except Exception:ok=False
            if not ok:
                self._json(503,{'error':'rustdesk_handoff_failed'})
                return
            self._json(200,{'protocol':_base.HANDOFF_PROTOCOL,'status':'handoff-started','app':'rustdesk'})
        def do_PUT(self):self._json(405,{'error':'method_not_allowed'})
        def do_DELETE(self):self._json(405,{'error':'method_not_allowed'})
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
