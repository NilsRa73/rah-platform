#!/usr/bin/env python3
from __future__ import annotations
import base64,hashlib,hmac,importlib.util,json,secrets,sys,threading,time
from pathlib import Path

STABLE_PATH=Path(__file__).with_name('rah-node-agent-v1.2-candidate.py')
_spec=importlib.util.spec_from_file_location('rah_node_agent_v12_candidate_for_v13',STABLE_PATH)
if _spec is None or _spec.loader is None:raise RuntimeError('Unable to load Node Agent 1.2 Candidate baseline')
_v12=importlib.util.module_from_spec(_spec);_spec.loader.exec_module(_v12)
_base=_v12._base

AGENT_VERSION='1.3.0-candidate'
ACTIONS_PROTOCOL='rah-node-actions-v7'
AUTH_PROTOCOL='rah-node-auth-v2'
ALLOWLIST_POLICY_ID='rah-capability-allowlist-v1'
AUTH_INIT_HEADER='X-RAH-Auth-Init'
AUTH_NONCE_HEADER='X-RAH-Auth-Nonce'
AUTH_PROOF_HEADER='X-RAH-Auth-Proof'
AUTH_NONCE_TTL_SECONDS=30
AUTH_NONCE_MAX_PER_SOURCE=8
AUTH_NONCE_MAX_GLOBAL=64
AUTH_CANONICAL_VERSION='RAH-AUTH-V2'
REQUESTER_CONTEXT_HEADER=_v12.REQUESTER_CONTEXT_HEADER
APPROVAL_ACTION_HEADER=_v12.APPROVAL_ACTION_HEADER
APPROVAL_TARGET_HEADER=_v12.APPROVAL_TARGET_HEADER
LOCAL_APPROVAL_HEADER=_v12.LOCAL_APPROVAL_HEADER
ACTION_CHALLENGE_HEADER=_v12.ACTION_CHALLENGE_HEADER
ACTION_CHALLENGE_TTL_SECONDS=_v12.ACTION_CHALLENGE_TTL_SECONDS
LOCAL_APPROVAL_TTL_SECONDS=_v12.LOCAL_APPROVAL_TTL_SECONDS
PORT=_v12.PORT
ALLOWED_CAPABILITIES=_v12.ALLOWED_CAPABILITIES
ACTION_CATALOG=_v12.ACTION_CATALOG
MUTATING_ACTION_IDS=_v12.MUTATING_ACTION_IDS
ROUTES=_v12.ROUTES

sanitize_capabilities=_v12.sanitize_capabilities
build_permissions=_v12.build_permissions
build_app_paths=_v12.build_app_paths
is_valid_rustdesk_peer_id=_v12.is_valid_rustdesk_peer_id
valid_requester_context=_v12.valid_requester_context
requester_context_digest=_v12.requester_context_digest
normalize_requester_source=_v12.normalize_requester_source
ContextBoundConfirmationCoordinator=_v12.ContextBoundConfirmationCoordinator
LocalConfirmationCoordinator=ContextBoundConfirmationCoordinator
canonical_input_digest=_v12.canonical_input_digest

_original_build_actions_payload=_v12.build_actions_payload
_original_issue_catalog=_v12.issue_catalog
_original_build_health_payload=_v12.build_health_payload

def build_actions_payload(capabilities=None,app_paths=None,session_id=''):
    payload=_original_build_actions_payload(capabilities,app_paths,session_id);payload['protocol']=ACTIONS_PROTOCOL;payload['policyId']=ALLOWLIST_POLICY_ID;return payload

def issue_catalog(base_payload,challenge_state,challenge_lock,grant=None,ttl_seconds=ACTION_CHALLENGE_TTL_SECONDS,now=None):
    payload=_original_issue_catalog(base_payload,challenge_state,challenge_lock,grant,ttl_seconds,now);payload['protocol']=ACTIONS_PROTOCOL;payload['policyId']=ALLOWLIST_POLICY_ID;return payload

def build_health_payload(node_name='',node_role='',capabilities=None,session_id=''):
    payload=_original_build_health_payload(node_name,node_role,capabilities,session_id);payload['agentVersion']=AGENT_VERSION;return payload

