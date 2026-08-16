import importlib.util
import json
import re
import threading
import unittest
import urllib.request
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
CANDIDATE=ROOT/'rah-node-agent-v0.9-candidate.py'
spec=importlib.util.spec_from_file_location('rah_node_agent_candidate',CANDIDATE)
module=importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class PolicyIdCandidateTests(unittest.TestCase):
    def test_versions_and_authority_surface_are_pinned(self):
        self.assertEqual(module.AGENT_VERSION,'0.9.0-candidate')
        self.assertEqual(module.ACTIONS_PROTOCOL,'rah-node-actions-v4')
        self.assertEqual(module.ALLOWLIST_POLICY_ID,'rah-capability-allowlist-v1')
        self.assertEqual(tuple(module.ALLOWED_CAPABILITIES),('compute','storage','display','remote-desktop'))
        self.assertEqual(set(module.ACTION_CATALOG),{'storage-summary.read','rustdesk.launch','rustdesk.connect'})

    def test_actions_payload_carries_policy_id_without_new_actions(self):
        payload=module.build_actions_payload(
            ['compute','storage','display','remote-desktop'],
            {'rustdesk':'/fixed/rustdesk'},
            'ABCDEFGHIJKLMNOPQRSTUVWX'
        )
        self.assertEqual(payload['protocol'],'rah-node-actions-v4')
        self.assertEqual(payload['policyId'],'rah-capability-allowlist-v1')
        self.assertEqual([row['id'] for row in payload['actions']],['storage-summary.read','rustdesk.launch','rustdesk.connect'])

    def test_fresh_challenge_payload_preserves_policy_id(self):
        base=module.build_actions_payload(['storage'],{},'ABCDEFGHIJKLMNOPQRSTUVWX')
        state={}
        lock=threading.Lock()
        payload=module.issue_action_challenges(base,state,lock,ttl_seconds=60,now=10)
        self.assertEqual(payload['protocol'],'rah-node-actions-v4')
        self.assertEqual(payload['policyId'],'rah-capability-allowlist-v1')
        self.assertEqual(len(payload['actions']),1)
        self.assertEqual(payload['actions'][0]['id'],'storage-summary.read')
        self.assertTrue(payload['actions'][0]['challenge'])
        self.assertEqual(payload['actions'][0]['challengeTtlSeconds'],60)

    def test_live_actions_endpoint_advertises_candidate_policy(self):
        token='candidate-test-token'
        server=module.create_server('127.0.0.1',0,token,capabilities=['storage'])
        thread=threading.Thread(target=server.serve_forever,daemon=True)
        thread.start()
        try:
            host,port=server.server_address
            request=urllib.request.Request(f'http://{host}:{port}/actions')
            request.add_header('Origin','http://127.0.0.1:18765')
            request.add_header('Authorization','Bearer '+token)
            with urllib.request.urlopen(request,timeout=3) as response:
                payload=json.loads(response.read().decode('utf-8'))
            self.assertEqual(payload['protocol'],'rah-node-actions-v4')
            self.assertEqual(payload['policyId'],'rah-capability-allowlist-v1')
            self.assertEqual([row['id'] for row in payload['actions']],['storage-summary.read'])
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=3)

    def test_stable_route_surface_is_inherited_not_expanded(self):
        stable=(ROOT/'rah-node-agent.py').read_text(encoding='utf-8')
        self.assertIn('("/health","/actions","/storage","/launch/rustdesk","/handoff/rustdesk")',stable)
        candidate=CANDIDATE.read_text(encoding='utf-8')
        forbidden_endpoint=re.compile(r'''["']/(?:shell|exec|command|commands|file|files|remote-control|remote_control|token|auth/refresh)(?:/|["'?])''',re.I)
        self.assertIsNone(forbidden_endpoint.search(candidate))

if __name__=='__main__':
    unittest.main()
