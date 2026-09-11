// ==UserScript==
// @name         RAH Raven Vision → ChatGPT
// @namespace    https://github.com/NilsRa73/rah-platform
// @version      0.3.0
// @description  Capture a Raven screen source, attach it to ChatGPT, and optionally insert a reusable task prompt without auto-sending.
// @match        https://chatgpt.com/*
// @grant        GM_xmlhttpRequest
// @connect      127.0.0.1
// @connect      localhost
// @run-at       document-idle
// ==/UserScript==

(() => {
  'use strict';

  const BRIDGE = 'http://127.0.0.1:18765';
  const WIDGET_ID = 'rah-raven-chatgpt-bridge';
  const PREF_KEY = 'rah-raven-chatgpt-v03';
  const DEFAULT_PROMPT = 'Les vedlagte skjermbilde. Finn feilen eller det viktigste som skjer, og fortell meg nøyaktig hva jeg skal gjøre videre. Bruk korte steg. Ikke gjett på uleselig tekst.';

  let monitors = [];
  let busy = false;
  let healthTimer = null;

  function requestJson(path) {
    return new Promise((resolve, reject) => {
      GM_xmlhttpRequest({
        method: 'GET',
        url: BRIDGE + path,
        timeout: 15000,
        headers: {'Cache-Control': 'no-store'},
        onload: response => {
          try {
            const data = JSON.parse(response.responseText || '{}');
            if (response.status < 200 || response.status >= 300 || data.ok === false) {
              reject(new Error(data.error || `Raven Bridge HTTP ${response.status}`));
              return;
            }
            resolve(data);
          } catch {
            reject(new Error('Raven Bridge returnerte ugyldig JSON.'));
          }
        },
        onerror: () => reject(new Error('Får ikke kontakt med Raven Bridge på 127.0.0.1:18765.')),
        ontimeout: () => reject(new Error('Raven Bridge svarte ikke innen tidsfristen.')),
      });
    });
  }

  function loadPrefs() {
    const fallback = {
      source: 'monitor:1',
      area: {left: 0, top: 0, width: 1280, height: 720},
      prompt: DEFAULT_PROMPT,
      collapsed: false,
    };
    try {
      const parsed = JSON.parse(localStorage.getItem(PREF_KEY) || '{}');
      return {
        ...fallback,
        ...parsed,
        area: {...fallback.area, ...(parsed.area || {})},
        prompt: String(parsed.prompt || fallback.prompt),
      };
    } catch {
      return fallback;
    }
  }

  function savePrefs(patch = {}) {
    const current = loadPrefs();
    localStorage.setItem(PREF_KEY, JSON.stringify({...current, ...patch}));
  }

  function dataUrlToFile(dataUrl, name) {
    const match = /^data:([^;]+);base64,(.+)$/.exec(dataUrl || '');
    if (!match) throw new Error('Raven returnerte ikke et gyldig bilde.');
    const mime = match[1];
    const binary = atob(match[2]);
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i += 1) bytes[i] = binary.charCodeAt(i);
    return new File([bytes], name, {type: mime, lastModified: Date.now()});
  }

  function findComposer() {
    const candidates = [
      '#prompt-textarea',
      'div[contenteditable="true"][data-lexical-editor="true"]',
      'div[contenteditable="true"][role="textbox"]',
      'textarea',
    ];
    for (const selector of candidates) {
      const node = document.querySelector(selector);
      if (node && node.offsetParent !== null) return node;
    }
    return null;
  }

  function findFileInput() {
    const inputs = [...document.querySelectorAll('input[type="file"]')];
    return inputs.find(input => !input.disabled && (input.accept || '').includes('image'))
      || inputs.find(input => !input.disabled)
      || null;
  }

  async function waitForFileInput(ms = 1400) {
    const first = findFileInput();
    if (first) return first;
    return new Promise(resolve => {
      const started = Date.now();
      const timer = setInterval(() => {
        const input = findFileInput();
        if (input || Date.now() - started >= ms) {
          clearInterval(timer);
          resolve(input || null);
        }
      }, 80);
    });
  }

  function assignFile(input, file) {
    const transfer = new DataTransfer();
    transfer.items.add(file);
    input.files = transfer.files;
    input.dispatchEvent(new Event('input', {bubbles: true}));
    input.dispatchEvent(new Event('change', {bubbles: true}));
  }

  function dispatchDrop(file) {
    const composer = findComposer();
    if (!composer) return false;
    try {
      const transfer = new DataTransfer();
      transfer.items.add(file);
      composer.dispatchEvent(new DragEvent('drop', {
        bubbles: true,
        cancelable: true,
        dataTransfer: transfer,
      }));
      return true;
    } catch {
      return false;
    }
  }

  async function clipboardFallback(file) {
    if (!navigator.clipboard || typeof ClipboardItem === 'undefined') return false;
    try {
      await navigator.clipboard.write([new ClipboardItem({[file.type || 'image/png']: file})]);
      return true;
    } catch {
      return false;
    }
  }

  function setStatus(text, kind = '') {
    const node = document.querySelector(`#${WIDGET_ID} [data-role="status"]`);
    if (!node) return;
    node.textContent = text;
    node.dataset.kind = kind;
  }

  function setHealth(text, kind = '') {
    const node = document.querySelector(`#${WIDGET_ID} [data-role="health"]`);
    if (!node) return;
    node.textContent = text;
    node.dataset.kind = kind;
  }

  function areaValues() {
    const box = document.getElementById(WIDGET_ID);
    const read = role => Number(box?.querySelector(`[data-role="${role}"]`)?.value || 0);
    const area = {
      left: read('area-left'),
      top: read('area-top'),
      width: read('area-width'),
      height: read('area-height'),
    };
    if (!Number.isInteger(area.left) || !Number.isInteger(area.top)
      || !Number.isInteger(area.width) || !Number.isInteger(area.height)
      || area.width < 2 || area.height < 2) {
      throw new Error('Område trenger heltall for X, Y, bredde og høyde (minst 2×2).');
    }
    return area;
  }

  function selectedSource() {
    const value = document.querySelector(`#${WIDGET_ID} [data-role="source"]`)?.value || loadPrefs().source;
    if (value === 'active') return {kind: 'active'};
    if (value === 'area') return {kind: 'area', area: areaValues()};
    if (value.startsWith('monitor:')) {
      return {kind: 'monitor', index: Number(value.split(':')[1] || 1)};
    }
    return {kind: 'monitor', index: 1};
  }

  function sourceRequest(source) {
    if (source.kind === 'active') {
      return {
        path: '/capture/after-delay?seconds=3',
        label: 'Aktivt vindu',
        filename: `RAH-Raven-Active-${Date.now()}.png`,
        pending: 'Bytt til ønsket vindu — Raven fanger om 3 sek…',
      };
    }
    if (source.kind === 'area') {
      const a = source.area;
      const query = new URLSearchParams({
        left: String(a.left),
        top: String(a.top),
        width: String(a.width),
        height: String(a.height),
      });
      return {
        path: `/capture/area?${query.toString()}`,
        label: `Område ${a.left},${a.top} ${a.width}×${a.height}`,
        filename: `RAH-Raven-Area-${Date.now()}.png`,
        pending: 'Fanger valgt område…',
      };
    }
    return {
      path: `/capture/monitor?index=${encodeURIComponent(source.index)}`,
      label: `Monitor ${source.index}`,
      filename: `RAH-Raven-M${source.index}-${Date.now()}.png`,
      pending: `Fanger M${source.index}…`,
    };
  }

  async function attachFile(file, label) {
    let input = await waitForFileInput(350);
    if (input) {
      assignFile(input, file);
      setStatus(`${label} lagt ved. Kontroller og send når du vil.`, 'good');
      return true;
    }

    if (dispatchDrop(file)) {
      await new Promise(resolve => setTimeout(resolve, 450));
      setStatus(`${label} sendt til ChatGPT-komponisten. Kontroller vedlegget.`, 'good');
      return true;
    }

    input = await waitForFileInput(900);
    if (input) {
      assignFile(input, file);
      setStatus(`${label} lagt ved. Kontroller og send når du vil.`, 'good');
      return true;
    }

    if (await clipboardFallback(file)) {
      setStatus(`Automatisk vedlegg feilet. ${label} ligger på utklippstavlen — Ctrl+V er reservevei.`, 'warn');
      return false;
    }

    throw new Error('Fant ikke ChatGPTs bildeopplasting. Oppdater Raven-userscriptet hvis ChatGPT-grensesnittet er endret.');
  }

  function insertPrompt(text) {
    const prompt = String(text || '').trim();
    if (!prompt) return false;
    const composer = findComposer();
    if (!composer) throw new Error('Fant ikke ChatGPT-meldingsfeltet.');
    composer.focus();

    if (composer instanceof HTMLTextAreaElement || composer instanceof HTMLInputElement) {
      const existing = String(composer.value || '').trim();
      const next = existing ? `${composer.value}\n\n${prompt}` : prompt;
      const proto = composer instanceof HTMLTextAreaElement ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype;
      const setter = Object.getOwnPropertyDescriptor(proto, 'value')?.set;
      if (setter) setter.call(composer, next);
      else composer.value = next;
      composer.dispatchEvent(new Event('input', {bubbles: true}));
      return true;
    }

    if (composer.isContentEditable) {
      const selection = window.getSelection();
      const range = document.createRange();
      range.selectNodeContents(composer);
      range.collapse(false);
      selection?.removeAllRanges();
      selection?.addRange(range);
      const prefix = String(composer.innerText || '').trim() ? '\n\n' : '';
      const payload = prefix + prompt;
      let inserted = false;
      try {
        inserted = document.execCommand('insertText', false, payload);
      } catch {
        inserted = false;
      }
      if (!inserted) {
        range.insertNode(document.createTextNode(payload));
        range.collapse(false);
      }
      try {
        composer.dispatchEvent(new InputEvent('input', {
          bubbles: true,
          inputType: 'insertText',
          data: payload,
        }));
      } catch {
        composer.dispatchEvent(new Event('input', {bubbles: true}));
      }
      return true;
    }

    throw new Error('ChatGPT-meldingsfeltet har et ukjent format.');
  }

  function currentPrompt() {
    const value = document.querySelector(`#${WIDGET_ID} [data-role="prompt"]`)?.value;
    return String(value || loadPrefs().prompt || DEFAULT_PROMPT).trim();
  }

  async function captureAndAttach(source = selectedSource(), withPrompt = false) {
    if (busy) return;
    busy = true;
    const buttons = [...document.querySelectorAll(`#${WIDGET_ID} button[data-busy]`)];
    buttons.forEach(button => { button.disabled = true; });
    try {
      const request = sourceRequest(source);
      setStatus(request.pending);
      const data = await requestJson(request.path);
      const file = dataUrlToFile(data.image, request.filename);
      await attachFile(file, request.label);
      if (withPrompt) {
        insertPrompt(currentPrompt());
        setStatus(`${request.label} + oppdrag er klart. Du bestemmer når meldingen sendes.`, 'good');
      }
    } catch (error) {
      setStatus('FEIL: ' + error.message, 'bad');
    } finally {
      busy = false;
      buttons.forEach(button => { button.disabled = false; });
    }
  }

  function persistUi() {
    const box = document.getElementById(WIDGET_ID);
    if (!box) return;
    const source = box.querySelector('[data-role="source"]')?.value || 'monitor:1';
    let area = loadPrefs().area;
    try { area = areaValues(); } catch {}
    const prompt = String(box.querySelector('[data-role="prompt"]')?.value || DEFAULT_PROMPT);
    savePrefs({source, area, prompt});
  }

  function updateAreaVisibility() {
    const box = document.getElementById(WIDGET_ID);
    if (!box) return;
    const source = box.querySelector('[data-role="source"]')?.value || '';
    box.querySelector('[data-role="area-row"]').hidden = source !== 'area';
    persistUi();
  }

  function applyCollapsed(collapsed) {
    const box = document.getElementById(WIDGET_ID);
    if (!box) return;
    box.dataset.collapsed = collapsed ? 'true' : 'false';
    const button = box.querySelector('[data-role="collapse"]');
    if (button) button.textContent = collapsed ? '+' : '−';
    savePrefs({collapsed});
  }

  async function refreshHealth() {
    try {
      const health = await requestJson('/health');
      const green = health.ok === true
        && health.council_proxy === true
        && health.vision_monitor_capture === true
        && health.local_device_adapter === true;
      setHealth(green ? '● BRIDGE GREEN' : '● BRIDGE DELVIS', green ? 'good' : 'warn');
    } catch {
      setHealth('● BRIDGE OFFLINE', 'bad');
    }
  }

  async function refreshMonitors() {
    try {
      const data = await requestJson('/capture/monitors');
      monitors = data.monitors || [];
      const select = document.querySelector(`#${WIDGET_ID} [data-role="source"]`);
      if (!select) return;
      const preferred = loadPrefs().source || select.value;
      const options = [
        ...monitors.map(m => `<option value="monitor:${m.index}">Monitor ${m.index} · ${m.width}×${m.height}</option>`),
        '<option value="active">Aktivt vindu · 3 sek</option>',
        '<option value="area">Område · X/Y/W/H</option>',
      ];
      select.innerHTML = options.join('');
      if ([...select.options].some(o => o.value === preferred)) {
        select.value = preferred;
      } else if (monitors.some(m => Number(m.index) === 1)) {
        select.value = 'monitor:1';
      } else {
        select.value = 'active';
      }
      updateAreaVisibility();
      setStatus(monitors.length
        ? `Raven klar · ${monitors.length} monitor(er) · Alt+Shift+R = bilde + oppdrag`
        : 'Raven klar · ingen monitorer oppdaget',
      monitors.length ? 'good' : 'warn');
      await refreshHealth();
    } catch {
      setStatus('Raven Bridge er ikke startet.', 'bad');
      setHealth('● BRIDGE OFFLINE', 'bad');
    }
  }

  function buildWidget() {
    if (document.getElementById(WIDGET_ID)) return;
    const prefs = loadPrefs();
    const box = document.createElement('div');
    box.id = WIDGET_ID;
    box.innerHTML = `
      <div class="rah-head">
        <div class="rah-title">🐦‍⬛ RAVEN VISION <span data-role="health">● KOBLER…</span></div>
        <button type="button" data-role="collapse" class="rah-mini" title="Minimer">−</button>
      </div>
      <div class="rah-body">
        <div class="rah-row">
          <select data-role="source" aria-label="Raven capture source">
            <option value="monitor:1">Monitor 1</option>
            <option value="monitor:2">Monitor 2</option>
            <option value="active">Aktivt vindu</option>
            <option value="area">Område</option>
          </select>
          <button type="button" data-role="capture" data-busy>Legg ved</button>
        </div>
        <div class="rah-area" data-role="area-row" hidden>
          <input data-role="area-left" type="number" step="1" value="${Number(prefs.area.left) || 0}" title="X / left" aria-label="Area X">
          <input data-role="area-top" type="number" step="1" value="${Number(prefs.area.top) || 0}" title="Y / top" aria-label="Area Y">
          <input data-role="area-width" type="number" step="1" min="2" value="${Number(prefs.area.width) || 1280}" title="Width" aria-label="Area width">
          <input data-role="area-height" type="number" step="1" min="2" value="${Number(prefs.area.height) || 720}" title="Height" aria-label="Area height">
        </div>
        <textarea data-role="prompt" aria-label="Raven task prompt">${String(prefs.prompt || DEFAULT_PROMPT).replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;')}</textarea>
        <div class="rah-row rah-actions">
          <button type="button" data-role="capture-prompt" data-busy class="rah-primary">Bilde + oppdrag</button>
          <button type="button" data-role="refresh">↻</button>
          <button type="button" data-role="open-vision">Vision</button>
        </div>
        <div class="rah-status" data-role="status">Kobler til lokal Raven…</div>
        <div class="rah-hotkey">Alt+Shift+1..9 = monitor · +A = aktiv · +O = område · +R = valgt kilde + oppdrag</div>
        <div class="rah-safe">Raven legger ved og skriver oppdraget, men trykker aldri Send.</div>
      </div>
    `;

    const style = document.createElement('style');
    style.textContent = `
      #${WIDGET_ID}{
        position:fixed;right:14px;bottom:88px;z-index:2147483646;
        width:330px;padding:10px;border:1px solid #6c541a;border-radius:14px;
        background:rgba(8,8,8,.97);box-shadow:0 12px 34px rgba(0,0,0,.45);
        color:#f5eedc;font:12px/1.35 "Segoe UI",Arial,sans-serif;
      }
      #${WIDGET_ID} .rah-head{display:flex;align-items:center;justify-content:space-between;gap:8px}
      #${WIDGET_ID} .rah-title{font-weight:800;color:#ffe894;letter-spacing:.04em;margin-bottom:7px}
      #${WIDGET_ID} [data-role="health"]{font-size:9px;color:#aaa392;margin-left:4px}
      #${WIDGET_ID} [data-role="health"][data-kind="good"]{color:#9cf0c2}
      #${WIDGET_ID} [data-role="health"][data-kind="warn"]{color:#ffe894}
      #${WIDGET_ID} [data-role="health"][data-kind="bad"]{color:#ffb1b1}
      #${WIDGET_ID} .rah-row{display:flex;gap:6px}
      #${WIDGET_ID} select,#${WIDGET_ID} button,#${WIDGET_ID} input,#${WIDGET_ID} textarea{
        border:1px solid #5b4718;border-radius:9px;background:#151108;color:#ffe894;padding:7px;
      }
      #${WIDGET_ID} select{min-width:160px;flex:1}
      #${WIDGET_ID} button{cursor:pointer;font-weight:700}
      #${WIDGET_ID} button:hover{filter:brightness(1.16)}
      #${WIDGET_ID} button:disabled{opacity:.55;cursor:wait}
      #${WIDGET_ID} .rah-mini{padding:1px 7px;min-width:26px}
      #${WIDGET_ID} .rah-area{display:grid;grid-template-columns:repeat(4,1fr);gap:5px;margin-top:6px}
      #${WIDGET_ID} .rah-area[hidden]{display:none}
      #${WIDGET_ID} .rah-area input{width:100%;min-width:0}
      #${WIDGET_ID} textarea{width:100%;height:72px;resize:vertical;margin-top:7px;color:#f5eedc}
      #${WIDGET_ID} .rah-actions{margin-top:6px}
      #${WIDGET_ID} .rah-primary{flex:1;background:linear-gradient(135deg,#ffe894,#b78319);color:#161006}
      #${WIDGET_ID} .rah-status{margin-top:7px;color:#aaa392;min-height:16px}
      #${WIDGET_ID} .rah-status[data-kind="good"]{color:#9cf0c2}
      #${WIDGET_ID} .rah-status[data-kind="warn"]{color:#ffe894}
      #${WIDGET_ID} .rah-status[data-kind="bad"]{color:#ffb1b1}
      #${WIDGET_ID} .rah-hotkey{margin-top:4px;color:#777164;font-size:10px}
      #${WIDGET_ID} .rah-safe{margin-top:5px;color:#9f987f;font-size:10px;border-top:1px solid #322815;padding-top:5px}
      #${WIDGET_ID}[data-collapsed="true"]{width:auto;min-width:210px}
      #${WIDGET_ID}[data-collapsed="true"] .rah-body{display:none}
    `;
    document.documentElement.appendChild(style);
    document.body.appendChild(box);

    box.querySelector('[data-role="source"]').addEventListener('change', updateAreaVisibility);
    box.querySelector('[data-role="capture"]').addEventListener('click', () => captureAndAttach());
    box.querySelector('[data-role="capture-prompt"]').addEventListener('click', () => captureAndAttach(selectedSource(), true));
    box.querySelector('[data-role="refresh"]').addEventListener('click', refreshMonitors);
    box.querySelector('[data-role="open-vision"]').addEventListener('click', () => window.open(`${BRIDGE}/vision/ui`, '_blank', 'noopener'));
    box.querySelector('[data-role="collapse"]').addEventListener('click', () => applyCollapsed(box.dataset.collapsed !== 'true'));
    box.querySelector('[data-role="prompt"]').addEventListener('input', persistUi);
    box.querySelectorAll('.rah-area input').forEach(input => input.addEventListener('change', persistUi));

    applyCollapsed(Boolean(prefs.collapsed));
    refreshMonitors();
    if (healthTimer) clearInterval(healthTimer);
    healthTimer = setInterval(refreshHealth, 30000);
  }

  document.addEventListener('keydown', event => {
    if (!event.altKey || !event.shiftKey || event.ctrlKey || event.metaKey) return;

    if (/^[1-9]$/.test(event.key)) {
      const index = Number(event.key);
      if (monitors.length && !monitors.some(m => Number(m.index) === index)) return;
      event.preventDefault();
      captureAndAttach({kind: 'monitor', index});
      return;
    }

    const key = event.key.toLowerCase();
    if (key === 'a') {
      event.preventDefault();
      captureAndAttach({kind: 'active'});
      return;
    }
    if (key === 'o') {
      event.preventDefault();
      try {
        captureAndAttach({kind: 'area', area: areaValues()});
      } catch (error) {
        setStatus('FEIL: ' + error.message, 'bad');
      }
      return;
    }
    if (key === 'r') {
      event.preventDefault();
      try {
        captureAndAttach(selectedSource(), true);
      } catch (error) {
        setStatus('FEIL: ' + error.message, 'bad');
      }
    }
  }, true);

  const ensureWidget = () => {
    if (document.body) buildWidget();
  };
  ensureWidget();
  new MutationObserver(ensureWidget).observe(document.documentElement, {childList: true, subtree: true});
})();