# Patch only the private Node 1.2 module instance loaded by this Candidate process.
_v12.build_actions_payload=build_actions_payload
_v12.issue_catalog=issue_catalog
_v12.build_health_payload=build_health_payload


def _safe_ascii(value,max_len=256):return isinstance(value,str) and value.isascii() and len(value)<=max_len and not any(ch in value for ch in ('\r','\n','\0'))
def _safe_token(value,min_len=24,max_len=64):return _safe_ascii(value,max_len) and len(value)>=min_len and all(ch.isalnum() or ch in '_-' for ch in value)
def _safe_equal(left,right):
    if not isinstance(left,str) or not isinstance(right,str) or not left or not right:return False
    return hmac.compare_digest(left,right)
def _body_sha256(data):return hashlib.sha256(data).hexdigest()
def _proof(token,canonical):
    if not isinstance(token,str) or not token or not isinstance(canonical,str) or not canonical:return ''
    digest=hmac.new(token.encode('utf-8'),canonical.encode('utf-8'),hashlib.sha256).digest()
    return base64.urlsafe_b64encode(digest).decode('ascii').rstrip('=')

def _security_fields(headers):
    values={
        'approvalAction':headers.get(APPROVAL_ACTION_HEADER,'') or '',
        'approvalTarget':headers.get(APPROVAL_TARGET_HEADER,'') or '',
        'requesterContext':headers.get(REQUESTER_CONTEXT_HEADER,'') or '',
        'actionChallenge':headers.get(ACTION_CHALLENGE_HEADER,'') or '',
        'nodeLocalApprovalProof':headers.get(LOCAL_APPROVAL_HEADER,'') or '',
    }
    return values if all(_safe_ascii(v) for v in values.values()) else None

def canonical_request(session_id,nonce,method,path,body_bytes=b'',headers=None):
    session=_base.sanitize_session_id(session_id);n=nonce if _safe_token(nonce) else '';m=method.upper() if isinstance(method,str) else '';p=path if isinstance(path,str) else '';fields=_security_fields(headers or {})
    if not session or not n or fields is None or p not in ROUTES or '?' in p or '#' in p:return ''
    empty=len(body_bytes)==0
    if p=='/health':valid=m=='GET' and empty and all(not v for v in fields.values())
    elif p=='/actions':
        if m!='GET' or not empty:valid=False
        elif all(not v for v in fields.values()):valid=True
        else:
            action=fields['approvalAction'];context=fields['requesterContext'];target=fields['approvalTarget']
            valid=action in MUTATING_ACTION_IDS and valid_requester_context(context) and not fields['actionChallenge'] and not fields['nodeLocalApprovalProof'] and ((action=='rustdesk.launch' and not target) or (action=='rustdesk.connect' and is_valid_rustdesk_peer_id(target)))
    elif p=='/storage':valid=m=='GET' and empty and _safe_token(fields['actionChallenge']) and not fields['approvalAction'] and not fields['approvalTarget'] and not fields['requesterContext'] and not fields['nodeLocalApprovalProof']
    elif p=='/launch/rustdesk':valid=m=='POST' and empty and valid_requester_context(fields['requesterContext']) and _safe_token(fields['actionChallenge']) and _safe_token(fields['nodeLocalApprovalProof']) and not fields['approvalAction'] and not fields['approvalTarget']
    elif p=='/handoff/rustdesk':valid=m=='POST' and 0<len(body_bytes)<=256 and valid_requester_context(fields['requesterContext']) and _safe_token(fields['actionChallenge']) and _safe_token(fields['nodeLocalApprovalProof']) and not fields['approvalAction'] and not fields['approvalTarget']
    else:valid=False
    if not valid:return ''
    return '\n'.join([AUTH_CANONICAL_VERSION,session,n,m,p,_body_sha256(body_bytes),fields['approvalAction'],fields['approvalTarget'],fields['requesterContext'],fields['actionChallenge'],fields['nodeLocalApprovalProof']])

