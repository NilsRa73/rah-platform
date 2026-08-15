import importlib.util
import json
import threading
import unittest
import urllib.error
import urllib.request
from pathlib import Path

ROOT=Path(__file__).resolve().parent.parent
spec=importlib.util.spec_from_file_location('rah_node_agent',ROOT/'rah-node-agent.py')
agent=importlib.util.module_from_spec(spec);spec.loader.exec_module(agent)

class NodeAgentV09Tests(unittest.TestCase):
    def setUp(self):
        self.token='token-abcdefghijklmnopqrstuvwxyz';self.session='SessionId_abcdefghijklmnop';self.launched=[];self.handoffs=[]
        self.server=agent.create_server('127.0.0.1',0,self.token,'Node','Role',['storage','remote-desktop'],{'rustdesk':'/fixed/rustdesk'},lambda path:self.launched.append(path) or True,lambda path,peer:self.handoffs.append((path,peer)) or True,session_id=self.session)
        self.port=self.server.server_address[1];self.thread=threading.Thread(target=self.server.serve_forever,daemon=True);self.thread.start()
    def tearDown(self):
        self.server.shutdown();self.server.server_close();self.thread.join(timeout=2)
    def request(self,path,method='GET',headers=None,data=None,port=None):
        h={'Origin':'null'};h.update(headers or {});raw=data.encode() if isinstance(data,str) else data;req=urllib.request.Request(f'http://127.0.0.1:{port or self.port}{path}',headers=h,method=method,data=raw)
        try:
            with urllib.request.urlopen(req,timeout=2) as res:return res.status,dict(res.headers),json.loads(res.read() or b'{}')
        except urllib.error.HTTPError as exc:return exc.code,dict(exc.headers),json.loads(exc.read() or b'{}')
    def auth_challenge(self,port=None):
        s,_,p=self.request('/auth/challenge',port=port);self.assertEqual(s,200);return p
    def proof_headers(self,method,path,body=b'',token=None,challenge=None,canonical_path=None,port=None):
        auth=self.auth_challenge(port);canon=agent.build_auth_canonical(auth['sessionId'],auth['nonce'],method,canonical_path or path,agent.body_sha256_hex(body));proof=agent.compute_auth_proof(token or self.token,canon);headers={agent.AUTH_NONCE_HEADER:auth['nonce'],agent.AUTH_PROOF_HEADER:proof}
        if challenge:headers[agent.ACTION_CHALLENGE_HEADER]=challenge
        return headers
    def protected(self,path,method='GET',body=b'',token=None,action_challenge=None,content_type=None,canonical_path=None,port=None):
        h=self.proof_headers(method,path,body,token,action_challenge,canonical_path,port)
        if content_type:h['Content-Type']=content_type
        return self.request(path,method,h,body if body else None,port)
    def catalog(self):
        s,_,p=self.protected('/actions');self.assertEqual(s,200);return p
    def action_challenge(self,action_id):return next(x for x in self.catalog()['actions'] if x['id']==action_id)['challenge']
    def test_auth_challenge_is_public_nonce_only_and_session_bound(self):
        p=self.auth_challenge();self.assertEqual(p['protocol'],'rah-node-auth-v1');self.assertEqual(p['status'],'challenge');self.assertEqual(p['sessionId'],self.session);self.assertEqual(p['ttlSeconds'],30);self.assertRegex(p['nonce'],r'^[A-Za-z0-9_-]{24,64}$');self.assertEqual(set(p),{'protocol','status','sessionId','nonce','ttlSeconds'})
    def test_health_requires_hmac_and_rejects_bearer_transport(self):
        self.assertEqual(self.request('/health')[0],428);self.assertEqual(self.request('/health',headers={'Authorization':'Bearer '+self.token})[0],400);s,_,p=self.protected('/health');self.assertEqual(s,200);self.assertEqual(p['protocol'],'rah-node-health-v2');self.assertEqual(p['sessionId'],self.session);self.assertEqual(p['agentVersion'],'0.9.0')
    def test_auth_nonce_is_single_use_and_bound_to_method_path_body(self):
        auth=self.auth_challenge();canon=agent.build_auth_canonical(self.session,auth['nonce'],'GET','/health',agent.body_sha256_hex(b''));proof=agent.compute_auth_proof(self.token,canon);h={agent.AUTH_NONCE_HEADER:auth['nonce'],agent.AUTH_PROOF_HEADER:proof};self.assertEqual(self.request('/health',headers=h)[0],200);self.assertEqual(self.request('/health',headers=h)[0],401);self.assertEqual(self.protected('/health',canonical_path='/actions')[0],401);self.assertEqual(self.protected('/launch/rustdesk',method='POST',canonical_path='/health')[0],401)
    def test_actions_still_issue_session_bound_single_use_action_challenges(self):
        c=self.catalog();self.assertEqual(c['protocol'],'rah-node-actions-v3');self.assertEqual(c['sessionId'],self.session);self.assertEqual([x['id'] for x in c['actions']],['storage-summary.read','rustdesk.launch','rustdesk.connect'])
        for row in c['actions']:
            self.assertEqual(row['challengeTtlSeconds'],60);self.assertRegex(row['challenge'],r'^[A-Za-z0-9_-]{24,64}$')
            for forbidden in ('url','command','arguments','executable','password','peerId'):self.assertNotIn(forbidden,row)
    def test_storage_requires_both_auth_proof_and_action_challenge(self):
        self.assertEqual(self.protected('/storage')[0],428);ch=self.action_challenge('storage-summary.read');s,_,p=self.protected('/storage',action_challenge=ch);self.assertEqual(s,200);self.assertEqual(p['protocol'],'rah-node-storage-v1');self.assertEqual(self.protected('/storage',action_challenge=ch)[0],409)
    def test_launch_and_handoff_are_fixed_and_password_free(self):
        ch=self.action_challenge('rustdesk.launch');s,_,p=self.protected('/launch/rustdesk',method='POST',action_challenge=ch);self.assertEqual(s,200);self.assertEqual(p['protocol'],'rah-node-launch-v1');self.assertEqual(self.launched,['/fixed/rustdesk']);bad=b'{"peerId":"123456789","password":"secret"}';ch=self.action_challenge('rustdesk.connect');self.assertEqual(self.protected('/handoff/rustdesk',method='POST',body=bad,action_challenge=ch,content_type='application/json')[0],400);body=b'{"peerId":"123456789"}';ch=self.action_challenge('rustdesk.connect');s,_,p=self.protected('/handoff/rustdesk',method='POST',body=body,action_challenge=ch,content_type='application/json');self.assertEqual(s,200);self.assertEqual(p['status'],'handoff-started');self.assertEqual(self.handoffs,[('/fixed/rustdesk','123456789')])
    def test_capability_and_generic_endpoint_boundaries(self):
        token='compute-only-token-abcdefghijklmnopqrstuvwxyz';session='ComputeSession_abcdefghijkl';server=agent.create_server('127.0.0.1',0,token,capabilities=['compute'],app_paths={'rustdesk':'/fixed/rustdesk'},session_id=session);port=server.server_address[1];thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
        try:
            def req(path,method='GET',body=b''):
                auth=self.auth_challenge(port);canon=agent.build_auth_canonical(auth['sessionId'],auth['nonce'],method,path,agent.body_sha256_hex(body));proof=agent.compute_auth_proof(token,canon);h={agent.AUTH_NONCE_HEADER:auth['nonce'],agent.AUTH_PROOF_HEADER:proof};return self.request(path,method,h,body if body else None,port)
            self.assertEqual(req('/actions')[2]['actions'],[]);self.assertEqual(req('/storage')[0],403);self.assertEqual(req('/launch/rustdesk','POST')[0],403)
        finally:server.shutdown();server.server_close();thread.join(timeout=2)
        for path in ('/command','/action','/action/run','/files','/shell','/launch','/launch/calc','/handoff','/connect','/remote-control'):self.assertEqual(self.request(path)[0],404,path)
    def test_cors_and_source_safety(self):
        for path in ('/auth/challenge','/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk'):
            s,h,_=self.request(path,method='OPTIONS',headers={'Access-Control-Request-Private-Network':'true'});self.assertEqual(s,204);allowed=h.get('Access-Control-Allow-Headers','');self.assertIn(agent.AUTH_NONCE_HEADER,allowed);self.assertIn(agent.AUTH_PROOF_HEADER,allowed);self.assertNotIn('Authorization',allowed)
        source=(ROOT/'rah-node-agent.py').read_text();self.assertIn('hmac.new(token.encode("utf-8")',source);self.assertIn('subprocess.Popen([path, "--connect", peer_id]',source);self.assertIn('"shell": False',source);self.assertNotIn('shell=True',source);self.assertNotIn('"--password"',source);self.assertNotIn('/action/run',source)
if __name__=='__main__':unittest.main()