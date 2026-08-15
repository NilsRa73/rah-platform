import importlib.util,json,threading,unittest,urllib.error,urllib.request
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];spec=importlib.util.spec_from_file_location('rah_node_agent',ROOT/'rah-node-agent.py');agent=importlib.util.module_from_spec(spec);spec.loader.exec_module(agent)
class T(unittest.TestCase):
 def setUp(self):
  self.token='token-abcdefghijklmnopqrstuvwxyz';self.session='SessionId_abcdefghijklmnop';self.launched=[];self.handoffs=[];self.server=agent.create_server('127.0.0.1',0,self.token,'Node','Role',['storage','remote-desktop'],{'rustdesk':'/fixed/rustdesk'},lambda p:self.launched.append(p) or True,lambda p,x:self.handoffs.append((p,x)) or True,session_id=self.session);self.port=self.server.server_address[1];self.th=threading.Thread(target=self.server.serve_forever,daemon=True);self.th.start()
 def tearDown(self):self.server.shutdown();self.server.server_close();self.th.join(timeout=2)
 def req(self,path,method='GET',data=None,challenge=None):
  h={'Origin':'null','Authorization':'Bearer '+self.token};
  if challenge:h[agent.ACTION_CHALLENGE_HEADER]=challenge
  if data is not None:h['Content-Type']='application/json'
  r=urllib.request.Request(f'http://127.0.0.1:{self.port}{path}',headers=h,method=method,data=data.encode() if isinstance(data,str) else data)
  try:
   with urllib.request.urlopen(r,timeout=2) as x:return x.status,json.loads(x.read() or b'{}')
  except urllib.error.HTTPError as e:return e.code,json.loads(e.read() or b'{}')
 def catalog(self):return self.req('/actions')[1]
 def test_health_actions_same_session(self):
  st,h=self.req('/health');self.assertEqual(st,200);a=self.catalog();self.assertEqual(h['protocol'],'rah-node-health-v2');self.assertEqual(a['protocol'],'rah-node-actions-v3');self.assertEqual(h['sessionId'],self.session);self.assertEqual(a['sessionId'],self.session);self.assertEqual(h['agentVersion'],'0.8.0')
 def test_restart_session_differs_by_default(self):
  s1=agent.create_server('127.0.0.1',0,'a'*32,capabilities=[]);s2=agent.create_server('127.0.0.1',0,'b'*32,capabilities=[])
  try:
   h1=s1.RequestHandlerClass;h2=s2.RequestHandlerClass;self.assertIsNot(h1,h2)
  finally:s1.server_close();s2.server_close()
  self.assertRegex(agent.sanitize_session_id('SessionId_abcdefghijklmnop'),r'^[A-Za-z0-9_-]{20,64}$')
 def test_challenge_still_single_use(self):
  c=self.catalog();row=next(x for x in c['actions'] if x['id']=='storage-summary.read');self.assertEqual(c['sessionId'],self.session);self.assertEqual(self.req('/storage',challenge=row['challenge'])[0],200);self.assertEqual(self.req('/storage',challenge=row['challenge'])[0],409)
 def test_handoff_boundaries_unchanged(self):
  c=self.catalog();row=next(x for x in c['actions'] if x['id']=='rustdesk.connect');self.assertEqual(self.req('/handoff/rustdesk','POST','{"peerId":"123456789","password":"x"}',row['challenge'])[0],400);c=self.catalog();row=next(x for x in c['actions'] if x['id']=='rustdesk.connect');self.assertEqual(self.req('/handoff/rustdesk','POST','{"peerId":"123456789"}',row['challenge'])[0],200);self.assertEqual(self.handoffs,[('/fixed/rustdesk','123456789')])
 def test_source_has_no_generic_authority(self):
  s=(ROOT/'rah-node-agent.py').read_text();self.assertNotIn('os.system',s);self.assertNotIn('shell=True',s);self.assertNotIn('"--password"',s);self.assertNotIn('/action/run',s)
if __name__=='__main__':unittest.main()
