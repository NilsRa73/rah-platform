import importlib.util
import json
from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[1]
PATH=ROOT/'rah-node-agent-v1.2-candidate.py'
CONTRACT=ROOT/'RAH-REQUESTER-CONTEXT-CANDIDATE.json'
spec=importlib.util.spec_from_file_location('rah_node_agent_v12_candidate',PATH)
mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)

SESSION='ABCDEFGHIJKLMNOPQRSTUVWX'
CONTEXT_A='A'*40
CONTEXT_B='B'*40

class RequesterContextCandidateTests(unittest.TestCase):
    def test_identity_protocol_policy_and_fixed_authority(self):
        self.assertEqual(mod.AGENT_VERSION,'1.2.0-candidate')
        self.assertEqual(mod.ACTIONS_PROTOCOL,'rah-node-actions-v6')
        self.assertEqual(mod.ALLOWLIST_POLICY_ID,'rah-capability-allowlist-v1')
        self.assertEqual(mod.REQUESTER_CONTEXT_HEADER,'X-RAH-Requester-Context')
        self.assertEqual(tuple(mod.ALLOWED_CAPABILITIES),('compute','storage','display','remote-desktop'))
        self.assertEqual(tuple(mod.MUTATING_ACTION_IDS),('rustdesk.launch','rustdesk.connect'))
        self.assertEqual(tuple(mod.ROUTES),('/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk'))

    def test_context_format_is_ascii_base64url_like_only(self):
        self.assertTrue(mod.valid_requester_context(CONTEXT_A))
        self.assertTrue(mod.valid_requester_context('Ab9_-'+('x'*27)))
        self.assertFalse(mod.valid_requester_context('short'))
        self.assertFalse(mod.valid_requester_context('!'*40))
        self.assertFalse(mod.valid_requester_context('é'*40))
        self.assertEqual(len(mod.requester_context_digest(CONTEXT_A)),64)
        self.assertEqual(mod.requester_context_digest('short'),'')

    def test_actions_v6_advertises_requester_context_only_for_mutating_actions(self):
        payload=mod.build_actions_payload(['storage','remote-desktop'],{'rustdesk':'C:/fixed/RustDesk.exe'},SESSION)
        self.assertEqual(payload['protocol'],'rah-node-actions-v6')
        self.assertEqual(payload['policyId'],'rah-capability-allowlist-v1')
        self.assertEqual(payload['approvalMode'],'command-center-ephemeral-plus-node-local-context')
        rows={row['id']:row for row in payload['actions']}
        self.assertNotIn('requesterContextRequired',rows['storage-summary.read'])
        self.assertTrue(rows['rustdesk.launch']['requesterContextRequired'])
        self.assertTrue(rows['rustdesk.connect']['requesterContextRequired'])

    def test_same_source_wrong_context_does_not_consume_correct_pair(self):
        tokens=iter(['challenge-AAAAAAAAAAAAAAAAAAAA','proof-BBBBBBBBBBBBBBBBBBBBBBBB'])
        coordinator=mod.RequesterContextConfirmationCoordinator(
            SESSION,interactive=True,input_func=lambda prompt:'yes',
            token_func=lambda:next(tokens),cooldown_seconds=0,start_thread=True,
        )
        result=coordinator.request('rustdesk.launch','','192.168.1.20',CONTEXT_A)
        self.assertTrue(result['ok'])
        grant=result['grant']
        self.assertEqual(coordinator.consume('rustdesk.launch','',grant['challenge'],grant['localApprovalProof'],'192.168.1.20',CONTEXT_B),'requester_context_mismatch')
        self.assertEqual(coordinator.consume('rustdesk.launch','',grant['challenge'],grant['localApprovalProof'],'192.168.1.20',CONTEXT_A),'ok')
        self.assertEqual(coordinator.consume('rustdesk.launch','',grant['challenge'],grant['localApprovalProof'],'192.168.1.20',CONTEXT_A),'missing')

    def test_wrong_source_is_independent_and_does_not_consume_pair(self):
        tokens=iter(['challenge-CCCCCCCCCCCCCCCCCCCC','proof-DDDDDDDDDDDDDDDDDDDDDDDD'])
        coordinator=mod.RequesterContextConfirmationCoordinator(
            SESSION,interactive=True,input_func=lambda prompt:'yes',
            token_func=lambda:next(tokens),cooldown_seconds=0,start_thread=True,
        )
        result=coordinator.request('rustdesk.connect','123456789','10.0.0.42',CONTEXT_A)
        grant=result['grant']
        self.assertEqual(coordinator.consume('rustdesk.connect','123456789',grant['challenge'],grant['localApprovalProof'],'10.0.0.43',CONTEXT_A),'requester_mismatch')
        self.assertEqual(coordinator.consume('rustdesk.connect','123456789',grant['challenge'],grant['localApprovalProof'],'10.0.0.42',CONTEXT_A),'ok')

    def test_snapshot_contains_digest_only_not_raw_context_proof_challenge_or_peer(self):
        tokens=iter(['challenge-EEEEEEEEEEEEEEEEEEEE','proof-FFFFFFFFFFFFFFFFFFFFFFFF'])
        coordinator=mod.RequesterContextConfirmationCoordinator(
            SESSION,interactive=True,input_func=lambda prompt:'yes',
            token_func=lambda:next(tokens),cooldown_seconds=0,start_thread=True,
        )
        result=coordinator.request('rustdesk.connect','123456789','127.0.0.1',CONTEXT_A)
        snap=json.dumps(coordinator.snapshot())
        self.assertIn(mod.requester_context_digest(CONTEXT_A),snap)
        self.assertNotIn(CONTEXT_A,snap)
        self.assertNotIn(result['grant']['challenge'],snap)
        self.assertNotIn(result['grant']['localApprovalProof'],snap)
        self.assertNotIn('123456789',snap)

    def test_issue_catalog_keeps_storage_challenge_context_free_and_mutating_context_required(self):
        payload=mod.build_actions_payload(['storage','remote-desktop'],{'rustdesk':'C:/fixed/RustDesk.exe'},SESSION)
        state={};lock=mod.threading.Lock()
        catalog=mod.issue_catalog(payload,state,lock,now=100)
        rows={row['id']:row for row in catalog['actions']}
        self.assertEqual(catalog['protocol'],'rah-node-actions-v6')
        self.assertIn('challenge',rows['storage-summary.read'])
        self.assertNotIn('requesterContextRequired',rows['storage-summary.read'])
        self.assertTrue(rows['rustdesk.launch']['requesterContextRequired'])
        self.assertTrue(rows['rustdesk.connect']['requesterContextRequired'])
        self.assertNotIn('localApprovalProof',rows['rustdesk.launch'])

    def test_handler_keeps_exact_route_surface_and_fixed_context_header(self):
        coordinator=mod.RequesterContextConfirmationCoordinator(SESSION,interactive=False,start_thread=False)
        handler=mod.make_handler('token','node','test',['storage','remote-desktop'],{'rustdesk':'C:/fixed/RustDesk.exe'},session_id=SESSION,coordinator=coordinator)
        self.assertEqual(handler.server_version,'RAHNodeAgent/1.2-candidate')
        source=PATH.read_text(encoding='utf-8')
        self.assertIn('self.client_address[0]',source)
        self.assertIn("REQUESTER_CONTEXT_HEADER='X-RAH-Requester-Context'",source)
        self.assertNotIn("headers.get('X-Forwarded-For'",source)
        self.assertNotIn("headers.get('Forwarded'",source)
        for forbidden in ('/shell','/exec','/command','/files','/remote-control'):
            self.assertNotIn(forbidden,source)

    def test_candidate_contract_preserves_authority_and_forbids_persistence(self):
        contract=json.loads(CONTRACT.read_text(encoding='utf-8'))
        self.assertEqual(contract['authorityDelta'],'none')
        self.assertEqual(contract['protocol']['candidateActionsProtocol'],'rah-node-actions-v6')
        self.assertEqual(contract['protocol']['policyId'],'rah-capability-allowlist-v1')
        self.assertEqual(contract['authoritySurface']['capabilities'],['compute','storage','display','remote-desktop'])
        self.assertEqual(contract['authoritySurface']['actions'],['storage-summary.read','rustdesk.launch','rustdesk.connect'])
        self.assertEqual(contract['authoritySurface']['routes'],['/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk'])
        for key in ('bearer-token','action-challenge','node-local-approval-proof','raw-requester-context','password','rustdesk-peer-id','executable-path','arbitrary-arguments'):
            self.assertIn(key,contract['persistence']['forbidden'])

if __name__=='__main__':unittest.main()
