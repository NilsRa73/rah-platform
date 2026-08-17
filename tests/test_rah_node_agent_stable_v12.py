import importlib.util,json,threading,unittest,urllib.error,urllib.request
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
SPEC=importlib.util.spec_from_file_location('rah_node_agent_v12_stable',ROOT/'rah-node-agent-v1.2.py')
agent=importlib.util.module_from_spec(SPEC);SPEC.loader.exec_module(agent)
TOKEN='node-token-stable-v12';ORIGIN='null'
CTX='RequesterContext_abcdefghijklmnopqrstuvwxyz1234567890';OTHER='RequesterContext_ZYXWVUTSRQPONMLKJIHGFEDCBA9876543210'

class StableNode12Tests(unittest.TestCase):
    def setUp(self):
        self.launched=[]
        self.server=agent.create_server('127.0.0.1',0,TOKEN,'Stable Node','Test',['remote-desktop'],{'rustdesk':'/tmp/fake-rustdesk'},app_launcher=lambda path:self.launched.append(path) or True,interactive_console=True,local_input=lambda prompt:'y')
        self.thread=threading.Thread(target=self.server.serve_forever,daemon=True);self.thread.start();self.base=f'http://127.0.0.1:{self.server.server_address[1]}'
    def tearDown(self):self.server.shutdown();self.server.server_close();self.thread.join(timeout=2)
    def request(self,method,path,headers=None,body=None):
        h={'Origin':ORIGIN,'Authorization':'Bearer '+TOKEN};h.update(headers or {});data=None
        if body is not None:data=json.dumps(body,separators=(',',':')).encode();h['Content-Type']='application/json'
        req=urllib.request.Request(self.base+path,data=data,headers=h,method=method)
        try:
            with urllib.request.urlopen(req,timeout=4) as r:return r.status,json.loads(r.read().decode())
        except urllib.error.HTTPError as e:
            raw=e.read().decode();return e.code,json.loads(raw) if raw else {}
    def grant(self):return self.request('GET','/actions',{agent.APPROVAL_ACTION_HEADER:'rustdesk.launch',agent.REQUESTER_CONTEXT_HEADER:CTX})

    def test_stable_identity_and_health(self):
        self.assertEqual(agent.AGENT_VERSION,'1.2.0');self.assertEqual(agent.ACTIONS_PROTOCOL,'rah-node-actions-v6');self.assertEqual(agent.ALLOWLIST_POLICY_ID,'rah-capability-allowlist-v1')
        self.assertEqual(tuple(agent.ROUTES),('/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk'))
        status,payload=self.request('GET','/health');self.assertEqual(status,200,payload);self.assertEqual(payload.get('agentVersion'),'1.2.0')

    def test_stable_wrong_context_preserves_pair_then_correct_consumes_once(self):
        status,payload=self.grant();self.assertEqual(status,200,payload);self.assertEqual(payload.get('protocol'),'rah-node-actions-v6')
        row=next(x for x in payload['actions'] if x['id']=='rustdesk.launch')
        headers={agent.ACTION_CHALLENGE_HEADER:row['challenge'],agent.LOCAL_APPROVAL_HEADER:row['localApprovalProof'],agent.REQUESTER_CONTEXT_HEADER:OTHER}
        status,bad=self.request('POST','/launch/rustdesk',headers);self.assertEqual(status,409,bad);self.assertEqual(bad.get('error'),'requester_context_mismatch');self.assertEqual(self.launched,[])
        headers[agent.REQUESTER_CONTEXT_HEADER]=CTX
        status,ok=self.request('POST','/launch/rustdesk',headers);self.assertEqual(status,200,ok);self.assertEqual(len(self.launched),1)
        status,replay=self.request('POST','/launch/rustdesk',headers);self.assertNotEqual(status,200,replay);self.assertEqual(len(self.launched),1)

    def test_stable_context_is_absent_from_snapshot(self):
        status,payload=self.grant();self.assertEqual(status,200,payload)
        snapshot=json.dumps(self.server.local_confirmation_coordinator.snapshot(),sort_keys=True)
        self.assertNotIn(CTX,snapshot);self.assertNotIn('requesterContext',snapshot);self.assertNotIn('requesterContextDigest',snapshot)

    def test_stable_health_catalog_storage_context_boundaries(self):
        for path in ('/health','/actions','/storage'):
            status,payload=self.request('GET',path,{agent.REQUESTER_CONTEXT_HEADER:CTX});self.assertEqual(status,400,(path,payload))
        status,payload=self.request('GET','/health',{'X-RAH-Requester-Anything':CTX});self.assertEqual(status,400);self.assertEqual(payload.get('error'),'unknown_requester_header')

if __name__=='__main__':unittest.main()
