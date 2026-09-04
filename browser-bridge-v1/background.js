importScripts('config.js');

const CFG = self.RAH_CONFIG;
const PENDING_KEY = 'rah_pending_results_v12';
const DIAG_KEY = 'rah_diag_v12';
const STATE_KEY = 'rah_state_v12';
const MAX_PENDING = 100;
const MAX_DIAG = 400;

async function getLocal(key, fallback) {
  const obj = await chrome.storage.local.get(key);
  return obj[key] ?? fallback;
}
async function setLocal(key, value) {
  await chrome.storage.local.set({[key]: value});
}
async function setState(patch={}) {
  const state = await getLocal(STATE_KEY, {});
  const next = {...state, ...patch, updated_at:new Date().toISOString()};
  await setLocal(STATE_KEY, next);
  return next;
}
async function log(stage, detail={}) {
  const rows = await getLocal(DIAG_KEY, []);
  rows.push({ts:new Date().toISOString(), stage, detail});
  await setLocal(DIAG_KEY, rows.slice(-MAX_DIAG));
  await setState({last_stage:stage, last_detail:detail});
}
async function getPending() {
  const q = await getLocal(PENDING_KEY, []);
  return Array.isArray(q) ? q : [];
}
async function setPending(items) {
  await setLocal(PENDING_KEY, items.slice(-MAX_PENDING));
  await setState({pending_count:items.length});
}
async function enqueue(payload) {
  const q = await getPending();
  const rid = payload?.request_id;
  if (rid && q.some(x => x?.request_id === rid)) {
    await log('QUEUE_DUPLICATE_SKIPPED', {request_id:rid});
    return;
  }
  q.push(payload);
  await setPending(q);
  await log('QUEUE_ENQUEUED', {request_id:rid, tool:payload?.tool, pending:q.length});
}
async function ack(requestId) {
  const q = await getPending();
  const next = q.filter(x => x?.request_id !== requestId);
  await setPending(next);
  await log('DELIVERY_ACK', {request_id:requestId, pending:next.length});
}
async function agentFetch(path, options={}) {
  const headers = Object.assign({}, options.headers || {}, {
    'Authorization': 'Bearer ' + CFG.token,
    'Content-Type': 'application/json'
  });
  const r = await fetch(CFG.agent + path, {...options, headers, cache:'no-store'});
  let data = {};
  try { data = await r.json(); } catch (_) {}
  if (!r.ok) throw new Error(data.error || `HTTP ${r.status}`);
  return data;
}
async function health() {
  const r = await fetch(CFG.agent + '/health', {cache:'no-store'});
  const data = await r.json();
  const ok = r.ok && !!data.ok;
  await log('AGENT_HEALTH', {ok, version:data?.version});
  await setState({agent_online:ok, agent_version:data?.version || null});
  return {ok, data};
}

chrome.runtime.onMessage.addListener((msg, sender, sendResponse) => {
  (async () => {
    try {
      if (msg?.type === 'health') {
        sendResponse(await health());
        return;
      }
      if (msg?.type === 'tool') {
        const req = msg.request || {};
        await log('TOOL_REQUEST', {request_id:req.request_id, tool:req.tool});
        const data = await agentFetch('/v1/tool', {
          method:'POST',
          body:JSON.stringify({tool:req.tool, args:req.args || {}})
        });
        const payload = {
          protocol:'RAH_AGENT_RESULT_V1',
          request_id:req.request_id || ('rah-' + Date.now()),
          tool:req.tool,
          ok:!!data.ok,
          result:data.result ?? null,
          error:data.error ?? null,
          duration_ms:data.duration_ms ?? null,
          bridge:'RAH_BROWSER_BRIDGE_V12',
          bridge_version:CFG.version
        };
        await log('TOOL_RESULT', {
          request_id:payload.request_id,
          tool:payload.tool,
          ok:payload.ok,
          duration_ms:payload.duration_ms
        });
        await enqueue(payload);
        sendResponse({ok:true, payload});
        return;
      }
      if (msg?.type === 'pending') {
        sendResponse({ok:true, items:await getPending()});
        return;
      }
      if (msg?.type === 'ack') {
        await ack(msg.request_id);
        sendResponse({ok:true});
        return;
      }
      if (msg?.type === 'log') {
        await log(String(msg.stage || 'CONTENT_EVENT'), msg.detail || {});
        sendResponse({ok:true});
        return;
      }
      if (msg?.type === 'diag') {
        sendResponse({ok:true, rows:await getLocal(DIAG_KEY, [])});
        return;
      }
      if (msg?.type === 'state') {
        sendResponse({
          ok:true,
          state:await getLocal(STATE_KEY, {}),
          pending:await getPending()
        });
        return;
      }
      if (msg?.type === 'diagClear') {
        await setLocal(DIAG_KEY, []);
        await setLocal(STATE_KEY, {});
        sendResponse({ok:true});
        return;
      }
      if (msg?.type === 'clearPending') {
        await setPending([]);
        await log('QUEUE_CLEARED', {});
        sendResponse({ok:true});
        return;
      }
      sendResponse({ok:false,error:'unknown message'});
    } catch (e) {
      await log('BACKGROUND_ERROR', {error:String(e?.message || e), type:msg?.type});
      await setState({last_error:String(e?.message || e)});
      sendResponse({ok:false,error:String(e?.message || e)});
    }
  })();
  return true;
});

chrome.runtime.onInstalled.addListener(async details => {
  await chrome.storage.local.set({
    rah_bridge_version: CFG.version,
    rah_installed_at: new Date().toISOString()
  });
  await log('EXTENSION_INSTALLED', {reason:details.reason, version:CFG.version});
});
