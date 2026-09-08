// ==UserScript==
// @name         RAH Raven Vision → ChatGPT
// @namespace    https://github.com/NilsRa73/rah-platform
// @version      0.4.0
// @description  Raven Vision attachments, 5-second latest-frame buffer, and focused-tab Quick Check delivery without auto-send.
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
  const LIVE_KEY = 'rah.raven.chatgpt.live5s';
  const LIVE_INTERVAL_MS = 5000;
  const LIVE_MAX_AGE_MS = 15000;
  let monitors = [];
  let busy = false;
  let deliveryBusy = false;
  let liveCaptureBusy = false;
  let liveEnabled = localStorage.getItem(LIVE_KEY) !== '0';
  let liveMonitorIndex = 1;
  let latestLive = null;
  let liveAutoAttached = false;
  let autoAttachTimer = null;

  function requestJson(path, options = {}) {
    const method = String(options.method || 'GET').toUpperCase();
    const hasBody = options.body !== undefined && options.body !== null;
    return new Promise((resolve, reject) => {
      GM_xmlhttpRequest({
        method,
        url: BRIDGE + path,
        timeout: 15000,
        headers: {
          'Cache-Control': 'no-store',
          ...(hasBody ? {'Content-Type': 'application/json'} : {}),
        },
        data: hasBody ? JSON.stringify(options.body) : undefined,
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

  function composerText(composer) {
    if (!composer) return '';
    if ('value' in composer && typeof composer.value === 'string') return composer.value;
    return composer.textContent || '';
  }

  function insertComposerDraft(text) {
    const composer = findComposer();
    if (!composer) throw new Error('Fant ikke ChatGPT-meldingsfeltet.');
    if (composerText(composer).trim()) {
      throw new Error('ChatGPT-meldingsfeltet er ikke tomt. Raven lar utkastet stå i kø så teksten din ikke overskrives.');
    }
    const value = String(text || '').trim();
    if (!value) throw new Error('Quick Check-utkastet er tomt.');

    composer.focus();
    if (composer instanceof HTMLTextAreaElement) {
      const setter = Object.getOwnPropertyDescriptor(HTMLTextAreaElement.prototype, 'value')?.set;
      if (setter) setter.call(composer, value);
      else composer.value = value;
      composer.dispatchEvent(new InputEvent('input', {bubbles: true, inputType: 'insertText', data: value}));
      composer.dispatchEvent(new Event('change', {bubbles: true}));
    } else {
      let inserted = false;
      try {
        inserted = typeof document.execCommand === 'function' && document.execCommand('insertText', false, value) === true;
      } catch {
        inserted = false;
      }
      if (!inserted || !composerText(composer).trim()) {
        const paragraph = document.createElement('p');
        paragraph.textContent = value;
        composer.replaceChildren(paragraph);
        composer.dispatchEvent(new InputEvent('input', {bubbles: true, inputType: 'insertText', data: value}));
      }
    }

    if (!composerText(composer).trim()) throw new Error('ChatGPT godtok ikke Quick Check-utkastet.');
    return true;
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

  function updateLiveUi() {
    const box = document.getElementById(WIDGET_ID);
    const button = box?.querySelector('[data-role="live"]');
    const state = box?.querySelector('[data-role="live-state"]');
    if (button) {
      button.textContent = liveEnabled ? 'LIVE 5s ON' : 'LIVE 5s OFF';
      button.dataset.enabled = liveEnabled ? '1' : '0';
    }
    if (state) {
      const age = latestLive ? Math.max(0, Math.round((Date.now() - latestLive.capturedAt) / 1000)) : null;
      state.textContent = liveEnabled
        ? `M${liveMonitorIndex} · ${latestLive ? `siste bilde ${age}s siden` : 'venter på første bilde'} · kun minne`
        : 'Live-buffer er av';
    }
  }

  async function captureLiveFrame(force = false) {
    if (!liveEnabled || liveCaptureBusy) return latestLive;
    if (!force && document.visibilityState !== 'visible') return latestLive;
    liveCaptureBusy = true;
    try {
      const data = await requestJson(`/capture/monitor?index=${encodeURIComponent(liveMonitorIndex)}`);
      latestLive = {
        file: dataUrlToFile(data.image, `RAH-Raven-Live-M${liveMonitorIndex}-${Date.now()}.png`),
        capturedAt: Date.now(),
        monitorIndex: liveMonitorIndex,
      };
      updateLiveUi();
      return latestLive;
    } catch (error) {
      setStatus('LIVE: ' + error.message, 'bad');
      return latestLive;
    } finally {
      liveCaptureBusy = false;
    }
  }

  async function attachLatestLive() {
    let frame = latestLive;
    if (!frame || Date.now() - frame.capturedAt > LIVE_MAX_AGE_MS) frame = await captureLiveFrame(true);
    if (!frame?.file) throw new Error('Raven Live har ikke et ferskt skjermbilde ennå.');
    await attachFile(frame.file, `Raven Live M${frame.monitorIndex}`);
    return true;
  }

  async function maybeAutoAttachLive() {
    if (!liveEnabled || busy || liveAutoAttached) return;
    const composer = findComposer();
    const text = composerText(composer).trim();
    if (!text) {
      liveAutoAttached = false;
      return;
    }
    if (!/^se(?:\s|$)/i.test(text)) return;
    busy = true;
    try {
      await attachLatestLive();
      liveAutoAttached = true;
      setStatus('Raven Live: ferskeste 5s-bilde er lagt ved. Trykk Send når du er klar.', 'good');
    } catch (error) {
      setStatus('Raven Live: ' + error.message, 'bad');
    } finally {
      busy = false;
    }
  }

  async function pollQuickCheckDraft() {
    if (deliveryBusy || busy || document.visibilityState !== 'visible' || !document.hasFocus()) return;
    deliveryBusy = true;
    try {
      const data = await requestJson('/agent/chatgpt/pending');
      if (!data.pending) return;
      const item = data.item || {};
      if (item.kind !== 'quick-check' || item.auto_send !== false || !item.id || typeof item.text !== 'string') {
        throw new Error('Raven returnerte et ugyldig Quick Check-utkast.');
      }
      insertComposerDraft(item.text);
      await requestJson('/agent/chatgpt/ack', {method: 'POST', body: {id: item.id}});
      setStatus('Quick Check lagt inn i denne samtalen. Kontroller teksten og trykk Send.', 'good');
    } catch (error) {
      if (String(error.message || '').includes('ikke tomt')) {
        setStatus(error.message, 'warn');
      } else {
        setStatus('Quick Check levering: ' + error.message, 'bad');
      }
    } finally {
      deliveryBusy = false;
    }
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
    const value = document.querySelector(`#${WIDGET_ID} [data-role="source"]`)?.value || 'monitor:1';
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
      setStatus(`${label} lagt ved. Skriv/send meldingen.`, 'good');
      return true;
    }

    if (dispatchDrop(file)) {
      await new Promise(resolve => setTimeout(resolve, 450));
      setStatus(`${label} sendt til ChatGPT-komponisten. Kontroller vedlegget og send.`, 'good');
      return true;
    }

    input = await waitForFileInput(900);
    if (input) {
      assignFile(input, file);
      setStatus(`${label} lagt ved. Skriv/send meldingen.`, 'good');
      return true;
    }

    if (await clipboardFallback(file)) {
      setStatus(`Automatisk vedlegg feilet. ${label} ligger på utklippstavlen — Ctrl+V er reservevei.`, 'warn');
      return false;
    }

    throw new Error('Fant ikke ChatGPTs bildeopplasting. Oppdater Raven-userscriptet hvis ChatGPT-grensesnittet er endret.');
  }

  async function captureAndAttach(source = selectedSource()) {
    if (busy) return;
    busy = true;
    const button = document.querySelector(`#${WIDGET_ID} [data-role="capture"]`);
    if (button) button.disabled = true;
    try {
      const request = sourceRequest(source);
      setStatus(request.pending);
      const data = await requestJson(request.path);
      const file = dataUrlToFile(data.image, request.filename);
      await attachFile(file, request.label);
    } catch (error) {
      setStatus('FEIL: ' + error.message, 'bad');
    } finally {
      busy = false;
      if (button) button.disabled = false;
    }
  }

  function updateAreaVisibility() {
    const box = document.getElementById(WIDGET_ID);
    if (!box) return;
    const source = box.querySelector('[data-role="source"]')?.value || '';
    box.querySelector('[data-role="area-row"]').hidden = source !== 'area';
    if (source.startsWith('monitor:')) {
      liveMonitorIndex = Number(source.split(':')[1] || 1);
      latestLive = null;
      updateLiveUi();
      captureLiveFrame(true);
    }
  }

  async function refreshMonitors() {
    try {
      const data = await requestJson('/capture/monitors');
      monitors = data.monitors || [];
      const select = document.querySelector(`#${WIDGET_ID} [data-role="source"]`);
      if (!select) return;
      const previous = select.value;
      const options = [
        ...monitors.map(m => `<option value="monitor:${m.index}">Monitor ${m.index} · ${m.width}×${m.height}</option>`),
        '<option value="active">Aktivt vindu · 3 sek</option>',
        '<option value="area">Område · X/Y/W/H</option>',
      ];
      select.innerHTML = options.join('');
      if ([...select.options].some(o => o.value === previous)) {
        select.value = previous;
      } else if (monitors.some(m => Number(m.index) === 1)) {
        select.value = 'monitor:1';
      } else {
        select.value = 'active';
      }
      if (select.value.startsWith('monitor:')) liveMonitorIndex = Number(select.value.split(':')[1] || 1);
      updateAreaVisibility();
      setStatus(monitors.length
        ? `Raven klar · ${monitors.length} monitor(er) · LIVE ${liveEnabled ? 'ON' : 'OFF'}`
        : 'Raven klar · ingen monitorer oppdaget',
      monitors.length ? 'good' : 'warn');
      updateLiveUi();
      captureLiveFrame(true);
    } catch {
      setStatus('Raven Bridge er ikke startet.', 'bad');
    }
  }

  function buildWidget() {
    if (document.getElementById(WIDGET_ID)) return;
    const box = document.createElement('div');
    box.id = WIDGET_ID;
    box.innerHTML = `
      <div class="rah-title">🐦‍⬛ RAVEN VISION</div>
      <div class="rah-row">
        <select data-role="source" aria-label="Raven capture source">
          <option value="monitor:1">Monitor 1</option>
          <option value="monitor:2">Monitor 2</option>
          <option value="active">Aktivt vindu</option>
          <option value="area">Område</option>
        </select>
        <button type="button" data-role="capture">Legg ved</button>
      </div>
      <div class="rah-row rah-live-row">
        <button type="button" data-role="live">LIVE 5s ON</button>
        <span data-role="live-state">Starter live-buffer…</span>
      </div>
      <div class="rah-area" data-role="area-row" hidden>
        <input data-role="area-left" type="number" step="1" value="0" title="X / left" aria-label="Area X">
        <input data-role="area-top" type="number" step="1" value="0" title="Y / top" aria-label="Area Y">
        <input data-role="area-width" type="number" step="1" min="2" value="1280" title="Width" aria-label="Area width">
        <input data-role="area-height" type="number" step="1" min="2" value="720" title="Height" aria-label="Area height">
      </div>
      <div class="rah-status" data-role="status">Kobler til lokal Raven…</div>
      <div class="rah-hotkey">Skriv <b>se …</b> → ferskeste live-bilde legges ved · ingen auto-send</div>
    `;

    const style = document.createElement('style');
    style.textContent = `
      #${WIDGET_ID}{
        position:fixed;right:14px;bottom:88px;z-index:2147483646;
        width:310px;padding:10px;border:1px solid #6c541a;border-radius:14px;
        background:rgba(8,8,8,.96);box-shadow:0 12px 34px rgba(0,0,0,.45);
        color:#f5eedc;font:12px/1.35 "Segoe UI",Arial,sans-serif;
      }
      #${WIDGET_ID} .rah-title{font-weight:800;color:#ffe894;letter-spacing:.04em;margin-bottom:7px}
      #${WIDGET_ID} .rah-row{display:flex;gap:6px;align-items:center}
      #${WIDGET_ID} select,#${WIDGET_ID} button,#${WIDGET_ID} input{
        border:1px solid #5b4718;border-radius:9px;background:#151108;color:#ffe894;padding:7px;
      }
      #${WIDGET_ID} select{min-width:160px;flex:1}
      #${WIDGET_ID} button{cursor:pointer;font-weight:700}
      #${WIDGET_ID} button:hover{filter:brightness(1.16)}
      #${WIDGET_ID} button:disabled{opacity:.55;cursor:wait}
      #${WIDGET_ID} [data-role="live"][data-enabled="1"]{background:#19351f;border-color:#4f9f61;color:#aef4bd}
      #${WIDGET_ID} .rah-live-row{margin-top:6px}
      #${WIDGET_ID} [data-role="live-state"]{color:#8f8a7d;font-size:10px;flex:1}
      #${WIDGET_ID} .rah-area{display:grid;grid-template-columns:repeat(4,1fr);gap:5px;margin-top:6px}
      #${WIDGET_ID} .rah-area[hidden]{display:none}
      #${WIDGET_ID} .rah-area input{width:100%;min-width:0}
      #${WIDGET_ID} .rah-status{margin-top:7px;color:#aaa392;min-height:16px}
      #${WIDGET_ID} .rah-status[data-kind="good"]{color:#9cf0c2}
      #${WIDGET_ID} .rah-status[data-kind="warn"]{color:#ffe894}
      #${WIDGET_ID} .rah-status[data-kind="bad"]{color:#ffb1b1}
      #${WIDGET_ID} .rah-hotkey{margin-top:4px;color:#777164;font-size:10px}
    `;
    document.documentElement.appendChild(style);
    document.body.appendChild(box);

    box.querySelector('[data-role="source"]').addEventListener('change', updateAreaVisibility);
    box.querySelector('[data-role="capture"]').addEventListener('click', () => captureAndAttach());
    box.querySelector('[data-role="live"]').addEventListener('click', () => {
      liveEnabled = !liveEnabled;
      localStorage.setItem(LIVE_KEY, liveEnabled ? '1' : '0');
      if (!liveEnabled) latestLive = null;
      updateLiveUi();
      if (liveEnabled) captureLiveFrame(true);
    });
    refreshMonitors();
  }

  document.addEventListener('input', event => {
    const composer = findComposer();
    if (!composer || (event.target !== composer && !composer.contains(event.target))) return;
    if (!composerText(composer).trim()) liveAutoAttached = false;
    clearTimeout(autoAttachTimer);
    autoAttachTimer = setTimeout(maybeAutoAttachLive, 450);
  }, true);

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
    }
  }, true);

  const ensureWidget = () => {
    if (document.body) buildWidget();
  };
  ensureWidget();
  new MutationObserver(ensureWidget).observe(document.documentElement, {childList: true, subtree: true});
  setInterval(pollQuickCheckDraft, 1200);
  setInterval(() => captureLiveFrame(false), LIVE_INTERVAL_MS);
  setInterval(updateLiveUi, 1000);
  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'visible') {
      pollQuickCheckDraft();
      captureLiveFrame(true);
    }
  });
  window.addEventListener('focus', () => {
    pollQuickCheckDraft();
    captureLiveFrame(true);
  });
})();
