// ==UserScript==
// @name         RAH Raven Wheel v1.1
// @namespace    https://github.com/NilsRa73/rah-platform
// @version      1.1.0
// @description  Raven Wheel for ChatGPT: Command Center, Mission Control, System Doctor, Raven Vault and safe download registration.
// @author       RAH AI Studios
// @match        https://chatgpt.com/*
// @match        https://chat.openai.com/*
// @grant        GM_xmlhttpRequest
// @connect      127.0.0.1
// @connect      localhost
// @run-at       document-idle
// ==/UserScript==

(() => {
  'use strict';

  const BASE = 'http://127.0.0.1:18765';
  const ALLOWED_EXT = ['pdf','zip','docx','xlsx','pptx','txt','md','json','csv','html','htm','py','bat','ps1','png','jpg','jpeg','webp','gif'];
  const state = { open: false, status: null, recent: [] };

  function gm(method, path, data) {
    return new Promise((resolve, reject) => {
      GM_xmlhttpRequest({
        method,
        url: BASE + path,
        headers: data ? { 'Content-Type': 'application/json' } : undefined,
        data: data ? JSON.stringify(data) : undefined,
        timeout: 6000,
        onload: response => {
          let body = null;
          try { body = JSON.parse(response.responseText || '{}'); } catch { body = {}; }
          if (response.status < 200 || response.status >= 300 || body?.ok === false) {
            reject(new Error(body?.error || `HTTP ${response.status}`));
            return;
          }
          resolve(body);
        },
        ontimeout: () => reject(new Error('Raven Bridge svarte ikke.')),
        onerror: () => reject(new Error('Kunne ikke kontakte Raven Bridge.')),
      });
    });
  }

  function extFromName(name) {
    const lower = String(name || '').toLowerCase().trim();
    if (lower.endsWith('.user.js')) return 'user.js';
    const match = lower.match(/\.([a-z0-9]{1,8})(?:[?#].*)?$/);
    return match ? match[1] : '';
  }

  function extFromLabel(label) {
    const lower = String(label || '').toLowerCase();
    for (const ext of ['pdf','zip','docx','xlsx','pptx','png','jpg','jpeg','webp','txt','md','json','csv','html','py','bat','ps1']) {
      if (new RegExp(`\\b${ext}\\b`, 'i').test(lower)) return ext;
    }
    return '';
  }

  function cleanFilename(value) {
    let name = String(value || '').trim();
    try { name = decodeURIComponent(name); } catch {}
    name = name.split(/[?#]/)[0].split('/').pop() || '';
    return name.length <= 180 ? name : name.slice(-180);
  }

  function inferDownload(anchor) {
    if (!(anchor instanceof HTMLAnchorElement)) return null;
    const label = (anchor.textContent || '').trim().replace(/\s+/g, ' ').slice(0, 180);
    const href = anchor.getAttribute('href') || '';
    const downloadAttr = anchor.getAttribute('download') || '';
    const candidates = [downloadAttr, cleanFilename(href), label];
    let filename = '';
    let ext = '';
    for (const candidate of candidates) {
      const maybe = cleanFilename(candidate);
      const maybeExt = extFromName(maybe);
      if (ALLOWED_EXT.includes(maybeExt)) {
        filename = maybe;
        ext = maybeExt;
        break;
      }
    }
    if (!ext) ext = extFromLabel(label);
    const looksLikeDownload = Boolean(filename || ext) || /\b(last ned|download)\b/i.test(label);
    if (!looksLikeDownload) return null;
    return { filename, extension: ext, label };
  }

  async function registerExpectedDownload(info) {
    if (!info) return;
    const extension = info.extension ? '.' + info.extension.replace(/^\./, '') : '';
    if (!info.filename && !extension) return;
    try {
      await gm('POST', '/downloads/expect', {
        source: 'chatgpt',
        filename: info.filename || '',
        extension,
        label: info.label || '',
        ttl_seconds: 1200,
      });
      toast('Raven følger denne nedlastingen 🐦');
      setTimeout(refresh, 1800);
    } catch (error) {
      toast('Raven Bridge er ikke klar: ' + error.message, true);
    }
  }

  document.addEventListener('click', event => {
    const target = event.target instanceof Element ? event.target.closest('a') : null;
    if (!target) return;
    const info = inferDownload(target);
    if (info) registerExpectedDownload(info);
  }, true);

  const css = document.createElement('style');
  css.textContent = `
    #rah-raven-wheel-root{position:fixed;right:24px;bottom:24px;z-index:2147483646;font-family:Segoe UI,Arial,sans-serif;color:#fff}
    #rah-raven-wheel-button{width:58px;height:58px;border-radius:50%;border:1px solid #b98a25;background:radial-gradient(circle at 35% 30%,#ffe695,#b57a12 48%,#171006 74%);box-shadow:0 0 0 4px #080808,0 8px 30px #000b,0 0 28px #c9922355;color:#140d03;font-size:27px;cursor:pointer;font-weight:900}
    #rah-raven-wheel-panel{position:absolute;right:0;bottom:72px;width:310px;background:#0a0a09f5;border:1px solid #6d531c;border-radius:18px;padding:12px;box-shadow:0 18px 55px #000d;backdrop-filter:blur(14px);display:none}
    #rah-raven-wheel-root.rah-open #rah-raven-wheel-panel{display:block}
    .rah-title{display:flex;align-items:center;justify-content:space-between;gap:10px;padding:6px 6px 10px;color:#ffe493;font-weight:850;font-size:17px}
    .rah-status{font-size:12px;color:#aaa48e;padding:0 6px 8px}.rah-good{color:#76e5a5}.rah-bad{color:#ff9a9a}
    .rah-grid{display:grid;grid-template-columns:1fr 1fr;gap:8px}.rah-action{background:#17130a;border:1px solid #5d491a;color:#ffe498;border-radius:11px;padding:10px 9px;cursor:pointer;text-align:left;font-weight:700}.rah-action:hover{border-color:#c79831;background:#211907}.rah-action.rah-primary{background:linear-gradient(135deg,#f5d575,#a86e0d);color:#160f04;border:0}
    .rah-files{margin-top:10px;border-top:1px solid #39301c;padding-top:8px;max-height:230px;overflow:auto}.rah-file{display:block;width:100%;text-align:left;background:#0e0e0d;border:1px solid #2f2b20;color:#eee;border-radius:9px;padding:8px;margin:6px 0;cursor:pointer}.rah-file strong{display:block;color:#ffe294;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.rah-file small{display:block;color:#999;margin-top:2px}
    #rah-raven-toast{position:fixed;right:24px;bottom:100px;z-index:2147483647;max-width:340px;background:#111;border:1px solid #83651d;color:#ffe8a1;border-radius:12px;padding:10px 13px;box-shadow:0 12px 40px #000c;opacity:0;transform:translateY(8px);transition:.18s;pointer-events:none}#rah-raven-toast.show{opacity:1;transform:none}#rah-raven-toast.bad{border-color:#7a3333;color:#ffc1c1}
  `;
  document.documentElement.appendChild(css);

  const root = document.createElement('div');
  root.id = 'rah-raven-wheel-root';
  root.innerHTML = `
    <div id="rah-raven-wheel-panel">
      <div class="rah-title"><span>🐦‍⬛ RAVEN WHEEL</span><span id="rah-raven-wheel-version" style="font-size:11px;color:#9c8a58">v1.1.0</span></div>
      <div id="rah-raven-wheel-status" class="rah-status">Tester lokal Raven…</div>
      <div class="rah-grid">
        <button class="rah-action rah-primary" data-action="command">🏠 Command Center</button>
        <button class="rah-action rah-primary" data-action="mission">🎯 Mission Control</button>
        <button class="rah-action" data-action="doctor">🩺 System Doctor</button>
        <button class="rah-action" data-action="recent">🕘 Siste filer</button>
        <button class="rah-action" data-action="vault">📂 Raven Vault</button>
        <button class="rah-action" data-action="downloads">⬇ Filoversikt</button>
        <button class="rah-action" data-action="studio">🚀 AI Studio</button>
        <button class="rah-action" data-action="vision">👁 Vision</button>
      </div>
      <div id="rah-raven-wheel-files" class="rah-files"><small style="color:#8f8a7d">Ingen filer hentet ennå.</small></div>
    </div>
    <button id="rah-raven-wheel-button" title="RAH Raven Wheel">🐦</button>
  `;
  document.documentElement.appendChild(root);

  const toastBox = document.createElement('div');
  toastBox.id = 'rah-raven-toast';
  document.documentElement.appendChild(toastBox);

  function toast(message, bad = false) {
    toastBox.textContent = message;
    toastBox.className = bad ? 'show bad' : 'show';
    clearTimeout(toastBox._rahTimer);
    toastBox._rahTimer = setTimeout(() => { toastBox.className = ''; }, 2600);
  }

  function setStatus(text, ok) {
    const el = document.getElementById('rah-raven-wheel-status');
    el.textContent = text;
    el.className = 'rah-status ' + (ok ? 'rah-good' : 'rah-bad');
  }

  function renderFiles(items) {
    const box = document.getElementById('rah-raven-wheel-files');
    if (!items?.length) {
      box.innerHTML = '<small style="color:#8f8a7d">Ingen ChatGPT-filer i Raven Vault ennå.</small>';
      return;
    }
    box.innerHTML = items.slice(0, 8).map(item => `
      <button class="rah-file" data-file-id="${String(item.id || '').replace(/"/g, '&quot;')}">
        <strong>${escapeHtml(item.stored_name || item.original_name || 'Fil')}</strong>
        <small>${escapeHtml(item.project || 'Inbox')} · ${escapeHtml((item.captured_at || '').replace('T',' ').slice(0,16))}</small>
      </button>`).join('');
    box.querySelectorAll('[data-file-id]').forEach(button => {
      button.addEventListener('click', async () => {
        try {
          await gm('POST', '/downloads/open-file', { id: button.dataset.fileId, confirm: true });
        } catch (error) { toast(error.message, true); }
      });
    });
  }

  function escapeHtml(value) {
    return String(value ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  }

  async function refresh() {
    try {
      const [status, recent] = await Promise.all([
        gm('GET', '/downloads/status'),
        gm('GET', '/downloads/recent?limit=8'),
      ]);
      state.status = status;
      state.recent = recent.items || [];
      setStatus(`Bridge klar · Vault ${status.automatic ? 'AUTO' : 'PAUSET'} · ${status.pending_expectations} venter`, true);
      renderFiles(state.recent);
    } catch (error) {
      setStatus('Raven Bridge frakoblet · start START-RAH-RAVEN-V2.bat', false);
    }
  }

  function openLocal(path) {
    window.open(BASE + path, '_blank', 'noopener');
  }

  root.querySelector('#rah-raven-wheel-button').addEventListener('click', () => {
    state.open = !state.open;
    root.classList.toggle('rah-open', state.open);
    if (state.open) refresh();
  });

  root.querySelector('[data-action="recent"]').addEventListener('click', refresh);
  root.querySelector('[data-action="downloads"]').addEventListener('click', () => openLocal('/downloads/ui'));
  root.querySelector('[data-action="command"]').addEventListener('click', () => window.open('https://nilsra73.github.io/rah-platform/', '_blank', 'noopener'));
  root.querySelector('[data-action="mission"]').addEventListener('click', () => window.open('https://nilsra73.github.io/rah-platform/?view=missions', '_blank', 'noopener'));
  root.querySelector('[data-action="doctor"]').addEventListener('click', () => window.open('https://nilsra73.github.io/rah-platform/?view=settings&health=run', '_blank', 'noopener'));
  root.querySelector('[data-action="studio"]').addEventListener('click', () => window.open('https://nilsra73.github.io/rah-platform/RAH-RAVEN-START.html', '_blank', 'noopener'));
  root.querySelector('[data-action="vision"]').addEventListener('click', () => window.open('https://nilsra73.github.io/rah-platform/RAH-RAVEN-VISION-CORE.html', '_blank', 'noopener'));
  root.querySelector('[data-action="vault"]').addEventListener('click', async () => {
    try { await gm('POST', '/downloads/open-vault', { confirm: true }); }
    catch (error) { toast(error.message, true); }
  });

  refresh();
  setInterval(refresh, 30000);
})();
