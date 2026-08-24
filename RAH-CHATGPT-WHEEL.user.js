// ==UserScript==
// @name         RAH ChatGPT Wheel
// @namespace    rah.ai.studios
// @version      1.0.0
// @description  Enkel RAH-snarvei inne i ChatGPT. Home Control åpnes via lokal Raven Bridge.
// @match        https://chatgpt.com/*
// @match        https://chat.openai.com/*
// @grant        GM_registerMenuCommand
// ==/UserScript==

(() => {
  'use strict';

  const HOME_CONTROL_URL = 'http://127.0.0.1:18765/home-control/ui';
  const ROOT_ID = 'rah-chatgpt-wheel-v1';

  function openHomeControl() {
    window.open(HOME_CONTROL_URL, '_blank', 'noopener,noreferrer');
  }

  function mount() {
    if (document.getElementById(ROOT_ID)) return;

    const root = document.createElement('div');
    root.id = ROOT_ID;
    root.innerHTML = `
      <button class="rah-main" type="button" aria-expanded="false" title="RAH Wheel">RAH</button>
      <div class="rah-menu" hidden>
        <button class="rah-item" type="button" data-rah-action="home">🏠 Home Control</button>
      </div>`;

    const style = document.createElement('style');
    style.textContent = `
      #${ROOT_ID}{position:fixed;right:18px;bottom:82px;z-index:2147483646;font-family:Segoe UI,Arial,sans-serif}
      #${ROOT_ID} .rah-main{width:58px;height:58px;border-radius:50%;border:1px solid #c79a32;background:radial-gradient(circle at 35% 30%,#3a2b09,#090909 60%);color:#ffe493;font-weight:900;box-shadow:0 8px 28px #0008;cursor:pointer}
      #${ROOT_ID} .rah-menu{position:absolute;right:0;bottom:68px;min-width:190px;padding:8px;border:1px solid #6e541c;border-radius:14px;background:#0b0b0bf2;box-shadow:0 12px 35px #000a}
      #${ROOT_ID} .rah-item{width:100%;border:1px solid #7c6020;border-radius:10px;background:#201805;color:#ffe493;padding:10px 12px;text-align:left;font-weight:700;cursor:pointer}
      #${ROOT_ID} .rah-item:hover{background:#2d2209}
    `;
    document.head.appendChild(style);
    document.body.appendChild(root);

    const main = root.querySelector('.rah-main');
    const menu = root.querySelector('.rah-menu');
    main.addEventListener('click', () => {
      const open = menu.hidden;
      menu.hidden = !open;
      main.setAttribute('aria-expanded', String(open));
    });
    root.querySelector('[data-rah-action="home"]').addEventListener('click', openHomeControl);
  }

  if (typeof GM_registerMenuCommand === 'function') {
    GM_registerMenuCommand('RAH: Åpne Home Control', openHomeControl);
  }

  mount();
  new MutationObserver(mount).observe(document.documentElement, {childList:true, subtree:true});
})();
