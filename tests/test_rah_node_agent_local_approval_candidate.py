from __future__ import annotations
import hashlib,http.client,importlib.util,json,threading,time,unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
CANDIDATE_PATH=ROOT/'rah-node-agent-v1.0-candidate.py'
SPEC=importlib.util.spec_from_file_location('rah_node_agent_v10_candidate',CANDIDATE_PATH)
if SPEC is None or SPEC.loader is None:raise RuntimeError('unable to load Node Agent 1.0 Candidate')
node=importlib.util.module_from_spec(SPEC);SPEC.loader.exec_module(node)

MANIFEST=json.loads((ROOT/'RAH-NODE-LOCAL-APPROVAL-PROOF-CANDIDATE.json').read_text(encoding='utf-8'))
SOURCE=CANDIDATE_PATH.read_text(encoding='utf-8')
SESSION='ABCDEFGHIJKLMNOPQRSTUVWX'
ORIGIN='http://127.0.0.1:18765'
TOKEN='candidate-test-token'
CAPS=['storage','remote-desktop']
ACTIONS=['storage-summary.read','rustdesk.launch','rustdesk.connect']
ROUTES=['/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk']


def git_blob_sha(path:Path)->str:
    data=path.read_bytes();header=f'blob {len(data)}\0'.encode()
    return hashlib.sha1(header+data).hexdigest()


class FakeClock:
    def __init__(self,value=100.0):self.value=float(value)
    def __call__(self):return self.value
    def advance(self,seconds):self.value+=float(seconds)


class TokenSequence:
    def __init__(self):self.i=0
    def __call__(self):
        self.i+=1
        return f'candidate-token-{self.i:04d}-ABCDEFGHIJKLMNOPQRSTUVWXYZ'


class ServerHarness:
    def __init__(self,interactive=True,local_input=None,capabilities=None,app_paths=None):
        self.launch_calls=[];self.handoff_calls=[];self.prompts=[]
        def launch(path):self.launch_calls.append(path);return True
        def handoff(path,peer):self.handoff_calls.append((path,peer));return True
        def prompt(text):
            self.prompts.append(text)
            return 'y' if local_input is None else local_input(text)
        self.server=node.create_server(
            '127.0.0.1',0,TOKEN,'Candidate Node','test',
            capabilities if capabilities is not None else CAPS,
            app_paths if app_paths is not None else {'rustdesk':'/fixed/rustdesk'},
            app_launcher=launch,handoff_launcher=handoff,
            session_id=SESSION,interactive_console=interactive,local_input=prompt,
            token_func=TokenSequence(),
        )
        self.thread=threading.Thread(target=self.server.serve_forever,daemon=True);self.thread.start()
        self.host,self.port=self.server.server_address
    def close(self):
        self.server.shutdown();self.server.server_close();self.thread.join(timeout=2)
    def request(self,method,path,headers=None,body=None,authorized=True,origin=ORIGIN):
        hdr={'Origin':origin}
        if authorized:hdr['Authorization']='Bearer '+TOKEN
        if headers:hdr.update(headers)
        payload=body
        if isinstance(body,(dict,list)):
            payload=json.dumps(body,separators=(',',':')).encode();hdr.setdefault('Content-Type','application/json')
        elif isinstance(body,str):payload=body.encode()
        conn=http.client.HTTPConnection(self.host,self.port,timeout=3)
        conn.request(method,path,body=payload,headers=hdr)
        response=conn.getresponse();raw=response.read();status=response.status;out_headers=dict(response.getheaders());conn.close()
        data=json.loads(raw.decode()) if raw else None
        return status,data,out_headers
    def malformed_content_length_intent(self):
        conn=http.client.HTTPConnection(self.host,self.port,timeout=3)
        conn.putrequest('GET','/actions')
        conn.putheader('Origin',ORIGIN);conn.putheader('Authorization','Bearer '+TOKEN)
        conn.putheader(node.APPROVAL_ACTION_HEADER,'rustdesk.launch')
        conn.putheader('Content-Length','not-a-number')
        conn.endheaders()
        response=conn.getresponse();raw=response.read();status=response.status;conn.close()
        return status,json.loads(raw.decode())


