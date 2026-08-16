import crypto from 'node:crypto';

export const CAPABILITIES=Object.freeze(['compute','storage','display','remote-desktop']);
export const ACTIONS=Object.freeze(['storage-summary.read','rustdesk.launch','rustdesk.connect']);
export const MUTATING_ACTIONS=Object.freeze(['rustdesk.launch','rustdesk.connect']);
export const ROUTES=Object.freeze(['/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk']);
export const APPROVAL_ACTION_HEADER='X-RAH-Approval-Action';
export const APPROVAL_TARGET_HEADER='X-RAH-Approval-Target';
export const APPROVAL_PROOF_HEADER='X-RAH-Local-Approval';

const PEER_ID=/^(?:\d{6,20}|[A-Za-z][A-Za-z0-9_]{5,15})$/;

function safeEqual(a,b){
  if(typeof a!=='string'||typeof b!=='string')return false;
  const x=Buffer.from(a),y=Buffer.from(b);
  return x.length===y.length&&crypto.timingSafeEqual(x,y);
}
function digest(value){return crypto.createHash('sha256').update(value).digest('hex')}
function randomToken(){return crypto.randomBytes(24).toString('base64url')}
function nowSeconds(){return Date.now()/1000}

export function validPeerId(value){return typeof value==='string'&&value===value.trim()&&PEER_ID.test(value)}
export function canonicalInputDigest(actionId,target=''){
  if(actionId==='rustdesk.launch')return target===''?digest('rustdesk.launch:none'):'';
  if(actionId==='rustdesk.connect')return validPeerId(target)?digest(`rustdesk.connect:peer:${target}`):'';
  return '';
}

export class LocalApprovalProofResearchModel{
  constructor({sessionId='ABCDEFGHIJKLMNOPQRSTUVWX',clock=nowSeconds,random=randomToken,proofTtlSeconds=30,promptTtlSeconds=30,cooldownSeconds=2}={}){
    if(!/^[A-Za-z0-9_-]{20,64}$/.test(sessionId))throw new Error('invalid session');
    this.sessionId=sessionId;
    this.clock=clock;
    this.random=random;
    this.proofTtlSeconds=proofTtlSeconds;
    this.promptTtlSeconds=promptTtlSeconds;
    this.cooldownSeconds=cooldownSeconds;
    this.pending=null;
    this.activePair=null;
    this.cooldownUntil=0;
  }

  requestIntent({actionId,target='',originAllowed=true,tokenValid=true,advertisedActions=ACTIONS,capabilities=CAPABILITIES}={}){
    const now=this.clock();
    if(!originAllowed)return{ok:false,error:'origin_not_allowed'};
    if(!tokenValid)return{ok:false,error:'unauthorized'};
    if(!MUTATING_ACTIONS.includes(actionId))return{ok:false,error:'mutating_fixed_action_required'};
    if(!Array.isArray(advertisedActions)||!advertisedActions.includes(actionId))return{ok:false,error:'action_not_advertised'};
    if(!Array.isArray(capabilities)||!capabilities.includes('remote-desktop'))return{ok:false,error:'remote_desktop_capability_not_enabled'};
    const inputDigest=canonicalInputDigest(actionId,target);
    if(!inputDigest)return{ok:false,error:'invalid_fixed_action_input'};
    if(this.pending)return{ok:false,error:'local_confirmation_busy'};
    if(now<this.cooldownUntil)return{ok:false,error:'local_confirmation_rate_limited'};
    const requestId=this.random();
    this.pending={requestId,actionId,sessionId:this.sessionId,inputDigest,expires:now+this.promptTtlSeconds};
    return{
      ok:true,
      status:'pending-local-confirmation',
      localPrompt:Object.freeze({requestId,actionId,target:actionId==='rustdesk.connect'?target:''})
    };
  }

  confirmLocal({requestId,approved}={}){
    const now=this.clock(),pending=this.pending;
    if(!pending)return{ok:false,error:'no_pending_confirmation'};
    if(!safeEqual(requestId,pending.requestId))return{ok:false,error:'wrong_local_confirmation'};
    this.pending=null;
    this.cooldownUntil=now+this.cooldownSeconds;
    if(now>pending.expires)return{ok:false,error:'local_confirmation_expired'};
    if(approved!==true)return{ok:false,error:'local_confirmation_denied'};
    let challenge=this.random(),approvalProof=this.random();
    if(safeEqual(challenge,approvalProof))approvalProof=this.random();
    this.activePair={
      actionId:pending.actionId,
      sessionId:pending.sessionId,
      inputDigest:pending.inputDigest,
      challenge,
      approvalProof,
      expires:now+this.proofTtlSeconds
    };
    return{
      ok:true,
      status:'approved-locally',
      grant:Object.freeze({
        actionId:pending.actionId,
        challenge,
        approvalProof,
        ttlSeconds:this.proofTtlSeconds
      })
    };
  }

  consume({actionId,target='',sessionId=this.sessionId,challenge='',approvalProof=''}={}){
    const now=this.clock(),pair=this.activePair;
    if(!pair)return{ok:false,error:'local_approval_proof_required'};
    if(now>pair.expires){this.activePair=null;return{ok:false,error:'local_approval_proof_expired'};}
    const inputDigest=canonicalInputDigest(actionId,target);
    if(actionId!==pair.actionId)return{ok:false,error:'local_approval_action_mismatch'};
    if(sessionId!==pair.sessionId)return{ok:false,error:'local_approval_session_mismatch'};
    if(!inputDigest||inputDigest!==pair.inputDigest)return{ok:false,error:'local_approval_input_mismatch'};
    if(!safeEqual(challenge,pair.challenge))return{ok:false,error:'action_challenge_invalid'};
    if(!safeEqual(approvalProof,pair.approvalProof))return{ok:false,error:'local_approval_proof_invalid'};
    this.activePair=null;
    return{ok:true,status:'proof-pair-consumed'};
  }

  snapshot(){
    return JSON.parse(JSON.stringify({
      sessionId:this.sessionId,
      pending:this.pending,
      activePair:this.activePair,
      cooldownUntil:this.cooldownUntil
    }));
  }
}
