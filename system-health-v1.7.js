/* RAH Raven System Health v1.7
 * Local-first diagnostics for Command Center, Vision, Desktop Bridge,
 * LM Studio, Supabase session/cloud sync, Voice Control and Mission Engine.
 */
(() => {
  "use strict";

  const VERSION = "1.7.0";
  const BRIDGE = "http://127.0.0.1:8765";
  const LM_STUDIO = "http://127.0.0.1:1234";
  const CHECK_TIMEOUT = 4500;
  const HISTORY_KEY = "rah-system-health-history-v1";

  const services = [
    { id: "command", label: "Command Center", icon: "🏠" },
    { id: "vision", label: "Raven Vision", icon: "👁️" },
    { id: "bridge", label: "Desktop Bridge", icon: "🖥️" },
    { id: "lmstudio", label: "LM Studio", icon: "🧠" },
    { id: "cloud", label: "Cloud Sync", icon: "☁️" },
    { id: "voice", label: "Voice Control", icon: "🎙️" },
    { id: "mission", label: "Mission Engine", icon: "🎯" }
  ];

  let currentResults = {};
  let running = false;

  function esc(value) {
    return String(value ?? "").replace(/[&<>"']/g, ch => ({
      "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;"
    }[ch]));
  }

  function timeoutSignal(ms = CHECK_TIMEOUT) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), ms);
    return { signal: controller.signal, clear: () => clearTimeout(timer) };
  }

  async function fetchJson(url, options = {}) {
    const guard = timeoutSignal();
    try {
      const response = await fetch(url, { cache: "no-store", ...options, signal: guard.signal });
      const text = await response.text();
      let data = null;
      try { data = text ? JSON.parse(text) : null; } catch { data = null; }
      if (!response.ok) throw new Error(data?.error || `HTTP ${response.status}`);
      return data;
    } finally {
      guard.clear();
    }
  }

  function result(ok, detail, fix = "", extra = {}) {
    return { ok, detail, fix, checkedAt: new Date().toISOString(), ...extra };
  }

  async function checkCommandCenter() {
    const hasState = typeof window.state === "object" || localStorage.getItem("rah-raven-command-center-v1.2");
    const hasRender = typeof window.render === "function" || document.querySelector(".app");
    return result(Boolean(hasState && hasRender), hasState && hasRender ? "Command Center er lastet." : "Command Center mangler kjernestatus.", "Oppdater siden med Ctrl + F5.");
  }

  async function checkVision() {
    const script = [...document.scripts].some(s => String(s.src).includes("vision-module.js"));
    const panel = document.getElementById("vision") || document.getElementById("analyzeVision");
    return result(Boolean(script && panel), script && panel ? "Vision-modulen er koblet inn." : "Vision-modulen ble ikke funnet.", "Oppdater siden eller åpne vision.html.");
  }

  async function checkBridge() {
    try {
      const data = await fetchJson(`${BRIDGE}/health`);
      return result(Boolean(data?.ok), data?.ok ? `Desktop Bridge v${data.version || "ukjent"} svarer.` : "Bridge svarte uten OK-status.", "Start desktop-bridge/start-raven-vision.bat.", { data });
    } catch (error) {
      return result(false, `Desktop Bridge utilgjengelig: ${error.message}`, "Start desktop-bridge/start-raven-vision.bat og kontroller port 8765.");
    }
  }

  async function checkLmStudio() {
    try {
      const data = await fetchJson(`${LM_STUDIO}/v1/models`);
      const models = Array.isArray(data?.data) ? data.data.map(m => m.id).filter(Boolean) : [];
      if (!models.length) return result(false, "LM Studio svarer, men ingen modell er lastet.", "Last inn en vision-modell og start Local Server på port 1234.");
      return result(true, `${models.length} modell(er) tilgjengelig: ${models.slice(0, 2).join(", ")}${models.length > 2 ? " …" : ""}`, "", { models });
    } catch (error) {
      return result(false, `LM Studio utilgjengelig: ${error.message}`, "Åpne LM Studio, last en vision-modell og start Local Server på port 1234.");
    }
  }

  async function checkCloud() {
    const supabaseReady = Boolean(window.supabase?.createClient || window.rahSupabase || window.__rahSupabaseClient);
    const syncScript = [...document.scripts].some(s => String(s.src).includes("cloud-sync.js"));
    let session = null;
    const candidates = [window.rahSupabase, window.__rahSupabaseClient].filter(Boolean);
    for (const client of candidates) {
      try {
        const response = await client.auth.getSession();
        session = response?.data?.session || null;
        break;
      } catch {}
    }
    if (!syncScript) return result(false, "Cloud Sync-modulen mangler.", "Oppdater siden med Ctrl + F5.");
    if (!supabaseReady) return result(false, "Supabase-klienten er ikke klar.", "Kontroller nettforbindelsen og oppdater siden.");
    if (!session) return result(false, "Cloud Sync er lastet, men ingen innlogget sesjon ble funnet.", "Logg inn med RAH-kontoen.");
    return result(true, `Innlogget som ${session.user?.email || "RAH-medlem"}.`);
  }

  async function checkVoice() {
    const script = [...document.scripts].some(s => String(s.src).includes("voice-control-v1.6.js"));
    const recognition = Boolean(window.SpeechRecognition || window.webkitSpeechRecognition);
    const synthesis = "speechSynthesis" in window;
    if (!script) return result(false, "Voice Control v1.6 mangler.", "Oppdater siden med Ctrl + F5.");
    if (!recognition) return result(false, "Nettleseren støtter ikke talegjenkjenning.", "Bruk Chrome eller Edge for full stemmestyring.");
    return result(true, synthesis ? "Talegjenkjenning og talesvar er klare." : "Talegjenkjenning er klar, men talesvar mangler.");
  }

  async function checkMission() {
    const script = [...document.scripts].some(s => String(s.src).includes("mission-engine.js"));
    const usable = script && (typeof window.runNextMissionStep === "function" || document.getElementById("runNextMissionStep"));
    return result(Boolean(usable), usable ? "Mission Engine v1.5 er klar." : "Mission Engine kunne ikke bekreftes.", "Oppdater siden med Ctrl + F5.");
  }

  const checkers = {
    command: checkCommandCenter,
    vision: checkVision,
    bridge: checkBridge,
    lmstudio: checkLmStudio,
    cloud: checkCloud,
    voice: checkVoice,
    mission: checkMission
  };

  function statusClass(item) {
    if (!item) return "rah-health-pending";
    return item.ok ? "rah-health-good" : "rah-health-bad";
  }

  function statusText(item) {
    if (!item) return "VENTER";
    return item.ok ? "KLAR" : "FEIL";
  }

  function saveHistory(summary) {
    let history = [];
    try { history = JSON.parse(localStorage.getItem(HISTORY_KEY) || "[]"); } catch {}
    history.unshift(summary);
    localStorage.setItem(HISTORY_KEY, JSON.stringify(history.slice(0, 20)));
  }

  function getHistory() {
    try { return JSON.parse(localStorage.getItem(HISTORY_KEY) || "[]"); } catch { return []; }
  }

  function renderCards() {
    const container = document.getElementById("rahHealthCards");
    if (!container) return;
    container.innerHTML = services.map(service => {
      const item = currentResults[service.id];
      return `<article class="rah-health-card ${statusClass(item)}">
        <div class="rah-health-card-head"><span>${service.icon}</span><strong>${esc(service.label)}</strong><span class="rah-health-pill">${statusText(item)}</span></div>
        <div class="rah-health-detail">${esc(item?.detail || "Ikke kontrollert ennå.")}</div>
        ${item?.fix && !item.ok ? `<div class="rah-health-fix"><strong>Løsning:</strong> ${esc(item.fix)}</div>` : ""}
      </article>`;
    }).join("");
  }

  function renderSummary() {
    const summary = document.getElementById("rahHealthSummary");
    const button = document.getElementById("rahRunHealthCheck");
    if (!summary) return;
    const values = Object.values(currentResults);
    const ready = values.filter(v => v?.ok).length;
    const failed = values.filter(v => v && !v.ok).length;
    summary.textContent = running
      ? "Raven kontrollerer systemet …"
      : values.length
        ? `${ready}/${services.length} systemer klare${failed ? ` • ${failed} trenger handling` : " • Alt er klart"}`
        : "Ikke kontrollert ennå.";
    if (button) {
      button.disabled = running;
      button.textContent = running ? "Kontrollerer …" : "⚡ Kjør full systemkontroll";
    }
  }

  function renderHistory() {
    const box = document.getElementById("rahHealthHistory");
    if (!box) return;
    const history = getHistory();
    box.innerHTML = history.slice(0, 6).map(entry => `
      <div class="list-item"><div><strong>${entry.ready}/${entry.total} klare</strong><div class="meta">${new Date(entry.time).toLocaleString("no-NO")}</div></div><span class="pill">${entry.failed ? `${entry.failed} FEIL` : "KLAR"}</span></div>
    `).join("") || "<p>Ingen systemkontroller ennå.</p>";
  }

  async function runFullCheck() {
    if (running) return;
    running = true;
    currentResults = {};
    renderCards();
    renderSummary();

    await Promise.all(services.map(async service => {
      try {
        currentResults[service.id] = await checkers[service.id]();
      } catch (error) {
        currentResults[service.id] = result(false, `Uventet feil: ${error.message}`, "Oppdater siden og prøv igjen.");
      }
      renderCards();
      renderSummary();
    }));

    running = false;
    const values = Object.values(currentResults);
    const summary = {
      time: new Date().toISOString(),
      ready: values.filter(v => v.ok).length,
      failed: values.filter(v => !v.ok).length,
      total: services.length,
      results: currentResults
    };
    saveHistory(summary);
    renderSummary();
    renderHistory();

    if (typeof window.notify === "function") {
      window.notify(summary.failed ? `Systemkontroll: ${summary.failed} feil funnet` : "Alle Raven-systemer er klare");
    }
    return summary;
  }

  function injectStyles() {
    const style = document.createElement("style");
    style.textContent = `
      .rah-health-shell{margin-top:16px;padding:17px;border:1px solid #463817;border-radius:18px;background:linear-gradient(180deg,#15130d,#0c0c0d)}
      .rah-health-head{display:flex;justify-content:space-between;align-items:center;gap:12px;flex-wrap:wrap;margin-bottom:12px}
      .rah-health-head h2{margin:0;color:#ffe28a;font-size:17px}.rah-health-head p{margin:4px 0 0;color:#aaa392}
      .rah-health-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:10px}
      .rah-health-card{padding:13px;border:1px solid #302812;border-radius:13px;background:#0b0b0c;min-height:116px}
      .rah-health-card-head{display:flex;align-items:center;gap:8px}.rah-health-card-head strong{flex:1}
      .rah-health-pill{font-size:10px;padding:4px 7px;border-radius:99px;border:1px solid #51431f}
      .rah-health-detail{margin-top:10px;color:#d8d3c6;font-size:13px;line-height:1.4}.rah-health-fix{margin-top:8px;color:#f2c458;font-size:12px;line-height:1.35}
      .rah-health-good{border-color:#24563d}.rah-health-good .rah-health-pill{color:#8ff0ba;border-color:#2d8d5b;background:#10261a}
      .rah-health-bad{border-color:#643838}.rah-health-bad .rah-health-pill{color:#ffb5b5;border-color:#8f4646;background:#2a1111}
      .rah-health-pending{opacity:.8}.rah-health-actions{display:flex;gap:8px;flex-wrap:wrap;margin-top:12px}
      @media(max-width:760px){.rah-health-grid{grid-template-columns:1fr}}
    `;
    document.head.appendChild(style);
  }

  function injectPanel() {
    const target = document.getElementById("settings") || document.querySelector("main");
    if (!target || document.getElementById("rahSystemHealth")) return;
    const shell = document.createElement("section");
    shell.id = "rahSystemHealth";
    shell.className = target.id === "settings" ? "rah-health-shell" : "panel full rah-health-shell";
    shell.innerHTML = `
      <div class="rah-health-head">
        <div><h2>🩺 Raven System Health v1.7</h2><p id="rahHealthSummary">Ikke kontrollert ennå.</p></div>
        <button class="btn primary" id="rahRunHealthCheck">⚡ Kjør full systemkontroll</button>
      </div>
      <div class="rah-health-grid" id="rahHealthCards"></div>
      <div class="rah-health-actions">
        <button class="btn" id="rahOpenVision">👁️ Åpne Vision</button>
        <button class="btn" id="rahOpenBridgeHealth">🖥️ Bridge-status</button>
        <button class="btn" id="rahOpenLmModels">🧠 LM Studio-modeller</button>
        <button class="btn" id="rahClearHealthHistory">Tøm historikk</button>
      </div>
      <div style="margin-top:14px"><h2>🕒 Siste kontroller</h2><div id="rahHealthHistory"></div></div>
    `;
    target.appendChild(shell);

    document.getElementById("rahRunHealthCheck").onclick = runFullCheck;
    document.getElementById("rahOpenVision").onclick = () => typeof window.switchView === "function" ? window.switchView("vision") : window.open("vision.html", "_blank", "noopener");
    document.getElementById("rahOpenBridgeHealth").onclick = () => window.open(`${BRIDGE}/health`, "_blank", "noopener");
    document.getElementById("rahOpenLmModels").onclick = () => window.open(`${LM_STUDIO}/v1/models`, "_blank", "noopener");
    document.getElementById("rahClearHealthHistory").onclick = () => { localStorage.removeItem(HISTORY_KEY); renderHistory(); };

    renderCards();
    renderHistory();
  }

  function exposeVoiceHook() {
    window.runRavenSystemHealth = runFullCheck;
    window.getRavenSystemHealth = () => ({ version: VERSION, running, results: currentResults });
  }

  function boot() {
    injectStyles();
    injectPanel();
    exposeVoiceHook();
    setTimeout(runFullCheck, 1200);
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", boot, { once: true });
  else boot();
})();
