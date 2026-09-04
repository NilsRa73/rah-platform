importScripts('config.js');

const CFG = self.RAH_CONFIG;
const PENDING_KEY = 'rah_pending_results_v1';

async function getPending() {
  const obj = await chrome.storage.local.get(PENDING_KEY);
  return Array.isArray(obj[PENDING_KEY]) ? obj[PENDING_KEY] : [];
}
async function setPending(items) {
  await chrome.storage.local.set({[PENDING_KEY]: items.slice(-100)});
}
async function enqueue(payload) {
  const q = await getPending();
  const rid = payload?.request_id;
  if (rid && q.some(x => x?.request_id === rid)) return;
  q.push(payload);
  await setPending(q);
}
async function ack(requestId) {
  const q = await getPending();
  await setPending(q.filter(x => x?.request_id !== requestId));
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

chrome.runtime.onMessage.addListener((msg, sender, sendResponse) => {
  (async () => {
    try {
      if (msg?.type === 'health') {
        const r = await fetch(CFG.agent + '/health', {cache:'no-store'});
        const data = await r.json();
        sendResponse({ok:r.ok && !!data.ok, data});
        return;
      }
      if (msg?.type === 'tool') {
        const req = msg.request || {};
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
          bridge:'RAH_BROWSER_BRIDGE_V1',
          bridge_version:CFG.version
        };
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
      if (msg?.type === 'clearPending') {
        await setPending([]);
        sendResponse({ok:true});
        return;
      }
      sendResponse({ok:false,error:'unknown message'});
    } catch (e) {
      sendResponse({ok:false,error:String(e?.message || e)});
    }
  })();
  return true;
});

chrome.runtime.onInstalled.addListener(() => {
  chrome.storage.local.set({
    rah_bridge_version: CFG.version,
    rah_installed_at: new Date().toISOString()
  });
});