class AuthNonceStore:
    def __init__(self,clock=None,nonce_func=None,ttl_seconds=AUTH_NONCE_TTL_SECONDS,max_per_source=AUTH_NONCE_MAX_PER_SOURCE,max_global=AUTH_NONCE_MAX_GLOBAL):
        self.clock=time.monotonic if clock is None else clock;self.nonce_func=(lambda:secrets.token_urlsafe(24)) if nonce_func is None else nonce_func;self.ttl=max(1,float(ttl_seconds));self.max_per=max(1,int(max_per_source));self.max_global=max(self.max_per,int(max_global));self._lock=threading.Lock();self._items={}
    def _prune_locked(self,now):
        for nonce,item in list(self._items.items()):
            if now>float(item['expires']):self._items.pop(nonce,None)
    def issue(self,source):
        src=normalize_requester_source(source);now=float(self.clock())
        if not src:return {'ok':False,'error':'requester_source_not_allowed'}
        with self._lock:
            self._prune_locked(now)
            if len(self._items)>=self.max_global:return {'ok':False,'error':'auth_nonce_capacity'}
            if sum(1 for item in self._items.values() if item['source']==src)>=self.max_per:return {'ok':False,'error':'auth_nonce_source_capacity'}
            nonce=''
            for _ in range(8):
                candidate=str(self.nonce_func() or '')
                if _safe_token(candidate) and candidate not in self._items:nonce=candidate;break
            if not nonce:return {'ok':False,'error':'auth_nonce_generation_failed'}
            self._items[nonce]={'source':src,'expires':now+self.ttl}
            return {'ok':True,'nonce':nonce,'ttl':int(self.ttl)}
    def consume_for_source(self,nonce,source):
        src=normalize_requester_source(source);now=float(self.clock())
        if not src:return 'requester_source_not_allowed'
        if not _safe_token(nonce):return 'invalid'
        with self._lock:
            self._prune_locked(now);item=self._items.get(nonce)
            if item is None:return 'invalid'
            if item['source']!=src:return 'requester_mismatch'
            self._items.pop(nonce,None);return 'ok'
    def snapshot(self):
        now=float(self.clock())
        with self._lock:
            self._prune_locked(now);per={}
            for item in self._items.values():per[item['source']]=per.get(item['source'],0)+1
            return {'outstanding':len(self._items),'perSource':per,'rawNoncesExposed':False}