def action_row(payload,action_id):
    return next(row for row in payload['actions'] if row['id']==action_id)


class CandidateIdentityTests(unittest.TestCase):
    def test_candidate_versions_and_exact_authority_surface(self):
        self.assertEqual(node.AGENT_VERSION,'1.0.0-candidate')
        self.assertEqual(node.ACTIONS_PROTOCOL,'rah-node-actions-v5')
        self.assertEqual(node.ALLOWLIST_POLICY_ID,'rah-capability-allowlist-v1')
        self.assertEqual(list(node.ALLOWED_CAPABILITIES),['compute','storage','display','remote-desktop'])
        self.assertEqual(list(node.ACTION_CATALOG.keys()),ACTIONS)
        self.assertEqual(list(node.ROUTES),ROUTES)
        self.assertEqual(MANIFEST['authorityDelta'],'none')
        self.assertEqual(MANIFEST['authoritySurface']['actions'],ACTIONS)
        self.assertEqual(MANIFEST['authoritySurface']['routes'],ROUTES)

    def test_candidate_imports_stable_node_and_pins_reviewed_blob(self):
        self.assertIn("STABLE_PATH=Path(__file__).with_name('rah-node-agent-v0.9.py')",SOURCE)
        self.assertEqual(git_blob_sha(CANDIDATE_PATH),MANIFEST['nodeAgent']['runtime']['gitBlobSha'])
        for group,key in [(MANIFEST['sourceStable'],'nodeAgent'),(MANIFEST['sourceStable'],'releaseManifest'),(MANIFEST['readinessEvidence'],'gate'),(MANIFEST['readinessEvidence'],'design')]:
            ref=group[key];self.assertEqual(git_blob_sha(ROOT/ref['path']),ref['gitBlobSha'])

    def test_build_actions_payload_is_v5_policy_bound_with_same_three_actions(self):
        payload=node.build_actions_payload(CAPS,{'rustdesk':'/fixed/rustdesk'},SESSION)
        self.assertEqual(payload['protocol'],'rah-node-actions-v5')
        self.assertEqual(payload['policyId'],'rah-capability-allowlist-v1')
        self.assertEqual(payload['sessionId'],SESSION)
        self.assertEqual([row['id'] for row in payload['actions']],ACTIONS)
        self.assertEqual(payload['approvalMode'],'command-center-ephemeral-plus-node-local')

    def test_candidate_source_adds_no_generic_process_or_persistence_power(self):
        self.assertNotIn('subprocess.Popen',SOURCE)
        self.assertNotIn('shell=True',SOURCE)
        self.assertNotIn("'/exec'",SOURCE);self.assertNotIn("'/files'",SOURCE);self.assertNotIn("'/shell'",SOURCE)
        self.assertNotIn('write_text(',SOURCE);self.assertNotIn('write_bytes(',SOURCE)
        self.assertIn("ROUTES=('/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk')",SOURCE)
        self.assertIn('def log_message(self,fmt,*args):return',SOURCE)
        self.assertIn('secrets.token_urlsafe(24)',SOURCE)
        self.assertTrue(MANIFEST['localProofPolicy']['proofPersistence']=='forbidden')
        self.assertTrue(MANIFEST['localProofPolicy']['challengePersistence']=='forbidden')


