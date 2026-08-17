import importlib.util,json,threading,unittest,urllib.error,urllib.request
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('rah_node_agent_v13_stable',ROOT/'rah-node-agent-v1.3.py');agent=importlib.util.module_from_spec(spec);spec.loader.exec_module(agent)
TOKEN='FreshStableNodeToken_abcdefghijklmnopqrstuvwxyz123456';ORIGIN='null';CTX='RequesterContext_abcdefghijklmnopqrstuvwxyz1234567890';OTHER='RequesterContext_ZYXWVUTSRQPONMLKJIHGFEDCBA9876543210';PEER='123456789'

class StableNode13Tests(unittest.TestCase):
    def setUp(self):
        self.launched=[];self.handoffs=[]
        self.server=agent.create_server('127.0.0.1',0,TOKEN,'Stable Token Proof Node','Test',['storage','remote-desktop'],{'rustdesk':'/tmp/fake-rustdesk'},app_launcher=lambda path:self.launched.append(path) or True,handoff_launcher=lambda path,peer:self.handoffs.append((path,peer)) or True,interactive_console=True,local_input=lambda prompt:'y')
        self.thread=threading.Thread(target=self.server.serve_forever,daemon=True);self.thread.start();self.base=f'http://127.0.0.1:{self.server.server_address[1]}'
    def tearDown(self):self.server.shutdown();self.server.server_close();self.thread.join(timeout=2)
    def request(self,method,path,headers=None,body=None):
        h={'Origin':ORIGIN};h.update(headers or {});req=urllib.request.Request(self.base+path,data=body,headers=h,method=method)
        try:
            with urllib.request.urlopen(req,timeout=5) as r:
                raw=r.read().decode();return r.status,json.loads(raw) if raw else None
        except urllib.error.HTTPError as e:
            raw=e.read().decode();return e.code,json.loads(raw) if raw else None
    def init(self):
        status,payload=self.request('GET','/health',{agent.AUTH_INIT_HEADER:'1'});self.assertEqual(status,200,payload);return payload
    def signed(self,method,path,security=None,body=b'',content_type=None,proof_override=None):
        auth=self.init();fields=dict(security or {});canonical=agent.canonical_request(auth['sessionId'],auth['nonce'],method,path,body,fields);self.assertTrue(canonical);proof=agent._proof(TOKEN,canonical) if proof_override is None else proof_override;headers={**fields,agent.AUTH_NONCE_HEADER:auth['nonce'],agent.AUTH_PROOF_HEADER:proof};
        if content_type:headers['Content-Type']=content_type
        return auth,headers,*self.request(method,path,headers,body if body else None)
    def grant(self,action='rustdesk.launch',target=''):
        security={agent.APPROVAL_ACTION_HEADER:action,agent.REQUESTER_CONTEXT_HEADER:CTX};
        if target:security[agent.APPROVAL_TARGET_HEADER]=target
        _,_,status,payload=self.signed('GET','/actions',security);self.assertEqual(status,200,payload);return next(x for x in payload['actions'] if x['id']==action)

    def test_stable_identity_and_challenge_only_bootstrap(self):
        self.assertEqual(agent.AGENT_VERSION,'1.3.0');self.assertEqual(agent.ACTIONS_PROTOCOL,'rah-node-actions-v7');self.assertEqual(agent.AUTH_PROTOCOL,'rah-node-auth-v2');self.assertEqual(agent.ALLOWLIST_POLICY_ID,'rah-capability-allowlist-v1');self.assertEqual(tuple(agent.ROUTES),('/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk'))
        payload=self.init();self.assertEqual(set(payload),{'protocol','status','sessionId','nonce','nonceTtlSeconds'});self.assertNotIn('hostname',payload)
        status,bad=self.request('GET','/health',{'Authorization':'Bearer '+TOKEN});self.assertEqual(status,400,bad);self.assertEqual(bad.get('error'),'authorization_transport_forbidden')

    def test_stable_proof_replay_and_invalid_proof_fail_closed(self):
        auth,headers,status,payload=self.signed('GET','/health');self.assertEqual(status,200,payload);self.assertEqual(payload.get('agentVersion'),'1.3.0');status,replay=self.request('GET','/health',headers);self.assertEqual(status,409,replay)
        auth=self.init();canonical=agent.canonical_request(auth['sessionId'],auth['nonce'],'GET','/health',b'',{});headers={agent.AUTH_NONCE_HEADER:auth['nonce'],agent.AUTH_PROOF_HEADER:'WrongProof_abcdefghijklmnopqrstuvwxyz123456'};status,bad=self.request('GET','/health',headers);self.assertEqual(status,401,bad);self.assertEqual(bad.get('error'),'auth_proof_invalid');headers[agent.AUTH_PROOF_HEADER]=agent._proof(TOKEN,canonical);status,burned=self.request('GET','/health',headers);self.assertEqual(status,409,burned)

    def test_bad_auth_proof_and_wrong_context_do_not_consume_correct_pair(self):
        row=self.grant();security={agent.REQUESTER_CONTEXT_HEADER:CTX,agent.ACTION_CHALLENGE_HEADER:row['challenge'],agent.LOCAL_APPROVAL_HEADER:row['localApprovalProof']};auth=self.init();canonical=agent.canonical_request(auth['sessionId'],auth['nonce'],'POST','/launch/rustdesk',b'',security);headers={**security,agent.AUTH_NONCE_HEADER:auth['nonce'],agent.AUTH_PROOF_HEADER:'WrongProof_abcdefghijklmnopqrstuvwxyz123456'};status,bad=self.request('POST','/launch/rustdesk',headers);self.assertEqual(status,401,bad);self.assertEqual(self.launched,[]);self.assertIsNotNone(self.server.local_confirmation_coordinator.snapshot().get('activePair'))
        wrong={**security,agent.REQUESTER_CONTEXT_HEADER:OTHER};_,_,status,bad=self.signed('POST','/launch/rustdesk',wrong);self.assertEqual(status,409,bad);self.assertEqual(bad.get('error'),'requester_context_mismatch');self.assertIsNotNone(self.server.local_confirmation_coordinator.snapshot().get('activePair'))
        _,_,status,ok=self.signed('POST','/launch/rustdesk',security);self.assertEqual(status,200,ok);self.assertEqual(len(self.launched),1)

    def test_handoff_exact_body_is_proof_bound_and_cached(self):
        row=self.grant('rustdesk.connect',PEER);security={agent.REQUESTER_CONTEXT_HEADER:CTX,agent.ACTION_CHALLENGE_HEADER:row['challenge'],agent.LOCAL_APPROVAL_HEADER:row['localApprovalProof']};good=json.dumps({'peerId':PEER},separators=(',',':')).encode();bad=json.dumps({'peerId':'987654321'},separators=(',',':')).encode();auth=self.init();canonical=agent.canonical_request(auth['sessionId'],auth['nonce'],'POST','/handoff/rustdesk',good,security);headers={**security,agent.AUTH_NONCE_HEADER:auth['nonce'],agent.AUTH_PROOF_HEADER:agent._proof(TOKEN,canonical),'Content-Type':'application/json'};status,rejected=self.request('POST','/handoff/rustdesk',headers,bad);self.assertEqual(status,401,rejected);self.assertEqual(self.handoffs,[]);self.assertIsNotNone(self.server.local_confirmation_coordinator.snapshot().get('activePair'))
        _,_,status,ok=self.signed('POST','/handoff/rustdesk',security,good,'application/json');self.assertEqual(status,200,ok);self.assertEqual(self.handoffs,[('/tmp/fake-rustdesk',PEER)])

    def test_storage_and_options_boundaries(self):
        _,_,status,catalog=self.signed('GET','/actions');self.assertEqual(status,200,catalog);row=next(x for x in catalog['actions'] if x['id']=='storage-summary.read');_,_,status,payload=self.signed('GET','/storage',{agent.ACTION_CHALLENGE_HEADER:row['challenge']});self.assertEqual(status,200,payload)
        before=self.server.auth_nonce_store.snapshot()['outstanding'];status,_=self.request('OPTIONS','/health',{'Access-Control-Request-Headers':agent.AUTH_NONCE_HEADER+', '+agent.AUTH_PROOF_HEADER});self.assertEqual(status,204);self.assertEqual(before,self.server.auth_nonce_store.snapshot()['outstanding'])

if __name__=='__main__':unittest.main()