def make_handler(token,node_name='',node_role='',capabilities=None,app_paths=None,app_launcher=None,handoff_launcher=None,challenge_ttl_seconds=ACTION_CHALLENGE_TTL_SECONDS,session_id=None,coordinator=None,interactive_console=None,local_input=None,clock=None,token_func=None,auth_nonce_store=None):
    caps=sanitize_capabilities(capabilities);paths=build_app_paths(app_paths);session=_base.sanitize_session_id(session_id) or secrets.token_urlsafe(18)
    local=coordinator or ContextBoundConfirmationCoordinator(session,interactive=interactive_console,input_func=local_input,clock=clock,token_func=token_func)
    nonces=auth_nonce_store or AuthNonceStore(clock=clock)
    Parent=_v12.make_handler(token,node_name,node_role,caps,paths,app_launcher,handoff_launcher,challenge_ttl_seconds,session,local,interactive_console,local_input,clock,token_func)

    class Handler(Parent):
        server_version='RAHNodeAgent/1.3-candidate'
        def _cors(self):
            origin=self._origin()
            if origin in _base.ALLOWED_ORIGINS:
                self.send_header('Access-Control-Allow-Origin',origin);self.send_header('Vary','Origin');self.send_header('Access-Control-Allow-Methods','GET, POST, OPTIONS')
                self.send_header('Access-Control-Allow-Headers','Content-Type, '+AUTH_INIT_HEADER+', '+AUTH_NONCE_HEADER+', '+AUTH_PROOF_HEADER+', '+ACTION_CHALLENGE_HEADER+', '+APPROVAL_ACTION_HEADER+', '+APPROVAL_TARGET_HEADER+', '+LOCAL_APPROVAL_HEADER+', '+REQUESTER_CONTEXT_HEADER)
                if self.headers.get('Access-Control-Request-Private-Network','').lower()=='true':self.send_header('Access-Control-Allow-Private-Network','true')
        def _requester_source_auth(self):return normalize_requester_source(self.client_address[0] if self.client_address else '')
        def _auth_header_names_valid(self,init=False):
            allowed={AUTH_INIT_HEADER.lower()} if init else {AUTH_NONCE_HEADER.lower(),AUTH_PROOF_HEADER.lower()}
            for key in self.headers.keys():
                lowered=key.lower()
                if lowered.startswith('x-rah-auth-') and lowered not in allowed:self._json(400,{'error':'unknown_auth_header'});return False
            return True
        def _authorization_absent(self):
            if self.headers.get('Authorization') is not None:self._json(400,{'error':'authorization_transport_forbidden'});return False
            return True
        def _auth_init(self):
            if not self._origin_allowed():self._json(403,{'error':'origin_not_allowed'});return
            if not self._authorization_absent() or not self._auth_header_names_valid(True):return
            if self.headers.get(AUTH_INIT_HEADER)!='1':self._json(400,{'error':'auth_init_invalid'});return
            if self.headers.get('Transfer-Encoding') or int(self.headers.get('Content-Length','0') or 0)!=0:self._json(400,{'error':'auth_init_body_not_allowed'});return
            for key in (REQUESTER_CONTEXT_HEADER,APPROVAL_ACTION_HEADER,APPROVAL_TARGET_HEADER,ACTION_CHALLENGE_HEADER,LOCAL_APPROVAL_HEADER):
                if self.headers.get(key) is not None:self._json(400,{'error':'auth_init_security_fields_forbidden'});return
            source=self._requester_source_auth();result=nonces.issue(source)
            if not result.get('ok'):
                status=429 if result.get('error') in ('auth_nonce_capacity','auth_nonce_source_capacity') else 403 if result.get('error')=='requester_source_not_allowed' else 503
                self._json(status,{'error':result.get('error','auth_nonce_generation_failed')});return
            self._json(200,{'protocol':AUTH_PROTOCOL,'status':'challenge','sessionId':session,'nonce':result['nonce'],'nonceTtlSeconds':result['ttl']})
        def _read_auth_body(self,method):
            if self.headers.get('Transfer-Encoding'):self._json(400,{'error':'transfer_encoding_not_allowed'});return None
            try:length=int(self.headers.get('Content-Length','0') or 0)
            except ValueError:self._json(400,{'error':'invalid_content_length'});return None
            if length<0:self._json(400,{'error':'invalid_content_length'});return None
            if method=='GET' or self.path=='/launch/rustdesk':
                if length!=0:self._json(400,{'error':'request_body_not_allowed'});return None
                return b''
            if self.path=='/handoff/rustdesk':
                if length<=0 or length>256:self._json(400,{'error':'invalid_handoff_body_size'});return None
                data=self.rfile.read(length)
                if len(data)!=length:self._json(400,{'error':'incomplete_request_body'});return None
                return data
            return b''
        def _prepare_auth(self,method):
            self._rah_auth_verified=False;self._rah_cached_body=None
            if not self._origin_allowed():self._json(403,{'error':'origin_not_allowed'});return False
            if not self._authorization_absent() or not self._auth_header_names_valid(False):return False
            if self.headers.get(AUTH_INIT_HEADER) is not None:self._json(400,{'error':'auth_init_not_allowed'});return False
            source=self._requester_source_auth()
            if not source:self._json(403,{'error':'requester_source_not_allowed'});return False
            body=self._read_auth_body(method)
            if body is None:return False
            nonce=self.headers.get(AUTH_NONCE_HEADER,'');proof=self.headers.get(AUTH_PROOF_HEADER,'')
            canonical=canonical_request(session,nonce,method,self.path,body,self.headers)
            if not canonical:self._json(400,{'error':'auth_request_shape_invalid'});return False
            result=nonces.consume_for_source(nonce,source)
            if result=='requester_mismatch':self._json(409,{'error':'auth_nonce_requester_mismatch'});return False
            if result=='requester_source_not_allowed':self._json(403,{'error':'requester_source_not_allowed'});return False
            if result!='ok':self._json(409,{'error':'auth_nonce_invalid_or_expired'});return False
            expected=_proof(token,canonical)
            if not _safe_token(proof,40,64) or not _safe_equal(proof,expected):self._json(401,{'error':'auth_proof_invalid'});return False
            self._rah_cached_body=body;self._rah_auth_verified=True;return True
        def _authorized(self):
            if getattr(self,'_rah_auth_verified',False):return True
            self._json(401,{'error':'auth_proof_required'});return False
        def _handoff_peer_id(self):
            data=getattr(self,'_rah_cached_body',None)
            if not isinstance(data,(bytes,bytearray)) or not data:self._json(400,{'error':'handoff_body_not_cached'});return None
            content_type=self.headers.get('Content-Type','').split(';',1)[0].strip().lower()
            if content_type!='application/json':self._json(415,{'error':'json_content_type_required'});return None
            try:payload=json.loads(bytes(data).decode('utf-8'))
            except Exception:self._json(400,{'error':'invalid_json'});return None
            if not isinstance(payload,dict) or set(payload.keys())!={'peerId'}:self._json(400,{'error':'peer_id_only'});return None
            peer_id=payload.get('peerId')
            if not is_valid_rustdesk_peer_id(peer_id):self._json(400,{'error':'invalid_peer_id'});return None
            return peer_id
        def do_GET(self):
            if self.path=='/health' and self.headers.get(AUTH_INIT_HEADER) is not None:self._auth_init();return
            if not self._prepare_auth('GET'):return
            return super().do_GET()
        def do_POST(self):
            if not self._prepare_auth('POST'):return
            return super().do_POST()
    Handler.local_confirmation_coordinator=local;Handler.auth_nonce_store=nonces
    return Handler


