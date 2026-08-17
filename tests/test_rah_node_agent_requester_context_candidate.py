import importlib.util,json,threading,unittest,urllib.error,urllib.request
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
SPEC=importlib.util.spec_from_file_location('rah_node_agent_v12_candidate',ROOT/'rah-node-agent-v1.2-candidate.py')
agent=importlib.util.module_from_spec(SPEC);SPEC.loader.exec_module(agent)

TOKEN='node-token-test'
ORIGIN='null'
CTX='RequesterContext_abcdefghijklmnopqrstuvwxyz1234567890'
OTHER_CTX='RequesterContext_ZYXWVUTSRQPONMLKJIHGFEDCBA9876543210'
UNICODE_CTX='é'*40

class NodeAgentRequesterContextTests(unittest.TestCase):
    def setUp(self):
        self.launched=[]
        self.server=agent.create_server('127.0.0.1',0,TOKEN,'Node','Test',['remote-desktop'],{'rustdesk':'/tmp/fake-rustdesk'},app_launcher=lambda path:self.launched.append(path) or True,interactive_console=True,local_input=lambda prompt:'y')
        self.thread=threading.Thread(target=self.server.serve_forever,daemon=True);self.thread.start()
        self.base=f'http://127.0.0.1:{self.server.server_address[1]}'
    def tearDown(self):
        self.server.shutdown();self.server.server_close();self.thread.join(timeout=2)
    def request(self,method,path,headers=None,body=None):
        h={'Origin':ORIGIN,'Authorization':'Bearer '+TOKEN}
        if headers:h.update(headers)
        data=None
        if body is not None:
            data=json.dumps(body,separators=(',',':')).encode();h['Content-Type']='application/json'
        req=urllib.request.Request(self.base+path,data=data,headers=h,method=method)
        try:
            with urllib.request.urlopen(req,timeout=4) as r:return r.status,json.loads(r.read().decode())
        except urllib.error.HTTPError as e:
            raw=e.read().decode();return e.code,json.loads(raw) if raw else {}
    def grant_launch(self,context=CTX):
        return self.request('GET','/actions',{agent.APPROVAL_ACTION_HEADER:'rustdesk.launch',agent.REQUESTER_CONTEXT_HEADER:context})

    def test_protocol_and_authority_remain_fixed(self):
        self.assertEqual(agent.AGENT_VERSION,'1.2.0-candidate')
        self.assertEqual(agent.ACTIONS_PROTOCOL,'rah-node-actions-v6')
        self.assertEqual(agent.ALLOWLIST_POLICY_ID,'rah-capability-allowlist-v1')
        self.assertEqual(tuple(agent.ROUTES),('/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk'))
        self.assertEqual(set(agent.ACTION_CATALOG),{'storage-summary.read','rustdesk.launch','rustdesk.connect'})
        self.assertEqual(tuple(agent.ALLOWED_CAPABILITIES),('compute','storage','display','remote-desktop'))

    def test_context_forbidden_on_health_normal_catalog_and_storage(self):
        for path in ('/health','/actions','/storage'):
            status,payload=self.request('GET',path,{agent.REQUESTER_CONTEXT_HEADER:CTX})
            self.assertEqual(status,400,(path,payload))
            self.assertIn(payload.get('error'),('requester_context_not_allowed','storage_capability_not_enabled'))

    def test_unknown_requester_header_fails_closed(self):
        status,payload=self.request('GET','/health',{'X-RAH-Requester-Foo':CTX})
        self.assertEqual(status,400);self.assertEqual(payload.get('error'),'unknown_requester_header')

    def test_mutating_intent_requires_ascii_base64url_like_context(self):
        status,payload=self.request('GET','/actions',{agent.APPROVAL_ACTION_HEADER:'rustdesk.launch'})
        self.assertEqual(status,400);self.assertEqual(payload.get('error'),'requester_context_required')
        status,payload=self.request('GET','/actions',{agent.APPROVAL_ACTION_HEADER:'rustdesk.launch',agent.REQUESTER_CONTEXT_HEADER:'short'})
        self.assertEqual(status,400);self.assertEqual(payload.get('error'),'requester_context_required')
        self.assertFalse(agent.valid_requester_context(UNICODE_CTX))
        self.assertEqual(agent.requester_context_digest(UNICODE_CTX),'')

    def test_wrong_context_does_not_consume_correct_pair_then_correct_succeeds_once(self):
        status,payload=self.grant_launch(CTX)
        self.assertEqual(status,200,payload);self.assertEqual(payload.get('protocol'),'rah-node-actions-v6')
        row=next(x for x in payload['actions'] if x['id']=='rustdesk.launch')
        headers={agent.ACTION_CHALLENGE_HEADER:row['challenge'],agent.LOCAL_APPROVAL_HEADER:row['localApprovalProof'],agent.REQUESTER_CONTEXT_HEADER:OTHER_CTX}
        status,bad=self.request('POST','/launch/rustdesk',headers)
        self.assertEqual(status,409,bad);self.assertEqual(bad.get('error'),'requester_context_mismatch');self.assertEqual(self.launched,[])
        snapshot=json.dumps(self.server.local_confirmation_coordinator.snapshot(),sort_keys=True)
        self.assertNotIn(CTX,snapshot);self.assertNotIn(OTHER_CTX,snapshot);self.assertNotIn('requesterContextDigest',snapshot)
        headers[agent.REQUESTER_CONTEXT_HEADER]=CTX
        status,ok=self.request('POST','/launch/rustdesk',headers)
        self.assertEqual(status,200,ok);self.assertEqual(ok.get('status'),'launched');self.assertEqual(len(self.launched),1)
        status,replay=self.request('POST','/launch/rustdesk',headers)
        self.assertNotEqual(status,200,replay);self.assertEqual(len(self.launched),1)

    def test_missing_execution_context_fails_before_pair_consumption(self):
        status,payload=self.grant_launch(CTX);self.assertEqual(status,200,payload)
        row=next(x for x in payload['actions'] if x['id']=='rustdesk.launch')
        security={agent.ACTION_CHALLENGE_HEADER:row['challenge'],agent.LOCAL_APPROVAL_HEADER:row['localApprovalProof']}
        status,bad=self.request('POST','/launch/rustdesk',security)
        self.assertEqual(status,428,bad);self.assertEqual(bad.get('error'),'requester_context_required')
        security[agent.REQUESTER_CONTEXT_HEADER]=CTX
        status,ok=self.request('POST','/launch/rustdesk',security)
        self.assertEqual(status,200,ok);self.assertEqual(len(self.launched),1)

    def test_wrong_source_is_independent_and_pair_survives(self):
        coordinator=agent.ContextBoundConfirmationCoordinator('SessionId_abcdefghijklmnop',interactive=True,input_func=lambda prompt:'y')
        result=coordinator.request('rustdesk.launch','','192.168.1.10',CTX)
        self.assertTrue(result.get('ok'),result)
        grant=result['grant']
        wrong=coordinator.consume('rustdesk.launch','',grant['challenge'],grant['localApprovalProof'],'192.168.1.11',CTX)
        self.assertEqual(wrong,'requester_mismatch')
        bad_context=coordinator.consume('rustdesk.launch','',grant['challenge'],grant['localApprovalProof'],'192.168.1.10',OTHER_CTX)
        self.assertEqual(bad_context,'requester_context_mismatch')
        good=coordinator.consume('rustdesk.launch','',grant['challenge'],grant['localApprovalProof'],'192.168.1.10',CTX)
        self.assertEqual(good,'ok')

    def test_context_never_appears_in_snapshot(self):
        coordinator=agent.ContextBoundConfirmationCoordinator('SessionId_abcdefghijklmnop',interactive=True,input_func=lambda prompt:'y')
        result=coordinator.request('rustdesk.launch','','127.0.0.1',CTX);self.assertTrue(result.get('ok'),result)
        snapshot=json.dumps(coordinator.snapshot(),sort_keys=True)
        self.assertNotIn(CTX,snapshot);self.assertNotIn('requesterContext',snapshot);self.assertNotIn('requesterContextDigest',snapshot)

if __name__=='__main__':unittest.main()