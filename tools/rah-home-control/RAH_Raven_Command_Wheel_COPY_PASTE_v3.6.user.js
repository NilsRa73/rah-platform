// ==UserScript==
// @name         RAH Raven Command Wheel v3.6 — RAH Control Edition
// @namespace    https://rah-ai.com/
// @version      3.7.2
// @description  Universal Firefox/Chromium black-gold RAH command wheel with Home Control, shared commands and multi-monitor shortcuts.
// @author       RAH AI Studios
// @match        http://*/*
// @match        https://*/*
// @updateURL    https://raw.githubusercontent.com/NilsRa73/rah-platform/codex/rah-home-control-powershell/tools/rah-home-control/RAH_Raven_Command_Wheel_COPY_PASTE_v3.6.user.js
// @downloadURL  https://raw.githubusercontent.com/NilsRa73/rah-platform/codex/rah-home-control-powershell/tools/rah-home-control/RAH_Raven_Command_Wheel_COPY_PASTE_v3.6.user.js
// @run-at       document-idle
// @grant        GM_getValue
// @grant        GM_setValue
// @grant        GM_deleteValue
// @grant        GM_addValueChangeListener
// @grant        GM_removeValueChangeListener
// ==/UserScript==

(() => {
    "use strict";

    if (window.top !== window.self) return;

    const STYLE_ID = "rah-raven-v36-style";
    const UI_ID = "rah-raven-v36-ui";
    const SKY_ID = "rah-raven-v36-sky";
    const HOST_ID = "rah-command-wheel-host";
    const CURRENT_VERSION = "3.7.2";
    const STORE_KEY = "rah-raven-v36-settings";
    const RAH_CC = "https://nilsra73.github.io/rah-platform/";
    const RAH_REPO = "https://github.com/NilsRa73/rah-platform";
    const PENDING_ACTION_KEY = "rah-raven-pending-action-v1";
    const IS_CHATGPT = ["chatgpt.com", "chat.openai.com"]
        .includes(location.hostname.toLowerCase());

    const rahShortcuts = [
        {
            key: "1",
            id: "cc",
            icon: "⌂",
            label: "RAH COMMAND CENTER",
            url: RAH_CC,
            target: "rah-command-center"
        },
        {
            key: "2",
            id: "missions",
            icon: "🎯",
            label: "MISSION CONTROL",
            url: `${RAH_CC}?rah=missions`,
            target: "rah-mission-control"
        },
        {
            key: "3",
            id: "projects",
            icon: "📂",
            label: "RAH PROJECTS",
            url: `${RAH_CC}?rah=projects`,
            target: "rah-projects"
        },
        {
            key: "4",
            id: "vision",
            icon: "👁",
            label: "RAVEN VISION",
            url: `${RAH_CC}vision.html`,
            target: "rah-vision"
        },
        {
            key: "5",
            id: "brain",
            icon: "🧠",
            label: "PROJECT BRAIN",
            url: `${RAH_CC}?rah=brain`,
            target: "rah-project-brain"
        },
        {
            key: "6",
            id: "brief",
            icon: "📋",
            label: "RAVEN BRIEF",
            url: `${RAH_CC}?rah=brief`,
            target: "rah-raven-brief"
        },
        {
            key: "7",
            id: "github",
            icon: "🐙",
            label: "GITHUB REPOSITORY",
            url: RAH_REPO,
            target: "rah-github"
        },
        {
            key: "8",
            id: "actions",
            icon: "⚙",
            label: "GITHUB ACTIONS",
            url: `${RAH_REPO}/actions`,
            target: "rah-github-actions"
        },
        {
            key: "9",
            id: "chatgpt",
            icon: "✦",
            label: "NEW CHATGPT",
            url: "https://chatgpt.com/",
            target: "rah-chatgpt"
        },
        {
            key: "H",
            id: "home-control",
            icon: "🏠",
            label: "RAH CONTROL CENTER",
            url: "rah-control-center://open",
            target: "rah-control-center",
            protocol: true
        },
        {
            key: "U",
            id: "home-update",
            icon: "↻",
            label: "UPDATE HOME CONTROL",
            url: "rah-control-center://update-home-control",
            target: "rah-home-update",
            protocol: true
        },
        {
            key: "W",
            id: "firefox-wheel",
            icon: "🦊",
            label: "REPAIR FIREFOX WHEEL",
            url: "rah-control-center://firefox-wheel",
            target: "rah-firefox-wheel",
            protocol: true
        },
        {
            key: "D",
            id: "system-doctor",
            icon: "✚",
            label: "SYSTEM DOCTOR",
            url: "rah-control-center://doctor",
            target: "rah-system-doctor",
            protocol: true
        }
    ];

    const rahHomeActions = [
        { icon: "⚡", label: "MASTER POWER", protocol: "start-all" },
        { icon: "⌂", label: "CONTROL CENTER", protocol: "open" },
        { icon: "◉", label: "START NODE SERVER", protocol: "node-server" },
        { icon: "＋", label: "REGISTER THIS NODE", protocol: "register-node" },
        { icon: "⇅", label: "START SPEED SERVER", protocol: "speed-server" },
        { icon: "↯", label: "RUN SPEED TEST", protocol: "speed-test" },
        { icon: "▦", label: "ROOM CONTROL", protocol: "room-control" },
        { icon: "▤", label: "NODE DASHBOARD", protocol: "node-dashboard" },
        { icon: "≋", label: "SPEED RESULTS", protocol: "speed-results" },
        { icon: "↗", label: "REMOTE SETUP", protocol: "remote-setup" },
        { icon: "✚", label: "SYSTEM DOCTOR", protocol: "doctor" },
        { icon: "🦊", label: "FIREFOX REPAIR", protocol: "firefox-wheel" },
        {
            icon: "↻",
            label: "UPDATE HOME CONTROL",
            protocol: "update-home-control",
            wide: true
        }
    ];

    function connectRahBackgroundTab(signal) {
        const host = location.hostname.toLowerCase();

        if (host === "github.com") {
            window.name = location.pathname.includes("/actions")
                ? "rah-github-actions"
                : "rah-github";
            return true;
        }

        if (host !== "nilsra73.github.io") return false;

        if (location.pathname.endsWith("/vision.html")) {
            window.name = "rah-vision";
            return true;
        }

        const targetNames = {
            home: "rah-command-center",
            projects: "rah-projects",
            missions: "rah-mission-control",
            brain: "rah-project-brain",
            brief: "rah-raven-brief"
        };
        const requested = new URLSearchParams(location.search).get("rah");
        const requestedView = Object.prototype.hasOwnProperty.call(
            targetNames,
            requested
        ) ? requested : null;
        let attempts = 0;

        const connect = () => {
            if (requestedView) {
                document.querySelector(
                    `nav button[data-view="${requestedView}"]`
                )?.click();
            }

            const activeView = document.querySelector(".view.active")?.id
                || requestedView
                || "home";
            window.name = targetNames[activeView] || `rah-${activeView}`;

            if (!document.querySelector(".view.active") && attempts < 30) {
                attempts += 1;
                setTimeout(connect, 150);
            }
        };

        connect();
        document.addEventListener(
            "click",
            () => setTimeout(connect, 0),
            { capture: true, signal }
        );
        return true;
    }

    const defaults = {
        master: true,
        theme: true,
        ravens: true,
        focus: false,
        lightgun: false,
        voice: false,
        contextMenu: false,
        ravenFrequency: 4,
        ravenScale: 1,
        wheelScale: 1,
        glow: "normal",
        voiceLanguage: "auto",
        wheelX: null,
        wheelY: null,
        projects: [
            "RAH AI Studios",
            "Raven Command Center",
            "Raven Browser",
            "Light Gun Arcade",
            "RAH Gammon",
            "RAH OS"
        ]
    };

    let settings = { ...defaults };

    try {
        const saved =
            localStorage.getItem(STORE_KEY)
            || localStorage.getItem("rah-raven-v35-settings")
            || localStorage.getItem("rah-raven-v34-settings")
            || localStorage.getItem("rah-raven-v33-settings")
            || "{}";

        settings = {
            ...defaults,
            ...JSON.parse(saved)
        };
        settings.voice = false;
    } catch {}

    function compareVersions(left, right) {
        const a = String(left || "0").split(".").map(Number);
        const b = String(right || "0").split(".").map(Number);
        const count = Math.max(a.length, b.length);

        for (let index = 0; index < count; index += 1) {
            const difference = (a[index] || 0) - (b[index] || 0);
            if (difference) return difference;
        }
        return 0;
    }

    function claimRahWheelHost() {
        const existing = document.getElementById(HOST_ID);
        if (existing) {
            const existingVersion = existing.dataset.rahWheelVersion || "0";
            if (compareVersions(existingVersion, CURRENT_VERSION) >= 0) {
                return null;
            }
            existing.dispatchEvent(new CustomEvent("rah-wheel-shutdown"));
            existing.remove();
        }

        const marker = document.createElement("meta");
        marker.id = HOST_ID;
        marker.dataset.rahWheelVersion = CURRENT_VERSION;
        marker.dataset.rahWheelIdentity =
            "RAH Raven Command Wheel v3.6 — RAH Control Edition";
        (document.head || document.documentElement).appendChild(marker);
        return marker;
    }

    function start() {
        const hostMarker = claimRahWheelHost();
        if (!hostMarker) return;
        const lifetime = new AbortController();
        connectRahBackgroundTab(lifetime.signal);
        if (IS_CHATGPT) window.name = "rah-chatgpt";

        [
            "rah-raven-v31-style",
            "rah-raven-v32-style",
            "rah-raven-v31-ui",
            "rah-raven-v32-ui",
            "rah-raven-v31-sky",
            "rah-raven-v32-sky",
            "rah-raven-v33-style",
            "rah-raven-v33-ui",
            "rah-raven-v33-sky",
            "rah-raven-v34-style",
            "rah-raven-v34-ui",
            "rah-raven-v34-sky",
            "rah-raven-v35-style",
            "rah-raven-v35-ui",
            "rah-raven-v35-sky"
        ].forEach(id => document.getElementById(id)?.remove());

        document.getElementById(STYLE_ID)?.remove();
        document.getElementById(UI_ID)?.remove();
        document.getElementById(SKY_ID)?.remove();

        const style = document.createElement("style");
        style.id = STYLE_ID;
        style.textContent = `
            :root {
                --rah-black: #050505;
                --rah-panel: rgba(8, 7, 5, .94);
                --rah-gold: #d4af37;
                --rah-light-gold: #ffe08a;
                --rah-border: rgba(212, 175, 55, .42);
            }

            html.rah-theme {
                color-scheme: dark;
                --main-surface-primary: #060606 !important;
                --main-surface-secondary: #0d0b07 !important;
                --main-surface-tertiary: #151108 !important;
                --sidebar-surface-primary: #070706 !important;
                --sidebar-surface-secondary: #100d07 !important;
                --message-surface: #171208 !important;
                --text-primary: #f7efd7 !important;
                --text-secondary: #bdaf86 !important;
                --border-light: rgba(212,175,55,.22) !important;
                --border-medium: rgba(212,175,55,.42) !important;
            }

            html.rah-theme body {
                color: #f7efd7 !important;
                background-color: #030303 !important;
                background-image:
                    radial-gradient(circle at 50% 42%,
                        rgba(120,87,16,.13), transparent 43%),
                    linear-gradient(rgba(0,0,0,.7), rgba(0,0,0,.84)),
                    url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 1600 900'%3E%3Cg fill='none' stroke='%23d4af37' stroke-width='9' opacity='.18' stroke-linecap='round'%3E%3Cpath d='M800 810V390M800 440C710 360 635 310 520 285M800 500C900 420 985 350 1100 320M800 575C690 500 610 455 470 445M800 620C920 540 1015 500 1150 470M800 390C745 320 735 245 760 150M800 390C850 315 865 235 842 145M800 765C710 790 650 825 600 875M800 765C895 790 955 830 1010 875M760 150C690 175 625 170 560 130M842 145C920 170 985 160 1050 115M520 285C455 265 400 225 350 165M1100 320C1170 285 1215 240 1250 175M470 445C390 430 330 390 280 335M1150 470C1230 450 1290 405 1340 350'/%3E%3Ccircle cx='800' cy='390' r='58'/%3E%3C/g%3E%3C/svg%3E") !important;
                background-size: auto, auto, cover !important;
                background-position: center !important;
                background-attachment: fixed !important;
            }

            html.rah-theme body > div:first-child {
                background: transparent !important;
            }

            html.rah-theme main {
                background: rgba(4,4,4,.66) !important;
                backdrop-filter: blur(2px);
            }

            html.rah-theme nav,
            html.rah-theme aside {
                background: rgba(5,5,5,.94) !important;
                border-color: rgba(212,175,55,.22) !important;
            }

            html.rah-theme [class*="bg-token-main-surface"] {
                background-color: rgba(6,6,6,.76) !important;
            }

            html.rah-theme [class*="bg-token-sidebar-surface"] {
                background-color: rgba(7,7,6,.92) !important;
            }

            html.rah-theme [class*="bg-token-message-surface"] {
                background: linear-gradient(145deg,
                    rgba(28,22,8,.94), rgba(7,7,6,.94)) !important;
                border: 1px solid rgba(212,175,55,.25) !important;
            }

            html.rah-theme #prompt-textarea {
                color: #fff1bd !important;
                caret-color: #ffd866 !important;
            }

            html.rah-theme form:has(#prompt-textarea) {
                background: rgba(6,6,6,.91) !important;
                border-color: rgba(212,175,55,.55) !important;
                box-shadow:
                    0 0 16px rgba(212,175,55,.28),
                    inset 0 0 12px rgba(212,175,55,.06) !important;
            }

            html.rah-theme a {
                color: var(--rah-gold) !important;
            }

            html.rah-theme ::selection {
                color: #050505;
                background: var(--rah-gold);
            }

            html.rah-focus aside,
            html.rah-focus nav[aria-label] {
                display: none !important;
            }

            html.rah-focus main {
                width: 100% !important;
                max-width: none !important;
            }

            html.rah-lightgun,
            html.rah-lightgun * {
                cursor: crosshair !important;
            }

            html.rah-lightgun button,
            html.rah-lightgun [role="button"] {
                outline: 1px solid rgba(212,175,55,.4);
                outline-offset: 2px;
            }

            html.rah-master-off body {
                background-image: none !important;
            }

            html.rah-master-off #rah-brand,
            html.rah-master-off #rah-status,
            html.rah-master-off #rah-wheel,
            html.rah-master-off #rah-home-panel,
            html.rah-master-off #rah-project-panel,
            html.rah-master-off #rah-shortcut-panel,
            html.rah-master-off #rah-context-menu,
            html.rah-master-off #rah-control-panel,
            html.rah-master-off .rah-mini-button:not([data-setting="master"]) {
                display: none !important;
            }

            #${UI_ID} {
                position: fixed;
                inset: 0;
                z-index: 2147483645;
                pointer-events: none;
                font-family: Arial, sans-serif;
            }

            #rah-brand {
                position: absolute;
                top: 18px;
                right: 18px;
                display: flex;
                align-items: center;
                gap: 10px;
                padding: 8px 13px;
                color: var(--rah-light-gold);
                background: var(--rah-panel);
                border: 1px solid var(--rah-gold);
                border-radius: 9px;
                box-shadow: 0 0 16px rgba(212,175,55,.32);
                pointer-events: auto;
                font: 900 12px Georgia, serif;
                letter-spacing: 1.4px;
            }

            #rah-brand span {
                display: grid;
                place-items: center;
                width: 27px;
                height: 27px;
                border: 1px solid var(--rah-gold);
                border-radius: 50%;
                font-size: 17px;
            }

            #rah-status {
                position: absolute;
                left: 50%;
                top: 18px;
                min-width: 210px;
                transform: translateX(-50%);
                padding: 9px 15px;
                color: #cbbd94;
                background: rgba(5,5,5,.95);
                border: 1px solid rgba(212,175,55,.42);
                border-radius: 999px;
                box-shadow: 0 0 14px rgba(0,0,0,.8);
                text-align: center;
                font: 900 11px Arial, sans-serif;
                letter-spacing: 1.3px;
                pointer-events: none;
                transition: .25s;
            }

            #rah-status::before {
                content: "";
                display: inline-block;
                width: 8px;
                height: 8px;
                margin-right: 8px;
                background: #777;
                border-radius: 50%;
                box-shadow: 0 0 7px currentColor;
            }

            #rah-status.working {
                color: #ffe08a;
                border-color: #d4af37;
                box-shadow: 0 0 19px rgba(212,175,55,.5);
            }

            #rah-status.working::before {
                background: #ffd866;
                animation: rah-status-pulse .8s ease-in-out infinite alternate;
            }

            #rah-status.finished {
                color: #a9edb2;
                border-color: #4ea85c;
            }

            #rah-status.finished::before {
                background: #6ee77d;
            }

            @keyframes rah-status-pulse {
                from { opacity: .4; transform: scale(.8); }
                to { opacity: 1; transform: scale(1.3); }
            }

            #rah-mini-deck {
                position: absolute;
                right: 18px;
                top: 78px;
                display: grid;
                gap: 7px;
                padding: 7px;
                background: var(--rah-panel);
                border: 1px solid var(--rah-border);
                border-radius: 12px;
                box-shadow: 0 0 16px rgba(0,0,0,.8);
                pointer-events: auto;
            }

            .rah-mini-button,
            #rah-wheel-toggle,
            .rah-wheel-item {
                display: grid;
                place-items: center;
                padding: 0;
                color: var(--rah-light-gold);
                background: radial-gradient(circle at 35% 25%, #352809, #080805 72%);
                border: 1px solid var(--rah-gold);
                border-radius: 50%;
                box-shadow:
                    0 0 0 2px rgba(0,0,0,.82),
                    0 0 11px rgba(212,175,55,.25),
                    inset 0 0 9px rgba(212,175,55,.1);
                cursor: pointer;
                pointer-events: auto;
            }

            .rah-mini-button {
                width: 39px;
                height: 39px;
                font-size: 17px;
            }

            .rah-mini-button.active {
                color: #050505;
                background: linear-gradient(145deg, #ffe88f, #a97810);
            }

            .rah-mini-button:hover,
            .rah-wheel-item:hover,
            .rah-wheel-item:focus-visible {
                color: #050505;
                background: linear-gradient(145deg, #ffe88f, #a97810);
                outline: none;
            }

            #rah-wheel {
                position: absolute;
                right: 120px;
                bottom: 130px;
                width: 76px;
                height: 76px;
                pointer-events: auto;
                touch-action: none;
                scale: var(--rah-wheel-scale, 1);
                transform-origin: center;
            }

            #rah-wheel-toggle {
                position: absolute;
                left: 50%;
                top: 50%;
                width: 76px;
                height: 76px;
                transform: translate(-50%, -50%);
                font: 900 16px Georgia, serif;
                letter-spacing: 1px;
                transition: .22s;
                cursor: grab;
            }

            #rah-wheel.dragging #rah-wheel-toggle {
                cursor: grabbing;
                transform: translate(-50%, -50%) scale(1.08);
            }

            #rah-wheel-toggle:hover {
                transform: translate(-50%, -50%) scale(1.08);
                box-shadow:
                    0 0 0 2px #000,
                    0 0 28px rgba(255,216,102,.72);
            }

            #rah-wheel.open #rah-wheel-toggle {
                color: #050505;
                background: linear-gradient(145deg, #ffe88f, #a97810);
                transform: translate(-50%, -50%) rotate(45deg);
            }

            .rah-wheel-item {
                position: absolute;
                left: 50%;
                top: 50%;
                width: 62px;
                height: 62px;
                opacity: 0;
                pointer-events: none;
                transform: translate(-50%, -50%) scale(.15);
                transition:
                    transform .3s cubic-bezier(.2,.82,.2,1),
                    opacity .2s;
                font: 900 20px Arial, sans-serif;
            }

            #rah-wheel.open .rah-wheel-item {
                opacity: 1;
                pointer-events: auto;
                transform:
                    translate(-50%, -50%)
                    rotate(calc(var(--i) * 40deg))
                    translateY(-111px)
                    rotate(calc(var(--i) * -40deg))
                    scale(1);
            }

            .rah-wheel-item::after,
            .rah-mini-button::after {
                content: attr(data-label);
                position: absolute;
                left: 50%;
                top: calc(100% + 6px);
                width: max-content;
                max-width: 150px;
                transform: translateX(-50%);
                padding: 5px 7px;
                color: var(--rah-light-gold);
                background: rgba(5,5,5,.97);
                border: 1px solid #9e7c1f;
                border-radius: 5px;
                font: 800 9px Arial, sans-serif;
                letter-spacing: .6px;
                opacity: 0;
                pointer-events: none;
                transition: opacity .15s;
            }

            .rah-wheel-item:hover::after,
            .rah-mini-button:hover::after {
                opacity: 1;
            }

            #rah-project-panel {
                position: absolute;
                right: 22px;
                bottom: 24px;
                display: none;
                width: min(330px, calc(100vw - 44px));
                padding: 12px;
                color: #f7efd7;
                background: rgba(7,6,4,.97);
                border: 1px solid #d4af37;
                border-radius: 13px;
                box-shadow: 0 0 26px rgba(0,0,0,.9);
                pointer-events: auto;
            }

            #rah-project-panel.open {
                display: block;
            }

            #rah-shortcut-panel {
                position: absolute;
                right: 76px;
                top: 78px;
                display: none;
                width: min(390px, calc(100vw - 100px));
                max-height: calc(100vh - 105px);
                overflow: auto;
                padding: 13px;
                color: #f7efd7;
                background: rgba(6,5,4,.98);
                border: 1px solid #d4af37;
                border-radius: 13px;
                box-shadow:
                    0 0 0 2px rgba(0,0,0,.85),
                    0 0 28px rgba(212,175,55,.3);
                pointer-events: auto;
            }

            #rah-shortcut-panel.open {
                display: block;
            }

            #rah-shortcut-title {
                display: flex;
                justify-content: space-between;
                margin-bottom: 10px;
                color: #ffe08a;
                font: 900 12px Georgia, serif;
                letter-spacing: 1px;
            }

            #rah-shortcut-grid {
                display: grid;
                grid-template-columns: 1fr 1fr;
                gap: 7px;
            }

            .rah-shortcut-button {
                display: grid;
                grid-template-columns: 29px 26px 1fr;
                gap: 7px;
                align-items: center;
                padding: 9px 8px;
                color: #f7e6ae;
                background: linear-gradient(145deg, #171207, #070706);
                border: 1px solid rgba(212,175,55,.48);
                border-radius: 7px;
                text-align: left;
                font: 800 9px Arial, sans-serif;
                cursor: pointer;
            }

            .rah-shortcut-button:hover {
                color: #050505;
                background: linear-gradient(145deg, #ffe88f, #a97810);
            }

            .rah-shortcut-key {
                display: inline-grid;
                place-items: center;
                min-width: 27px;
                height: 22px;
                color: #050505;
                background: #d4af37;
                border-radius: 4px;
                font: 900 9px Arial, sans-serif;
            }

            .rah-shortcut-icon {
                font-size: 16px;
                text-align: center;
            }

            #rah-shortcut-help {
                margin: 10px 0 0;
                padding-top: 9px;
                color: #bdaf86;
                border-top: 1px solid rgba(212,175,55,.2);
                font: 700 9px/1.55 Arial, sans-serif;
            }

            #rah-shortcut-close {
                width: 100%;
                margin-top: 9px;
                padding: 8px;
                color: #f7e6ae;
                background: #0b0906;
                border: 1px solid rgba(212,175,55,.45);
                border-radius: 7px;
                font: 800 9px Arial, sans-serif;
                cursor: pointer;
            }

            #rah-shortcut-close:hover {
                color: #050505;
                background: linear-gradient(145deg, #ffe88f, #a97810);
            }

            #rah-home-panel {
                position: absolute;
                right: 22px;
                bottom: 24px;
                display: none;
                width: min(610px, calc(100vw - 44px));
                max-height: calc(100vh - 48px);
                overflow: auto;
                padding: 15px;
                color: #f7efd7;
                background:
                    radial-gradient(circle at 50% 0,
                        rgba(126,91,17,.2), transparent 48%),
                    rgba(6,5,4,.985);
                border: 1px solid #d4af37;
                border-radius: 15px;
                box-shadow:
                    0 0 0 2px rgba(0,0,0,.88),
                    0 0 34px rgba(212,175,55,.34);
                pointer-events: auto;
            }

            #rah-home-panel.open {
                display: block;
            }

            #rah-home-title {
                display: flex;
                justify-content: space-between;
                color: #ffe08a;
                font: 900 13px Georgia, serif;
                letter-spacing: 1.1px;
            }

            #rah-home-subtitle {
                margin: 5px 0 12px;
                color: #a99b72;
                font: 800 9px Arial, sans-serif;
                letter-spacing: .7px;
            }

            #rah-home-grid {
                display: grid;
                grid-template-columns: repeat(3, 1fr);
                gap: 8px;
            }

            .rah-home-button {
                display: grid;
                grid-template-columns: 28px 1fr;
                gap: 8px;
                align-items: center;
                min-height: 48px;
                padding: 9px;
                color: #f7e6ae;
                background: linear-gradient(145deg, #191307, #070706);
                border: 1px solid rgba(212,175,55,.48);
                border-radius: 8px;
                text-align: left;
                font: 850 9px Arial, sans-serif;
                cursor: pointer;
            }

            .rah-home-button.wide {
                grid-column: 1 / -1;
                justify-content: center;
            }

            .rah-home-button span:first-child {
                color: #ffe08a;
                font-size: 18px;
                text-align: center;
            }

            .rah-home-button:hover,
            #rah-home-close:hover {
                color: #050505;
                background: linear-gradient(145deg, #ffe88f, #a97810);
            }

            #rah-home-close {
                width: 100%;
                margin-top: 10px;
                padding: 9px;
                color: #f7e6ae;
                background: #0b0906;
                border: 1px solid rgba(212,175,55,.45);
                border-radius: 7px;
                font: 800 9px Arial, sans-serif;
                cursor: pointer;
            }

            @media (max-width: 720px) {
                #rah-home-grid { grid-template-columns: 1fr 1fr; }
            }

            #rah-project-header {
                display: flex;
                align-items: center;
                justify-content: space-between;
                margin-bottom: 9px;
                color: #ffe08a;
                font: 900 11px Georgia, serif;
                letter-spacing: 1px;
            }

            #rah-project-buttons {
                display: grid;
                grid-template-columns: 1fr 1fr;
                gap: 7px;
            }

            .rah-project-button,
            #rah-project-edit,
            #rah-project-close {
                padding: 9px 8px;
                color: #f7e6ae;
                background: linear-gradient(145deg, #171207, #070706);
                border: 1px solid rgba(212,175,55,.48);
                border-radius: 7px;
                font: 800 10px Arial, sans-serif;
                cursor: pointer;
            }

            .rah-project-button:hover,
            #rah-project-edit:hover,
            #rah-project-close:hover {
                color: #050505;
                background: linear-gradient(145deg, #ffe88f, #a97810);
            }

            #rah-project-actions {
                display: flex;
                gap: 7px;
                margin-top: 9px;
            }

            #rah-project-edit,
            #rah-project-close {
                flex: 1;
            }

            #rah-context-menu {
                position: absolute;
                left: 0;
                top: 0;
                display: none;
                width: 218px;
                padding: 7px;
                color: #f7efd7;
                background: rgba(6,5,4,.98);
                border: 1px solid #d4af37;
                border-radius: 11px;
                box-shadow:
                    0 0 0 2px rgba(0,0,0,.85),
                    0 0 26px rgba(212,175,55,.34);
                pointer-events: auto;
            }

            #rah-context-menu.open {
                display: grid;
                gap: 5px;
            }

            #rah-context-title {
                padding: 7px 8px;
                color: #ffe08a;
                border-bottom: 1px solid rgba(212,175,55,.3);
                font: 900 10px Georgia, serif;
                letter-spacing: 1px;
            }

            .rah-context-command {
                display: flex;
                align-items: center;
                gap: 9px;
                padding: 8px 10px;
                color: #f7e6ae;
                background: linear-gradient(145deg, #151107, #070706);
                border: 1px solid rgba(212,175,55,.3);
                border-radius: 6px;
                text-align: left;
                font: 800 10px Arial, sans-serif;
                cursor: pointer;
            }

            .rah-context-command:hover {
                color: #050505;
                background: linear-gradient(145deg, #ffe88f, #a97810);
            }

            #rah-control-panel {
                position: absolute;
                right: 76px;
                top: 78px;
                display: none;
                width: min(350px, calc(100vw - 100px));
                max-height: calc(100vh - 105px);
                overflow: auto;
                padding: 13px;
                color: #f7efd7;
                background: rgba(6,5,4,.98);
                border: 1px solid #d4af37;
                border-radius: 13px;
                box-shadow:
                    0 0 0 2px rgba(0,0,0,.85),
                    0 0 28px rgba(212,175,55,.3);
                pointer-events: auto;
            }

            #rah-control-panel.open {
                display: block;
            }

            #rah-control-title {
                display: flex;
                justify-content: space-between;
                margin-bottom: 12px;
                color: #ffe08a;
                font: 900 12px Georgia, serif;
                letter-spacing: 1px;
            }

            .rah-control-row {
                display: grid;
                grid-template-columns: 1fr auto;
                gap: 7px 12px;
                align-items: center;
                padding: 9px 0;
                border-bottom: 1px solid rgba(212,175,55,.18);
            }

            .rah-control-row label {
                font: 800 10px Arial, sans-serif;
                letter-spacing: .5px;
            }

            .rah-control-row output {
                min-width: 36px;
                color: #ffe08a;
                text-align: right;
                font: 900 10px Arial, sans-serif;
            }

            .rah-control-row input[type="range"] {
                grid-column: 1 / -1;
                width: 100%;
                accent-color: #d4af37;
            }

            .rah-control-row select {
                min-width: 130px;
                padding: 6px;
                color: #ffeab0;
                background: #0b0906;
                border: 1px solid rgba(212,175,55,.5);
                border-radius: 6px;
            }

            #rah-control-actions {
                display: grid;
                grid-template-columns: 1fr 1fr;
                gap: 7px;
                margin-top: 12px;
            }

            .rah-control-action {
                padding: 9px 7px;
                color: #f7e6ae;
                background: linear-gradient(145deg, #171207, #070706);
                border: 1px solid rgba(212,175,55,.45);
                border-radius: 7px;
                font: 800 9px Arial, sans-serif;
                cursor: pointer;
            }

            .rah-control-action:hover {
                color: #050505;
                background: linear-gradient(145deg, #ffe88f, #a97810);
            }

            #${UI_ID}.rah-glow-low .rah-mini-button,
            #${UI_ID}.rah-glow-low #rah-wheel-toggle {
                box-shadow: 0 0 0 2px #000, 0 0 4px rgba(212,175,55,.2);
            }

            #${UI_ID}.rah-glow-high .rah-mini-button,
            #${UI_ID}.rah-glow-high #rah-wheel-toggle,
            #${UI_ID}.rah-glow-high #rah-status {
                box-shadow:
                    0 0 0 2px #000,
                    0 0 25px rgba(255,216,102,.72);
            }

            #rah-toast {
                position: absolute;
                left: 50%;
                top: 22px;
                transform: translate(-50%, -15px);
                padding: 10px 16px;
                color: var(--rah-light-gold);
                background: #060606;
                border: 1px solid var(--rah-gold);
                border-radius: 8px;
                box-shadow: 0 0 17px rgba(212,175,55,.55);
                font: 900 11px Arial, sans-serif;
                letter-spacing: 1px;
                opacity: 0;
                transition: .22s;
            }

            #rah-toast.show {
                opacity: 1;
                transform: translate(-50%, 0);
            }

            #${SKY_ID} {
                position: fixed;
                inset: 0;
                z-index: 2147482000;
                overflow: hidden;
                pointer-events: none;
            }

            .rah-raven {
                position: absolute;
                left: -100px;
                top: var(--top);
                font-size: var(--size);
                line-height: 1;
                filter:
                    drop-shadow(0 2px 1px #000)
                    drop-shadow(0 0 5px rgba(212,175,55,.35));
                animation:
                    rah-fly var(--speed) linear forwards,
                    rah-flap .55s ease-in-out infinite alternate;
                will-change: transform;
            }

            .rah-raven.reverse {
                left: auto;
                right: -100px;
                animation-name: rah-fly-back, rah-flap-back;
            }

            @keyframes rah-fly {
                from { transform: translateX(0) scaleX(1); }
                to { transform: translateX(calc(100vw + 210px)) scaleX(1); }
            }

            @keyframes rah-fly-back {
                from { transform: translateX(0) scaleX(-1); }
                to { transform: translateX(calc(-100vw - 210px)) scaleX(-1); }
            }

            @keyframes rah-flap {
                from { margin-top: -5px; rotate: -3deg; }
                to { margin-top: 5px; rotate: 3deg; }
            }

            @keyframes rah-flap-back {
                from { margin-top: -5px; rotate: 3deg; }
                to { margin-top: 5px; rotate: -3deg; }
            }

            .rah-shot {
                position: fixed;
                z-index: 2147483647;
                width: 52px;
                height: 52px;
                transform: translate(-50%, -50%) scale(.2);
                border: 3px solid #ffd866;
                border-radius: 50%;
                box-shadow: 0 0 9px #ffd866, inset 0 0 9px #ffd866;
                pointer-events: none;
                animation: rah-shot .42s ease-out forwards;
            }

            .rah-shot::before,
            .rah-shot::after {
                content: "";
                position: absolute;
                left: 50%;
                top: 50%;
                background: #ffd866;
                transform: translate(-50%, -50%);
            }

            .rah-shot::before { width: 68px; height: 2px; }
            .rah-shot::after { width: 2px; height: 68px; }

            @keyframes rah-shot {
                from {
                    opacity: 1;
                    transform: translate(-50%, -50%) scale(.2);
                }
                to {
                    opacity: 0;
                    transform: translate(-50%, -50%) scale(1.35);
                }
            }

            @media (max-width: 720px) {
                #rah-brand { display: none; }
                #rah-status { top: 8px; min-width: 175px; }
                #rah-mini-deck { right: 7px; top: 65px; transform: scale(.86); }
                #rah-wheel { right: 75px; bottom: 112px; transform: scale(.82); }
            }
        `;

        const sky = document.createElement("div");
        sky.id = SKY_ID;

        const ui = document.createElement("div");
        ui.id = UI_ID;
        ui.innerHTML = `
            <div id="rah-brand"><span>🐦‍⬛</span> RAH RAVEN · AI STUDIOS</div>
            <div id="rah-status">RAVEN READY</div>

            <div id="rah-mini-deck">
                <button class="rah-mini-button" data-setting="theme"
                    data-label="BLACK & GOLD">◐</button>
                <button class="rah-mini-button" data-setting="ravens"
                    data-label="FLYING RAVENS">🐦‍⬛</button>
                <button class="rah-mini-button" data-setting="focus"
                    data-label="FOCUS MODE">◉</button>
                <button class="rah-mini-button" data-setting="lightgun"
                    data-label="LIGHT-GUN MODE">🎯</button>
                <button class="rah-mini-button" data-setting="voice"
                    data-label="VOICE COMMANDS">🎙</button>
                <button class="rah-mini-button" data-setting="contextMenu"
                    data-label="RIGHT-CLICK MENU">☰</button>
                <button class="rah-mini-button" data-open-shortcuts
                    data-label="RAH APPS · ALT+R">⌘</button>
                <button class="rah-mini-button" data-open-wheel
                    data-label="COMMAND WHEEL">✺</button>
                <button class="rah-mini-button" data-open-controls
                    data-label="CONTROL LAB">⚙</button>
                <button class="rah-mini-button" data-setting="master"
                    data-label="MASTER POWER">⏻</button>
            </div>

            <div id="rah-wheel">
                <button id="rah-wheel-toggle"
                    title="Click to open · Drag to move · Double-click to reset">
                    RAH
                </button>
                <button class="rah-wheel-item" style="--i:0"
                    data-command="continue" data-label="C — CONTINUE">C</button>
                <button class="rah-wheel-item" style="--i:1"
                    data-command="image" data-label="CREATE IMAGE">🖼</button>
                <button class="rah-wheel-item" style="--i:2"
                    data-command="build" data-label="BUILD APPLICATION">🛠</button>
                <button class="rah-wheel-item" style="--i:3"
                    data-command="summary" data-label="SUMMARIZE">Σ</button>
                <button class="rah-wheel-item" style="--i:4"
                    data-command="search" data-label="SEARCH WEB">🌐</button>
                <button class="rah-wheel-item" style="--i:5"
                    data-command="speak" data-label="READ ALOUD">🔊</button>
                <button class="rah-wheel-item" style="--i:6"
                    data-command="projects" data-label="PROJECT LIST">☷</button>
                <button class="rah-wheel-item" style="--i:7"
                    data-command="lightgun" data-label="LIGHT-GUN MODE">🎯</button>
                <button class="rah-wheel-item" style="--i:8"
                    data-command="home-control" data-label="RAH CONTROL CENTER">🏠</button>
            </div>

            <div id="rah-home-panel">
                <div id="rah-home-title">
                    <span>🏠 RAH HOME CONTROL</span>
                    <span>v3.7.2</span>
                </div>
                <div id="rah-home-subtitle">
                    DATAROM / VINTERHAGE · MAIN ROOM · AUTO DISCOVERY
                </div>
                <div id="rah-home-grid"></div>
                <button id="rah-home-close">CLOSE HOME PANEL</button>
            </div>

            <div id="rah-shortcut-panel">
                <div id="rah-shortcut-title">
                    <span>⌘ RAH MULTI-MONITOR SHORTCUTS</span>
                    <span>v3.7.2</span>
                </div>
                <div id="rah-shortcut-grid"></div>
                <div id="rah-shortcut-help">
                    <b>Alt+R</b> opens this panel · <b>Alt+1…9</b> opens or
                    returns to the named RAH tab · <b>Alt+H</b> Home Panel ·
                    <b>Alt+U</b> Update · <b>Alt+W</b> Wheel Repair ·
                    <b>Alt+D</b> Doctor · <b>Alt+0</b> ChatGPT box.<br>
                    Browser tabs: <b>Ctrl+Tab</b> next ·
                    <b>Ctrl+Shift+Tab</b> previous · <b>Ctrl+9</b> last tab.
                </div>
                <button id="rah-shortcut-close">CLOSE</button>
            </div>

            <div id="rah-project-panel">
                <div id="rah-project-header">
                    <span>RAH PROJECT LAUNCHER</span>
                    <span>◆</span>
                </div>
                <div id="rah-project-buttons"></div>
                <div id="rah-project-actions">
                    <button id="rah-project-edit">EDIT PROJECTS</button>
                    <button id="rah-project-close">CLOSE</button>
                </div>
            </div>

            <div id="rah-context-menu">
                <div id="rah-context-title">🐦‍⬛ RAH RAVEN COMMANDS</div>
                <button class="rah-context-command"
                    data-context-command="continue">C · Continue</button>
                <button class="rah-context-command"
                    data-context-command="image">🖼 · Create image</button>
                <button class="rah-context-command"
                    data-context-command="build">🛠 · Build application</button>
                <button class="rah-context-command"
                    data-context-command="summary">Σ · Summarize</button>
                <button class="rah-context-command"
                    data-context-command="search">🌐 · Search web</button>
                <button class="rah-context-command"
                    data-context-command="projects">☷ · Projects</button>
                <button class="rah-context-command"
                    data-context-command="speak">🔊 · Read aloud</button>
                <button class="rah-context-command"
                    data-context-command="lightgun">🎯 · Light-gun mode</button>
            </div>

            <div id="rah-control-panel">
                <div id="rah-control-title">
                    <span>⚙ RAH CONTROL LAB</span>
                    <span>v3.7.2</span>
                </div>

                <div class="rah-control-row">
                    <label for="rah-raven-frequency">RAVEN AMOUNT</label>
                    <output id="rah-raven-frequency-value"></output>
                    <input id="rah-raven-frequency" type="range"
                        min="1" max="10" step="1"
                        data-control="ravenFrequency">
                </div>

                <div class="rah-control-row">
                    <label for="rah-raven-scale">RAVEN SIZE</label>
                    <output id="rah-raven-scale-value"></output>
                    <input id="rah-raven-scale" type="range"
                        min="0.6" max="1.8" step="0.1"
                        data-control="ravenScale">
                </div>

                <div class="rah-control-row">
                    <label for="rah-wheel-scale">WHEEL SIZE</label>
                    <output id="rah-wheel-scale-value"></output>
                    <input id="rah-wheel-scale" type="range"
                        min="0.7" max="1.5" step="0.1"
                        data-control="wheelScale">
                </div>

                <div class="rah-control-row">
                    <label for="rah-glow-select">GOLD GLOW</label>
                    <select id="rah-glow-select" data-control="glow">
                        <option value="low">LOW</option>
                        <option value="normal">NORMAL</option>
                        <option value="high">HIGH</option>
                    </select>
                </div>

                <div class="rah-control-row">
                    <label for="rah-language-select">VOICE LANGUAGE</label>
                    <select id="rah-language-select"
                        data-control="voiceLanguage">
                        <option value="auto">AUTO</option>
                        <option value="en-US">ENGLISH</option>
                        <option value="nb-NO">NORSK</option>
                    </select>
                </div>

                <div id="rah-control-actions">
                    <button class="rah-control-action"
                        data-control-action="export">COPY BACKUP</button>
                    <button class="rah-control-action"
                        data-control-action="import">IMPORT BACKUP</button>
                    <button class="rah-control-action"
                        data-control-action="reset">RESET DEFAULTS</button>
                    <button class="rah-control-action"
                        data-control-action="close">CLOSE</button>
                </div>
            </div>

            <div id="rah-toast"></div>
        `;

        document.head.appendChild(style);
        document.body.append(sky, ui);

        const root = document.documentElement;
        const wheel = ui.querySelector("#rah-wheel");
        const wheelToggle = ui.querySelector("#rah-wheel-toggle");
        const homePanel = ui.querySelector("#rah-home-panel");
        const homeGrid = ui.querySelector("#rah-home-grid");
        const shortcutPanel = ui.querySelector("#rah-shortcut-panel");
        const shortcutGrid = ui.querySelector("#rah-shortcut-grid");
        const projectPanel = ui.querySelector("#rah-project-panel");
        const projectButtons = ui.querySelector("#rah-project-buttons");
        const contextMenu = ui.querySelector("#rah-context-menu");
        const controlPanel = ui.querySelector("#rah-control-panel");
        const status = ui.querySelector("#rah-status");
        const toast = ui.querySelector("#rah-toast");
        let toastTimer;
        let wasBusy = false;
        let finishedUntil = 0;
        let suppressWheelClick = false;
        let recognition = null;
        let voicePausedForSpeech = false;
        let ravenTimer = null;

        function save() {
            localStorage.setItem(STORE_KEY, JSON.stringify(settings));
        }

        function showToast(message) {
            clearTimeout(toastTimer);
            toast.textContent = message;
            toast.classList.add("show");
            toastTimer = setTimeout(() => toast.classList.remove("show"), 2100);
        }

        function renderRahShortcuts() {
            shortcutGrid.replaceChildren();

            rahShortcuts.forEach(shortcut => {
                const button = document.createElement("button");
                button.className = "rah-shortcut-button";
                button.dataset.rahShortcut = shortcut.key;

                const key = document.createElement("span");
                key.className = "rah-shortcut-key";
                key.textContent = `ALT+${shortcut.key}`;

                const icon = document.createElement("span");
                icon.className = "rah-shortcut-icon";
                icon.textContent = shortcut.icon;

                const label = document.createElement("span");
                label.textContent = shortcut.label;

                button.append(key, icon, label);
                shortcutGrid.appendChild(button);
            });
        }

        function renderRahHomeActions() {
            homeGrid.replaceChildren();

            rahHomeActions.forEach(action => {
                const button = document.createElement("button");
                button.className = `rah-home-button${action.wide ? " wide" : ""}`;
                button.dataset.homeProtocol = action.protocol;
                button.dataset.homeLabel = action.label;

                const icon = document.createElement("span");
                icon.textContent = action.icon;
                const label = document.createElement("span");
                label.textContent = action.label;
                button.append(icon, label);
                homeGrid.appendChild(button);
            });
        }

        function openRahProtocol(protocol, label) {
            homePanel.classList.remove("open");
            shortcutPanel.classList.remove("open");
            showToast(`${label}: STARTING`);
            window.location.href = `rah-control-center://${protocol}`;
        }

        function openRahShortcut(key) {
            const normalizedKey = String(key).toLowerCase();
            const shortcut = rahShortcuts.find(
                item => item.key.toLowerCase() === normalizedKey
            );
            if (!shortcut) return;

            if (shortcut.protocol) {
                openRahProtocol(
                    shortcut.url.replace("rah-control-center://", ""),
                    shortcut.label
                );
                return;
            }

            const opened = window.open(shortcut.url, shortcut.target);

            if (!opened) {
                showToast("ALLOW POP-UPS FOR RAH SHORTCUTS");
                return;
            }

            try {
                opened.focus();
            } catch {}

            shortcutPanel.classList.remove("open");
            showToast(`${shortcut.label}: OPEN`);
        }

        function focusChatInput() {
            if (!IS_CHATGPT) {
                openRahShortcut("9");
                return;
            }

            const input = document.querySelector(
                '#prompt-textarea, textarea, [contenteditable="true"]'
            );

            if (!input) {
                showToast("CHAT INPUT NOT FOUND");
                return;
            }

            input.focus();
            input.scrollIntoView({ block: "center", behavior: "smooth" });
            showToast("CHAT INPUT READY");
        }

        function setStatus(mode, message) {
            status.className = mode;
            status.textContent = message;
        }

        function monitorStatus() {
            if (!IS_CHATGPT) {
                if (Date.now() > finishedUntil) {
                    setStatus("", "RAH FIREFOX READY");
                }
                return;
            }

            const busy = Boolean(
                document.querySelector('button[data-testid="stop-button"]')
                || document.querySelector('button[aria-label*="Stop"]')
                || document.querySelector('button[title*="Stop"]')
            );

            if (busy) {
                wasBusy = true;
                setStatus("working", "RAVEN WORKING");
            } else if (wasBusy) {
                wasBusy = false;
                finishedUntil = Date.now() + 4000;
                setStatus("finished", "RAVEN FINISHED");
            } else if (
                settings.master
                && settings.voice
                && recognition
            ) {
                setStatus("working", "RAVEN LISTENING");
            } else if (Date.now() > finishedUntil) {
                setStatus("", "RAVEN READY");
            }
        }

        function renderProjects() {
            const safeProjects = Array.isArray(settings.projects)
                ? settings.projects.slice(0, 8)
                : defaults.projects;

            projectButtons.replaceChildren();

            safeProjects.forEach(name => {
                const button = document.createElement("button");
                button.className = "rah-project-button";
                button.dataset.project = name;
                button.textContent = name;
                projectButtons.appendChild(button);
            });
        }

        function syncControls() {
            const values = {
                ravenFrequency: Number(settings.ravenFrequency) || 4,
                ravenScale: Number(settings.ravenScale) || 1,
                wheelScale: Number(settings.wheelScale) || 1,
                glow: settings.glow || "normal",
                voiceLanguage: settings.voiceLanguage || "auto"
            };

            Object.entries(values).forEach(([key, value]) => {
                const control = controlPanel.querySelector(
                    `[data-control="${key}"]`
                );
                if (control) {
                    control.setAttribute("value", String(value));

                    try {
                        control.value = String(value);
                    } catch {}

                    if (control.tagName === "SELECT") {
                        [...control.options].forEach(option => {
                            option.toggleAttribute(
                                "selected",
                                option.value === String(value)
                            );
                        });
                    }
                }
            });

            controlPanel.querySelector("#rah-raven-frequency-value")
                .textContent = `${values.ravenFrequency}/10`;
            controlPanel.querySelector("#rah-raven-scale-value")
                .textContent = `${Math.round(values.ravenScale * 100)}%`;
            controlPanel.querySelector("#rah-wheel-scale-value")
                .textContent = `${Math.round(values.wheelScale * 100)}%`;
        }

        function applySettings() {
            root.classList.toggle("rah-master-off", !settings.master);
            root.classList.toggle(
                "rah-theme",
                IS_CHATGPT && settings.master && settings.theme
            );
            root.classList.toggle(
                "rah-focus",
                IS_CHATGPT && settings.master && settings.focus
            );
            root.classList.toggle(
                "rah-lightgun",
                settings.master && settings.lightgun
            );
            ui.classList.toggle("rah-glow-low", settings.glow === "low");
            ui.classList.toggle("rah-glow-high", settings.glow === "high");
            wheel.style.setProperty(
                "--rah-wheel-scale",
                String(Number(settings.wheelScale) || 1)
            );

            ui.querySelectorAll("[data-setting]").forEach(button => {
                button.classList.toggle(
                    "active",
                    Boolean(settings[button.dataset.setting])
                );
            });

            if (
                Number.isFinite(settings.wheelX)
                && Number.isFinite(settings.wheelY)
            ) {
                wheel.style.left = `${settings.wheelX}px`;
                wheel.style.top = `${settings.wheelY}px`;
                wheel.style.right = "auto";
                wheel.style.bottom = "auto";
            }
        }

        function toggleSetting(key) {
            settings[key] = !settings[key];
            save();
            applySettings();

            if (
                (key === "ravens" && !settings.ravens)
                || (key === "master" && !settings.master)
            ) {
                sky.replaceChildren();
            }

            if (
                key === "voice"
                || (key === "master" && !settings.master)
            ) {
                if (settings.master && settings.voice) startVoice();
                else stopVoice();
            }

            if (key === "master" && !settings.master) {
                contextMenu.classList.remove("open");
                homePanel.classList.remove("open");
                projectPanel.classList.remove("open");
                shortcutPanel.classList.remove("open");
                controlPanel.classList.remove("open");
                wheel.classList.remove("open");
                window.speechSynthesis?.cancel?.();
            }

            if (
                settings.master
                && settings.ravens
                && (key === "ravens" || key === "master")
            ) {
                spawnRaven();
                setTimeout(spawnRaven, 500);
            }

            showToast(
                `${key.toUpperCase()}: ${settings[key] ? "ON" : "OFF"}`
            );
        }

        function spawnRaven() {
            if (!settings.master || !settings.ravens || document.hidden) return;

            const raven = document.createElement("div");
            const reverse = Math.random() > .7;
            const ravenScale = Number(settings.ravenScale) || 1;
            raven.className = `rah-raven${reverse ? " reverse" : ""}`;
            raven.textContent = "🐦‍⬛";
            raven.style.setProperty("--top", `${8 + Math.random() * 60}vh`);
            raven.style.setProperty(
                "--size",
                `${(30 + Math.random() * 28) * ravenScale}px`
            );
            raven.style.setProperty("--speed", `${12 + Math.random() * 8}s`);
            sky.appendChild(raven);

            raven.addEventListener("animationend", event => {
                if (event.animationName.includes("fly")) raven.remove();
            });
        }

        function scheduleRavens() {
            clearTimeout(ravenTimer);

            const frequency = Math.max(
                1,
                Math.min(10, Number(settings.ravenFrequency) || 4)
            );
            const delay = Math.max(1800, 11000 - frequency * 900);

            ravenTimer = setTimeout(() => {
                spawnRaven();
                scheduleRavens();
            }, delay);
        }

        function findComposer() {
            return document.querySelector("#prompt-textarea")
                || document.querySelector("textarea[placeholder]")
                || document.querySelector(
                    '[contenteditable="true"][role="textbox"]'
                );
        }

        function writePrompt(text, sendNow = false) {
            const composer = findComposer();

            if (!composer) {
                showToast("PROMPT BOX NOT FOUND");
                return;
            }

            composer.focus();

            if ("value" in composer) {
                const setter = Object.getOwnPropertyDescriptor(
                    Object.getPrototypeOf(composer),
                    "value"
                )?.set;

                if (setter) setter.call(composer, text);
                else composer.value = text;
            } else {
                const selection = window.getSelection();
                const range = document.createRange();
                range.selectNodeContents(composer);
                selection.removeAllRanges();
                selection.addRange(range);

                if (!document.execCommand("insertText", false, text)) {
                    const paragraph = document.createElement("p");
                    paragraph.textContent = text;
                    composer.replaceChildren(paragraph);
                }
            }

            composer.dispatchEvent(new InputEvent("input", {
                bubbles: true,
                inputType: "insertText",
                data: text
            }));

            if (!sendNow) {
                showToast("PROMPT READY — ADD DETAILS");
                return;
            }

            showToast("SENDING RAH COMMAND");
            setStatus("working", "RAVEN SENDING COMMAND");

            let attempts = 0;
            const trySend = () => {
                attempts += 1;

                const form = composer.closest("form");
                const sendButton =
                    form?.querySelector('button[data-testid="send-button"]')
                    || form?.querySelector('button[aria-label*="Send"]')
                    || document.querySelector(
                        'button[data-testid="send-button"]'
                    );

                if (sendButton && !sendButton.disabled) {
                    sendButton.click();
                } else if (attempts < 8) {
                    setTimeout(trySend, 180);
                } else {
                    showToast("PROMPT READY — PRESS ENTER");
                }
            };

            setTimeout(trySend, 250);
        }

        function readLastAnswer() {
            if (!("speechSynthesis" in window)) {
                showToast("READ ALOUD NOT SUPPORTED");
                return;
            }

            if (speechSynthesis.speaking || speechSynthesis.pending) {
                speechSynthesis.cancel();
                showToast("READ ALOUD: STOPPED");
                return;
            }

            const answers = [
                ...document.querySelectorAll(
                    '[data-message-author-role="assistant"]'
                )
            ];
            const text = answers.at(-1)?.innerText?.trim();

            if (!text) {
                showToast("NO ANSWER TO READ");
                return;
            }

            const speech = new SpeechSynthesisUtterance(text);
            voicePausedForSpeech = true;
            recognition?.stop?.();
            speech.lang =
                document.documentElement.lang
                || navigator.language
                || "en-US";
            speech.rate = .95;
            speech.pitch = .9;
            speech.onend = () => {
                voicePausedForSpeech = false;
                showToast("READ ALOUD: FINISHED");
                if (settings.master && settings.voice) startVoice();
            };
            speechSynthesis.speak(speech);
            showToast("READ ALOUD: PLAYING");
        }

        function runCommand(command) {
            wheel.classList.remove("open");

            if (command === "home-control") {
                homePanel.classList.toggle("open");
                projectPanel.classList.remove("open");
                shortcutPanel.classList.remove("open");
                controlPanel.classList.remove("open");
                showToast("RAH HOME CONTROL");
                return;
            }

            if (
                !IS_CHATGPT
                && !["projects", "lightgun"].includes(command)
            ) {
                queueRahAction({ kind: "command", command });
                openRahShortcut("9");
                showToast("COMMAND SENT TO CHATGPT");
                return;
            }

            const prompts = {
                continue:
                    "Continue from exactly where we stopped. Keep the same RAH Raven design and complete the next practical step.",
                image:
                    "Create a premium black-and-gold RAH Raven image of ",
                build:
                    "Build a complete working RAH Raven application for ",
                summary:
                    "Summarize our current work: what is finished, what works, and the best next step.",
                search:
                    "Search the web for the latest reliable information about ",
                projects: ""
            };

            if (command === "speak") {
                readLastAnswer();
            } else if (command === "lightgun") {
                toggleSetting("lightgun");
            } else if (command === "projects") {
                projectPanel.classList.toggle("open");
                homePanel.classList.remove("open");
            } else {
                writePrompt(
                    prompts[command],
                    ["continue", "summary", "projects"].includes(command)
                );
            }
        }

        function handleVoiceCommand(transcript) {
            const words = transcript
                .toLowerCase()
                .replace(/[.,!?]/g, "")
                .trim();

            if (!words.includes("raven")) return;

            showToast(`VOICE: ${transcript.toUpperCase()}`);

            const project = (settings.projects || []).find(name =>
                words.includes(name.toLowerCase())
            );

            if (project) {
                writePrompt(
                    `Continue work on the ${project} project. Review where we stopped and complete the next practical step.`,
                    true
                );
            } else if (words.includes("stop listening")) {
                settings.voice = false;
                save();
                applySettings();
                stopVoice();
            } else if (words.includes("continue")) {
                runCommand("continue");
            } else if (words.includes("project")) {
                runCommand("projects");
            } else if (words.includes("image")) {
                runCommand("image");
            } else if (words.includes("build") || words.includes("application")) {
                runCommand("build");
            } else if (words.includes("summary") || words.includes("summarize")) {
                runCommand("summary");
            } else if (words.includes("search")) {
                runCommand("search");
            } else if (words.includes("read")) {
                runCommand("speak");
            } else if (words.includes("light gun")) {
                toggleSetting("lightgun");
            } else if (words.includes("focus")) {
                toggleSetting("focus");
            } else if (words.includes("theme")) {
                toggleSetting("theme");
            } else if (words.includes("ravens")) {
                toggleSetting("ravens");
            } else if (words.includes("power off")) {
                toggleSetting("master");
            } else {
                showToast("RAVEN HEARD YOU — COMMAND NOT FOUND");
            }
        }

        function startVoice() {
            const Recognition =
                window.SpeechRecognition
                || window.webkitSpeechRecognition;

            if (!Recognition) {
                settings.voice = false;
                save();
                applySettings();
                showToast("VOICE COMMANDS NOT SUPPORTED");
                return;
            }

            if (recognition) return;

            recognition = new Recognition();
            recognition.continuous = true;
            recognition.interimResults = false;
            recognition.lang =
                settings.voiceLanguage === "auto"
                    ? (
                        document.documentElement.lang
                        || navigator.language
                        || "en-US"
                    )
                    : settings.voiceLanguage;

            recognition.onstart = () => {
                setStatus("working", "RAVEN LISTENING");
            };

            recognition.onresult = event => {
                const result = event.results[event.results.length - 1];
                const transcript = result?.[0]?.transcript?.trim();
                if (transcript) handleVoiceCommand(transcript);
            };

            recognition.onerror = event => {
                if (!["aborted", "no-speech"].includes(event.error)) {
                    showToast(`VOICE ERROR: ${event.error}`);
                }
            };

            recognition.onend = () => {
                recognition = null;

                if (
                    settings.master
                    && settings.voice
                    && !voicePausedForSpeech
                ) {
                    setTimeout(startVoice, 450);
                }
            };

            try {
                recognition.start();
            } catch {
                recognition = null;
            }
        }

        function stopVoice() {
            recognition?.stop?.();
            recognition = null;
            if (settings.master) setStatus("", "RAVEN READY");
        }

        function editProjects() {
            const current = (settings.projects || defaults.projects).join(", ");
            const edited = window.prompt(
                "Write project names separated by commas:",
                current
            );

            if (edited === null) return;

            const names = edited
                .split(",")
                .map(name => name.trim())
                .filter(Boolean)
                .slice(0, 8);

            if (!names.length) {
                showToast("KEEP AT LEAST ONE PROJECT");
                return;
            }

            settings.projects = names;
            save();
            renderProjects();
            showToast("PROJECT BUTTONS UPDATED");
        }

        async function exportSettings() {
            const backup = JSON.stringify(settings, null, 2);

            try {
                await navigator.clipboard.writeText(backup);
                showToast("SETTINGS BACKUP COPIED");
            } catch {
                window.prompt("Copy this settings backup:", backup);
            }
        }

        function importSettings() {
            const backup = window.prompt("Paste your RAH settings backup:");
            if (!backup) return;

            try {
                const imported = JSON.parse(backup);
                settings = {
                    ...defaults,
                    ...imported,
                    voice: false
                };
                save();
                stopVoice();
                renderProjects();
                syncControls();
                applySettings();
                scheduleRavens();
                showToast("SETTINGS BACKUP IMPORTED");
            } catch {
                showToast("BACKUP TEXT IS NOT VALID");
            }
        }

        function resetSettings() {
            if (!window.confirm("Reset all RAH v3.7.2 settings?")) return;

            stopVoice();
            settings = {
                ...defaults,
                projects: [...defaults.projects]
            };
            save();
            renderProjects();
            syncControls();
            applySettings();
            scheduleRavens();
            showToast("RAH SETTINGS RESET");
        }

        function queueRahAction(action) {
            const value = JSON.stringify({
                ...action,
                queuedAt: Date.now()
            });

            try {
                GM_setValue(PENDING_ACTION_KEY, value);
            } catch {
                localStorage.setItem(PENDING_ACTION_KEY, value);
            }
        }

        function takeRahAction(rawValue = null) {
            let value = rawValue;

            try {
                if (!value) value = GM_getValue(PENDING_ACTION_KEY, null);
                GM_deleteValue(PENDING_ACTION_KEY);
            } catch {
                if (!value) value = localStorage.getItem(PENDING_ACTION_KEY);
                localStorage.removeItem(PENDING_ACTION_KEY);
            }

            if (!value) return null;

            try {
                const action = typeof value === "string"
                    ? JSON.parse(value)
                    : value;
                if (
                    !action
                    || !action.queuedAt
                    || Date.now() - action.queuedAt > 180000
                ) return null;
                return action;
            } catch {
                return null;
            }
        }

        function processRahAction(rawValue = null) {
            if (!IS_CHATGPT) return;
            const action = takeRahAction(rawValue);
            if (!action) return;

            setTimeout(() => {
                if (action.kind === "prompt" && action.prompt) {
                    writePrompt(action.prompt, Boolean(action.sendNow));
                } else if (action.kind === "command" && action.command) {
                    runCommand(action.command);
                }
            }, 900);
        }

        ui.addEventListener("click", event => {
            const settingButton = event.target.closest("[data-setting]");
            const commandButton = event.target.closest("[data-command]");
            const homeActionButton = event.target.closest(
                "[data-home-protocol]"
            );
            const contextCommand =
                event.target.closest("[data-context-command]");
            const controlAction =
                event.target.closest("[data-control-action]");

            if (settingButton) {
                toggleSetting(settingButton.dataset.setting);
            } else if (
                event.target.closest("#rah-wheel-toggle")
                || event.target.closest("[data-open-wheel]")
            ) {
                if (suppressWheelClick) return;
                homePanel.classList.remove("open");
                wheel.classList.toggle("open");
            } else if (commandButton) {
                runCommand(commandButton.dataset.command);
            } else if (contextCommand) {
                contextMenu.classList.remove("open");
                runCommand(contextCommand.dataset.contextCommand);
            } else if (homeActionButton) {
                openRahProtocol(
                    homeActionButton.dataset.homeProtocol,
                    homeActionButton.dataset.homeLabel
                );
            } else if (event.target.closest("#rah-home-close")) {
                homePanel.classList.remove("open");
            } else if (event.target.closest("[data-open-controls]")) {
                controlPanel.classList.toggle("open");
                homePanel.classList.remove("open");
            } else if (event.target.closest("[data-open-shortcuts]")) {
                shortcutPanel.classList.toggle("open");
                homePanel.classList.remove("open");
                controlPanel.classList.remove("open");
            } else if (event.target.closest("[data-rah-shortcut]")) {
                openRahShortcut(
                    event.target.closest("[data-rah-shortcut]")
                        .dataset.rahShortcut
                );
            } else if (event.target.closest("#rah-shortcut-close")) {
                shortcutPanel.classList.remove("open");
            } else if (controlAction) {
                const action = controlAction.dataset.controlAction;
                if (action === "export") exportSettings();
                else if (action === "import") importSettings();
                else if (action === "reset") resetSettings();
                else if (action === "close") {
                    controlPanel.classList.remove("open");
                }
            } else if (event.target.closest(".rah-project-button")) {
                const name = event.target.closest(".rah-project-button")
                    .dataset.project;
                projectPanel.classList.remove("open");
                const prompt = `Continue work on the ${name} project. Review where we stopped and complete the next practical step.`;
                if (IS_CHATGPT) {
                    writePrompt(prompt, true);
                } else {
                    queueRahAction({ kind: "prompt", prompt, sendNow: true });
                    openRahShortcut("9");
                    showToast("PROJECT SENT TO CHATGPT");
                }
            } else if (event.target.closest("#rah-project-edit")) {
                editProjects();
            } else if (event.target.closest("#rah-project-close")) {
                projectPanel.classList.remove("open");
            }
        });

        controlPanel.addEventListener("input", event => {
            const control = event.target.closest("[data-control]");
            if (!control) return;

            const key = control.dataset.control;
            const numericKeys = [
                "ravenFrequency",
                "ravenScale",
                "wheelScale"
            ];

            settings[key] = numericKeys.includes(key)
                ? Number(control.value)
                : control.value;

            save();
            syncControls();
            applySettings();

            if (key === "ravenFrequency") scheduleRavens();
            if (key === "voiceLanguage" && settings.voice) {
                stopVoice();
                startVoice();
            }
        });

        let dragState = null;

        wheelToggle.addEventListener("pointerdown", event => {
            if (event.button !== 0) return;

            const rect = wheel.getBoundingClientRect();
            dragState = {
                pointerId: event.pointerId,
                startX: event.clientX,
                startY: event.clientY,
                left: rect.left,
                top: rect.top,
                moved: false
            };

            wheelToggle.setPointerCapture?.(event.pointerId);
        });

        wheelToggle.addEventListener("pointermove", event => {
            if (!dragState || event.pointerId !== dragState.pointerId) return;

            const dx = event.clientX - dragState.startX;
            const dy = event.clientY - dragState.startY;

            if (!dragState.moved && Math.hypot(dx, dy) < 6) return;

            dragState.moved = true;
            suppressWheelClick = true;
            wheel.classList.add("dragging");
            wheel.classList.remove("open");

            const left = Math.max(
                8,
                Math.min(window.innerWidth - 84, dragState.left + dx)
            );
            const top = Math.max(
                8,
                Math.min(window.innerHeight - 84, dragState.top + dy)
            );

            wheel.style.left = `${left}px`;
            wheel.style.top = `${top}px`;
            wheel.style.right = "auto";
            wheel.style.bottom = "auto";
        });

        wheelToggle.addEventListener("pointerup", event => {
            if (!dragState || event.pointerId !== dragState.pointerId) return;

            if (dragState.moved) {
                const rect = wheel.getBoundingClientRect();
                settings.wheelX = Math.round(rect.left);
                settings.wheelY = Math.round(rect.top);
                save();
                showToast("WHEEL POSITION SAVED");
            }

            wheel.classList.remove("dragging");
            dragState = null;
            setTimeout(() => { suppressWheelClick = false; }, 80);
        });

        wheelToggle.addEventListener("dblclick", event => {
            event.preventDefault();
            settings.wheelX = null;
            settings.wheelY = null;
            wheel.style.left = "";
            wheel.style.top = "";
            wheel.style.right = "";
            wheel.style.bottom = "";
            save();
            showToast("WHEEL POSITION RESET");
        });

        document.addEventListener("pointerdown", event => {
            if (settings.master && settings.lightgun) {
                const shot = document.createElement("div");
                shot.className = "rah-shot";
                shot.style.left = `${event.clientX}px`;
                shot.style.top = `${event.clientY}px`;
                document.body.appendChild(shot);
                shot.addEventListener("animationend", () => shot.remove());
            }

            if (
                wheel.classList.contains("open")
                && !event.target.closest("#rah-wheel")
                && !event.target.closest("[data-open-wheel]")
                && !event.target.closest("#rah-project-panel")
                && !event.target.closest("#rah-home-panel")
                && !event.target.closest("#rah-shortcut-panel")
                && !event.target.closest("#rah-control-panel")
            ) {
                wheel.classList.remove("open");
            }

            if (
                homePanel.classList.contains("open")
                && !event.target.closest("#rah-home-panel")
                && !event.target.closest('[data-command="home-control"]')
            ) {
                homePanel.classList.remove("open");
            }

            if (
                shortcutPanel.classList.contains("open")
                && !event.target.closest("#rah-shortcut-panel")
                && !event.target.closest("[data-open-shortcuts]")
            ) {
                shortcutPanel.classList.remove("open");
            }

            if (!event.target.closest("#rah-context-menu")) {
                contextMenu.classList.remove("open");
            }
        }, { capture: true, signal: lifetime.signal });

        document.addEventListener("contextmenu", event => {
            if (
                !settings.master
                || !settings.contextMenu
                || event.shiftKey
                || event.target.closest("#rah-context-menu")
            ) {
                return;
            }

            event.preventDefault();

            const menuWidth = 218;
            const menuHeight = 390;
            const left = Math.min(
                event.clientX,
                window.innerWidth - menuWidth - 10
            );
            const top = Math.min(
                event.clientY,
                window.innerHeight - menuHeight - 10
            );

            contextMenu.style.left = `${Math.max(8, left)}px`;
            contextMenu.style.top = `${Math.max(8, top)}px`;
            contextMenu.classList.add("open");
        }, { signal: lifetime.signal });

        document.addEventListener("keydown", event => {
            const key = event.key.toLowerCase();

            if (
                event.altKey
                && !event.ctrlKey
                && !event.metaKey
                && key === "r"
            ) {
                event.preventDefault();
                shortcutPanel.classList.toggle("open");
                homePanel.classList.remove("open");
                controlPanel.classList.remove("open");
                wheel.classList.remove("open");
            } else if (
                event.altKey
                && !event.ctrlKey
                && !event.metaKey
                && key === "h"
            ) {
                event.preventDefault();
                homePanel.classList.toggle("open");
                shortcutPanel.classList.remove("open");
                controlPanel.classList.remove("open");
                wheel.classList.remove("open");
            } else if (
                event.altKey
                && !event.ctrlKey
                && !event.metaKey
                && (
                    /^[1-9]$/.test(key)
                    || ["u", "w", "d"].includes(key)
                )
            ) {
                event.preventDefault();
                openRahShortcut(key);
            } else if (
                event.altKey
                && !event.ctrlKey
                && !event.metaKey
                && key === "0"
            ) {
                event.preventDefault();
                focusChatInput();
            } else if (event.altKey && key === "c") {
                event.preventDefault();
                homePanel.classList.remove("open");
                wheel.classList.toggle("open");
            } else if (event.key === "Escape") {
                wheel.classList.remove("open");
                homePanel.classList.remove("open");
                shortcutPanel.classList.remove("open");
            }
        }, { signal: lifetime.signal });

        renderRahShortcuts();
        renderRahHomeActions();
        renderProjects();
        syncControls();
        applySettings();
        const initialRavenTimers = [
            setTimeout(spawnRaven, 700),
            setTimeout(spawnRaven, 1350)
        ];
        scheduleRavens();
        const statusTimer = setInterval(monitorStatus, 700);
        let pendingListenerId = null;
        if (IS_CHATGPT) {
            try {
                pendingListenerId = GM_addValueChangeListener(
                    PENDING_ACTION_KEY,
                    (_name, _oldValue, newValue) => {
                        if (newValue) processRahAction(newValue);
                    }
                );
            } catch {}
            processRahAction();
        }
        hostMarker.addEventListener("rah-wheel-shutdown", () => {
            lifetime.abort();
            initialRavenTimers.forEach(clearTimeout);
            clearTimeout(ravenTimer);
            clearInterval(statusTimer);
            stopVoice();
            window.speechSynthesis?.cancel?.();
            if (pendingListenerId !== null) {
                try { GM_removeValueChangeListener(pendingListenerId); }
                catch {}
            }
            root.classList.remove(
                "rah-theme",
                "rah-focus",
                "rah-lightgun",
                "rah-master-off"
            );
            style.remove();
            sky.remove();
            ui.remove();
        }, { once: true });
        showToast("RAH COMMAND WHEEL v3.7.2 ONLINE · ALT+C");
    }

    if (document.body) start();
    else window.addEventListener("DOMContentLoaded", start, { once: true });
})();
