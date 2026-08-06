/* RAH Raven Chronicle Sync Core v0.1.0
 * Builds privacy-minimal Chronicle event payloads from local Raven records.
 * It never includes images, prompts, model answers, document text or command output.
 */
(function attachRavenChronicleSync(root, factory) {
  const api = factory();
  if (typeof module === "object" && module.exports) module.exports = api;
  root.RavenChronicleSyncCore = api;
})(typeof globalThis !== "undefined" ? globalThis : this, function createChronicleSyncCore() {
  "use strict";

  const VERSION = "0.1.0";
  const SYNC_KEY = "rah.raven.chronicle.sync.v1";
  const MAX_EVENTS = 50;
  const safe = (value, max = 220) => String(value ?? "").trim().slice(0, max);

  function eventId(kind, record) {
    return `${kind}:${safe(record?.id || record?.createdAt || record?.time || "unknown", 180)}`;
  }

  function visionEvent(record) {
    if (!record) return null;
    return {
      local_id: eventId("vision", record),
      title: "Raven Vision-analyse fullført",
      project: "RAH Raven Core",
      category: "vision",
      privacy: "private",
      note: [
        `Kilde: ${safe(record.source || "valgt bilde", 120)}`,
        `Modell: ${safe(record.model || "ukjent", 120)}`,
        `Tid: ${safe(record.createdAt || "ukjent", 80)}`,
        "Bilde lagret: nei",
        "Prompt og analysesvar lagret i Chronicle: nei"
      ].join("\n")
    };
  }

  function councilEvent(record) {
    if (!record) return null;
    return {
      local_id: eventId("council", record),
      title: "Raven Council fullført",
      project: safe(record.project || "RAH Platform", 160),
      category: "council",
      privacy: "private",
      note: [
        `Modell: ${safe(record.model || "ukjent", 120)}`,
        `Tid: ${safe(record.createdAt || "ukjent", 80)}`,
        `Roller: ${Object.keys(record.roles || {}).length + 1}`,
        `Planpunkter: ${Array.isArray(record.plan) ? record.plan.length : 0}`,
        "Mål, rådsinnhold og modellsvaret lagret i Chronicle: nei"
      ].join("\n")
    };
  }

  function agentEvent(record) {
    if (!record) return null;
    return {
      local_id: eventId("agent", record),
      title: `Agent Runner: ${safe(record.title || record.capabilityId || "capability", 150)}`,
      project: "RAH Platform",
      category: "agent-runner",
      privacy: "private",
      note: [
        `Status: ${record.ok ? "OK" : "FEIL"}`,
        `Tid: ${safe(record.time || "ukjent", 80)}`,
        `Varighet: ${Number(record.durationMs || 0)} ms`,
        `Read only: ${record.readOnly === true ? "ja" : "ukjent"}`,
        `Prosjektfiler endret: ${record.filesModified === true ? "ja" : "nei"}`,
        "Kommando-output og feillogg lagret i Chronicle: nei"
      ].join("\n")
    };
  }

  function missionEvent(mission) {
    if (!mission || !mission.id) return null;
    return {
      local_id: `mission:${safe(mission.id, 180)}`,
      title: "Raven Mission oppdatert",
      project: "RAH Platform",
      category: "mission",
      privacy: "private",
      note: [
        `Status: ${safe(mission.status || "ukjent", 40)}`,
        `Steg: ${Array.isArray(mission.steps) ? mission.steps.length : 0}`,
        `Oppdatert: ${safe(mission.updatedAt || mission.createdAt || "ukjent", 80)}`,
        "Mission-tittel, oppgaveinnhold og resultater lagret i Chronicle: nei"
      ].join("\n")
    };
  }

  function buildEvents(input = {}) {
    const events = [];
    const add = event => { if (event) events.push(event); };
    add(visionEvent(input.vision));
    add(councilEvent(input.council));
    add(agentEvent(input.agent));
    add(missionEvent(input.mission));
    return events.slice(0, MAX_EVENTS);
  }

  function unsynced(events, syncedIds = []) {
    const known = new Set(Array.isArray(syncedIds) ? syncedIds.map(String) : []);
    return (Array.isArray(events) ? events : []).filter(event => event?.local_id && !known.has(event.local_id));
  }

  function toChroniclePayload(event) {
    if (!event?.title) throw new Error("Ugyldig Chronicle-hendelse.");
    return {
      title: safe(event.title, 220),
      project: safe(event.project, 160),
      category: safe(event.category || "note", 60),
      privacy: "private",
      note: safe(event.note, 4000)
    };
  }

  return Object.freeze({
    VERSION,
    SYNC_KEY,
    visionEvent,
    councilEvent,
    agentEvent,
    missionEvent,
    buildEvents,
    unsynced,
    toChroniclePayload
  });
});
