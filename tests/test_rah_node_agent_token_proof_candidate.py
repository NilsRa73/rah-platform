import importlib.util,json,threading,unittest,urllib.error,urllib.request
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

def load(name,path):
    spec=importlib.util.spec_from_file_location(name,ROOT/path);mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod);return mod
agent=load('rah_node_agent_v13_candidate','rah-node-agent-v1.3-candidate.py')
stable12=load('rah_node_agent_v12_stable_protocol_mismatch','rah-node-agent-v1.2.py')
TOKEN='FreshNodeToken_abcdefghijklmnopqrstuvwxyz123456'
ORIGIN='null'
CTX='RequesterContext_abcdefghijklmnopqrstuvwxyz1234567890'
OTHER_CTX='RequesterContext_ZYXWVUTSRQPONMLKJIHGFEDCBA9876543210'
PEER='123456789'

class TokenProofCandidateTests(unittest.TestCase):
    def setUp(self):
        self.launched=[];self.handoffs=[]
        self.server=agent.create_server('127.0.0.1',0,TOKEN,'Token Proof Node','Test',['storage','remote-desktop'],{'rustdesk':'/tmp/fake-rustdesk'},app_launcher=lambda path:self.launched.append(path) or True,handoff_launcher=lambda path,peer:self.handoffs.append((path,peer)) or True,interactive_console=True,local_input=lambda prompt:'y')
        self.thread=threading.Thread(target=self.server.serve_forever,daemon=True);self.thread.start();self.base=f'http://127.0.0.1:{self.server.server_address[1]}'
    def tearDown(self):self.server.shutdown();self.server.server_close();self.thread.join(timeout=2)
    def request(self,method,path,headers=None,body=None,base=None):
        h={'Origin':ORIGIN};h.update(headers or {});data=body
        req=urllib.request.Request((base or self.base)+path,data=data,headers=h,method=method)
        try:
            with urllib.request.urlopen(req,timeout=5) as r:
                raw=r.read().decode();return r.status,json.loads(raw) if raw else None
        except urllib.error.HTTPError as e:
            raw=e.read().decode();return e.code,json.loads(raw) if raw else None
    def init(self):
        status,payload=self.request('GET','/health',{agent.AUTH_INIT_HEADER:'1'});self.assertEqual(status,200,payload);return payload
    def signed_headers(self,method,path,security=None,body=b'',token=TOKEN):
        auth=self.init();fields=dict(security or {});canonical=agent.canonical_request(auth['sessionId'],auth['nonce'],method,path,body,fields);self.assertTrue(canonical,(method,path,fields,body));proof=agent._proof(token,canonical);headers={**fields,agent.AUTH_NONCE_HEADER:auth['nonce'],agent.AUTH_PROOF_HEADER:proof};return auth,headers
    def signed_request(self,method,path,security=None,body=b'',content_type=None):
        auth,headers=self.signed_headers(method,path,security,body)
        if content_type:headers['Content-Type']=content_type
        status,payload=self.request(method,path,headers,body if body else None);return auth,headers,status,payload
    def grant(self,action='rustdesk.launch',target='',context=CTX):
        security={agent.APPROVAL_ACTION_HEADER:action,agent.REQUESTER_CONTEXT_HEADER:context}
        if target:security[agent.APPROVAL_TARGET_HEADER]=target
        _,_,status,payload=self.signed_request('GET','/actions',security);self.assertEqual(status,200,payload);row=next(x for x in payload['actions'] if x['id']==action);return row

    def test_identity_and_exact_authority(self):
        self.assertEqual(agent.AGENT_VERSION,'1.3.0-candidate');self.assertEqual(agent.AUTH_PROTOCOL,'rah-node-auth-v2');self.assertEqual(agent.ACTIONS_PROTOCOL,'rah-node-actions-v7');self.assertEqual(agent.ALLOWLIST_POLICY_ID,'rah-capability-allowlist-v1')
        self.assertEqual(tuple(agent.ALLOWED_CAPABILITIES),('compute','storage','display','remote-desktop'));self.assertEqual(set(agent.ACTION_CATALOG),{'storage-summary.read','rustdesk.launch','rustdesk.connect'});self.assertEqual(tuple(agent.ROUTES),('/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk'))

    def test_auth_init_is_challenge_only_and_bearer_is_rejected(self):
        payload=self.init();self.assertEqual(set(payload),{'protocol','status','sessionId','nonce','nonceTtlSeconds'});self.assertEqual(payload['protocol'],'rah-node-auth-v2');self.assertEqual(payload['status'],'challenge');self.assertNotIn('hostname',payload);self.assertNotIn('capabilities',payload)
        status,bad=self.request('GET','/health',{'Authorization':'Bearer '+TOKEN});self.assertEqual(status,400,bad);self.assertEqual(bad.get('error'),'authorization_transport_forbidden')
        status,bad=self.request('GET','/health',{agent.AUTH_INIT_HEADER:'2'});self.assertEqual(status,400,bad);self.assertEqual(bad.get('error'),'auth_init_invalid')
        status,bad=self.request('GET','/actions',{agent.AUTH_INIT_HEADER:'1'});self.assertEqual(status,400,bad);self.assertEqual(bad.get('error'),'auth_init_not_allowed')
        status,bad=self.request('GET','/health',{'X-RAH-Auth-Unknown':'x'});self.assertEqual(status,400,bad);self.assertEqual(bad.get('error'),'unknown_auth_header')
        status,bad=self.request('GET','/health',{agent.AUTH_INIT_HEADER:'1','Content-Length':'not-a-number'});self.assertEqual(status,400,bad);self.assertEqual(bad.get('error'),'invalid_content_length')

    def test_proofed_health_succeeds_once_and_replay_fails(self):
        auth,headers=self.signed_headers('GET','/health');status,payload=self.request('GET','/health',headers);self.assertEqual(status,200,payload);self.assertEqual(payload.get('agentVersion'),'1.3.0-candidate');self.assertEqual(payload.get('sessionId'),auth['sessionId'])
        status,replay=self.request('GET','/health',headers);self.assertEqual(status,409,replay);self.assertEqual(replay.get('error'),'auth_nonce_invalid_or_expired')

    def test_invalid_proof_from_correct_source_burns_nonce(self):
        auth,headers=self.signed_headers('GET','/health');good=headers[agent.AUTH_PROOF_HEADER];headers[agent.AUTH_PROOF_HEADER]='WrongProof_abcdefghijklmnopqrstuvwxyz123456';status,bad=self.request('GET','/health',headers);self.assertEqual(status,401,bad);self.assertEqual(bad.get('error'),'auth_proof_invalid');headers[agent.AUTH_PROOF_HEADER]=good;status,replay=self.request('GET','/health',headers);self.assertEqual(status,409,replay)

    def test_nonce_store_wrong_source_does_not_consume_and_capacity_is_bounded(self):
        i=[0]
        def nxt():i[0]+=1;return 'Nonce_'+str(i[0]).zfill(30)
        store=agent.AuthNonceStore(nonce_func=nxt,max_per_source=2,max_global=3);a=store.issue('192.168.1.10');b=store.issue('192.168.1.10');self.assertTrue(a['ok']);self.assertTrue(b['ok']);self.assertEqual(store.issue('192.168.1.10')['error'],'auth_nonce_source_capacity');c=store.issue('192.168.1.11');self.assertTrue(c['ok']);self.assertEqual(store.issue('192.168.1.12')['error'],'auth_nonce_capacity');self.assertEqual(store.consume_for_source(a['nonce'],'192.168.1.99'),'requester_mismatch');self.assertEqual(store.consume_for_source(a['nonce'],'192.168.1.10'),'ok')
        snap=json.dumps(store.snapshot());self.assertNotIn(a['nonce'],snap);self.assertNotIn(b['nonce'],snap)

    def test_path_and_security_header_tamper_invalidates_proof(self):
        auth,headers=self.signed_headers('GET','/health');status,bad=self.request('GET','/actions',headers);self.assertEqual(status,401,bad);self.assertEqual(bad.get('error'),'auth_proof_invalid')
        row=self.grant();security={agent.REQUESTER_CONTEXT_HEADER:OTHER_CTX,agent.ACTION_CHALLENGE_HEADER:row['challenge'],agent.LOCAL_APPROVAL_HEADER:row['localApprovalProof']};auth,headers=self.signed_headers('POST','/launch/rustdesk',{**security,agent.REQUESTER_CONTEXT_HEADER:CTX});headers[agent.REQUESTER_CONTEXT_HEADER]=OTHER_CTX;status,bad=self.request('POST','/launch/rustdesk',headers);self.assertEqual(status,401,bad);self.assertEqual(bad.get('error'),'auth_proof_invalid');self.assertEqual(self.launched,[])
        security[agent.REQUESTER_CONTEXT_HEADER]=CTX;_,_,status,ok=self.signed_request('POST','/launch/rustdesk',security);self.assertEqual(status,200,ok);self.assertEqual(len(self.launched),1)

    def test_bad_auth_proof_does_not_consume_node_local_pair(self):
        row=self.grant();security={agent.REQUESTER_CONTEXT_HEADER:CTX,agent.ACTION_CHALLENGE_HEADER:row['challenge'],agent.LOCAL_APPROVAL_HEADER:row['localApprovalProof']};auth,headers=self.signed_headers('POST','/launch/rustdesk',security);headers[agent.AUTH_PROOF_HEADER]='WrongProof_abcdefghijklmnopqrstuvwxyz123456';status,bad=self.request('POST','/launch/rustdesk',headers);self.assertEqual(status,401,bad);self.assertEqual(self.launched,[])
        snapshot=self.server.local_confirmation_coordinator.snapshot();self.assertIsNotNone(snapshot.get('activePair'))
        _,_,status,ok=self.signed_request('POST','/launch/rustdesk',security);self.assertEqual(status,200,ok);self.assertEqual(len(self.launched),1)

    def test_wrong_requester_context_after_valid_auth_preserves_pair(self):
        row=self.grant();wrong={agent.REQUESTER_CONTEXT_HEADER:OTHER_CTX,agent.ACTION_CHALLENGE_HEADER:row['challenge'],agent.LOCAL_APPROVAL_HEADER:row['localApprovalProof']};_,_,status,bad=self.signed_request('POST','/launch/rustdesk',wrong);self.assertEqual(status,409,bad);self.assertEqual(bad.get('error'),'requester_context_mismatch');self.assertIsNotNone(self.server.local_confirmation_coordinator.snapshot().get('activePair'))
        good={**wrong,agent.REQUESTER_CONTEXT_HEADER:CTX};_,_,status,ok=self.signed_request('POST','/launch/rustdesk',good);self.assertEqual(status,200,ok);self.assertEqual(len(self.launched),1)

    def test_handoff_body_is_proof_bound_cached_and_parsed_from_same_bytes(self):
        row=self.grant('rustdesk.connect',PEER,CTX);security={agent.REQUESTER_CONTEXT_HEADER:CTX,agent.ACTION_CHALLENGE_HEADER:row['challenge'],agent.LOCAL_APPROVAL_HEADER:row['localApprovalProof']};good_body=json.dumps({'peerId':PEER},separators=(',',':')).encode();bad_body=json.dumps({'peerId':'987654321'},separators=(',',':')).encode();auth,headers=self.signed_headers('POST','/handoff/rustdesk',security,good_body);headers['Content-Type']='application/json';status,bad=self.request('POST','/handoff/rustdesk',headers,bad_body);self.assertEqual(status,401,bad);self.assertEqual(bad.get('error'),'auth_proof_invalid');self.assertEqual(self.handoffs,[]);self.assertIsNotNone(self.server.local_confirmation_coordinator.snapshot().get('activePair'))
        _,_,status,ok=self.signed_request('POST','/handoff/rustdesk',security,good_body,'application/json');self.assertEqual(status,200,ok);self.assertEqual(self.handoffs,[('/tmp/fake-rustdesk',PEER)])

    def test_storage_challenge_and_execution_are_each_proof_authenticated(self):
        _,_,status,catalog=self.signed_request('GET','/actions');self.assertEqual(status,200,catalog);row=next(x for x in catalog['actions'] if x['id']=='storage-summary.read');security={agent.ACTION_CHALLENGE_HEADER:row['challenge']};_,_,status,payload=self.signed_request('GET','/storage',security);self.assertEqual(status,200,payload);self.assertEqual(payload.get('protocol'),'rah-node-storage-v1')

    def test_options_never_allocates_nonce(self):
        before=self.server.auth_nonce_store.snapshot()['outstanding'];status,payload=self.request('OPTIONS','/health',{'Access-Control-Request-Headers':agent.AUTH_NONCE_HEADER+', '+agent.AUTH_PROOF_HEADER});self.assertEqual(status,204);after=self.server.auth_nonce_store.snapshot()['outstanding'];self.assertEqual(before,after)

    def test_v17_proof_client_to_node12_and_v16_bearer_client_to_node13_fail_closed(self):
        status,bad=self.request('GET','/health',{'Authorization':'Bearer '+TOKEN});self.assertEqual(status,400,bad)
        old=stable12.create_server('127.0.0.1',0,TOKEN,'Old','Test',[],{});thread=threading.Thread(target=old.serve_forever,daemon=True);thread.start();base=f'http://127.0.0.1:{old.server_address[1]}'
        try:
            status,payload=self.request('GET','/health',{agent.AUTH_INIT_HEADER:'1'},base=base);self.assertNotEqual(status,200,payload)
        finally:old.shutdown();old.server_close();thread.join(timeout=2)

if __name__=='__main__':unittest.main()
