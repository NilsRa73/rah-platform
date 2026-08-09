(() => {
  "use strict";

  const DEFAULT_ENDPOINT = "http://127.0.0.1:1234/v1";
  const HISTORY_KEY = "rah-raven-vision-history-v1";
  const SETTINGS_KEY = "rah-raven-vision-settings-v1";

  const byId = id => document.getElementById(id);
  const status = byId("visionStatus");
  const preview = byId("visionPreview");
  const result = byId("visionResult");
  const note = byId("visionNote");
  const dropZone = byId("dropZone");

  if (!status || !preview || !result || !note || !dropZone) return;

  let imageData = "";
  let abortController = null;
  let currentModel = "";

  function notifyUser(text) {
    status.textContent = text;
    if (typeof window.notify === "function") window.notify(text);
  }

  function replaceNode(id) {
    const node = byId(id);
    if (!node) return null;
    const clean = node.cloneNode(true);
    node.replaceWith(clean);
    return clean;
  }

  function loadSettings() {
    try {
      return Object.assign(
        { endpoint: DEFAULT_ENDPOINT, model: "" },
        JSON.parse(localStorage.getItem(SETTINGS_KEY) || "{}")
      );
    } catch {
      return { endpoint: DEFAULT_ENDPOINT, model: "" };
    }
  }

  function normalizeEndpoint(value) {
    let endpoint = String(value || "").trim().replace(/\/+$/, "");
    if (!endpoint) endpoint = DEFAULT_ENDPOINT;
    if (!/\/v1$/i.test(endpoint)) endpoint += "/v1";
    return endpoint;
  }

  function saveSettings() {
    const settings = {
      endpoint: normalizeEndpoint(endpointInput.value),
      model: modelSelect.value || currentModel || ""
    };
    endpointInput.value = settings.endpoint;
    localStorage.setItem(SETTINGS_KEY, JSON.stringify(settings));
    settingsState.textContent = "Lagret lokalt";
    settingsState.className = "sync-good";
    notifyUser("Vision-innstillingene er lagret lokalt.");
    return settings;
  }

  function friendlyNetworkError(error) {
    const message = String(error?.message || error || "ukjent feil");
    if (/failed to fetch|networkerror|load failed|fetch/i.test(message)) {
      return "LM Studio svarer ikke. Åpne LM Studio, last inn en vision-modell, start Local Server på port 1234 og kontroller at CORS er aktivert.";
    }
    return message;
  }

  const fileInput = replaceNode("visionFile");
  const analyzeButton = replaceNode("analyzeVision");

  // Remove legacy capture actions. RAH Vision v1.4 only analyzes screenshots
  // the user explicitly chooses as files or drops onto the page.
  ["captureActiveWindow", "rahCaptureWindow", "rahCaptureScreen"].forEach(id => byId(id)?.remove());

  const controls = document.createElement("div");
  controls.className = "row";
  controls.style.marginTop = "10px";
  controls.innerHTML = `
    <button class="btn" id="rahChooseVisionFile">🖼️ Velg skjermbilde</button>
    <button class="btn" id="rahTestVision">🔌 Test tilkobling</button>
    <button class="btn" id="rahSaveVisionSettings">💾 Lagre innstillinger</button>
    <a class="btn" href="vision.html">↗ Åpne full Vision</a>
  `;
  dropZone.insertAdjacentElement("afterend", controls);

  const diagnostics = document.createElement("section");
  diagnostics.className = "panel full";
  diagnostics.style.marginTop = "15px";
  diagnostics.innerHTML = `
    <div class="row between">
      <div>
        <h2>🔧 Vision v1.4 status</h2>
        <div class="meta">Lokal LM Studio-analyse. Ingen skjult skjermopptak eller bakgrunnsfangst.</div>
      </div>
      <span class="pill" id="rahVisionVersion">v1.4</span>
    </div>
    <div class="quick-grid" style="margin-top:12px">
      <div class="quick"><span>🧠</span><strong id="rahLmState">Ikke testet</strong><small>LM Studio</small></div>
      <div class="quick"><span>🖼️</span><strong id="rahImageState">Ingen bilde</strong><small>Valgt skjermbilde</small></div>
      <div class="quick"><span>🔒</span><strong id="rahPrivacyState">Manuell</strong><small>Ingen skjult fangst</small></div>
      <div class="quick"><span>💾</span><strong id="rahSettingsState">Ikke lagret</strong><small>Lokale innstillinger</small></div>
    </div>
    <div class="field" style="margin-top:12px">
      <label for="rahVisionEndpoint">Lokal AI-adresse</label>
      <input id="rahVisionEndpoint" value="${DEFAULT_ENDPOINT}" spellcheck="false">
    </div>
    <div class="row" style="margin-top:12px">
      <select id="rahVisionModel" style="flex:1;min-width:260px"><option value="">Test tilkobling for å finne modeller…</option></select>
      <button class="btn danger" id="rahStopVision" disabled>Stopp analyse</button>
      <button class="btn" id="rahClearVisionHistory">Tøm historikk</button>
    </div>
    <div class="info-strip" style="margin-top:12px">
      Bare bildet du selv velger eller drar inn blir sendt til den lokale modellen sammen med Vision-oppdraget.
    </div>
    <div id="rahVisionHistory" style="margin-top:12px"></div>
  `;
  byId("vision").querySelector(".grid").appendChild(diagnostics);

  const endpointInput = byId("rahVisionEndpoint");
  const modelSelect = byId("rahVisionModel");
  const stopButton = byId("rahStopVision");
  const lmState = byId("rahLmState");
  const imageState = byId("rahImageState");
  const settingsState = byId("rahSettingsState");

  const saved = loadSettings();
  endpointInput.value = normalizeEndpoint(saved.endpoint);

  function setImage(data, label) {
    imageData = data || "";
    window.rahVisionImageData = imageData;
    if (imageData) {
      preview.src = imageData;
      preview.style.display = "block";
      imageState.textContent = label || "Bilde klart";
      imageState.className = "sync-good";
      notifyUser(`${label || "Bildet"} er klart for analyse.`);
    } else {
      preview.removeAttribute("src");
      preview.style.display = "none";
      imageState.textContent = "Ingen bilde";
      imageState.className = "";
      notifyUser("Ingen skjermbilde valgt.");
    }
  }

  function readFile(file) {
    if (!file) return;
    if (!["image/png", "image/jpeg", "image/webp"].includes(file.type)) {
      notifyUser("Velg en PNG-, JPG- eller WEBP-fil.");
      return;
    }
    if (file.size > 15 * 1024 * 1024) {
      notifyUser("Bildet er større enn 15 MB. Velg et mindre bilde.");
      return;
    }
    const reader = new FileReader();
    reader.onload = () => setImage(String(reader.result || ""), file.name);
    reader.onerror = () => notifyUser("Klarte ikke å lese bildet.");
    reader.readAsDataURL(file);
  }

  fileInput?.addEventListener("change", () => readFile(fileInput.files?.[0]));
  byId("rahChooseVisionFile")?.addEventListener("click", () => fileInput?.click());

  dropZone.addEventListener("dragover", event => {
    event.preventDefault();
    dropZone.classList.add("drag");
  });
  dropZone.addEventListener("dragleave", () => dropZone.classList.remove("drag"));
  dropZone.addEventListener("drop", event => {
    event.preventDefault();
    dropZone.classList.remove("drag");
    readFile(event.dataTransfer?.files?.[0]);
  });

  async function fetchJson(url, options = {}) {
    let response;
    try {
      response = await fetch(url, { cache: "no-store", ...options });
    } catch (error) {
      throw new Error(friendlyNetworkError(error));
    }
    if (!response.ok) {
      const body = await response.text().catch(() => "");
      throw new Error(`${response.status} ${response.statusText}${body ? `: ${body.slice(0, 300)}` : ""}`);
    }
    try {
      return await response.json();
    } catch {
      throw new Error("LM Studio returnerte ugyldig JSON.");
    }
  }

  async function discoverModels(showStatus = true) {
    const base = normalizeEndpoint(endpointInput.value);
    endpointInput.value = base;
    modelSelect.innerHTML = '<option value="">Søker etter modeller…</option>';
    if (showStatus) notifyUser("Tester LM Studio…");

    try {
      const payload = await fetchJson(`${base}/models`);
      const models = Array.isArray(payload.data) ? payload.data.filter(item => item?.id) : [];
      if (!models.length) throw new Error("LM Studio svarer, men ingen modell er lastet inn.");

      modelSelect.innerHTML = models
        .map(item => `<option value="${String(item.id).replace(/"/g, "&quot;")}">${item.id}</option>`)
        .join("");

      const preferred = loadSettings().model;
      currentModel = models.some(item => item.id === preferred) ? preferred : models[0].id;
      modelSelect.value = currentModel;

      lmState.textContent = `Klar: ${currentModel}`;
      lmState.className = "sync-good";
      if (showStatus) notifyUser(`LM Studio er klart. ${models.length} modell(er) funnet.`);
      return currentModel;
    } catch (error) {
      currentModel = "";
      modelSelect.innerHTML = '<option value="">LM Studio ikke tilgjengelig</option>';
      lmState.textContent = "Frakoblet";
      lmState.className = "sync-bad";
      if (showStatus) notifyUser(friendlyNetworkError(error));
      throw error;
    }
  }

  async function testConnection() {
    try {
      await discoverModels(true);
    } catch {
      // discoverModels already reports a clear user-facing error.
    }
  }

  function history() {
    try {
      return JSON.parse(localStorage.getItem(HISTORY_KEY) || "[]");
    } catch {
      return [];
    }
  }

  function saveHistory(entry) {
    const items = [entry, ...history()].slice(0, 12);
    localStorage.setItem(HISTORY_KEY, JSON.stringify(items));
    renderHistory();
  }

  function renderHistory() {
    const host = byId("rahVisionHistory");
    const items = history();
    host.innerHTML = items.length ? items.map(item => `
      <div class="list-item">
        <div>
          <strong>${new Date(item.time).toLocaleString("no-NO")}</strong>
          <div class="meta">${String(item.prompt).replace(/[&<>]/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;"}[c])).slice(0, 120)}</div>
        </div>
        <button class="btn" data-vision-history="${item.id}">Vis</button>
      </div>`).join("") : "<p>Ingen Vision-analyser lagret ennå.</p>";

    host.querySelectorAll("[data-vision-history]").forEach(button => {
      button.onclick = () => {
        const item = items.find(entry => entry.id === button.dataset.visionHistory);
        if (item) {
          note.value = item.prompt;
          result.textContent = item.answer;
          status.textContent = "Historisk analyse åpnet.";
        }
      };
    });
  }

  async function analyze() {
    imageData = imageData || window.rahVisionImageData || preview.src || "";
    if (!imageData || !imageData.startsWith("data:image/")) {
      notifyUser("Velg først et skjermbilde fra fil.");
      return;
    }

    const prompt = note.value.trim() ||
      "Les skjermbildet. Forklar kort hva du ser, finn problemet, og gi nummererte klikk-for-klikk-instruksjoner på norsk.";

    let model = modelSelect.value || currentModel;
    if (!model) {
      try {
        model = await discoverModels(false);
      } catch (error) {
        result.textContent =
          `LM Studio er ikke klart.\n\n` +
          `1. Åpne LM Studio.\n` +
          `2. Last inn en vision-modell.\n` +
          `3. Start Local Server på port 1234.\n` +
          `4. Aktiver CORS.\n\n` +
          `Feil: ${friendlyNetworkError(error)}`;
        notifyUser("LM Studio er ikke tilgjengelig.");
        return;
      }
    }

    const base = normalizeEndpoint(endpointInput.value);
    abortController = new AbortController();
    analyzeButton.disabled = true;
    stopButton.disabled = false;
    status.textContent = `Raven analyserer med ${model}…`;
    result.textContent = "Analyserer det valgte skjermbildet lokalt…";

    try {
      const payload = await fetchJson(`${base}/chat/completions`, {
        method: "POST",
        signal: abortController.signal,
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          model,
          temperature: 0.2,
          max_tokens: 1400,
          messages: [
            {
              role: "system",
              content:
                "Du er RAH Raven Vision. Svar på norsk. Vær konkret og nybegynnervennlig. " +
                "Beskriv synlige knapper og nøyaktig hvor brukeren skal klikke. Ikke gjett når tekst er uleselig."
            },
            {
              role: "user",
              content: [
                { type: "text", text: prompt },
                { type: "image_url", image_url: { url: imageData } }
              ]
            }
          ]
        })
      });

      const answer = payload?.choices?.[0]?.message?.content;
      if (!answer) throw new Error("Modellen returnerte ikke et lesbart svar. Kontroller at modellen støtter bilder.");

      result.textContent = answer;
      status.textContent = "Analysen er ferdig og lagret lokalt.";
      saveHistory({
        id: crypto.randomUUID ? crypto.randomUUID() : String(Date.now()),
        time: new Date().toISOString(),
        prompt,
        answer,
        model
      });

      try {
        const key = "rah-raven-state-v1";
        const projectState = JSON.parse(localStorage.getItem(key) || "null");
        if (projectState && typeof projectState === "object") {
          projectState.visionNote = prompt;
          projectState.brain =
            `${projectState.brain || ""}${projectState.brain ? "\n\n" : ""}` +
            `RAH Vision ${new Date().toLocaleString("no-NO")}:\n${answer}`;
          projectState.activity = [
            { text: "Raven Vision-analyse fullført", time: new Date().toISOString() },
            ...(projectState.activity || [])
          ].slice(0, 50);
          localStorage.setItem(key, JSON.stringify(projectState));
        }
      } catch (storageError) {
        console.warn("Kunne ikke synkronisere Vision til Project Brain", storageError);
      }
    } catch (error) {
      if (error.name === "AbortError") {
        result.textContent = "Analysen ble stoppet.";
        status.textContent = "Analyse stoppet.";
      } else {
        const message = friendlyNetworkError(error);
        result.textContent =
          `Kunne ikke analysere bildet.\n\n${message}\n\n` +
          `Kontroller at LM Studio kjører, at en vision-modell er lastet, og at CORS er aktivert.`;
        status.textContent = "Vision-analysen feilet.";
        lmState.textContent = "Feil";
        lmState.className = "sync-bad";
      }
    } finally {
      abortController = null;
      analyzeButton.disabled = false;
      stopButton.disabled = true;
    }
  }

  analyzeButton?.addEventListener("click", analyze);
  byId("rahTestVision")?.addEventListener("click", testConnection);
  byId("rahSaveVisionSettings")?.addEventListener("click", saveSettings);
  stopButton.addEventListener("click", () => abortController?.abort());

  modelSelect.addEventListener("change", () => {
    currentModel = modelSelect.value;
    settingsState.textContent = "Ikke lagret";
    settingsState.className = "";
  });
  endpointInput.addEventListener("input", () => {
    lmState.textContent = "Ikke testet";
    lmState.className = "";
    settingsState.textContent = "Ikke lagret";
    settingsState.className = "";
  });

  byId("rahClearVisionHistory").addEventListener("click", () => {
    localStorage.removeItem(HISTORY_KEY);
    renderHistory();
    notifyUser("Vision-historikken er tømt.");
  });

  const saveButton = byId("saveVision");
  saveButton?.addEventListener("click", () => {
    if (result.textContent && result.textContent !== "Analysen vises her.") {
      try {
        const key = "rah-raven-state-v1";
        const projectState = JSON.parse(localStorage.getItem(key) || "null");
        if (projectState && typeof projectState === "object") {
          projectState.brain =
            `${projectState.brain || ""}${projectState.brain ? "\n\n" : ""}` +
            `RAH Vision-resultat:\n${result.textContent}`;
          localStorage.setItem(key, JSON.stringify(projectState));
        }
      } catch (error) {
        console.warn(error);
      }
    }
  });

  if (saved.model) currentModel = saved.model;
  if (saved.endpoint || saved.model) {
    settingsState.textContent = "Lastet";
    settingsState.className = "sync-good";
  }

  renderHistory();
  status.textContent =
    "Vision v1.4 er klar. Velg et skjermbilde selv, skriv Vision-oppdraget og test LM Studio.";
})();