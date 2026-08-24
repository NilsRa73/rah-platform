// ==UserScript==
// @name         RAH Command Wheel for ChatGPT
// @namespace    rah.ai.studios
// @version      2.0.0
// @description  RAH-hovedmeny inne i ChatGPT. Lokale RAH-moduler åpnes via Raven Bridge.
// @match        https://chatgpt.com/*
// @match        https://chat.openai.com/*
// @grant        GM_registerMenuCommand
// ==/UserScript==

(() => {
  'use strict';

  const BRIDGE = 'http://127.0.0.1:18765';
  const ROOT_ID = 'rah-command-wheel-v2';
  const items = [
    ['🏠','Home Control', `${BRIDGE}/home-control/ui`],
    ['🐦','Raven Vision', `${BRIDGE}/vision/ui`],
    ['📜','Chronicle', `${BRIDGE}/chronicle/ui`],
    ['💡','Insights', `${BRIDGE}/chronicle/insights-ui`],
    ['☀️','Daily Brief', `${BRIDGE}/chronicle/brief-ui`],
    ['🌉','Bridge Status', `${BRIDGE}/health`],
    ['📟','Device Status', `${BRIDGE}/device/status`]
  ];

  const openUrl = url => window.open(url, '_blank', 'noopener,noreferrer');

  function mount() {
    if (document.getElementById(ROOT_ID) || !document.body) return;
    const root = document.createElement('div');
    root.id = ROOT_ID;
    root.innerHTML = `
      <button class="rah-main" type="button" aria-expanded="false" title="RAH Command Wheel">RAH</button>
      <section class="rah-panel" hidden aria-label="RAH Command Wheel">
        <header><strong>RAH COMMAND WHEEL</strong><small>AI STUDIOS</small></header>
        <div class="rah-status"><span class="rah-dot"></span><span>Bridge: sjekker…</span></div>
        <div class="rah-grid">${items.map(([icon,label,url],i)=>`<button type="button" data-url="${url}" title="${label}"><b>${icon}</b><span>${label}</span></button>`).join('')}</div>
        <footer>Local-first · port 18765</footer>
      </section>`;

    const style = document.createElement('style');
    style.textContent = `
      #${ROOT_ID}{position:fixed;right:18px;bottom:82px;z-index:2147483646;font-family:Segoe UI,Arial,sans-serif;color:#f7df92}
      #${ROOT_ID} *{box-sizing:border-box}
      #${ROOT_ID} .rah-main{width:62px;height:62px;border-radius:50%;border:1px solid #d2a53b;background:radial-gradient(circle at 35% 28%,#49370b,#0a0a09 62%);color:#ffe79b;font-weight:900;letter-spacing:1px;box-shadow:0 8px 30px #000a,0 0 16px #b8892428;cursor:pointer}
      #${ROOT_ID} .rah-panel{position:absolute;right:0;bottom:72px;width:300px;padding:12px;border:1px solid #72571c;border-radius:16px;background:linear-gradient(155deg,#15130d,#080808 62%);box-shadow:0 18px 45px #000c}
      #${ROOT_ID} header{display:flex;justify-content:space-between;align-items:end;padding:3px 4px 9px;border-bottom:1px solid #5c4619}
      #${ROOT_ID} header strong{font-size:13px;letter-spacing:1.2px} #${ROOT_ID} header small{font-size:9px;color:#aa8b45}
      #${ROOT_ID} .rah-status{display:flex;gap:7px;align-items:center;padding:9px 4px 5px;font-size:11px;color:#cbbd8e}
      #${ROOT_ID} .rah-dot{width:8px;height:8px;border-radius:50%;background:#8b6b24;box-shadow:0 0 8px currentColor}
      #${ROOT_ID} .rah-status.ok .rah-dot{background:#43b86b} #${ROOT_ID} .rah-status.bad .rah-dot{background:#c75445}
      #${ROOT_ID} .rah-grid{display:grid;grid-template-columns:1fr 1fr;gap:7px;padding-top:5px}
      #${ROOT_ID} .rah-grid button{min-height:62px;border:1px solid #5e491b;border-radius:11px;background:#17130a;color:#f5dda0;cursor:pointer;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:4px}
      #${ROOT_ID} .rah-grid button:hover{background:#292009;border-color:#c39931} #${ROOT_ID} .rah-grid b{font-size:20px} #${ROOT_ID} .rah-grid span{font-size:11px;font-weight:700}
      #${ROOT_ID} footer{text-align:center;padding-top:9px;font-size:9px;color:#806e43}
    `;
    document.head.appendChild(style);
    document.body.appendChild(root);

    const main = root.querySelector('.rah-main');
    const panel = root.querySelector('.rah-panel');
    const status = root.querySelector('.rah-status');
    main.addEventListener('click', () => {
      const opening = panel.hidden;
      panel.hidden = !opening;
      main.setAttribute('aria-expanded', String(opening));
      if (opening) checkBridge(status);
    });
    root.querySelectorAll('[data-url]').forEach(button => button.addEventListener('click', () => openUrl(button.dataset.url)));
  }

  async function checkBridge(status) {
    status.className = 'rah-status';
    status.lastElementChild.textContent = 'Bridge: sjekker…';
    try {
      const response = await fetch(`${BRIDGE}/health`, {method:'GET', cache:'no-store'});
      if (!response.ok) throw new Error('offline');
      status.classList.add('ok');
      status.lastElementChild.textContent = 'Bridge: ONLINE';
    } catch (_) {
      status.classList.add('bad');
      status.lastElementChild.textContent = 'Bridge: OFFLINE — bruk Desktop Start RAH';
    }
  }

  if (typeof GM_registerMenuCommand === 'function') {
    GM_registerMenuCommand('RAH: Home Control', () => openUrl(`${BRIDGE}/home-control/ui`));
    GM_registerMenuCommand('RAH: Bridge Status', () => openUrl(`${BRIDGE}/health`));
  }

  mount();
  new MutationObserver(mount).observe(document.documentElement, {childList:true,subtree:true});
})();
