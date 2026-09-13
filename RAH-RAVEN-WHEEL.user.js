// ==UserScript==
// @name         RAH Raven Wheel MASTER
// @namespace    https://github.com/NilsRa73/rah-platform
// @version      2.1.0
// @description  Canonical RAH wheel for ChatGPT: all core Raven shortcuts, Vault/download tracking, bridge status and native right-click repair.
// @author       RAH AI Studios
// @match        https://chatgpt.com/*
// @match        https://chat.openai.com/*
// @grant        GM_xmlhttpRequest
// @grant        GM_registerMenuCommand
// @connect      127.0.0.1
// @connect      localhost
// @run-at       document-start
// ==/UserScript==

(() => {
  'use strict';

  const VERSION = '2.1.0';
  const BASE = 'http://127.0.0.1:18765';
  const PAGES = 'https://nilsra73.github.io/rah-platform';
  const ROOT_ID = 'rah-raven-wheel-master';
  const ALLOWED_EXT = ['pdf','zip','docx','xlsx','pptx','txt','md','json','csv','html','htm','py','bat','ps1','png','jpg','jpeg','webp','gif'];
  const state = { open:false, recent:[] };

  // RAH rule: Raven Wheel is LEFT-CLICK only. Never steal the browser's native right-click.
  // This also repairs older Tampermonkey wheel builds that called preventDefault() on contextmenu.
  const nativePreventDefault = Event.prototype.preventDefault;
  Event.prototype.preventDefault = function(...args) {
    if (this && this.type === 'contextmenu' && this.isTrusted) return;
    return nativePreventDefault.apply(this, args);
  };

  function gm(method, path, data) {
    return new Promise((resolve, reject) => {
      GM_xmlhttpRequest({
        method,
        url: BASE + path,
        headers: data ? {'Content-Type':'application/json'} : undefined,
        data: data ? JSON.stringify(data) : undefined,
        timeout: 6000,
        onload: r => {
          let body = {};
          try { body = JSON.parse(r.responseText || '{}'); } catch {}
          if (r.status < 200 || r.status >= 300 || body?.ok === false) return reject(new Error(body?.error || `HTTP ${r.status}`));
          resolve(body);
        },
        ontimeout: () => reject(new Error('Raven Bridge svarte ikke.')),
        onerror: () => reject(new Error('Kunne ikke kontakte Raven Bridge.')),
      });
    });
  }

  const openUrl = url => window.open(url, '_blank', 'noopener,noreferrer');
  const openLocal = path => openUrl(BASE + path);

  function cleanFilename(value) {
    let name = String(value || '').trim();
    try { name = decodeURIComponent(name); } catch {}
    name = name.split(/[?#]/)[0].split('/').pop() || '';
    return name.length <= 180 ? name : name.slice(-180);
  }

  function extFromName(name) {
    const lower = String(name || '').toLowerCase().trim();
    if (lower.endsWith('.user.js')) return 'user.js';
    const m = lower.match(/\.([a-z0-9]{1,8})(?:[?#].*)?$/);
    return m ? m[1] : '';
  }

  function inferDownload(anchor) {
    if (!(anchor instanceof HTMLAnchorElement)) return null;
    const label = (anchor.textContent || '').trim().replace(/\s+/g,' ').slice(0,180);
    const candidates = [anchor.getAttribute('download') || '', cleanFilename(anchor.getAttribute('href') || ''), label];
    let filename = '', extension = '';
    for (const candidate of candidates) {
      const maybe = cleanFilename(candidate), ext = extFromName(maybe);
      if (ALLOWED_EXT.includes(ext)) { filename = maybe; extension = ext; break; }
    }
    if (!filename && !/\b(last ned|download|pdf|zip|docx|xlsx|pptx|png|jpg|jpeg|webp|gif)\b/i.test(label)) return null;
    return {filename, extension, label};
  }

  async function registerExpectedDownload(info) {
    if (!info || (!info.filename && !info.extension)) return;
    try {
      await gm('POST','/downloads/expect',{
        source:'chatgpt', filename:info.filename || '', extension:info.extension ? '.' + info.extension : '', label:info.label || '', ttl_seconds:1200
      });
      toast('Raven følger nedlastingen 🐦');
      setTimeout(refresh, 1500);
    } catch (e) { toast('Bridge ikke klar: ' + e.message, true); }
  }

  function escapeHtml(value) {
    return String(value ?? '').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  }

  function toast(message, bad=false) {
    let box = document.getElementById('rah-raven-toast-master');
    if (!box) return;
    box.textContent = message;
    box.className = bad ? 'show bad' : 'show';
    clearTimeout(box._t);
    box._t = setTimeout(()=>{ box.className=''; },2800);
  }

  function renderFiles(items) {
    const box = document.getElementById('rah-raven-wheel-files');
    if (!box) return;
    if (!items?.length) { box.innerHTML='<small>Ingen Raven Vault-filer hentet ennå.</small>'; return; }
    box.innerHTML = items.slice(0,6).map(item=>`<button class="rah-file" data-file-id="${escapeHtml(item.id || '')}"><strong>${escapeHtml(item.stored_name || item.original_name || 'Fil')}</strong><small>${escapeHtml(item.project || 'Inbox')} · ${escapeHtml((item.captured_at || '').replace('T',' ').slice(0,16))}</small></button>`).join('');
    box.querySelectorAll('[data-file-id]').forEach(btn=>btn.addEventListener('click',async()=>{
      try { await gm('POST','/downloads/open-file',{id:btn.dataset.fileId,confirm:true}); }
      catch(e){ toast(e.message,true); }
    }));
  }

  async function refresh() {
    const statusEl = document.getElementById('rah-raven-status');
    if (!statusEl) return;
    try {
      const [health,recent] = await Promise.all([gm('GET','/health').catch(()=>({ok:true})), gm('GET','/downloads/recent?limit=6').catch(()=>({items:[]}))]);
      state.recent = recent.items || [];
      statusEl.className='rah-status ok';
      statusEl.innerHTML='<span></span>Bridge ONLINE · native høyreklikk PÅ';
      renderFiles(state.recent);
    } catch(e) {
      statusEl.className='rah-status bad';
      statusEl.innerHTML='<span></span>Bridge OFFLINE · native høyreklikk PÅ';
      renderFiles([]);
    }
  }

  function mount() {
    if (!document.body || document.getElementById(ROOT_ID)) return;

    // Hide obsolete repo wheel UI if an older script is also enabled. It remains installed, but MASTER owns the visible wheel.
    const style = document.createElement('style');
    style.id='rah-raven-master-style';
    style.textContent=`
      #rah-command-wheel-v2,#rah-raven-wheel-root{display:none!important}
      #${ROOT_ID}{position:fixed;right:22px;bottom:24px;z-index:2147483646;font-family:Segoe UI,Arial,sans-serif;color:#f8e6a7}
      #${ROOT_ID} *{box-sizing:border-box} #${ROOT_ID} .rah-main{width:62px;height:62px;border-radius:50%;border:1px solid #d4aa42;background:radial-gradient(circle at 35% 28%,#ffe58b,#b47b17 45%,#121008 72%);color:#120c03;font-size:27px;font-weight:900;cursor:pointer;box-shadow:0 0 0 4px #070707,0 10px 32px #000b,0 0 24px #cf9c3055}
      #${ROOT_ID} .rah-panel{position:absolute;right:0;bottom:74px;width:min(430px,92vw);max-height:78vh;overflow:auto;padding:12px;border:1px solid #806322;border-radius:18px;background:linear-gradient(150deg,#17140cfa,#070809fa 68%);box-shadow:0 20px 55px #000d;backdrop-filter:blur(14px)}
      #${ROOT_ID} header{display:flex;justify-content:space-between;align-items:end;gap:8px;padding:3px 4px 8px;border-bottom:1px solid #5b471c} #${ROOT_ID} header strong{font-size:14px;letter-spacing:1px;color:#ffe697} #${ROOT_ID} header small{font-size:10px;color:#9e8954}
      #${ROOT_ID} .rah-status{display:flex;align-items:center;gap:7px;padding:9px 4px 7px;font-size:11px;color:#c9bc91} #${ROOT_ID} .rah-status span{width:8px;height:8px;border-radius:50%;background:#8d742f} #${ROOT_ID} .rah-status.ok span{background:#55cf7b} #${ROOT_ID} .rah-status.bad span{background:#d65b4b}
      #${ROOT_ID} .rah-grid{display:grid;grid-template-columns:repeat(3,1fr);gap:7px} #${ROOT_ID} .rah-action{min-height:58px;border:1px solid #5c491d;border-radius:11px;background:#17130a;color:#f6dda0;cursor:pointer;padding:8px 5px;font-size:11px;font-weight:750} #${ROOT_ID} .rah-action:hover{background:#292008;border-color:#d0a33a} #${ROOT_ID} .rah-action b{display:block;font-size:19px;margin-bottom:3px}
      #${ROOT_ID} .rah-files{margin-top:10px;padding-top:8px;border-top:1px solid #44371b;max-height:170px;overflow:auto} #${ROOT_ID} .rah-files>small{color:#8f8875} #${ROOT_ID} .rah-file{display:block;width:100%;text-align:left;margin:5px 0;padding:7px 8px;border:1px solid #302b1e;border-radius:9px;background:#0d0e0e;color:#eee;cursor:pointer} #${ROOT_ID} .rah-file strong{display:block;color:#ffe294;white-space:nowrap;overflow:hidden;text-overflow:ellipsis} #${ROOT_ID} .rah-file small{color:#918d82}
      #${ROOT_ID} footer{padding-top:9px;text-align:center;color:#8b7a4b;font-size:9px} #rah-raven-toast-master{position:fixed;right:22px;bottom:100px;z-index:2147483647;max-width:340px;padding:10px 13px;border:1px solid #806322;border-radius:11px;background:#111;color:#ffe8a1;opacity:0;pointer-events:none;transform:translateY(7px);transition:.18s} #rah-raven-toast-master.show{opacity:1;transform:none} #rah-raven-toast-master.bad{border-color:#843d3d;color:#ffc2c2}
      @media(max-width:520px){#${ROOT_ID} .rah-grid{grid-template-columns:repeat(2,1fr)}}
    `;
    document.head.appendChild(style);

    const root=document.createElement('div');
    root.id=ROOT_ID;
    root.innerHTML=`
      <button class="rah-main" type="button" title="RAH Raven Wheel MASTER" aria-expanded="false">🐦</button>
      <section class="rah-panel" hidden aria-label="RAH Raven Wheel MASTER">
        <header><strong>🐦‍⬛ RAVEN WHEEL MASTER</strong><small>v${VERSION}</small></header>
        <div id="rah-raven-status" class="rah-status"><span></span>Bridge sjekkes…</div>
        <div class="rah-grid">
          <button class="rah-action" data-url="${PAGES}/"><b>⌘</b>Command Center</button>
          <button class="rah-action" data-url="${PAGES}/RAH-RAVEN-MISSION-CONTROL.html"><b>🎯</b>Mission Control</button>
          <button class="rah-action" data-url="${BASE}/vision/ui"><b>👁</b>Raven Vision</button>
          <button class="rah-action" data-url="${BASE}/home-control/ui"><b>🏠</b>Home Control</button>
          <button class="rah-action" data-url="${BASE}/chronicle/ui"><b>📜</b>Chronicle</button>
          <button class="rah-action" data-url="${BASE}/chronicle/brief-ui"><b>☀️</b>Daily Brief</button>
          <button class="rah-action" data-url="${BASE}/chronicle/insights-ui"><b>💡</b>Insights</button>
          <button class="rah-action" data-url="${BASE}/doctor/ui"><b>🩺</b>Raven Doctor</button>
          <button class="rah-action" data-url="${BASE}/downloads/ui"><b>⬇</b>Downloads</button>
          <button class="rah-action" data-action="vault"><b>📂</b>Raven Vault</button>
          <button class="rah-action" data-url="${PAGES}/RAH-RAVEN-AGENT-RUNNER.html"><b>🦾</b>Agent Runner</button>
          <button class="rah-action" data-url="${PAGES}/RAH-RAVEN-START.html"><b>🚀</b>AI Studio</button>
          <button class="rah-action" data-url="${BASE}/device/status"><b>📟</b>Device Status</button>
          <button class="rah-action" data-url="${BASE}/vision/chatgpt.user.js"><b>🔌</b>ChatGPT Bridge</button>
          <button class="rah-action" data-url="${PAGES}/RAH-RAVEN-COMMAND-WHEEL.html"><b>🛞</b>Full Wheel</button>
        </div>
        <div id="rah-raven-wheel-files" class="rah-files"><small>Henter siste filer…</small></div>
        <footer>MASTER · venstreklikk åpner Raven · høyreklikk er alltid nettleseren</footer>
      </section>`;
    document.body.appendChild(root);

    const toastBox=document.createElement('div'); toastBox.id='rah-raven-toast-master'; document.body.appendChild(toastBox);
    const main=root.querySelector('.rah-main'),panel=root.querySelector('.rah-panel');
    main.addEventListener('click',()=>{ state.open=panel.hidden; panel.hidden=!state.open; main.setAttribute('aria-expanded',String(state.open)); if(state.open) refresh(); });
    root.querySelectorAll('[data-url]').forEach(btn=>btn.addEventListener('click',()=>openUrl(btn.dataset.url)));
    root.querySelector('[data-action="vault"]').addEventListener('click',async()=>{ try{await gm('POST','/downloads/open-vault',{confirm:true});}catch(e){toast(e.message,true);} });
    refresh();
  }

  document.addEventListener('click',event=>{
    const anchor=event.target instanceof Element ? event.target.closest('a') : null;
    if(anchor) registerExpectedDownload(inferDownload(anchor));
  },true);

  if(typeof GM_registerMenuCommand==='function'){
    GM_registerMenuCommand('RAH: Åpne Command Center',()=>openUrl(`${PAGES}/`));
    GM_registerMenuCommand('RAH: Raven Doctor',()=>openLocal('/doctor/ui'));
    GM_registerMenuCommand('RAH: Raven Vault',()=>openLocal('/downloads/ui'));
  }

  const start=()=>{ mount(); if(document.documentElement && !document.getElementById('rah-raven-master-observer')){
    const marker=document.createElement('meta'); marker.id='rah-raven-master-observer'; document.documentElement.appendChild(marker);
    new MutationObserver(mount).observe(document.documentElement,{childList:true,subtree:true});
  }};
  if(document.readyState==='loading') document.addEventListener('DOMContentLoaded',start,{once:true}); else start();
  setInterval(refresh,30000);
})();
