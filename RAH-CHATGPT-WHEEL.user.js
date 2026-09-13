// ==UserScript==
// @name         RAH Command Wheel for ChatGPT — LEGACY
// @namespace    rah.ai.studios
// @version      2.0.1
// @description  Legacy compatibility stub. The visible wheel is now RAH Raven Wheel MASTER (RAH-RAVEN-WHEEL.user.js).
// @match        https://chatgpt.com/*
// @match        https://chat.openai.com/*
// @grant        GM_registerMenuCommand
// ==/UserScript==

(() => {
  'use strict';
  const MASTER = 'https://raw.githubusercontent.com/NilsRa73/rah-platform/main/RAH-RAVEN-WHEEL.user.js';
  console.info('[RAH] Legacy ChatGPT Wheel is retired. Use RAH Raven Wheel MASTER.');
  if (typeof GM_registerMenuCommand === 'function') {
    GM_registerMenuCommand('RAH: Installer/oppdater Raven Wheel MASTER', () => window.open(MASTER, '_blank', 'noopener,noreferrer'));
  }
})();
