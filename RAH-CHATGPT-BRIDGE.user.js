// ==UserScript==
// @name         RAH ChatGPT Local Agent Bridge
// @namespace    rah.ai.studios
// @version      0.2.0
// @description  Connects ChatGPT to the local RAH agent with live status, self-test, tool routing and diagnostics.
// @match        https://chatgpt.com/*
// @match        https://chat.openai.com/*
// @grant        GM_xmlhttpRequest
// @connect      127.0.0.1
// @connect      localhost
// @run-at       document-idle
// ==/UserScript==

(() => {
  'use strict';

  const VERSION = '0.2.0';
  const AGENT = 'http://127.0.0.1:18779';
  const TOKEN = '__RAH_TOKEN__';
  const MARKER_RE = /\[\[RAH_TOOL\s+(\{[\s\S]*?\})\s*\]\]/g;
  const readOnly = new Set([
    'agent.status','system.snapshot','system.cpu','system.memory','system.gpu',
    'system.disks','system.network','system.displays','fs.list','fs.read_text',
    'fs.read_bytes','fs.search','fs.hash','process.list','service.list'
  ]);

  let busy = false;
  let lastHealth = null;
  let lastError = '';
  const seenKey = 'rah_bridge_seen_v2';
  const seen = new Set(JSON.parse(sessionStorage.getItem(seenKey) || '[]'));

  function saveSeen() {
    sessionStorage.setItem(seenKey, JSON.stringify(Array.from(seen).slice(-300)));
  }

  function hash(s) {
    let h = 2166136261;
    for (let i = 0; i < s.length; i++) {
      h ^= s.charCodeAt(i);
      h = Math.imul(h, 16777619);
    }
    return (h >>> 0).toString(16);
  }

  function gm(method, url, body) {
    return new Promise((resolve, reject) => {
      GM_xmlhttpRequest({
        method,
        url,
        headers: {
          'Authorization': 'Bearer ' + TOKEN,
          'Content-Type': 'application/json'
        },
        data: body === undefined ? undefined : JSON.stringify(body),
        timeout: 120000,
        onload: r => {
          let data;
          try { data = JSON.parse(r.responseText || '{}'); }
          catch (_) { return reject(new Error('Invalid JSON from RAH Agent')); }
          if (r.status >= 400) return reject(new Error(data.error || `HTTP ${r.status}`));
          resolve(data);
        },
        onerror: () => reject(new Error('RAH Agent connection failed')),
        ontimeout: () => reject(new Error('RAH Agent timed out'))
      });
    });
  }

  function findComposer() {
    return document.querySelector('#prompt-textarea') ||
      document.querySelector('textarea[data-testid="prompt-textarea"]') ||
      document.querySelector('form textarea') ||
      document.querySelector('main div[contenteditable="true"]') ||
      document.querySelector('div[contenteditable="true"]');
  }

  async function setComposer(text, autoSend = true) {
    const editor = findComposer();
    if (!editor) throw new Error('ChatGPT composer not found');
    editor.focus();

    if (editor.tagName === 'TEXTAREA') {
      const setter = Object.getOwnPropertyDescriptor(HTMLTextAreaElement.prototype, 'value')?.set;
      if (setter) setter.call(editor, text); else editor.value = text;
      editor.dispatchEvent(new Event('input', { bubbles: true }));
      editor.dispatchEvent(new Event('change', { bubbles: true }));
    } else {
      try {
        document.execCommand('selectAll', false, null);
        document.execCommand('insertText', false, text);
      } catch (_) {
        editor.replaceChildren(document.createTextNode(text));
      }
      editor.dispatchEvent(new InputEvent('input', {
        bubbles: true,
        inputType: 'insertText',
        data: text
      }));
    }

    await new Promise(r => setTimeout(r, 650));
    if (!autoSend) return;

    const send = document.querySelector('button[data-testid="send-button"]') ||
      document.querySelector('button[aria-label="Send prompt"]') ||
      document.querySelector('button[aria-label="Send message"]') ||
      document.querySelector('form button[type="submit"]');

    if (send && !send.disabled) {
      send.click();
      return;
    }

    editor.dispatchEvent(new KeyboardEvent('keydown', {
      key: 'Enter', code: 'Enter', keyCode: 13, which: 13, bubbles: true
    }));
  }

  function stateColor(state) {
    if (state === 'online') return '#4b8d56';
    if (state === 'error') return '#a54b4b';
    if (state === 'working') return '#b99332';
    return '#6d5a22';
  }

  let badgeEl;
  function badge(state, text) {
    if (!badgeEl) {
      badgeEl = document.createElement('button');
      badgeEl.type = 'button';
      badgeEl.id = 'rah-agent-badge';
      Object.assign(badgeEl.style, {
        position: 'fixed', right: '14px', bottom: '14px', zIndex: '2147483647',
        padding: '9px 12px', borderRadius: '10px', font: '600 12px Segoe UI,sans-serif',
        background: '#111', color: '#d6b85a', border: '1px solid #6d5a22',
        opacity: '0.96', boxShadow: '0 5px 20px rgba(0,0,0,.4)', cursor: 'pointer'
      });
      badgeEl.addEventListener('click', togglePanel);
      document.documentElement.appendChild(badgeEl);
    }
    badgeEl.textContent = text;
    badgeEl.style.borderColor = stateColor(state);
  }

  let panelEl;
  function togglePanel() {
    if (panelEl) {
      panelEl.remove();
      panelEl = null;
      return;
    }
    panelEl = document.createElement('div');
    Object.assign(panelEl.style, {
      position:'fixed', right:'14px', bottom:'58px', zIndex:'2147483647', width:'340px',
      background:'#0d0d0d', color:'#eee', border:'1px solid #6d5a22', borderRadius:'12px',
      padding:'14px', boxShadow:'0 10px 35px rgba(0,0,0,.55)', font:'12px/1.45 Segoe UI,sans-serif'
    });
    panelEl.innerHTML = `
      <div style="font-weight:800;color:#d6b85a;font-size:14px">RAH CHATGPT BRIDGE v${VERSION}</div>
      <div id="rah-panel-status" style="margin-top:8px;color:#bbb">Checking...</div>
      <div style="display:grid;grid-template-columns:1fr 1fr;gap:8px;margin-top:12px">
        <button id="rah-health-btn">HEALTH</button>
        <button id="rah-cpu-btn">CPU TEST</button>
        <button id="rah-send-btn" style="grid-column:1 / span 2">SEND TEST TO CHATGPT</button>
        <button id="rah-rescan-btn" style="grid-column:1 / span 2">RESCAN THIS CHAT</button>
      </div>
      <div id="rah-panel-error" style="margin-top:10px;color:#d77;word-break:break-word"></div>`;
    panelEl.querySelectorAll('button').forEach(b => Object.assign(b.style, {
      background:'#171717', color:'#d6b85a', border:'1px solid #5b4c22', borderRadius:'7px',
      padding:'8px', cursor:'pointer', fontWeight:'700'
    }));
    panelEl.querySelector('#rah-health-btn').onclick = health;
    panelEl.querySelector('#rah-cpu-btn').onclick = cpuSelfTest;
    panelEl.querySelector('#rah-send-btn').onclick = sendSelfTestToChat;
    panelEl.querySelector('#rah-rescan-btn').onclick = () => scan(true);
    updatePanel();
    document.documentElement.appendChild(panelEl);
  }

  function updatePanel() {
    if (!panelEl) return;
    const s = panelEl.querySelector('#rah-panel-status');
    const e = panelEl.querySelector('#rah-panel-error');
    s.textContent = lastHealth?.ok
      ? `Agent ONLINE | ${lastHealth.service || 'RAH Local Agent'} | bridge v${VERSION}`
      : `Agent ${lastHealth ? 'ERROR' : 'not checked'} | bridge v${VERSION}`;
    e.textContent = lastError ? `Last error: ${lastError}` : '';
  }

  async function health() {
    try {
      const data = await gm('GET', AGENT + '/health');
      lastHealth = data;
      lastError = '';
      badge(data.ok ? 'online' : 'error', data.ok ? 'RAH Agent online' : 'RAH Agent error');
    } catch (e) {
      lastHealth = { ok:false };
      lastError = String(e.message || e);
      badge('error', 'RAH Agent offline');
    }
    updatePanel();
    return lastHealth;
  }

  async function cpuSelfTest() {
    badge('working', 'RAH: CPU self-test');
    try {
      const data = await gm('POST', AGENT + '/v1/tool', { tool:'system.cpu', args:{} });
      lastError = '';
      badge('online', 'RAH CPU test OK');
      updatePanel();
      return data;
    } catch (e) {
      lastError = String(e.message || e);
      badge('error', 'RAH CPU test FAILED');
      updatePanel();
      throw e;
    }
  }

  async function sendSelfTestToChat() {
    try {
      const data = await cpuSelfTest();
      const result = {
        protocol:'RAH_AGENT_RESULT_V1', request_id:'bridge-selftest-' + Date.now(),
        tool:'system.cpu', ok:!!data.ok, result:data.result, error:data.error || null,
        duration_ms:data.duration_ms, bridge_version:VERSION
      };
      badge('working', 'RAH: sending test');
      await setComposer('RAH_AGENT_RESULT ' + JSON.stringify(result));
      badge('online', 'RAH test sent');
    } catch (e) {
      lastError = String(e.message || e);
      badge('error', 'RAH send failed');
      updatePanel();
    }
  }

  async function execute(req, key) {
    if (busy || seen.has(key)) return;
    busy = true;
    try {
      const tool = String(req.tool || '');
      const args = req.args || {};
      if (!tool) throw new Error('Missing RAH tool name');

      if (!readOnly.has(tool)) {
        const ok = confirm(`RAH Agent requests a local action:\n\n${tool}\n${JSON.stringify(args, null, 2).slice(0, 1600)}\n\nAllow this action?`);
        if (!ok) {
          seen.add(key); saveSeen(); return;
        }
      }

      badge('working', `RAH: ${tool}`);
      const data = await gm('POST', AGENT + '/v1/tool', { tool, args });
      seen.add(key); saveSeen();
      const result = {
        protocol:'RAH_AGENT_RESULT_V1', request_id:req.request_id || key,
        tool, ok:!!data.ok, result:data.result, error:data.error || null,
        duration_ms:data.duration_ms, bridge_version:VERSION
      };
      badge(data.ok ? 'online' : 'error', data.ok ? 'RAH Agent online' : 'RAH Agent error');
      await setComposer('RAH_AGENT_RESULT ' + JSON.stringify(result));
    } catch (e) {
      seen.add(key); saveSeen();
      lastError = String(e.message || e);
      badge('error', 'RAH bridge error');
      updatePanel();
      try {
        await setComposer('RAH_AGENT_RESULT ' + JSON.stringify({
          protocol:'RAH_AGENT_RESULT_V1', request_id:key, ok:false,
          error:lastError, bridge_version:VERSION
        }));
      } catch (_) {}
    } finally {
      busy = false;
    }
  }

  function candidateTexts() {
    const out = [];
    document.querySelectorAll('[data-message-author-role="assistant"]').forEach(el => {
      out.push(el.innerText || el.textContent || '');
    });
    if (!out.length) {
      document.querySelectorAll('main article, main [data-testid^="conversation-turn-"]').forEach(el => {
        out.push(el.innerText || el.textContent || '');
      });
    }
    return out;
  }

  function scan(force = false) {
    if (busy) return;
    if (force) {
      seen.clear();
      saveSeen();
    }
    const texts = candidateTexts();
    for (const text of texts) {
      MARKER_RE.lastIndex = 0;
      let m;
      while ((m = MARKER_RE.exec(text)) !== null) {
        const raw = m[0];
        const key = hash(raw);
        if (seen.has(key)) continue;
        try {
          const req = JSON.parse(m[1]);
          execute(req, key);
        } catch (_) {
          seen.add(key); saveSeen();
        }
        return;
      }
    }
  }

  badge('working', 'RAH Bridge starting');
  health().then(() => setTimeout(scan, 700));

  new MutationObserver(() => {
    clearTimeout(window.__rahBridgeScanTimer);
    window.__rahBridgeScanTimer = setTimeout(scan, 350);
  }).observe(document.documentElement, { subtree:true, childList:true, characterData:true });

  setInterval(health, 30000);
  setInterval(scan, 2000);
})();
