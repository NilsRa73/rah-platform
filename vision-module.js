(() => {
  "use strict";

  const LM_BASE = "http://127.0.0.1:1234";
  const BRIDGE_BASE = "http://127.0.0.1:8765";
  const HISTORY_KEY = "rah-raven-vision-history-v1";

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

  const fileInput = replaceNode("visionFile");
  const analyzeButton = replaceNode("analyzeVision");
  const oldCapture = byId("captureActiveWindow");
  if (oldCapture) oldCapture.remove();

  const controls = document.createElement("div");
  controls.className = "row";
  controls.style.marginTop = "10px";
  controls.innerHTML = `
    <button class="btn" id="rahCaptureWindow">🪟 Hent aktivt vindu</button>
    <button class="btn" id="rahCaptureScreen">🖥️ Del skjerm/vindu</button>
    <button class="btn" id="rahTestVision">🔌 Test forbindelser</button>
    <a class="btn" href="vision.html">↗ Åpne full Vision</a>
  `;
  dropZone.insertAdjacentElement("afterend", controls);

  const diagnostics = document.createElement("section");
  diagnostics.className = "panel full";
  diagnostics.style.marginTop = "15px";
  diagnostics.innerHTML = `
    <div class="row between">
      <div>
        <h2>🔧 Vision v1.3 status</h2>
        <div class="meta">Integrert LM Studio, Desktop Bridge og skjermdeling.</div>
      </div>
      <span class="pill" id="rahVisionVersion">v1.3</span>
    </div>
    <div class="quick-grid" style="margin-top:12px">
      <div class="quick"><span>🧠</span><strong id="rahLmState">Ikke testet</strong><small>LM Studio</small></div>
      <div class="quick"><span>🌉</span><strong id="rahBridgeState">Ikke testet</strong><small>Desktop Bridge</small></div>
      <div class="quick"><span>🖼️</span><strong id="rahImageState">Ingen bilde</strong><small>Felles bildestatus</small></div>
    </div>
    <div class="row" style="margin-top:12px">
      <select id="rahVisionModel" style="flex:1;min-width:260px"><option value="">Oppdager modeller automatisk…</option></select>
      <button class="btn danger" id="rahStopVision" disabled>Stopp analyse</button>
      <button class="btn" id="rahClearVisionHistory">Tøm historikk</button>
    </div>
    <div id="rahVisionHistory" style="margin-top:12px"></div>
  `;
  byId("vision").querySelector(".grid").appendChild(diagnostics);

  const modelSelect = byId("rahVisionModel");
  const stopButton = byId("rahStopVision");
  const lmState = byId("rahLmState");
  const bridgeState = byId("rahBridgeState");
  const imageState = byId("rahImageState");

  function setImage(data, label) {
    imageData = data || "";
    window.rahVisionImageData = imageData;
    if (imageData) {
      preview.src = imageData;
      preview.style.display = "block";
      imageState.textContent = label || "Bilde klart";
      notifyUser(`${label || "Bildet"} er klart for analyse.`);
    } else {
      preview.removeAttribute("src");
      preview.style.display = "none";
      imageState.textContent = "Ingen bilde";
      notifyUser("Ingen skjermbilde valgt.");
    }
  }

  function readFile(file) {
    if (!file) return;
    if (!file.type.startsWith("image/")) {
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
    const response = await fetch(url, { cache: "no-store", ...options });
    if (!response.ok) {
      const body = await response.text().catch(() => "");
      throw new Error(`${response.status} ${response.statusText}${body ? `: ${body.slice(0, 300)}` : ""}`);
    }
    return response.json();
  }

  async function discoverModels() {
    modelSelect.innerHTML = '<option value="">Søker etter modeller…</option>';
    try {
      const payload = await fetchJson(`${LM_BASE}/v1/models`);
      const models = Array.isArray(payload.data) ? payload.data : [];
      if (!models.length) throw new Error("Ingen modell er lastet inn.");
      modelSelect.innerHTML = models.map(model => `<option value="${String(model.id).replace(/"/g, "&quot;")}">${model.id}</option>`).join("");
      currentModel = models[0].id;
      modelSelect.value = currentModel;
      lmState.textContent = `Klar: ${currentModel}`;
      lmState.className = "sync-good";
      return currentModel;
    } catch (error) {
      currentModel = "";
      modelSelect.innerHTML = '<option value="">LM Studio ikke tilgjengelig</option>';
      lmState.textContent = "Frakoblet";
      lmState.className = "sync-bad";
      throw error;
    }
  }

  async function testBridge() {
    try {
      await fetchJson(`${BRIDGE_BASE}/health`);
      bridgeState.textContent = "Klar på port 8765";
      bridgeState.className = "sync-good";
      return true;
    } catch (error) {
      bridgeState.textContent = "Ikke startet";
      bridgeState.className = "sync-bad";
      throw error;
    }
  }

  async function testConnections() {
    status.textContent = "Tester LM Studio og Desktop Bridge…";
    const [lm, bridge] = await Promise.allSettled([discoverModels(), testBridge()]);
    const messages = [];
    messages.push(lm.status === "fulfilled" ? "LM Studio er klart." : `LM Studio: ${lm.reason?.message || "feil"}`);
    messages.push(bridge.status === "fulfilled" ? "Desktop Bridge er klart." : `Desktop Bridge: ${bridge.reason?.message || "ikke startet"}`);
    status.textContent = messages.join(" ");
  }

  async function captureActiveWindow() {
    notifyUser("Henter aktivt vindu fra Desktop Bridge…");
    try {
      const payload = await fetchJson(`${BRIDGE_BASE}/capture/active-window`);
      const data = payload.image || payload.imageData || payload.dataUrl || payload.screenshot;
      if (!data) throw new Error("Bridge returnerte ikke et bilde.");
      setImage(data, payload.window_title || "Aktivt vindu");
      bridgeState.textContent = "Fangst fullført";
      bridgeState.className = "sync-good";
    } catch (error) {
      bridgeState.textContent = "Fangst feilet";
      bridgeState.className = "sync-bad";
      result.textContent = `Desktop Bridge kunne ikke hente vinduet.\n\nStart desktop-bridge/start-bridge.bat og prøv igjen.\n\nFeil: ${error.message}`;
      notifyUser("Kunne ikke hente aktivt vindu.");
    }
  }

  async function captureSharedScreen() {
    if (!navigator.mediaDevices?.getDisplayMedia) {
      notifyUser("Denne nettleseren støtter ikke skjermdeling.");
      return;
    }
    let stream;
    try {
      stream = await navigator.mediaDevices.getDisplayMedia({ video: true, audio: false });
      const video = document.createElement("video");
      video.srcObject = stream;
      video.muted = true;
      await video.play();
      await new Promise(resolve => setTimeout(resolve, 250));
      const canvas = document.createElement("canvas");
      canvas.width = video.videoWidth;
      canvas.height = video.videoHeight;
      canvas.getContext("2d").drawImage(video, 0, 0);
      setImage(canvas.toDataURL("image/png"), "Delt skjerm/vindu");
    } catch (error) {
      notifyUser(error.name === "NotAllowedError" ? "Skjermdeling ble avbrutt." : `Skjermdeling feilet: ${error.message}`);
    } finally {
      stream?.getTracks().forEach(track => track.stop());
    }
  }

  function history() {
    try { return JSON.parse(localStorage.getItem(HISTORY_KEY) || "[]"); }
    catch { return []; }
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
        <div><strong>${new Date(item.time).toLocaleString("no-NO")}</strong><div class="meta">${String(item.prompt).replace(/[&<>]/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;"}[c])).slice(0, 120)}</div></div>
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
      notifyUser("Velg eller hent først et skjermbilde.");
      return;
    }

    const prompt = note.value.trim() || "Les skjermbildet. Forklar kort hva du ser, finn problemet, og gi nummererte klikk-for-klikk-instruksjoner på norsk.";
    let model = modelSelect.value || currentModel;
    if (!model) {
      try { model = await discoverModels(); }
      catch (error) {
        result.textContent = `LM Studio er ikke klart.\n\n1. Åpne LM Studio.\n2. Last inn en vision-modell.\n3. Start Local Server på port 1234.\n4. Aktiver CORS.\n\nFeil: ${error.message}`;
        notifyUser("LM Studio er ikke tilgjengelig.");
        return;
      }
    }

    abortController = new AbortController();
    analyzeButton.disabled = true;
    stopButton.disabled = false;
    status.textContent = `Raven analyserer med ${model}…`;
    result.textContent = "Analyserer skjermbildet lokalt…";

    try {
      const payload = await fetchJson(`${LM_BASE}/v1/chat/completions`, {
        method: "POST",
        signal: abortController.signal,
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          model,
          temperature: 0.2,
          max_tokens: 1400,
          messages: [
            { role: "system", content: "Du er RAH Raven Vision. Svar på norsk. Vær rolig, konkret og nybegynnervennlig. Beskriv synlige knapper og nøyaktig hvor brukeren skal klikke. Ikke gjett når tekst er uleselig." },
            { role: "user", content: [
              { type: "text", text: prompt },
              { type: "image_url", image_url: { url: imageData } }
            ] }
          ]
        })
      });
      const answer = payload?.choices?.[0]?.message?.content;
      if (!answer) throw new Error("Modellen returnerte ikke et lesbart svar.");
      result.textContent = answer;
      status.textContent = "Analysen er ferdig og lagret lokalt.";
      saveHistory({ id: crypto.randomUUID ? crypto.randomUUID() : String(Date.now()), time: new Date().toISOString(), prompt, answer, model });
      try {
        const key = "rah-raven-state-v1";
        const projectState = JSON.parse(localStorage.getItem(key) || "null");
        if (projectState && typeof projectState === "object") {
          projectState.visionNote = prompt;
          projectState.brain = `${projectState.brain || ""}${projectState.brain ? "\n\n" : ""}RAH Vision ${new Date().toLocaleString("no-NO")}:\n${answer}`;
          projectState.activity = [{ text: "Raven Vision-analyse fullført", time: new Date().toISOString() }, ...(projectState.activity || [])].slice(0, 50);
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
        result.textContent = `Kunne ikke analysere bildet.\n\nKontroller at LM Studio kjører på port 1234, at en vision-modell er lastet, og at CORS er aktivert.\n\nFeil: ${error.message}`;
        status.textContent = "Vision-analysen feilet.";
      }
    } finally {
      abortController = null;
      analyzeButton.disabled = false;
      stopButton.disabled = true;
    }
  }

  analyzeButton?.addEventListener("click", analyze);
  byId("rahCaptureWindow").addEventListener("click", captureActiveWindow);
  byId("rahCaptureScreen").addEventListener("click", captureSharedScreen);
  byId("rahTestVision").addEventListener("click", testConnections);
  stopButton.addEventListener("click", () => abortController?.abort());
  modelSelect.addEventListener("change", () => { currentModel = modelSelect.value; });
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
          projectState.brain = `${projectState.brain || ""}${projectState.brain ? "\n\n" : ""}RAH Vision-resultat:\n${result.textContent}`;
          localStorage.setItem(key, JSON.stringify(projectState));
        }
      } catch (error) { console.warn(error); }
    }
  });

  renderHistory();
  discoverModels().catch(() => {});
  testBridge().catch(() => {});
  status.textContent = "Vision v1.3 er integrert. Velg et bilde, hent et vindu eller del skjermen.";
})();
