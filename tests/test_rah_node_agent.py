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
 def health_from_server(self,server,token):
  port=server.server_address[1];th=threading.Thread(target=server.serve_forever,daemon=True);th.start()
  try:
   req=urllib.request.Request(f'http://127.0.0.1:{port}/health',headers={'Origin':'null','Authorization':'Bearer '+token},method='GET')
   with urllib.request.urlopen(req,timeout=2) as res:return json.loads(res.read())
  finally:server.shutdown();server.server_close();th.join(timeout=2)
 def test_health_actions_same_session(self):
  st,h=self.req('/health');self.assertEqual(st,200);a=self.catalog();self.assertEqual(h['protocol'],'rah-node-health-v2');self.assertEqual(a['protocol'],'rah-node-actions-v3');self.assertEqual(h['sessionId'],self.session);self.assertEqual(a['sessionId'],self.session);self.assertEqual(h['agentVersion'],'0.8.0')
 def test_restart_rotates_actual_session_id(self):
  token1='a'*32;token2='b'*32;s1=agent.create_server('127.0.0.1',0,token1,capabilities=[]);s2=agent.create_server('127.0.0.1',0,token2,capabilities=[]);h1=self.health_from_server(s1,token1);h2=self.health_from_server(s2,token2);self.assertRegex(h1['sessionId'],r'^[A-Za-z0-9_-]{20,64}$');self.assertRegex(h2['sessionId'],r'^[A-Za-z0-9_-]{20,64}$');self.assertNotEqual(h1['sessionId'],h2['sessionId'],'independent Node Agent starts must rotate the session ID')
 def test_challenge_still_single_use(self):
  c=self.catalog();row=next(x for x in c['actions'] if x['id']=='storage-summary.read');self.assertEqual(c['sessionId'],self.session);self.assertEqual(self.req('/storage',challenge=row['challenge'])[0],200);self.assertEqual(self.req('/storage',challenge=row['challenge'])[0],409)
 def test_handoff_boundaries_unchanged(self):
  c=self.catalog();row=next(x for x in c['actions'] if x['id']=='rustdesk.connect');self.assertEqual(self.req('/handoff/rustdesk','POST','{"peerId":"123456789","password":"x"}',row['challenge'])[0],400);c=self.catalog();row=next(x for x in c['actions'] if x['id']=='rustdesk.connect');self.assertEqual(self.req('/handoff/rustdesk','POST','{"peerId":"123456789"}',row['challenge'])[0],200);self.assertEqual(self.handoffs,[('/fixed/rustdesk','123456789')])
 def test_source_has_no_generic_authority(self):
  s=(ROOT/'rah-node-agent.py').read_text();self.assertIn('secrets.token_urlsafe(18)',s);self.assertNotIn('os.system',s);self.assertNotIn('shell=True',s);self.assertNotIn('"--password"',s);self.assertNotIn('/action/run',s)
if __name__=='__main__':unittest.main()
