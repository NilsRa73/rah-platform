import importlib.util,json,threading,unittest,urllib.error,urllib.request
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];spec=importlib.util.spec_from_file_location('rah_node_agent',ROOT/'rah-node-agent.py');agent=importlib.util.module_from_spec(spec);spec.loader.exec_module(agent)
class NodeAgentTests(unittest.TestCase):
 def setUp(self):self.token='test-token-abcdefghijklmnopqrstuvwxyz';self.server=agent.create_server('127.0.0.1',0,self.token,'Test Node','Read only',['compute','shell','storage','compute']);self.port=self.server.server_address[1];self.thread=threading.Thread(target=self.server.serve_forever,daemon=True);self.thread.start()
 def tearDown(self):self.server.shutdown();self.server.server_close();self.thread.join(timeout=2)
 def request(self,path='/health',token=None,method='GET',origin='null',private_network=False):
  headers={'Origin':origin}
  if token is not None:headers['Authorization']='Bearer '+token
  if private_network:headers['Access-Control-Request-Private-Network']='true'
  req=urllib.request.Request(f'http://127.0.0.1:{self.port}{path}',headers=headers,method=method)
  try:
   with urllib.request.urlopen(req,timeout=2) as res:return res.status,dict(res.headers),res.read()
  except urllib.error.HTTPError as exc:return exc.code,dict(exc.headers),exc.read()
 def test_health_requires_bearer_token(self):
  self.assertEqual(self.request()[0],401);status,headers,body=self.request(token=self.token);self.assertEqual(status,200);payload=json.loads(body);self.assertEqual(payload['agentVersion'],'0.2.0');self.assertEqual(payload['capabilities'],['compute','storage']);self.assertEqual(payload['permissions'],{'healthRead':True,'capabilityRead':True,'commands':False,'files':False,'shell':False,'remoteControl':False});self.assertNotIn('token',payload)
 def test_only_health_get_is_exposed(self):self.assertEqual(self.request('/command',token=self.token)[0],404);self.assertEqual(self.request('/capabilities',token=self.token)[0],404);self.assertEqual(self.request('/health',token=self.token,method='POST')[0],405);self.assertEqual(self.request('/files',token=self.token)[0],404)
 def test_origin_allowlist_and_private_network_preflight(self):self.assertEqual(self.request(token=self.token,origin='https://evil.example')[0],403);status,headers,_=self.request(method='OPTIONS',private_network=True);self.assertEqual(status,204);self.assertEqual(headers.get('Access-Control-Allow-Private-Network'),'true');self.assertEqual(headers.get('Access-Control-Allow-Origin'),'null')
 def test_capability_allowlist(self):self.assertEqual(agent.sanitize_capabilities(['compute','SHELL','display','remote-desktop','storage','compute']),['compute','display','remote-desktop','storage']);self.assertEqual(agent.ALLOWED_CAPABILITIES,('compute','storage','display','remote-desktop'))
 def test_fixed_contract(self):self.assertEqual(agent.PORT,18766);self.assertEqual(agent.PROTOCOL,'rah-node-health-v1');self.assertNotIn('*',agent.ALLOWED_ORIGINS);self.assertFalse(agent.READ_ONLY_PERMISSIONS['commands']);self.assertFalse(agent.READ_ONLY_PERMISSIONS['files']);self.assertFalse(agent.READ_ONLY_PERMISSIONS['shell']);self.assertFalse(agent.READ_ONLY_PERMISSIONS['remoteControl'])
if __name__=='__main__':unittest.main()
