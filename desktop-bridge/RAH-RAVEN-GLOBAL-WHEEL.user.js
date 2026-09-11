// ==UserScript==
// @name         RAH Raven Global Wheel
// @namespace    https://github.com/NilsRa73/rah-platform
// @version      1.0.0
// @description  Global passive Raven launcher wheel for normal web pages.
// @match        http://*/*
// @match        https://*/*
// @grant        GM_getValue
// @grant        GM_setValue
// @grant        GM_openInTab
// @grant        GM_xmlhttpRequest
// @grant        GM_registerMenuCommand
// @connect      127.0.0.1
// @connect      localhost
// @run-at       document-end
// ==/UserScript==

(() => {
  'use strict';

  const HOST_KEY = `rah-wheel-hidden:${location.host}`;
  const POS_KEY = 'rah-wheel-position';
  const BASE = 'http://127.0.0.1:18765';
  const targets = [
    ['V', 'Vision', `${BASE}/vision/ui`],
    ['C', 'Chronicle', `${BASE}/chronicle/ui`],
    ['I', 'Insights', `${BASE}/chronicle/insights-ui`],
    ['B', 'Brief', `${BASE}/chronicle/brief-ui`],
    ['H', 'Home', `${BASE}/home-control/ui`],
    ['D', 'Vault', `${BASE}/downloads/ui`],
    ['G', 'ChatGPT', 'https://chatgpt.com/'],
    ['S', 'Status', null],
  ];

  let hidden = Boolean(GM_getValue(HOST_KEY, false));
  let root = null;
  let shadow = null;
  let expanded = false;
  let statusText = 'CHECK';

  const openTab = (url) => GM_openInTab(url, { active: true, insert: true });

  function healthCheck(cb) {
    GM_xmlhttpRequest({
      method: 'GET',
      url: `${BASE}/health`,
      timeout: 3000,
      onload: (r) => {
        try {
          const h = JSON.parse(r.responseText || '{}');
          const ok = Boolean(h.ok && h.council_proxy && h.vision_monitor_capture && h.local_device_adapter);
          statusText = ok ? 'GREEN' : 'YELLOW';
          cb?.(ok, h);
        } catch {
          statusText = 'OFFLINE';
          cb?.(false, null);
        }
        updateBadge();
      },
      onerror: () => { statusText = 'OFFLINE'; updateBadge(); cb?.(false, null); },
      ontimeout: () => { statusText = 'OFFLINE'; updateBadge(); cb?.(false, null); },
    });
  }

  function updateBadge() {
    const badge = shadow?.querySelector('.badge');
    if (!badge) return;
    badge.dataset.state = statusText;
    badge.title = `Raven: ${statusText}`;
  }

  function showStatus() {
    const panel = shadow.querySelector('.status');
    panel.textContent = 'Checking Raven...';
    panel.hidden = false;
    healthCheck((ok, h) => {
      panel.textContent = ok
        ? `Raven TRUE GREEN • port ${h?.port ?? 18765} • Vision READY • Council READY`
        : `Raven ${statusText}. If offline, double-click “RAH Raven” on the desktop.`;
    });
  }

  function build() {
    if (root || hidden || !document.documentElement) return;
    root = document.createElement('div');
    root.id = 'rah-raven-wheel-host';
    root.style.cssText = 'position:fixed;z-index:2147483647;left:24px;bottom:24px;width:1px;height:1px;pointer-events:none;';
    document.documentElement.appendChild(root);
    shadow = root.attachShadow({ mode: 'open' });

    const saved = GM_getValue(POS_KEY, null);
    if (saved && Number.isFinite(saved.x) && Number.isFinite(saved.y)) {
      root.style.left = `${Math.max(0, Math.min(window.innerWidth - 70, saved.x))}px`;
      root.style.top = `${Math.max(0, Math.min(window.innerHeight - 70, saved.y))}px`;
      root.style.bottom = 'auto';
    }

    const wrap = document.createElement('div');
    wrap.innerHTML = `
      <style>
        *{box-sizing:border-box} .wrap{position:relative;width:64px;height:64px;pointer-events:auto;font-family:Arial,sans-serif;user-select:none}
        .core{position:absolute;inset:0;border-radius:50%;border:2px solid #d5a72e;background:radial-gradient(circle at 35% 30%,#2b2b2b,#050505 70%);color:#f6d77a;font-size:26px;font-weight:900;cursor:pointer;box-shadow:0 0 20px #000,0 0 14px rgba(213,167,46,.45)}
        .badge{position:absolute;right:-2px;top:-2px;width:14px;height:14px;border-radius:50%;background:#777;border:2px solid #111}.badge[data-state='GREEN']{background:#43d17b}.badge[data-state='YELLOW']{background:#e4b63b}.badge[data-state='OFFLINE']{background:#d14b4b}
        .item{position:absolute;width:48px;height:48px;border-radius:50%;border:1px solid #b88a20;background:#111;color:#f5d56c;font-weight:800;cursor:pointer;opacity:0;transform:translate(8px,8px) scale(.5);transition:.15s;box-shadow:0 4px 16px #0008}
        .wrap.open .item{opacity:1}.wrap.open .i0{transform:translate(4px,-72px)}.wrap.open .i1{transform:translate(58px,-52px)}.wrap.open .i2{transform:translate(78px,2px)}.wrap.open .i3{transform:translate(58px,56px)}.wrap.open .i4{transform:translate(4px,76px)}.wrap.open .i5{transform:translate(-50px,56px)}.wrap.open .i6{transform:translate(-70px,2px)}.wrap.open .i7{transform:translate(-50px,-52px)}
        .item:hover,.core:hover{filter:brightness(1.25)}.tip{position:absolute;left:78px;top:16px;white-space:nowrap;background:#090909;color:#f6d77a;border:1px solid #6f5417;padding:7px 10px;border-radius:8px;font-size:12px;display:none}.wrap.open:hover .tip{display:block}
        .status{position:absolute;left:78px;top:50px;width:300px;background:#080808;color:#eee;border:1px solid #b88a20;border-radius:10px;padding:10px;font-size:12px;box-shadow:0 8px 24px #0009}
      </style>
      <div class='wrap'>
        <button class='core' title='RAH Raven Wheel'>R</button><span class='badge' data-state='CHECK'></span><span class='tip'>RAH Raven Global Wheel</span><div class='status' hidden></div>
      </div>`;
    shadow.appendChild(wrap);
    const holder = shadow.querySelector('.wrap');

    targets.forEach(([key, label, url], i) => {
      const b = document.createElement('button');
      b.className = `item i${i}`;
      b.textContent = key;
      b.title = label;
      b.addEventListener('click', (ev) => {
        ev.stopPropagation();
        if (url) openTab(url); else showStatus();
      });
      holder.appendChild(b);
    });

    const core = shadow.querySelector('.core');
    let drag = null;
    core.addEventListener('click', (ev) => {
      if (drag?.moved) return;
      expanded = !expanded;
      holder.classList.toggle('open', expanded);
      shadow.querySelector('.status').hidden = true;
    });
    core.addEventListener('pointerdown', (ev) => {
      drag = { x: ev.clientX, y: ev.clientY, left: root.getBoundingClientRect().left, top: root.getBoundingClientRect().top, moved: false };
      core.setPointerCapture(ev.pointerId);
    });
    core.addEventListener('pointermove', (ev) => {
      if (!drag) return;
      const dx = ev.clientX - drag.x, dy = ev.clientY - drag.y;
      if (Math.abs(dx) + Math.abs(dy) > 5) drag.moved = true;
      if (!drag.moved) return;
      const x = Math.max(0, Math.min(window.innerWidth - 64, drag.left + dx));
      const y = Math.max(0, Math.min(window.innerHeight - 64, drag.top + dy));
      root.style.left = `${x}px`; root.style.top = `${y}px`; root.style.bottom = 'auto';
    });
    core.addEventListener('pointerup', () => {
      if (drag?.moved) {
        const r = root.getBoundingClientRect();
        GM_setValue(POS_KEY, { x: Math.round(r.left), y: Math.round(r.top) });
      }
      setTimeout(() => { drag = null; }, 0);
    });

    healthCheck();
    setInterval(() => healthCheck(), 30000);
  }

  function setHidden(value) {
    hidden = value;
    GM_setValue(HOST_KEY, value);
    root?.remove(); root = null; shadow = null;
    if (!hidden) build();
  }

  GM_registerMenuCommand('RAH Raven: show/hide wheel on this site', () => setHidden(!hidden));
  GM_registerMenuCommand('RAH Raven: reset wheel position', () => { GM_setValue(POS_KEY, null); location.reload(); });
  build();
})();
