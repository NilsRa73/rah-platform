/* RAH Mission Engine v1.6
 * Resumable, local-first mission execution for the Command Center.
 * Explicit execution and completion boundaries: no mission step is auto-completed.
 */
(() => {
  "use strict";

  const VERSION = "1.6.0";
  const MANUAL_ACTIONS = new Set([
    "open-project", "edit-index", "open-actions", "open-pages", "open-live",
    "open-vision", "focus-vision", "vision-issue", "open-studio", "focus-content",
    "review-content", "open-youtube", "open-chatgpt", "open-brief", "open-brain", "open-home"
  ]);
  const INTERNAL_ACTIONS = new Set([
    "sync-project", "save-vision", "copy-brief", "create-project-task", "save-mission-result"
  ]);

  const now = () => new Date().toISOString();
  const safeText = value => String(value ?? "").trim();

  function ensureMissionShape(mission) {
    if (!mission || typeof mission !== "object") return null;
    mission.engineVersion = VERSION;
    mission.logs = Array.isArray(mission.logs) ? mission.logs : [];
    mission.results = Array.isArray(mission.results) ? mission.results : [];
    mission.updatedAt = mission.updatedAt || now();
    mission.steps = Array.isArray(mission.steps) ? mission.steps : [];
    mission.steps.forEach((step, index) => {
      step.id = step.id || `${mission.id || "mission"}-step-${index + 1}`;
      step.status = step.done ? "COMPLETED" : (step.status || "PENDING");
      step.result = safeText(step.result);
      step.attempts = Number.isFinite(step.attempts) ? step.attempts : 0;
      step.startedAt = step.startedAt || null;
      step.completedAt = step.completedAt || null;
      step.error = step.error || null;
    });
    return mission;
  }

  function persist(message) {
    if (state.activeMission) ensureMissionShape(state.activeMission);
    saveState();
    if (message && typeof addActivity === "function") addActivity(message);
    document.dispatchEvent(new CustomEvent("rah:mission-change", {
      detail: { mission: state.activeMission, time: now() }
    }));
  }

  function log(mission, type, text, stepIndex = null) {
    mission.logs.unshift({ type, text, stepIndex, time: now() });
    mission.logs = mission.logs.slice(0, 100);
  }

  function activeProject() {
    return state.projects?.[state.activeProject] || state.projects?.[0] || null;
  }

  function appendBrainNote(mission, heading, body) {
    const project = activeProject();
    const block = [
      `## Mission: ${mission.title}`,
      `Dato: ${new Date().toLocaleString("no-NO")}`,
      project ? `Prosjekt: ${project.name}` : "",
      heading ? `Resultat: ${heading}` : "",
      body || "",
    ].filter(Boolean).join("\n");
    const existing = safeText(state.brain);
    state.brain = existing ? `${existing}\n\n${block}` : block;
  }

  function buildMissionSummary(mission) {
    const steps = mission.steps.map((step, index) => {
      const mark = step.status === "COMPLETED" ? "[x]" : step.status === "WAITING" ? "[~]" : "[ ]";
      const result = step.result ? `\n   Resultat: ${step.result}` : "";
      return `${mark} ${index + 1}. ${step.title}${result}`;
    });
    return [
      `Status: ${mission.status}`,
      `Fremdrift: ${typeof missionCompletion === "function" ? missionCompletion(mission) : 0}%`,
      ...steps,
    ].join("\n");
  }

  function finishMission(mission) {
    mission.status = "COMPLETED";
    mission.currentStep = mission.steps.length;
    mission.finishedAt = now();
    mission.updatedAt = mission.finishedAt;
    const summary = buildMissionSummary(mission);
    mission.results.unshift({ title: "Mission fullført", body: summary, time: now() });
    appendBrainNote(mission, "Mission fullført", summary);
    state.missionHistory = Array.isArray(state.missionHistory) ? state.missionHistory : [];
    const exists = state.missionHistory.some(item => item.id === mission.id && item.status === "COMPLETED");
    if (!exists) {
      state.missionHistory.unshift({
        id: mission.id,
        title: mission.title,
        status: "COMPLETED",
        progress: 100,
        createdAt: mission.createdAt,
        finishedAt: mission.finishedAt,
        summary,
      });
      state.missionHistory = state.missionHistory.slice(0, 30);
    }
    log(mission, "success", "Mission fullført etter eksplisitt ferdig-bekreftelse.");
    persist(`Mission fullført: ${mission.title}`);
    notify("Mission fullført og lagret i Project Brain");
  }

  function nextPendingIndex(mission) {
    return mission.steps.findIndex(step => step.status !== "COMPLETED");
  }

  function confirmationText(step) {
    return [
      "Kjør dette mission-steget nå?",
      "",
      safeText(step.title),
      safeText(step.detail),
      "",
      "Handlingen kjøres bare denne gangen. Steget blir IKKE markert ferdig automatisk."
    ].filter(Boolean).join("\n");
  }

  async function executeConfirmedAction(action, mission, step) {
    if (MANUAL_ACTIONS.has(action)) {
      if (typeof executeMissionAction !== "function") {
        throw new Error("Mission action-handler er ikke tilgjengelig.");
      }
      executeMissionAction(action);
      return "Handlingen er åpnet. Fullfør den og trykk «Bekreft ferdig».";
    }

    if (!INTERNAL_ACTIONS.has(action)) {
      throw new Error(`Mission action er ikke tillatt: ${safeText(action) || "ukjent"}`);
    }

    switch (action) {
      case "sync-project":
        if (typeof syncProjectBrain !== "function") throw new Error("Project Sync er ikke tilgjengelig.");
        await syncProjectBrain();
        return "Project Brain, README og deploy-status ble synkronisert etter eksplisitt bekreftelse.";
      case "save-vision": {
        const button = document.getElementById("saveVision");
        if (!button) throw new Error("Vision-lagring er ikke tilgjengelig.");
        button.click();
        return "Vision-notatet ble lagret i Project Brain etter eksplisitt bekreftelse.";
      }
      case "copy-brief":
        if (typeof copyText !== "function" || typeof buildRavenBrief !== "function") {
          throw new Error("Raven Brief-kopiering er ikke tilgjengelig.");
        }
        await copyText(buildRavenBrief());
        return "Raven Brief ble kopiert til utklippstavlen etter eksplisitt bekreftelse.";
      case "create-project-task": {
        const title = step.detail || step.title;
        state.tasks = Array.isArray(state.tasks) ? state.tasks : [];
        if (!state.tasks.some(task => task.text === title && !task.done)) {
          state.tasks.push({ text: title, done: false, missionId: mission.id, createdAt: now() });
        }
        return `Oppgaven «${title}» ble lagt til i Project Brain etter eksplisitt bekreftelse.`;
      }
      case "save-mission-result": {
        const summary = buildMissionSummary(mission);
        appendBrainNote(mission, "Delresultat", summary);
        return "Mission-resultatet ble lagret i Project Brain etter eksplisitt bekreftelse.";
      }
      default:
        throw new Error(`Mission action er ikke tillatt: ${safeText(action) || "ukjent"}`);
    }
  }

  async function startStep(index, options = {}) {
    const mission = ensureMissionShape(state.activeMission);
    if (!mission || !mission.steps[index]) return;
    if (mission.status === "PAUSED") return notify("Mission er pauset");
    if (mission.status === "COMPLETED") return notify("Mission er allerede fullført");

    const step = mission.steps[index];
    if (step.status === "COMPLETED") return reopenStep(index);
    if (step.status === "WAITING") return notify("Steget venter på eksplisitt «Bekreft ferdig».");
    if (step.status === "FAILED" && !options.retryConfirmed) return retryStep(index);

    const confirmed = options.retryConfirmed === true || window.confirm(confirmationText(step));
    if (!confirmed) {
      notify("Mission-steget ble ikke kjørt");
      return;
    }

    mission.status = "RUNNING";
    step.status = "RUNNING";
    step.startedAt = step.startedAt || now();
    step.attempts += 1;
    step.error = null;
    mission.currentStep = index;
    mission.updatedAt = now();
    log(mission, "info", `Eksplisitt bekreftet kjøring: ${step.title}`, index);
    persist(`Mission-steg bekreftet og startet: ${step.title}`);
    renderMissions();

    try {
      const result = await executeConfirmedAction(step.action, mission, step);
      step.result = result;
      step.status = "WAITING";
      mission.status = "WAITING";
      log(mission, "waiting", `${result} Venter på separat ferdig-bekreftelse.`, index);
      notify("Handlingen er utført — steget venter på «Bekreft ferdig»");
    } catch (error) {
      step.status = "FAILED";
      step.error = error?.message || String(error);
      mission.status = "BLOCKED";
      log(mission, "error", step.error, index);
      notify(`Steget feilet: ${step.error}`);
    }
    mission.updatedAt = now();
    persist();
    renderMissions();
  }

  function completeStep(index) {
    const mission = ensureMissionShape(state.activeMission);
    if (!mission || !mission.steps[index]) return;
    const step = mission.steps[index];
    if (step.status !== "WAITING") {
      return notify("Steget kan bare fullføres etter en eksplisitt bekreftet kjøring.");
    }
    const confirmed = window.confirm(`Marker «${safeText(step.title)}» som ferdig?\n\nDette er en separat ferdig-bekreftelse.`);
    if (!confirmed) {
      notify("Steget ble ikke markert ferdig");
      return;
    }

    step.status = "COMPLETED";
    step.done = true;
    step.completedAt = now();
    step.error = null;
    log(mission, "success", `Eksplisitt bekreftet ferdig: ${step.title}`, index);
    const next = nextPendingIndex(mission);
    mission.currentStep = next < 0 ? mission.steps.length : next;
    mission.status = next < 0 ? "COMPLETED" : "RUNNING";
    mission.updatedAt = now();
    if (next < 0) return finishMission(mission);
    persist(`Mission-steg eksplisitt fullført: ${step.title}`);
    renderMissions();
    notify("Steget er fullført");
  }

  function reopenStep(index) {
    const mission = ensureMissionShape(state.activeMission);
    if (!mission || !mission.steps[index]) return;
    const step = mission.steps[index];
    const confirmed = window.confirm(`Gjenåpne «${safeText(step.title)}»?`);
    if (!confirmed) return;
    step.done = false;
    step.status = "PENDING";
    step.completedAt = null;
    mission.status = "RUNNING";
    mission.currentStep = index;
    mission.updatedAt = now();
    log(mission, "info", `Eksplisitt gjenåpnet: ${step.title}`, index);
    persist(`Mission-steg gjenåpnet: ${step.title}`);
    renderMissions();
  }

  function retryStep(index) {
    const mission = ensureMissionShape(state.activeMission);
    if (!mission || !mission.steps[index]) return;
    const step = mission.steps[index];
    const confirmed = window.confirm(`Prøv «${safeText(step.title)}» igjen og kjør handlingen?`);
    if (!confirmed) return;
    step.status = "PENDING";
    step.error = null;
    mission.status = "RUNNING";
    startStep(index, { retryConfirmed: true });
  }

  function runNext() {
    const mission = ensureMissionShape(state.activeMission);
    if (!mission) return notify("Velg en mission først");
    if (mission.status === "PAUSED") return notify("Mission er pauset");
    if (mission.status === "COMPLETED") return notify("Mission er allerede fullført");
    const waiting = mission.steps.findIndex(step => step.status === "WAITING");
    if (waiting >= 0) {
      mission.currentStep = waiting;
      renderMissions();
      return notify("Neste steg er låst til du eksplisitt bekrefter det ventende steget som ferdig.");
    }
    const next = nextPendingIndex(mission);
    if (next < 0) return notify("Alle mission-steg er allerede fullført.");
    startStep(next);
  }

  function createIssueForMission() {
    const mission = ensureMissionShape(state.activeMission);
    if (!mission) return notify("Ingen aktiv mission");
    const body = [
      `Mission: ${mission.title}`,
      `Status: ${mission.status}`,
      `Fremdrift: ${missionCompletion(mission)}%`,
      "",
      "Steg:",
      ...mission.steps.map((step, index) => {
        const mark = step.status === "COMPLETED" ? "[x]" : "[ ]";
        return `${mark} ${index + 1}. ${step.title} — ${step.detail}${step.result ? `\n   Resultat: ${step.result}` : ""}`;
      }),
      "",
      `Mission-ID: ${mission.id}`,
      `Opprettet fra RAH Raven Command Center / Mission Engine v${VERSION}.`,
    ].join("\n");
    openPrefilledIssue(`Mission: ${mission.title}`, body);
    log(mission, "info", "GitHub Issue-skjema åpnet med ferdig mission-rapport.");
    persist();
  }

  function augmentMissionUI() {
    const mission = ensureMissionShape(state.activeMission);
    const container = document.getElementById("missionSteps");
    if (!container || !mission) return;

    container.innerHTML = mission.steps.map((step, index) => {
      const status = step.status || (step.done ? "COMPLETED" : "PENDING");
      const active = index === mission.currentStep && status !== "COMPLETED";
      const label = status === "WAITING" ? "Bekreft ferdig"
        : status === "FAILED" ? "Prøv igjen"
        : status === "COMPLETED" ? "Åpne igjen"
        : active ? "Kjør med bekreftelse" : "Kjør";
      const handler = status === "WAITING" ? `window.rahMission.complete(${index})`
        : status === "FAILED" ? `window.rahMission.retry(${index})`
        : status === "COMPLETED" ? `window.rahMission.reopen(${index})`
        : `window.rahMission.run(${index})`;
      return `<div class="mission-step ${status === "COMPLETED" ? "done" : ""} ${active ? "active" : ""}">
        <div class="step-number">${status === "COMPLETED" ? "✓" : index + 1}</div>
        <div>
          <strong>${esc(step.title)}</strong>
          <div class="meta">${esc(step.detail)}</div>
          <div class="meta">Status: ${esc(status)}${step.attempts ? ` • Forsøk: ${step.attempts}` : ""}</div>
          ${step.result ? `<div class="meta sync-good">${esc(step.result)}</div>` : ""}
          ${step.error ? `<div class="meta sync-bad">${esc(step.error)}</div>` : ""}
        </div>
        <button class="btn" onclick="${handler}">${label}</button>
      </div>`;
    }).join("");

    let logPanel = document.getElementById("missionExecutionLog");
    if (!logPanel) {
      logPanel = document.createElement("section");
      logPanel.className = "panel full";
      logPanel.innerHTML = `<h2>📜 Mission-logg</h2><div id="missionExecutionLogBody"></div>`;
      document.getElementById("missionHistory")?.closest("section")?.insertAdjacentElement("beforebegin", logPanel);
    }
    const logBody = document.getElementById("missionExecutionLogBody");
    if (logBody) {
      logBody.innerHTML = mission.logs.slice(0, 12).map(item => `
        <div class="list-item"><div><strong>${esc(item.text)}</strong>
        <div class="meta">${new Date(item.time).toLocaleString("no-NO")} • ${esc(item.type.toUpperCase())}</div></div></div>`
      ).join("") || "<p>Ingen kjøringer ennå.</p>";
    }
  }

  const oldRenderMissions = window.renderMissions;
  window.renderMissions = function renderMissionsV16() {
    if (state.activeMission) ensureMissionShape(state.activeMission);
    oldRenderMissions?.();
    augmentMissionUI();
  };

  window.runMissionStep = startStep;
  window.runNextMissionStep = runNext;
  window.missionIssue = createIssueForMission;
  window.rahMission = Object.freeze({
    version: VERSION,
    explicitExecutionOnly: true,
    executionRequiresConfirmation: true,
    completionRequiresConfirmation: true,
    automaticStepCompletion: false,
    runNextCompletesWaitingStep: false,
    unknownActionsRejected: true,
    automaticStartupWrite: false,
    run: startStep,
    next: runNext,
    complete: completeStep,
    reopen: reopenStep,
    retry: retryStep,
    issue: createIssueForMission,
    ensure: ensureMissionShape,
  });

  const nextButton = document.getElementById("runNextMissionStep");
  if (nextButton) nextButton.onclick = runNext;
  const issueButton = document.getElementById("missionToIssue");
  if (issueButton) issueButton.onclick = createIssueForMission;

  // Restore shape in memory only. Startup must never run or complete a step, nor persist state.
  if (state.activeMission) ensureMissionShape(state.activeMission);

  document.addEventListener("rah:cloud-sync-applied", () => {
    if (state.activeMission) ensureMissionShape(state.activeMission);
    window.renderMissions();
  });

  window.renderMissions();
  console.info(`RAH Mission Engine v${VERSION} ready — explicit execution and completion boundaries active`);
})();
