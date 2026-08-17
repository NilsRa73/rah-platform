import crypto from 'node:crypto';
import net from 'node:net';

export const CAPABILITIES=Object.freeze(['compute','storage','display','remote-desktop']);
export const ACTIONS=Object.freeze(['storage-summary.read','rustdesk.launch','rustdesk.connect']);
export const ROUTES=Object.freeze(['/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk']);
export const AUTH_PROTOCOL='rah-node-auth-v2';
export const ACTIONS_PROTOCOL='rah-node-actions-v7';
export const POLICY_ID='rah-capability-allowlist-v1';
export const AUTH_INIT_HEADER='X-RAH-Auth-Init';
export const AUTH_NONCE_HEADER='X-RAH-Auth-Nonce';
export const AUTH_PROOF_HEADER='X-RAH-Auth-Proof';
export const CANONICAL_VERSION='RAH-AUTH-V2';
export const TTL_SECONDS=30;

function normalizeSource(value){
  if(typeof value!=='string'||net.isIP(value)!==4)return'';
  const p=value.split('.').map(Number);
  if(p[0]===127||p[0]===10||(p[0]===172&&p[1]>=16&&p[1]<=31)||(p[0]===192&&p[1]===168))return p.join('.');
  return'';
}
function safeText(value,max=256){return typeof value==='string'&&value.length<=max&&!/[\r\n\0]/.test(value)?value:''}
function hashBytes(value){const buf=Buffer.isBuffer(value)?value:Buffer.from(value||'');return crypto.createHash('sha256').update(buf).digest('hex')}
function safeEqual(a,b){if(typeof a!=='string'||typeof b!=='string'||!a||!b)return false;const x=Buffer.from(a),y=Buffer.from(b);return x.length===y.length&&crypto.timingSafeEqual(x,y)}
function validContext(v){return typeof v==='string'&&v.length>=32&&v.length<=128&&/^[A-Za-z0-9_-]+$/.test(v)}
function fixedRequestShape(method,path){
  if(typeof path!=='string'||path.includes('?')||path.includes('#')||!ROUTES.includes(path))return false;
  if(path==='/health'||path==='/actions'||path==='/storage')return method==='GET';
  return method==='POST';
}
function normalizeFields(fields={}){
  const allowed=['approvalAction','approvalTarget','requesterContext','actionChallenge','nodeLocalApprovalProof'];
  if(!fields||typeof fields!=='object'||Array.isArray(fields)||Object.keys(fields).some(k=>!allowed.includes(k)))return null;
  const out={};for(const k of allowed){const v=fields[k]??'';if(typeof v!=='string'||v.length>256||/[\r\n\0]/.test(v))return null;out[k]=v}
  return out;
}
function semantics(method,path,body,fields){
  const f=normalizeFields(fields);if(!f||!fixedRequestShape(method,path))return false;
  const emptyBody=(Buffer.isBuffer(body)?body.length:Buffer.byteLength(body||''))===0;
  if(path==='/health')return emptyBody&&Object.values(f).every(v=>v==='');
  if(path==='/actions'){
    if(Object.values(f).every(v=>v===''))return emptyBody;
    if(!emptyBody||!['rustdesk.launch','rustdesk.connect'].includes(f.approvalAction)||!validContext(f.requesterContext)||f.actionChallenge||f.nodeLocalApprovalProof)return false;
    if(f.approvalAction==='rustdesk.launch')return f.approvalTarget==='';
    return /^\d{6,20}$/.test(f.approvalTarget)||/^[A-Za-z][A-Za-z0-9_]{5,15}$/.test(f.approvalTarget);
  }
  if(path==='/storage')return emptyBody&&!!f.actionChallenge&&!f.approvalAction&&!f.approvalTarget&&!f.requesterContext&&!f.nodeLocalApprovalProof;
  if(path==='/launch/rustdesk')return emptyBody&&validContext(f.requesterContext)&&!!f.actionChallenge&&!!f.nodeLocalApprovalProof&&!f.approvalAction&&!f.approvalTarget;
  if(path==='/handoff/rustdesk'){
    if(!validContext(f.requesterContext)||!f.actionChallenge||!f.nodeLocalApprovalProof||f.approvalAction||f.approvalTarget)return false;
    try{const p=JSON.parse(Buffer.isBuffer(body)?body.toString('utf8'):String(body||''));return !!p&&typeof p==='object'&&!Array.isArray(p)&&Object.keys(p).length===1&&typeof p.peerId==='string'&&( /^\d{6,20}$/.test(p.peerId)||/^[A-Za-z][A-Za-z0-9_]{5,15}$/.test(p.peerId) )}catch{return false}
  }
  return false;
}
export function canonicalRequest({sessionId,nonce,method,path,body=Buffer.alloc(0),fields={}}={}){
  if(typeof sessionId!=='string'||sessionId.length<16||typeof nonce!=='string'||nonce.length<24||!semantics(method,path,body,fields))return'';
  const f=normalizeFields(fields);
  return [CANONICAL_VERSION,sessionId,nonce,method,path,hashBytes(body),f.approvalAction,f.approvalTarget,f.requesterContext,f.actionChallenge,f.nodeLocalApprovalProof].join('\n');
}
export function signProof(token,canonical){
  if(typeof token!=='string'||token.length<16||typeof canonical!=='string'||!canonical)return'';
  return crypto.createHmac('sha256',Buffer.from(token,'utf8')).update(canonical,'utf8').digest('base64url');
}

