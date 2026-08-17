import crypto from 'node:crypto';
import net from 'node:net';

export const CAPABILITIES=Object.freeze(['compute','storage','display','remote-desktop']);
export const ACTIONS=Object.freeze(['storage-summary.read','rustdesk.launch','rustdesk.connect']);
export const MUTATING_ACTIONS=Object.freeze(['rustdesk.launch','rustdesk.connect']);
export const ROUTES=Object.freeze(['/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk']);
export const REQUESTER_CONTEXT_HEADER='X-RAH-Requester-Context';
export const RESEARCH_PROTOCOL='rah-node-actions-v6';
export const POLICY_ID='rah-capability-allowlist-v1';

function parseIpv4(value){
  if(typeof value!=='string'||net.isIP(value)!==4)return null;
  const parts=value.split('.').map(Number);
  return parts.length===4?parts:null;
}
export function normalizeRequesterSource(value){
  const p=parseIpv4(value);
  if(!p)return '';
  if(p[0]===127)return p.join('.');
  if(p[0]===10)return p.join('.');
  if(p[0]===172&&p[1]>=16&&p[1]<=31)return p.join('.');
  if(p[0]===192&&p[1]===168)return p.join('.');
  return '';
}
export function validRequesterContext(value){
  return typeof value==='string'&&value.length>=32&&value.length<=128&&/^[A-Za-z0-9_-]+$/.test(value);
}
export function requesterContextDigest(value){
  if(!validRequesterContext(value))return '';
  return crypto.createHash('sha256').update(value,'utf8').digest('hex');
}
export function canonicalInputDigest(actionId,target=''){
  let text='';
  if(actionId==='rustdesk.launch'){
    if(target!=='')return '';
    text='rustdesk.launch:none';
  }else if(actionId==='rustdesk.connect'){
    if(typeof target!=='string'||!/^[0-9]{6,12}$/.test(target))return '';
    text='rustdesk.connect:peer:'+target;
  }else return '';
  return crypto.createHash('sha256').update(text,'utf8').digest('hex');
}
function safeEqual(left,right){
  if(typeof left!=='string'||typeof right!=='string'||!left||!right)return false;
  const a=Buffer.from(left);const b=Buffer.from(right);
  return a.length===b.length&&crypto.timingSafeEqual(a,b);
}

export class RequesterContextResearchModel{
  constructor({sessionId,clock=()=>Date.now()/1000,random=()=>crypto.randomBytes(24).toString('base64url'),ttlSeconds=30}={}){
    if(typeof sessionId!=='string'||sessionId.length<16)throw new Error('invalid session');
    this.sessionId=sessionId;
    this.clock=clock;
    this.random=random;
    this.ttlSeconds=ttlSeconds;
    this.pending=null;
    this.activePair=null;
  }
  requestIntent({actionId,target='',requesterSource,requesterContext,tokenValid=true,originAllowed=true,advertisedActions=ACTIONS,capabilities=CAPABILITIES,policyId=POLICY_ID,protocol=RESEARCH_PROTOCOL}={}){
    if(!tokenValid)return{ok:false,error:'unauthorized'};
    if(!originAllowed)return{ok:false,error:'origin_not_allowed'};
    if(protocol!==RESEARCH_PROTOCOL)return{ok:false,error:'protocol_mismatch'};
    if(policyId!==POLICY_ID)return{ok:false,error:'policy_mismatch'};
    if(!MUTATING_ACTIONS.includes(actionId))return{ok:false,error:'mutating_fixed_action_required'};
    if(!advertisedActions.includes(actionId))return{ok:false,error:'action_not_advertised'};
    if(!capabilities.includes('remote-desktop'))return{ok:false,error:'remote_desktop_capability_not_enabled'};
    const source=normalizeRequesterSource(requesterSource);
    if(!source)return{ok:false,error:'requester_source_not_allowed'};
    const contextDigest=requesterContextDigest(requesterContext);
    if(!contextDigest)return{ok:false,error:'requester_context_invalid'};
    const inputDigest=canonicalInputDigest(actionId,target);
    if(!inputDigest)return{ok:false,error:'invalid_fixed_action_input'};
    const requestId=String(this.random()||'');
    if(!requestId)return{ok:false,error:'request_id_failed'};
    this.pending={requestId,actionId,inputDigest,requesterSource:source,contextDigest,expires:this.clock()+this.ttlSeconds};
    return{ok:true,localPrompt:{requestId,actionId,displayTarget:actionId==='rustdesk.connect'?target:'',requesterSource:source}};
  }
  confirmLocal({requestId,approved}={}){
    const now=this.clock();
    const pending=this.pending;
    this.pending=null;
    if(!pending)return{ok:false,error:'no_pending_confirmation'};
    if(now>pending.expires)return{ok:false,error:'local_confirmation_expired'};
    if(!safeEqual(String(requestId||''),pending.requestId))return{ok:false,error:'request_id_mismatch'};
    if(approved!==true)return{ok:false,error:'local_confirmation_denied'};
    let challenge=String(this.random()||'');
    let proof=String(this.random()||'');
    for(let i=0;i<4&&(!challenge||!proof||safeEqual(challenge,proof));i++){
      if(!challenge)challenge=String(this.random()||'');
      proof=String(this.random()||'');
    }
    if(!challenge||!proof||safeEqual(challenge,proof))return{ok:false,error:'grant_generation_failed'};
    this.activePair={
      actionId:pending.actionId,
      sessionId:this.sessionId,
      inputDigest:pending.inputDigest,
      requesterSource:pending.requesterSource,
      requesterContextDigest:pending.contextDigest,
      challenge,proof,expires:now+this.ttlSeconds,
    };
    return{ok:true,grant:{actionId:pending.actionId,challenge,localApprovalProof:proof,ttlSeconds:this.ttlSeconds}};
  }
  consume({actionId,target='',requesterSource,requesterContext,challenge,proof}={}){
    const pair=this.activePair;
    const now=this.clock();
    if(!pair)return'missing';
    if(now>pair.expires){this.activePair=null;return'expired';}
    const source=normalizeRequesterSource(requesterSource);
    if(!source)return'requester_source_not_allowed';
    if(source!==pair.requesterSource)return'requester_source_mismatch';
    const contextDigest=requesterContextDigest(requesterContext);
    if(!contextDigest)return'requester_context_invalid';
    if(contextDigest!==pair.requesterContextDigest)return'requester_context_mismatch';
    if(actionId!==pair.actionId)return'action_mismatch';
    if(this.sessionId!==pair.sessionId)return'session_mismatch';
    const inputDigest=canonicalInputDigest(actionId,target);
    if(!inputDigest||inputDigest!==pair.inputDigest)return'input_mismatch';
    if(!safeEqual(challenge,pair.challenge))return'challenge_invalid';
    if(!safeEqual(proof,pair.proof))return'proof_invalid';
    this.activePair=null;
    return'ok';
  }
  snapshot(){
    return{
      pending:this.pending?{actionId:this.pending.actionId,inputDigest:this.pending.inputDigest,requesterSource:this.pending.requesterSource,requesterContextDigest:this.pending.contextDigest,expires:this.pending.expires}:null,
      activePair:this.activePair?{actionId:this.activePair.actionId,sessionId:this.activePair.sessionId,inputDigest:this.activePair.inputDigest,requesterSource:this.activePair.requesterSource,requesterContextDigest:this.activePair.requesterContextDigest,expires:this.activePair.expires}:null,
    };
  }
}
