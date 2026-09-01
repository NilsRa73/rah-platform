// ==UserScript==
// @name         RAH Command Wheel - Home Control Addon
// @namespace    https://rah-ai.com/
// @version      1.0.0
// @description  Adds RAH Control Center to the existing RAH Raven Command Wheel without replacing it.
// @author       RAH AI Studios
// @match        https://chatgpt.com/*
// @match        https://chat.openai.com/*
// @run-at       document-idle
// @grant        none
// ==/UserScript==

(() => {
    "use strict";

    if (window.top !== window.self) return;

    const PROTOCOL = "rah-control-center://open";
    const BUTTON_ID = "rah-home-control-wheel-button";
    const STYLE_ID = "rah-home-control-wheel-style";

    function openControlCenter() {
        window.location.href = PROTOCOL;
    }

    function integrate() {
        const wheel = document.querySelector("#rah-wheel");
        if (!wheel) return;

        if (!document.getElementById(STYLE_ID)) {
            const style = document.createElement("style");
            style.id = STYLE_ID;
            style.textContent = `
                #rah-wheel.open .rah-wheel-item {
                    transform:
                        translate(-50%, -50%)
                        rotate(calc(var(--i) * 40deg))
                        translateY(-111px)
                        rotate(calc(var(--i) * -40deg))
                        scale(1) !important;
                }
            `;
            document.head.appendChild(style);
        }

        if (
            document.getElementById(BUTTON_ID)
            || wheel.querySelector('[data-command="home-control"]')
        ) return;

        const button = document.createElement("button");
        button.id = BUTTON_ID;
        button.className = "rah-wheel-item";
        button.style.setProperty("--i", "8");
        button.dataset.label = "RAH CONTROL CENTER";
        button.textContent = "🏠";
        button.title = "Open RAH Control Center";
        button.addEventListener("click", event => {
            event.preventDefault();
            event.stopPropagation();
            wheel.classList.remove("open");
            openControlCenter();
        });
        wheel.appendChild(button);
    }

    const observer = new MutationObserver(integrate);
    observer.observe(document.documentElement, { childList: true, subtree: true });
    integrate();

    document.addEventListener("keydown", event => {
        if (
            event.altKey
            && !event.ctrlKey
            && !event.metaKey
            && event.key.toLowerCase() === "h"
        ) {
            event.preventDefault();
            openControlCenter();
        }
    });
})();

