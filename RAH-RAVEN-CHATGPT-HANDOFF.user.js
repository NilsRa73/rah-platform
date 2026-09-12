// ==UserScript==
// @name         RAH Raven Handoff → ChatGPT
// @namespace    https://github.com/NilsRa73/rah-platform
// @version      1.0.0
// @description  Insert the latest local Raven Autopilot/Observer handoff into ChatGPT without auto-sending.
// @match        https://chatgpt.com/*
// @grant        GM_xmlhttpRequest
// @connect      127.0.0.1
// @connect      localhost
// @run-at       document-idle
// ==/UserScript==

(() => {
  'use strict';

  const LIVE = 'http://127.0.0.1:18767';
  const EXISTING_WIDGET = 'rah-raven-chatgpt-bridge';
  const BUTTON_ID = 'rah-raven-handoff-button';
  const FALLBACK_ID = 'rah-raven-handoff-fallback';

  function localGet(path) {
    return new Promise((resolve, reject) => {
      GM_xmlhttpRequest({
        method: 'GET',
        url: LIVE + path,
        timeout: 10000,
        headers: {'Cache-Control': 'no-store'},
        onload: response => {
          try {
            const data = JSON.parse(response.responseText || '{}');
            if (response.status < 200 || response.status >= 300 || data.ok === false) {
              reject(new Error(data.error || `Raven Live Wall HTTP ${response.status}`));
              return;
            }
            resolve(data);
          } catch {
            reject(new Error('Raven handoff returnerte ugyldig JSON.'));
          }
        },
        onerror: () => reject(new Error('Får ikke kontakt med Raven Live Wall på 127.0.0.1:18767.')),
        ontimeout: () => reject(new Error('Raven Live Wall svarte ikke innen tidsfristen.')),
      });
    });
  }

  function findComposer() {
    for (const selector of [
      '#prompt-textarea',
      'div[contenteditable="true"][data-lexical-editor="true"]',
      'div[contenteditable="true"][role="textbox"]',
      'textarea',
    ]) {
      const node = document.querySelector(selector);
      if (node && node.offsetParent !== null) return node;
    }
    return null;
  }

  function insertText(text) {
    const payload = String(text || '').trim();
    if (!payload) throw new Error('Raven handoff er tom.');
    const composer = findComposer();
    if (!composer) throw new Error('Fant ikke ChatGPT-meldingsfeltet.');
    composer.focus();

    if (composer instanceof HTMLTextAreaElement || composer instanceof HTMLInputElement) {
      const existing = String(composer.value || '').trim();
      const next = existing ? `${composer.value}\n\n${payload}` : payload;
      const proto = composer instanceof HTMLTextAreaElement ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype;
      const setter = Object.getOwnPropertyDescriptor(proto, 'value')?.set;
      if (setter) setter.call(composer, next); else composer.value = next;
      composer.dispatchEvent(new Event('input', {bubbles: true}));
      return;
    }

    if (composer.isContentEditable) {
      const selection = window.getSelection();
      const range = document.createRange();
      range.selectNodeContents(composer);
      range.collapse(false);
      selection?.removeAllRanges();
      selection?.addRange(range);
      const prefix = String(composer.innerText || '').trim() ? '\n\n' : '';
      const textToInsert = prefix + payload;
      let inserted = false;
      try { inserted = document.execCommand('insertText', false, textToInsert); } catch { inserted = false; }
      if (!inserted) {
        range.insertNode(document.createTextNode(textToInsert));
        range.collapse(false);
      }
      try {
        composer.dispatchEvent(new InputEvent('input', {bubbles: true, inputType: 'insertText', data: textToInsert}));
      } catch {
        composer.dispatchEvent(new Event('input', {bubbles: true}));
      }
      return;
    }
    throw new Error('ChatGPT-meldingsfeltet har et ukjent format.');
  }

  function setButtonState(button, text, kind = '') {
    button.textContent = text;
    button.dataset.state = kind;
  }

  async function insertHandoff(button) {
    if (button.dataset.busy === '1') return;
    button.dataset.busy = '1';
    button.disabled = true;
    const original = button.dataset.label || 'RAH HANDOFF';
    try {
      setButtonState(button, 'HENTER…');
      const data = await localGet('/handoff');
      const header = `RAH RAVEN LOCAL HANDOFF\nSource: ${data.source || 'local report'}\nAuto-send: OFF\n\n`;
      insertText(header + String(data.text || ''));
      setButtonState(button, 'KLAR · TRYKK SEND SELV', 'good');
      window.setTimeout(() => setButtonState(button, original, ''), 2400);
    } catch (error) {
      setButtonState(button, 'HANDOFF FEIL', 'bad');
      button.title = error.message;
      window.setTimeout(() => setButtonState(button, original, ''), 2800);
    } finally {
      button.dataset.busy = '0';
      button.disabled = false;
    }
  }

  function styleButton(button, compact = false) {
    button.type = 'button';
    button.dataset.label = 'RAH HANDOFF';
    button.textContent = 'RAH HANDOFF';
    button.title = 'Hent siste lokale Raven-diagnose inn i meldingsfeltet. Sender aldri automatisk. Alt+Shift+H.';
    Object.assign(button.style, {
      border: '1px solid #a57820',
      borderRadius: '9px',
      background: 'linear-gradient(135deg,#181106,#5f4312)',
      color: '#ffe39a',
      padding: compact ? '8px 10px' : '9px 12px',
      fontWeight: '800',
      fontSize: compact ? '10px' : '11px',
      letterSpacing: '.06em',
      cursor: 'pointer',
      boxShadow: '0 5px 20px rgba(0,0,0,.35)',
    });
    button.addEventListener('click', () => insertHandoff(button));
  }

  function installButton() {
    if (document.getElementById(BUTTON_ID) || document.getElementById(FALLBACK_ID)) return;
    const raven = document.getElementById(EXISTING_WIDGET);
    if (raven) {
      const button = document.createElement('button');
      button.id = BUTTON_ID;
      styleButton(button, true);
      button.style.margin = '6px';
      raven.appendChild(button);
      return;
    }

    const wrap = document.createElement('div');
    wrap.id = FALLBACK_ID;
    Object.assign(wrap.style, {
      position: 'fixed', right: '18px', bottom: '18px', zIndex: '2147483646',
      background: '#080b10', border: '1px solid #4c3b18', borderRadius: '12px', padding: '5px'
    });
    const button = document.createElement('button');
    button.id = BUTTON_ID;
    styleButton(button, false);
    wrap.appendChild(button);
    document.body.appendChild(wrap);
  }

  document.addEventListener('keydown', event => {
    if (event.altKey && event.shiftKey && event.code === 'KeyH') {
      event.preventDefault();
      installButton();
      const button = document.getElementById(BUTTON_ID);
      if (button) insertHandoff(button);
    }
  }, true);

  installButton();
  const observer = new MutationObserver(() => installButton());
  observer.observe(document.documentElement, {childList: true, subtree: true});
})();