export class TokenProofResearchModel{
  constructor({token,sessionId,clock=()=>Date.now()/1000,random=()=>crypto.randomBytes(24).toString('base64url'),ttlSeconds=TTL_SECONDS,maxPerSource=8,maxGlobal=64}={}){
    if(typeof token!=='string'||token.length<16)throw new Error('invalid token');
    if(typeof sessionId!=='string'||sessionId.length<16)throw new Error('invalid session');
    this.token=token;this.sessionId=sessionId;this.clock=clock;this.random=random;this.ttlSeconds=ttlSeconds;this.maxPerSource=maxPerSource;this.maxGlobal=maxGlobal;this.nonces=new Map();
  }
  prune(){const now=this.clock();for(const [nonce,v] of this.nonces)if(now>v.expires)this.nonces.delete(nonce)}
  issueChallenge({method='GET',path='/health',authInit='1',authorization='',requesterSource,originAllowed=true,requesterContext='',extraSecurityHeaders=false}={}){
    if(!originAllowed)return{ok:false,error:'origin_not_allowed'};
    if(method!=='GET'||path!=='/health'||authInit!=='1')return{ok:false,error:'auth_init_invalid'};
    if(authorization)return{ok:false,error:'authorization_transport_forbidden'};
    if(requesterContext||extraSecurityHeaders)return{ok:false,error:'auth_init_security_fields_forbidden'};
    const source=normalizeSource(requesterSource);if(!source)return{ok:false,error:'requester_source_not_allowed'};
    this.prune();
    if(this.nonces.size>=this.maxGlobal)return{ok:false,error:'auth_nonce_capacity'};
    let count=0;for(const v of this.nonces.values())if(v.source===source)count++;
    if(count>=this.maxPerSource)return{ok:false,error:'auth_nonce_source_capacity'};
    let nonce='';for(let i=0;i<8&&!nonce;i++){const v=String(this.random()||'');if(v.length>=24&&!this.nonces.has(v))nonce=v}
    if(!nonce)return{ok:false,error:'auth_nonce_generation_failed'};
    this.nonces.set(nonce,{source,expires:this.clock()+this.ttlSeconds});
    return{ok:true,payload:{protocol:AUTH_PROTOCOL,status:'challenge',sessionId:this.sessionId,nonce,nonceTtlSeconds:this.ttlSeconds}};
  }
  clientProof({nonce,method,path,body=Buffer.alloc(0),fields={}}={}){const canonical=canonicalRequest({sessionId:this.sessionId,nonce,method,path,body,fields});return signProof(this.token,canonical)}
  verify({nonce,proof,authorization='',requesterSource,method,path,body=Buffer.alloc(0),fields={}}={}){
    if(authorization)return{ok:false,error:'authorization_transport_forbidden'};
    const source=normalizeSource(requesterSource);if(!source)return{ok:false,error:'requester_source_not_allowed'};
    this.prune();const entry=this.nonces.get(nonce);if(!entry)return{ok:false,error:'auth_nonce_invalid_or_expired'};
    if(entry.source!==source)return{ok:false,error:'auth_nonce_requester_mismatch'};
    this.nonces.delete(nonce);
    const canonical=canonicalRequest({sessionId:this.sessionId,nonce,method,path,body,fields});if(!canonical)return{ok:false,error:'auth_request_shape_invalid'};
    const expected=signProof(this.token,canonical);if(!safeEqual(proof,expected))return{ok:false,error:'auth_proof_invalid'};
    return{ok:true,sessionId:this.sessionId};
  }
  snapshot(){this.prune();const perSource={};for(const v of this.nonces.values())perSource[v.source]=(perSource[v.source]||0)+1;return{outstanding:this.nonces.size,perSource,tokenStored:true,rawNoncesExposed:false}}
}