class CoordinatorTests(unittest.TestCase):
    def coordinator(self,**kwargs):
        options=dict(interactive=True,input_func=lambda _:'y',clock=FakeClock(),token_func=TokenSequence(),wait_seconds=1,proof_ttl_seconds=30,cooldown_seconds=0)
        options.update(kwargs)
        return node.LocalConfirmationCoordinator(SESSION,**options)

    def test_headless_fails_closed(self):
        c=node.LocalConfirmationCoordinator(SESSION,interactive=False,start_thread=False)
        self.assertEqual(c.request('rustdesk.launch'),{'ok':False,'error':'local_confirmation_unavailable'})
        self.assertIsNone(c.snapshot()['activePair'])

    def test_launch_local_yes_creates_distinct_memory_only_pair_and_replay_fails(self):
        c=self.coordinator();result=c.request('rustdesk.launch')
        self.assertTrue(result['ok']);grant=result['grant']
        self.assertNotEqual(grant['challenge'],grant['localApprovalProof'])
        snap=c.snapshot();self.assertEqual(snap['activePair']['actionId'],'rustdesk.launch')
        self.assertNotIn(grant['challenge'],json.dumps(snap));self.assertNotIn(grant['localApprovalProof'],json.dumps(snap))
        self.assertEqual(c.consume('rustdesk.launch','',grant['challenge'],grant['localApprovalProof']),'ok')
        self.assertEqual(c.consume('rustdesk.launch','',grant['challenge'],grant['localApprovalProof']),'missing')

    def test_connect_binds_digest_not_raw_peer_and_target_substitution_fails(self):
        peer='123456789';c=self.coordinator();result=c.request('rustdesk.connect',peer);grant=result['grant']
        snap=c.snapshot();encoded=json.dumps(snap)
        self.assertNotIn(peer,encoded)
        self.assertEqual(snap['activePair']['inputDigest'],node.canonical_input_digest('rustdesk.connect',peer))
        self.assertEqual(c.consume('rustdesk.connect','987654321',grant['challenge'],grant['localApprovalProof']),'input_mismatch')
        self.assertEqual(c.consume('rustdesk.connect',peer,grant['challenge'],grant['localApprovalProof']),'ok')

    def test_wrong_challenge_proof_and_session_state_do_not_execute(self):
        c=self.coordinator();grant=c.request('rustdesk.launch')['grant']
        self.assertEqual(c.consume('rustdesk.launch','','wrong',grant['localApprovalProof']),'challenge_invalid')
        self.assertEqual(c.consume('rustdesk.launch','',grant['challenge'],'wrong'),'proof_invalid')
        with c._lock:c._active_pair['sessionId']='ZYXWVUTSRQPONMLKJIHGFEDC'
        self.assertEqual(c.consume('rustdesk.launch','',grant['challenge'],grant['localApprovalProof']),'session_mismatch')

    def test_expiry_destroys_pair(self):
        clock=FakeClock();c=self.coordinator(clock=clock);grant=c.request('rustdesk.launch')['grant'];clock.advance(31)
        self.assertEqual(c.consume('rustdesk.launch','',grant['challenge'],grant['localApprovalProof']),'expired')
        self.assertIsNone(c.snapshot()['activePair'])

    def test_new_confirmation_invalidates_old_unused_pair(self):
        clock=FakeClock();c=self.coordinator(clock=clock,cooldown_seconds=2)
        first=c.request('rustdesk.launch')['grant'];clock.advance(2)
        second=c.request('rustdesk.connect','123456789')['grant']
        self.assertEqual(c.consume('rustdesk.launch','',first['challenge'],first['localApprovalProof']),'action_mismatch')
        self.assertEqual(c.consume('rustdesk.connect','123456789',second['challenge'],second['localApprovalProof']),'ok')

    def test_one_pending_prompt_blocks_second_prompt(self):
        entered=threading.Event();release=threading.Event()
        def blocking(_):entered.set();release.wait(1);return 'n'
        c=self.coordinator(input_func=blocking,wait_seconds=1)
        result={}
        t=threading.Thread(target=lambda:result.setdefault('first',c.request('rustdesk.launch')),daemon=True);t.start()
        self.assertTrue(entered.wait(1))
        self.assertEqual(c.request('rustdesk.connect','123456789')['error'],'local_confirmation_busy')
        release.set();t.join(2);self.assertEqual(result['first']['error'],'local_confirmation_denied')

    def test_timeout_cancellation_cannot_create_late_pair(self):
        entered=threading.Event();release=threading.Event()
        def blocking(_):entered.set();release.wait(1);return 'y'
        c=self.coordinator(input_func=blocking,wait_seconds=.05)
        result={};t=threading.Thread(target=lambda:result.setdefault('value',c.request('rustdesk.launch')),daemon=True);t.start()
        self.assertTrue(entered.wait(1));t.join(1);self.assertEqual(result['value']['error'],'local_confirmation_timeout')
        release.set();time.sleep(.08)
        self.assertIsNone(c.snapshot()['activePair'])


