/* RAH Raven Vision Core v0.6.0
 * Pure helpers for endpoint configuration, records and Project Brain handoff.
 * Images are never stored by this module.
 */
(function attachRavenVisionCore(root, factory) {
  const api = factory();
  if (typeof module === "object" && module.exports) module.exports = api;
  root.RavenVisionCore = api;
})(typeof globalThis !== "undefined" ? globalThis : this, function createRavenVisionCore() {
  "use strict";

  const VERSION = "0.6.0";
  const DEFAULT_BRIDGE_BASE = "http://127.0.0.1:18765";
  const STATE_KEY = "rah.command.center";

  const safeText = (value, max = 12000) => String(value ?? "").trim().slice(0, max);

  function isLoopbackBase(value) {
    const candidate = safeText(value, 500);
    if (!candidate) return false;
    try {
      const parsed = new URL(candidate);
      const host = parsed.hostname.toLowerCase();
      return (parsed.protocol === "http:" || parsed.protocol === "https:") &&
        !parsed.username && !parsed.password &&
        (host === "127.0.0.1" || host === "localhost" || host === "[::1]" || host === "::1");
    } catch {
      return false;
    }
  }

  function normalizeBase(value, fallback = DEFAULT_BRIDGE_BASE) {
    const candidate = safeText(value, 500) || fallback;
    if (!isLoopbackBase(candidate)) throw new Error("Vision Bridge må bruke lokal loopback-adresse.");
    return candidate.replace(/\/+$/, "");
  }

  function endpoints(base = DEFAULT_BRIDGE_BASE) {
    const root = normalizeBase(base);
    return Object.freeze({
      base: root,
      health: `${root}/health`,
      captureActiveWindow: `${root}/capture/active-window`,
      captureAfterDelay: seconds => `${root}/capture/after-delay?seconds=${Math.max(1, Math.min(10, Number(seconds) || 3))}`,
      models: `${root}/lm/models`,
      analyze: `${root}/lm/analyze`
    });
  }

  function createVisionRecord(input = {}) {
    const createdAt = new Date().toISOString();
    return {
      id: `vision-${Date.now()}`,
      version: VERSION,
      createdAt,
      source: safeText(input.source, 300) || "ukjent kilde",
      prompt: safeText(input.prompt, 5000),
      answer: safeText(input.answer, 20000),
      model: safeText(input.model, 300),
      metadata: input.metadata && typeof input.metadata === "object" ? structuredClone(input.metadata) : {},
      imageStored: false
    };
  }

  function applyVisionToRahState(currentState, record) {
    if (!record || !safeText(record.answer)) throw new Error("Vision-resultatet er tomt.");
    const state = currentState && typeof currentState === "object" ? structuredClone(currentState) : {};
    state.brain = safeText(state.brain, 100000);
    state.activity = Array.isArray(state.activity) ? state.activity : [];
    state.visionHistory = Array.isArray(state.visionHistory) ? state.visionHistory : [];
    state.visionNote = record.prompt;

    const block = [
      `## Raven Vision: ${record.source}`,
      `Dato: ${record.createdAt}`,
      record.model ? `Modell: ${record.model}` : "",
      record.prompt ? `Oppdrag: ${record.prompt}` : "",
      "",
      record.answer
    ].filter(Boolean).join("\n");
    state.brain = state.brain ? `${state.brain}\n\n${block}` : block;
    state.visionHistory.unshift(record);
    state.visionHistory = state.visionHistory.slice(0, 30);
    state.activity.unshift({ text: `Raven Vision fullført: ${record.source}`, time: record.createdAt });
    state.activity = state.activity.slice(0, 50);

    if (state.activeMission && typeof state.activeMission === "object") {
      const mission = state.activeMission;
      mission.results = Array.isArray(mission.results) ? mission.results : [];
      mission.logs = Array.isArray(mission.logs) ? mission.logs : [];
      mission.results.unshift({
        title: `Vision-analyse: ${record.source}`,
        body: record.answer,
        time: record.createdAt,
        visionId: record.id
      });
      mission.logs.unshift({
        type: "info",
        text: `Vision-analyse lagret: ${record.source}`,
        stepIndex: Number.isInteger(mission.currentStep) ? mission.currentStep : null,
        time: record.createdAt
      });
      mission.updatedAt = record.createdAt;
    }
    return state;
  }

  function visionMarkdown(record) {
    if (!record) return "";
    const metadata = Object.keys(record.metadata || {}).length
      ? `\n## Metadata\n\n\`\`\`json\n${JSON.stringify(record.metadata, null, 2)}\n\`\`\``
      : "";
    return [
      "# RAH Raven Vision",
      `Dato: ${record.createdAt || ""}`,
      `Kilde: ${record.source || ""}`,
      `Modell: ${record.model || "ukjent"}`,
      `Bilde lagret: ${record.imageStored ? "ja" : "nei"}`,
      `\n## Oppdrag\n\n${record.prompt || ""}`,
      `## Analyse\n\n${record.answer || ""}`,
      metadata,
      "\n---\nRaven Vision analyserer bare bilder som brukeren eksplisitt velger, laster opp eller fanger."
    ].join("\n\n");
  }

  return Object.freeze({
    VERSION,
    DEFAULT_BRIDGE_BASE,
    STATE_KEY,
    isLoopbackBase,
    normalizeBase,
    endpoints,
    createVisionRecord,
    applyVisionToRahState,
    visionMarkdown
  });
});
