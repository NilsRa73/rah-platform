(() => {
  "use strict";

  const VERSION = "1.6.0";
  const SETTINGS_KEY = "rah.voice.v1.6.settings";
  const HISTORY_LIMIT = 40;
  const sensitiveActions = new Set([
    "delete-local-data",
    "clear-mission",
    "logout",
    "publish",
    "open-supabase"
  ]);

  const settings = Object.assign({
    speechEnabled: true,
    confirmations: true,
    rate: 0.95,
    pitch: 0.9,
    volume: 1
  }, JSON.parse(localStorage.getItem(SETTINGS_KEY) || "{}"));

  let pendingConfirmation = null;
  let confirmationTimer = null;

  function persistSettings() {
    localStorage.setItem(SETTINGS_KEY, JSON.stringify(settings));
  }

  function normalize(text) {
    return String(text || "")
      .toLowerCase()
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g, "")
      .replace(/[^a-z0-9æøå\s-]/g, " ")
      .replace(/\s+/g, " ")
      .trim();
  }

  function say(text, force = false) {
    if (!window.speechSynthesis || (!settings.speechEnabled && !force)) return;
    window.speechSynthesis.cancel();
    const utterance = new SpeechSynthesisUtterance(String(text));
    utterance.lang = "nb-NO";
    utterance.rate = settings.rate;
    utterance.pitch = settings.pitch;
    utterance.volume = settings.volume;
    const voices = window.speechSynthesis.getVoices();
    const norwegian = voices.find(v => /^nb|^no/i.test(v.lang));
    if (norwegian) utterance.voice = norwegian;
    window.speechSynthesis.speak(utterance);
  }

  function toast(text) {
    if (typeof window.notify === "function") window.notify(text);
    else console.info("RAH Voice:", text);
  }

  function record(text, matched, result) {
    try {
      const raw = JSON.parse(localStorage.getItem("rah-command-center-v1.2") || "{}");
      raw.voiceHistory = Array.isArray(raw.voiceHistory) ? raw.voiceHistory : [];
      raw.voiceHistory.unshift({
        text,
        matched: matched || null,
        result: result || null,
        engine: `v${VERSION}`,
        time: new Date().toISOString()
      });
      raw.voiceHistory = raw.voiceHistory.slice(0, HISTORY_LIMIT);
      raw.lastVoiceCommand = text;
      localStorage.setItem("rah-command-center-v1.2", JSON.stringify(raw));
    } catch (error) {
      console.warn("Could not record voice command", error);
    }
  }

  function click(id) {
    const element = document.getElementById(id);
    if (!element) throw new Error(`Fant ikke ${id}`);
    element.click();
  }

  function go(view) {
    if (typeof window.switchView === "function") window.switchView(view);
    else {
      const button = document.querySelector(`[data-view="${view}"]`);
      if (button) button.click();
    }
  }

  function open(url) {
    if (typeof window.openUrl === "function") window.openUrl(url);
    else window.open(url, "_blank", "noopener");
  }

  function bridgeHealth() {
    return fetch("http://127.0.0.1:8765/health", { cache: "no-store" })
      .then(r => {
        if (!r.ok) throw new Error(`Bridge svarte ${r.status}`);
        return r.json();
      });
  }

  const commands = [
    { id: "continue", phrases: ["fortsett", "fortsett prosjekt", "ga videre", "continue"], run: () => click("continueBtn"), response: "Fortsetter aktivt prosjekt." },
    { id: "mission-open", phrases: ["apne mission control", "vis mission control", "mission control"], run: () => go("missions"), response: "Åpner Mission Control." },
    { id: "mission-next", phrases: ["kjor neste steg", "neste steg", "fortsett mission"], run: () => window.runNextMissionStep ? window.runNextMissionStep() : click("runNextMissionStep"), response: "Kjører neste mission-steg." },
    { id: "mission-confirm", phrases: ["bekreft ferdig", "steget er ferdig", "marker ferdig"], run: () => { const b = [...document.querySelectorAll("button")].find(x => /bekreft ferdig/i.test(x.textContent)); if (!b) throw new Error("Fant ingen ventende bekreftelse"); b.click(); }, response: "Steget er bekreftet ferdig." },
    { id: "mission-pause", phrases: ["pause mission", "paus mission"], run: () => click("pauseMission"), response: "Mission er pauset." },
    { id: "mission-resume", phrases: ["fortsett mission", "gjenoppta mission"], run: () => click("pauseMission"), response: "Mission fortsetter." },
    { id: "vision-open", phrases: ["apne vision", "vis vision", "raven vision"], run: () => go("vision"), response: "Åpner Raven Vision." },
    { id: "vision-capture", phrases: ["hent aktivt vindu", "ta skjermbilde", "fang aktivt vindu"], run: () => click("captureActiveWindow"), response: "Henter aktivt vindu." },
    { id: "vision-analyze", phrases: ["analyser skjermen", "analyser skjermbilde", "les skjermen"], run: () => click("analyzeVision"), response: "Starter skjermanalyse." },
    { id: "brain-open", phrases: ["apne project brain", "vis project brain", "apne hukommelsen"], run: () => go("brain"), response: "Åpner Project Brain." },
    { id: "cloud-sync", phrases: ["synkroniser skyen", "synkroniser project brain", "lagre i skyen"], run: () => { const b = document.querySelector("#rahCloudSyncPanel button") || [...document.querySelectorAll("button")].find(x => /synkroniser na/i.test(normalize(x.textContent))); if (!b) throw new Error("Cloud Sync-knappen ble ikke funnet"); b.click(); }, response: "Synkroniserer Project Brain med skyen." },
    { id: "project-sync", phrases: ["synkroniser prosjekt", "oppdater prosjektkontekst"], run: () => { go("sync"); click("syncProjectBrain"); }, response: "Synkroniserer prosjektkonteksten." },
    { id: "github", phrases: ["apne github", "apne repo", "vis github"], run: () => open("https://github.com/NilsRa73/rah-platform"), response: "Åpner GitHub-repositoriet." },
    { id: "settings", phrases: ["apne innstillinger", "vis innstillinger"], run: () => go("settings"), response: "Åpner innstillinger." },
    { id: "bridge-test", phrases: ["test desktop bridge", "sjekk bridge", "er bridge online"], run: async () => { const data = await bridgeHealth(); toast(`Desktop Bridge ${data.version || ""} er online`); say("Desktop Bridge er online."); }, response: null },
    { id: "voice-off", phrases: ["stopp lytting", "sla av stemmen", "stopp mikrofon"], run: () => { if (typeof window.stopVoiceRecognition === "function") window.stopVoiceRecognition(); }, response: "Stemmestyring er stoppet." },
    { id: "speech-toggle", phrases: ["sla av talesvar", "sla pa talesvar"], run: (text) => { settings.speechEnabled = !normalize(text).includes("av"); persistSettings(); }, response: (text) => settings.speechEnabled ? "Talesvar er på." : "Talesvar er av." },
    { id: "clear-mission", phrases: ["avslutt mission", "slett aktiv mission"], sensitive: true, run: () => click("clearMission"), response: "Aktiv mission avsluttes." },
    { id: "delete-local-data", phrases: ["slett lokale data", "nullstill raven"], sensitive: true, run: () => click("clearData"), response: "Lokale data slettes." },
    { id: "logout", phrases: ["logg ut"], sensitive: true, run: () => click("rahLogoutButton"), response: "Logger ut." }
  ];

  function matchCommand(text) {
    const q = normalize(text);
    let best = null;
    for (const command of commands) {
      for (const phrase of command.phrases) {
        const p = normalize(phrase);
        if (q === p || q.includes(p)) {
          const score = p.length + (q === p ? 100 : 0);
          if (!best || score > best.score) best = { command, score };
        }
      }
    }
    return best?.command || null;
  }

  function clearPendingConfirmation() {
    pendingConfirmation = null;
    clearTimeout(confirmationTimer);
    confirmationTimer = null;
  }

  function askConfirmation(command, originalText) {
    clearPendingConfirmation();
    pendingConfirmation = { command, originalText };
    confirmationTimer = setTimeout(clearPendingConfirmation, 15000);
    const message = `Bekreft handlingen ${command.id} ved å si ja bekreft, eller si avbryt.`;
    toast(message);
    say(message);
    record(originalText, command.id, "awaiting-confirmation");
  }

  async function execute(command, originalText) {
    try {
      const result = command.run(originalText);
      if (result && typeof result.then === "function") await result;
      const response = typeof command.response === "function" ? command.response(originalText) : command.response;
      if (response) {
        toast(response);
        say(response);
      }
      record(originalText, command.id, "completed");
      return true;
    } catch (error) {
      const message = `Kunne ikke kjøre kommandoen. ${error.message || error}`;
      toast(message);
      say(message);
      record(originalText, command.id, "failed");
      return false;
    }
  }

  async function process(text) {
    const q = normalize(text);
    if (!q) return false;

    if (pendingConfirmation) {
      if (["ja", "ja bekreft", "bekreft", "ok bekreft"].some(x => q.includes(x))) {
        const pending = pendingConfirmation;
        clearPendingConfirmation();
        return execute(pending.command, pending.originalText);
      }
      if (["nei", "avbryt", "stopp"].some(x => q.includes(x))) {
        clearPendingConfirmation();
        toast("Handlingen er avbrutt.");
        say("Handlingen er avbrutt.");
        record(text, "confirmation", "cancelled");
        return true;
      }
    }

    const command = matchCommand(text);
    if (!command) {
      const message = "Jeg fant ingen passende Raven-kommando.";
      toast(message);
      say(message);
      record(text, null, "unmatched");
      return false;
    }

    if ((command.sensitive || sensitiveActions.has(command.id)) && settings.confirmations) {
      askConfirmation(command, text);
      return true;
    }
    return execute(command, text);
  }

  function enhanceUI() {
    const panel = document.querySelector("#voice .panel.wide");
    if (!panel || document.getElementById("voiceV16Panel")) return;
    const box = document.createElement("div");
    box.id = "voiceV16Panel";
    box.className = "panel";
    box.style.cssText = "grid-column:1/-1;box-shadow:none;margin-top:14px;background:#0a0a0b";
    box.innerHTML = `
      <div class="row between">
        <div><h2>🐦‍⬛ Voice Control v1.6</h2><div class="meta">Norsk talesvar, Mission Control, Vision, Cloud Sync og sikre bekreftelser.</div></div>
        <span class="pill">ACTIVE</span>
      </div>
      <div class="row" style="margin-top:12px">
        <button class="btn" id="voiceSpeechToggle">Talesvar: ${settings.speechEnabled ? "PÅ" : "AV"}</button>
        <button class="btn" id="voiceConfirmToggle">Bekreftelser: ${settings.confirmations ? "PÅ" : "AV"}</button>
        <button class="btn" id="voiceSpeakTest">Test talesvar</button>
      </div>
      <div class="meta" style="margin-top:12px">Eksempler: «kjør neste steg», «bekreft ferdig», «hent aktivt vindu», «analyser skjermen», «synkroniser skyen».</div>`;
    panel.appendChild(box);

    document.getElementById("voiceSpeechToggle").onclick = event => {
      settings.speechEnabled = !settings.speechEnabled;
      persistSettings();
      event.currentTarget.textContent = `Talesvar: ${settings.speechEnabled ? "PÅ" : "AV"}`;
      say(settings.speechEnabled ? "Talesvar er aktivert." : "", true);
    };
    document.getElementById("voiceConfirmToggle").onclick = event => {
      settings.confirmations = !settings.confirmations;
      persistSettings();
      event.currentTarget.textContent = `Bekreftelser: ${settings.confirmations ? "PÅ" : "AV"}`;
    };
    document.getElementById("voiceSpeakTest").onclick = () => say("Raven Voice Control er klar.", true);
  }

  function installOverride() {
    const previous = window.processVoiceCommand;
    window.processVoiceCommand = function voiceV16Process(text) {
      const transcript = document.getElementById("voiceTranscript");
      if (transcript) transcript.textContent = text || "Ingen tale registrert.";
      process(text).then(matched => {
        if (!matched && typeof previous === "function" && previous !== window.processVoiceCommand) {
          // The old engine is retained only as a compatibility fallback.
        }
        if (typeof window.renderVoiceControl === "function") window.renderVoiceControl();
      });
    };
    window.RAHVoice = { version: VERSION, process, say, commands, settings };
  }

  function init() {
    installOverride();
    enhanceUI();
    document.addEventListener("click", () => window.speechSynthesis?.getVoices(), { once: true });
    console.info(`RAH Voice Control v${VERSION} ready`);
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init);
  else init();
})();
