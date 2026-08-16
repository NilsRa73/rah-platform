import importlib.util
from pathlib import Path
import unittest

PATH=Path(__file__).resolve().parents[1]/'rah-node-agent-v1.1-candidate.py'
spec=importlib.util.spec_from_file_location('rah_node_agent_v11_candidate',PATH)
mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)

class RequesterSourceCandidateTests(unittest.TestCase):
    def test_candidate_identity_and_fixed_authority(self):
        self.assertEqual(mod.AGENT_VERSION,'1.1.0-candidate')
        self.assertEqual(mod.ACTIONS_PROTOCOL,'rah-node-actions-v5')
        self.assertEqual(mod.ALLOWLIST_POLICY_ID,'rah-capability-allowlist-v1')
        self.assertEqual(tuple(mod.ALLOWED_CAPABILITIES),('compute','storage','display','remote-desktop'))
        self.assertEqual(tuple(mod.MUTATING_ACTION_IDS),('rustdesk.launch','rustdesk.connect'))
        self.assertEqual(tuple(mod.ROUTES),('/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk'))

    def test_requester_source_normalization_is_ipv4_loopback_or_rfc1918_only(self):
        for value in ('127.0.0.1','127.20.30.40','10.2.3.4','172.16.0.1','172.31.255.254','192.168.50.5'):
            self.assertEqual(mod.normalize_requester_source(value),value)
        for value in ('8.8.8.8','172.15.0.1','172.32.0.1','169.254.1.1','::1','2001:db8::1','bad',''):
            self.assertEqual(mod.normalize_requester_source(value),'')

    def test_pair_is_source_bound_wrong_source_does_not_consume_correct_source_consumes_once(self):
        prompts=[]
        tokens=iter(['challenge-AAAAAAAAAAAAAAAAAAAA','proof-BBBBBBBBBBBBBBBBBBBBBBBB'])
        coordinator=mod.SourceBoundConfirmationCoordinator(
            'ABCDEFGHIJKLMNOPQRSTUVWX',interactive=True,
            input_func=lambda prompt:(prompts.append(prompt) or 'y'),
            token_func=lambda:next(tokens),cooldown_seconds=0,start_thread=True,
        )
        result=coordinator.request('rustdesk.launch','', '192.168.1.20')
        self.assertTrue(result['ok'])
        grant=result['grant']
        self.assertIn('192.168.1.20',prompts[0])
        self.assertEqual(coordinator.consume('rustdesk.launch','',grant['challenge'],grant['localApprovalProof'],'192.168.1.21'),'requester_mismatch')
        self.assertEqual(coordinator.consume('rustdesk.launch','',grant['challenge'],grant['localApprovalProof'],'192.168.1.20'),'ok')
        self.assertEqual(coordinator.consume('rustdesk.launch','',grant['challenge'],grant['localApprovalProof'],'192.168.1.20'),'missing')

    def test_connect_pair_binds_source_and_input_without_snapshot_secrets(self):
        tokens=iter(['challenge-CCCCCCCCCCCCCCCCCCCC','proof-DDDDDDDDDDDDDDDDDDDDDDDD'])
        coordinator=mod.SourceBoundConfirmationCoordinator(
            'ABCDEFGHIJKLMNOPQRSTUVWX',interactive=True,input_func=lambda prompt:'yes',
            token_func=lambda:next(tokens),cooldown_seconds=0,start_thread=True,
        )
        result=coordinator.request('rustdesk.connect','123456789','10.0.0.42')
        self.assertTrue(result['ok'])
        snap=coordinator.snapshot()
        active=snap['activePair']
        self.assertEqual(active['requesterSource'],'10.0.0.42')
        self.assertEqual(active['actionId'],'rustdesk.connect')
        self.assertNotIn('challenge',active)
        self.assertNotIn('proof',active)
        self.assertNotIn('peerId',active)
        self.assertNotIn('displayTarget',active)
        grant=result['grant']
        self.assertEqual(coordinator.consume('rustdesk.connect','987654321',grant['challenge'],grant['localApprovalProof'],'10.0.0.42'),'input_mismatch')
        self.assertEqual(coordinator.consume('rustdesk.connect','123456789',grant['challenge'],grant['localApprovalProof'],'10.0.0.42'),'ok')

    def test_invalid_or_public_source_fails_before_confirmation(self):
        coordinator=mod.SourceBoundConfirmationCoordinator('ABCDEFGHIJKLMNOPQRSTUVWX',interactive=True,input_func=lambda prompt:'yes',start_thread=True)
        self.assertEqual(coordinator.request('rustdesk.launch','','8.8.8.8')['error'],'requester_source_not_allowed')
        self.assertEqual(coordinator.request('rustdesk.launch','','::1')['error'],'requester_source_not_allowed')

    def test_forwarding_headers_are_not_used_as_identity(self):
        source=PATH.read_text(encoding='utf-8')
        self.assertIn('self.client_address[0]',source)
        self.assertNotIn("headers.get('X-Forwarded-For'",source)
        self.assertNotIn('headers.get("X-Forwarded-For"',source)
        self.assertNotIn("headers.get('Forwarded'",source)
        self.assertNotIn('headers.get("Forwarded"',source)

if __name__=='__main__':unittest.main()
