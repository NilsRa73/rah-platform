import assert from 'node:assert/strict';
import core from '../rah-command-center-core-v2.4-candidate.js';

assert.equal(core.CC_VERSION,'2.4.0-candidate');
assert.equal(core.RAVEN_COMMANDER_VERSION,'rah-cc-raven-commander-v1');
assert.equal(core.RAVEN_STATUS_PROTOCOL,'rah-node-raven-status-v1');
assert.equal(core.RAVEN_STATUS_ROUTE,'/raven/status');
assert.equal(core.RAVEN_STATUS_CAPABILITY,'system-inventory');

const ip='192.168.0.49';
const req=core.nodeRavenStatusRequest(ip);
assert.ok(req);
assert.equal(req.method,'GET');
assert.equal(req.path,'/raven/status');
assert.equal(req.url,'http://192.168.0.49:18766/raven/status');
assert.deepEqual(req.headers,{});
assert.equal(core.nodeRavenStatusRequest('8.8.8.8'),null);
assert.equal(core.nodeRavenStatusRequest('example.com'),null);

const session='Session_ABCDEFGHIJKLMNOPQRSTUVWXYZ1234';
const nonce='Nonce_ABCDEFGHIJKLMNOPQRSTUVWXYZ1234';
const canonical=core.buildRavenStatusAuthCanonical(session,nonce,req,core.EMPTY_SHA256);
assert.ok(canonical.startsWith('RAH-AUTH-V2\n'));
assert.ok(canonical.includes('\nGET\n/raven/status\n'+core.EMPTY_SHA256+'\n'));
assert.equal(canonical.split('\n').length,11);
assert.equal(core.buildRavenStatusAuthCanonical(session,nonce,{...req,method:'POST'},core.EMPTY_SHA256),'');
assert.equal(core.buildRavenStatusAuthCanonical(session,nonce,{...req,path:'/raven/status?x=1'},core.EMPTY_SHA256),'');
assert.equal(core.buildRavenStatusAuthCanonical(session,nonce,{...req,headers:{'X-RAH-Requester-Context':'A'.repeat(40)}},core.EMPTY_SHA256),'');
assert.equal(core.buildRavenStatusAuthCanonical(session,nonce,req,'a'.repeat(64)),'');

const signed=core.attachRavenStatusAuthProof(req,nonce,'A'.repeat(43));
assert.ok(signed);
assert.equal(signed.headers[core.AUTH_NONCE_HEADER],nonce);
assert.equal(signed.headers[core.AUTH_PROOF_HEADER],'A'.repeat(43));

const payload={
  ok:true,
  protocol:'rah-node-raven-status-v1',
  source:'local-raven-job-executor',
  capability:'system-inventory',
  nodeJobId:'job-fixed-1',
  arbitraryCommands:false,
  argumentsAllowed:false,
  localOnlyHop:true,
  result:{
    ok:true,
    read_only:true,
    files_modified:false,
    arbitrary_commands:false,
    stdout:'RAH RAVEN - LOCAL SYSTEM INVENTORY\nHOSTNAME : HOVED-PC',
    inventory:{
      hostname:'HOVED-PC',
      os:{system:'Windows',release:'11',version:'x',architecture:'AMD64'},
      cpu:{name:'Test CPU',logical_cores:8},
      ram_gb:16,
      gpus:['Test GPU'],
      monitor_count:3,
      raven_bridge:{version:'17',port:18765,health_route:true,agent_route:true},
      safety:{mode:'read-only-allowlist',read_only:true,arbitrary_commands:false,file_writes:false,automatic_execution:false}
    }
  }
};
const safe=core.sanitizeRavenStatusPayload(payload);
assert.ok(safe);
assert.equal(safe.hostname,'HOVED-PC');
assert.equal(safe.readOnly,true);
assert.equal(safe.arbitraryCommands,false);
assert.equal(safe.argumentsAllowed,false);
assert.equal(safe.localOnlyHop,true);
assert.equal(safe.persistent,false);
assert.equal(safe.monitorCount,3);

assert.equal(core.sanitizeRavenStatusPayload({...payload,arbitraryCommands:true}),null);
assert.equal(core.sanitizeRavenStatusPayload({...payload,argumentsAllowed:true}),null);
assert.equal(core.sanitizeRavenStatusPayload({...payload,localOnlyHop:false}),null);
assert.equal(core.sanitizeRavenStatusPayload({...payload,result:{...payload.result,files_modified:true}}),null);
assert.equal(core.sanitizeRavenStatusPayload({...payload,result:{...payload.result,inventory:{...payload.result.inventory,safety:{...payload.result.inventory.safety,automatic_execution:true}}}}),null);

const eligible={id:'lenovo',label:'Lenovo',enrolled:true,endpointIp:ip,agentSessionId:session,capabilities:['compute'],approvedActions:[],advertisedActions:[]};
assert.equal(core.ravenCommanderEligibleDevice(eligible),true);
assert.equal(core.ravenCommanderEligibleDevice({...eligible,capabilities:['storage']}),false);
assert.equal(core.ravenCommanderEligibleDevice({...eligible,enrolled:false}),false);

console.log('CC 2.4 Raven Commander candidate boundary: OK');