class LiveHttpTests(unittest.TestCase):
    def with_server(self,**kwargs):return ServerHarness(**kwargs)

    def test_normal_catalog_and_storage_read_use_v5_without_mutating_proof(self):
        h=self.with_server()
        try:
            status,payload,_=h.request('GET','/actions');self.assertEqual(status,200)
            self.assertEqual(payload['protocol'],'rah-node-actions-v5');self.assertEqual(payload['policyId'],'rah-capability-allowlist-v1')
            self.assertEqual([row['id'] for row in payload['actions']],ACTIONS)
            storage=action_row(payload,'storage-summary.read');launch=action_row(payload,'rustdesk.launch');connect=action_row(payload,'rustdesk.connect')
            self.assertIn('challenge',storage);self.assertTrue(launch['localApprovalRequired']);self.assertTrue(connect['localApprovalRequired'])
            for row in (launch,connect):self.assertNotIn('localApprovalProof',row);self.assertNotIn('challenge',row)
            status,body,_=h.request('GET','/storage',{node.ACTION_CHALLENGE_HEADER:storage['challenge']});self.assertEqual(status,200);self.assertEqual(body['scope'],'system-volume')
            status,body,_=h.request('GET','/storage',{node.ACTION_CHALLENGE_HEADER:storage['challenge']});self.assertEqual(status,409)
        finally:h.close()

    def test_launch_requires_local_pair_and_is_single_use(self):
        h=self.with_server()
        try:
            status,payload,_=h.request('GET','/actions',{node.APPROVAL_ACTION_HEADER:'rustdesk.launch'});self.assertEqual(status,200)
            row=action_row(payload,'rustdesk.launch');self.assertIn('challenge',row);self.assertIn('localApprovalProof',row)
            self.assertEqual(h.prompts,['RAH local approval: Launch RustDesk? [y/N] '])
            status,body,_=h.request('POST','/launch/rustdesk',{node.ACTION_CHALLENGE_HEADER:row['challenge']});self.assertEqual(status,428);self.assertEqual(body['error'],'local_approval_proof_required')
            headers={node.ACTION_CHALLENGE_HEADER:row['challenge'],node.LOCAL_APPROVAL_HEADER:row['localApprovalProof']}
            status,body,_=h.request('POST','/launch/rustdesk',headers);self.assertEqual(status,200);self.assertEqual(h.launch_calls,['/fixed/rustdesk'])
            status,body,_=h.request('POST','/launch/rustdesk',headers);self.assertEqual(status,428);self.assertEqual(len(h.launch_calls),1)
        finally:h.close()

    def test_connect_target_substitution_fails_then_correct_target_succeeds(self):
        h=self.with_server()
        try:
            peer='123456789';status,payload,_=h.request('GET','/actions',{node.APPROVAL_ACTION_HEADER:'rustdesk.connect',node.APPROVAL_TARGET_HEADER:peer});self.assertEqual(status,200)
            row=action_row(payload,'rustdesk.connect');headers={node.ACTION_CHALLENGE_HEADER:row['challenge'],node.LOCAL_APPROVAL_HEADER:row['localApprovalProof']}
            self.assertEqual(h.prompts,[f'RAH local approval: Connect RustDesk to {peer}? [y/N] '])
            self.assertNotIn(peer,json.dumps(h.server.local_confirmation_coordinator.snapshot()))
            status,body,_=h.request('POST','/handoff/rustdesk',headers,{'peerId':'987654321'});self.assertEqual(status,409);self.assertEqual(body['error'],'local_approval_input_mismatch');self.assertEqual(h.handoff_calls,[])
            status,body,_=h.request('POST','/handoff/rustdesk',headers,{'peerId':peer});self.assertEqual(status,200);self.assertEqual(h.handoff_calls,[('/fixed/rustdesk',peer)])
        finally:h.close()

    def test_invalid_intents_fail_before_prompt(self):
        h=self.with_server()
        try:
            cases=[
                ({node.APPROVAL_TARGET_HEADER:'123456789'},400),
                ({node.APPROVAL_ACTION_HEADER:'storage-summary.read'},400),
                ({node.APPROVAL_ACTION_HEADER:'rustdesk.launch',node.APPROVAL_TARGET_HEADER:'123456789'},400),
                ({node.APPROVAL_ACTION_HEADER:'rustdesk.connect'},400),
                ({node.APPROVAL_ACTION_HEADER:'rustdesk.connect',node.APPROVAL_TARGET_HEADER:'bad target'},400),
                ({node.APPROVAL_ACTION_HEADER:'rustdesk.launch','X-RAH-Approval-Foo':'bar'},400),
                ({node.APPROVAL_ACTION_HEADER:'rustdesk.launch',node.LOCAL_APPROVAL_HEADER:'fake'},400),
                ({node.APPROVAL_ACTION_HEADER:'rustdesk.launch',node.ACTION_CHALLENGE_HEADER:'fake'},400),
            ]
            for headers,expected in cases:
                status,_,_=h.request('GET','/actions',headers);self.assertEqual(status,expected)
            status,_,_=h.request('GET','/actions',{node.APPROVAL_ACTION_HEADER:'rustdesk.launch'},authorized=False);self.assertEqual(status,401)
            status,_,_=h.request('GET','/actions',{node.APPROVAL_ACTION_HEADER:'rustdesk.launch'},origin='https://foreign.example');self.assertEqual(status,403)
            self.assertEqual(h.prompts,[])
        finally:h.close()

    def test_malformed_content_length_and_get_body_fail_closed_before_prompt(self):
        h=self.with_server()
        try:
            status,body=h.malformed_content_length_intent();self.assertEqual(status,400);self.assertEqual(body['error'],'invalid_content_length')
            status,body,_=h.request('GET','/actions',{node.APPROVAL_ACTION_HEADER:'rustdesk.launch'},body='x');self.assertEqual(status,400);self.assertEqual(body['error'],'approval_intent_body_not_allowed')
            self.assertEqual(h.prompts,[])
        finally:h.close()

    def test_headless_catalog_available_but_mutating_intent_fails_closed(self):
        h=self.with_server(interactive=False)
        try:
            status,payload,_=h.request('GET','/actions');self.assertEqual(status,200);self.assertEqual(payload['protocol'],'rah-node-actions-v5')
            status,body,_=h.request('GET','/actions',{node.APPROVAL_ACTION_HEADER:'rustdesk.launch'});self.assertEqual(status,503);self.assertEqual(body['error'],'local_confirmation_unavailable')
        finally:h.close()

    def test_options_and_unknown_routes_preserve_exact_surface(self):
        h=self.with_server()
        try:
            status,_,headers=h.request('OPTIONS','/actions',authorized=False);self.assertEqual(status,204)
            allow=headers.get('Access-Control-Allow-Headers','')
            for header in [node.ACTION_CHALLENGE_HEADER,node.APPROVAL_ACTION_HEADER,node.APPROVAL_TARGET_HEADER,node.LOCAL_APPROVAL_HEADER]:self.assertIn(header,allow)
            status,body,_=h.request('GET','/exec');self.assertEqual(status,404)
            status,body,_=h.request('POST','/files');self.assertEqual(status,404)
        finally:h.close()


if __name__=='__main__':unittest.main()