def create_server(host,port,token,node_name='',node_role='',capabilities=None,app_paths=None,app_launcher=None,handoff_launcher=None,challenge_ttl_seconds=ACTION_CHALLENGE_TTL_SECONDS,session_id=None,coordinator=None,interactive_console=None,local_input=None,clock=None,token_func=None,auth_nonce_store=None):
    handler=make_handler(token,node_name,node_role,capabilities,app_paths,app_launcher,handoff_launcher,challenge_ttl_seconds,session_id,coordinator,interactive_console,local_input,clock,token_func,auth_nonce_store)
    server=_v12.ThreadingHTTPServer((host,port),handler);server.local_confirmation_coordinator=handler.local_confirmation_coordinator;server.auth_nonce_store=handler.auth_nonce_store;return server


def main():
    args=_base.parse_args();host='0.0.0.0' if args.allow_lan else '127.0.0.1';token=secrets.token_urlsafe(32);capabilities=sanitize_capabilities(args.capability);paths=build_app_paths();server=create_server(host,PORT,token,args.name,args.role,capabilities,paths,interactive_console=sys.stdin.isatty());actions=build_actions_payload(capabilities,paths)['actions']
    print(f'RAH Node Agent v{AGENT_VERSION}');print('Stage: Candidate');print(f'Allowlist policy: {ALLOWLIST_POLICY_ID}');print(f'Actions protocol: {ACTIONS_PROTOCOL}');print(f'Auth protocol: {AUTH_PROTOCOL}');print('Authentication: token stays local; per-request HMAC-SHA256 proof; Authorization/Bearer rejected');print('Requester source/context + Node-local human confirmation remain independent action gates');print('Mode: '+('LAN enrollment enabled' if args.allow_lan else 'loopback only'));print(f'Port: {PORT}');print('Capabilities: '+(', '.join(capabilities) if capabilities else 'identity-only'));print('Advertised actions: '+(', '.join(a['id'] for a in actions) if actions else 'none'));print('Node-local confirmation: '+('interactive console enabled' if sys.stdin.isatty() else 'unavailable; mutating actions fail closed'));print('Fresh local token: '+token);print('Boundary: fixed 4 capabilities / 3 actions / 5 business routes; no shell/files/generic process/native remote-control API')
    try:server.serve_forever()
    except KeyboardInterrupt:pass
    finally:server.server_close()

if __name__=='__main__':main()
