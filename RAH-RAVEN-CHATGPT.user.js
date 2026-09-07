// ==UserScript==
// @name         RAH Raven Vision → ChatGPT
// @namespace    https://github.com/NilsRa73/rah-platform
// @version      0.1.0
// @description  Capture a chosen local monitor through Raven Bridge and attach it to the current ChatGPT composer.
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
  let monitors = [];
  let busy = false;

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
      const event = new DragEvent('drop', {
        bubbles: true,
        cancelable: true,
        dataTransfer: transfer,
      });
      composer.dispatchEvent(event);
      return true;
    } catch {
      return false;
    }
  }

  async function clipboardFallback(file) {
    if (!navigator.clipboard || typeof ClipboardItem === 'undefined') return false;
    try {
      await navigator.clipboard.write([
        new ClipboardItem({[file.type || 'image/png']: file}),
      ]);
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

  async function attachMonitor(index) {
    if (busy) return;
    busy = true;
    const button = document.querySelector(`#${WIDGET_ID} [data-role="capture"]`);
    if (button) button.disabled = true;
    try {
      setStatus(`Fanger M${index}…`);
      const data = await requestJson(`/capture/monitor?index=${encodeURIComponent(index)}`);
      const file = dataUrlToFile(data.image, `RAH-Raven-M${index}-${Date.now()}.png`);

      let input = await waitForFileInput(350);
      if (input) {
        assignFile(input, file);
        setStatus(`M${index} lagt ved. Skriv/send meldingen.`, 'good');
        return;
      }

      const dropped = dispatchDrop(file);
      if (dropped) {
        await new Promise(resolve => setTimeout(resolve, 450));
        setStatus(`M${index} sendt til ChatGPT-komponisten. Kontroller vedlegget og send.`, 'good');
        return;
      }

      input = await waitForFileInput(900);
      if (input) {
        assignFile(input, file);
        setStatus(`M${index} lagt ved. Skriv/send meldingen.`, 'good');
        return;
      }

      const copied = await clipboardFallback(file);
      if (copied) {
        setStatus(`Automatisk vedlegg feilet. M${index} ligger på utklippstavlen — Ctrl+V er reservevei.`, 'warn');
        return;
      }

      throw new Error('Fant ikke ChatGPTs bildeopplasting. Oppdater userscriptet hvis ChatGPT-grensesnittet er endret.');
    } catch (error) {
      setStatus('FEIL: ' + error.message, 'bad');
    } finally {
      busy = false;
      if (button) button.disabled = false;
    }
  }

  async function refreshMonitors() {
    try {
      const data = await requestJson('/capture/monitors');
      monitors = data.monitors || [];
      const select = document.querySelector(`#${WIDGET_ID} [data-role="monitor"]`);
      if (!select) return;
      const previous = select.value;
      select.innerHTML = monitors.length
        ? monitors.map(m => `<option value="${m.index}">M${m.index} · ${m.width}×${m.height}</option>`).join('')
        : '<option value="1">M1</option>';
      if ([...select.options].some(o => o.value === previous)) select.value = previous;
      setStatus(monitors.length ? `Raven klar · ${monitors.length} monitor(er)` : 'Ingen monitorer oppdaget', monitors.length ? 'good' : 'warn');
    } catch (error) {
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
        <select data-role="monitor" aria-label="Raven monitor"><option value="1">M1</option></select>
        <button type="button" data-role="capture">Legg ved skjerm</button>
      </div>
      <div class="rah-status" data-role="status">Kobler til lokal Raven…</div>
      <div class="rah-hotkey">Alt+Shift+1…9</div>
    `;
    const style = document.createElement('style');
    style.textContent = `
      #${WIDGET_ID}{
        position:fixed;right:14px;bottom:88px;z-index:2147483646;
        width:220px;padding:10px;border:1px solid #6c541a;border-radius:14px;
        background:rgba(8,8,8,.96);box-shadow:0 12px 34px rgba(0,0,0,.45);
        color:#f5eedc;font:12px/1.35 "Segoe UI",Arial,sans-serif;
      }
      #${WIDGET_ID} .rah-title{font-weight:800;color:#ffe894;letter-spacing:.04em;margin-bottom:7px}
      #${WIDGET_ID} .rah-row{display:flex;gap:6px}
      #${WIDGET_ID} select,#${WIDGET_ID} button{
        border:1px solid #5b4718;border-radius:9px;background:#151108;color:#ffe894;padding:7px;
      }
      #${WIDGET_ID} select{width:78px}
      #${WIDGET_ID} button{flex:1;cursor:pointer;font-weight:700}
      #${WIDGET_ID} button:hover{filter:brightness(1.16)}
      #${WIDGET_ID} button:disabled{opacity:.55;cursor:wait}
      #${WIDGET_ID} .rah-status{margin-top:7px;color:#aaa392;min-height:16px}
      #${WIDGET_ID} .rah-status[data-kind="good"]{color:#9cf0c2}
      #${WIDGET_ID} .rah-status[data-kind="warn"]{color:#ffe894}
      #${WIDGET_ID} .rah-status[data-kind="bad"]{color:#ffb1b1}
      #${WIDGET_ID} .rah-hotkey{margin-top:4px;color:#6f6a5e;font-size:10px}
    `;
    document.documentElement.appendChild(style);
    document.body.appendChild(box);

    box.querySelector('[data-role="capture"]').addEventListener('click', () => {
      const index = Number(box.querySelector('[data-role="monitor"]').value || 1);
      attachMonitor(index);
    });
    refreshMonitors();
  }

  document.addEventListener('keydown', event => {
    if (!event.altKey || !event.shiftKey || event.ctrlKey || event.metaKey) return;
    if (!/^[1-9]$/.test(event.key)) return;
    const index = Number(event.key);
    if (monitors.length && !monitors.some(m => Number(m.index) === index)) return;
    event.preventDefault();
    attachMonitor(index);
  }, true);

  const ensureWidget = () => {
    if (document.body) buildWidget();
  };
  ensureWidget();
  new MutationObserver(ensureWidget).observe(document.documentElement, {childList: true, subtree: true});
})();
