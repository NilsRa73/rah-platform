/* RAH Mission Engine v1.5
 * Resumable, local-first mission execution for the Command Center.
 * Uses the existing `state`, `saveState`, Project Brain and cloud-sync hooks.
 */
(() => {
  "use strict";

  const VERSION = "1.5.0";
  const MANUAL_ACTIONS = new Set([
    "open-project", "edit-index", "open-actions", "open-pages", "open-live",
    "open-vision", "focus-vision", "vision-issue", "open-studio", "focus-content",
    "review-content", "open-youtube", "open-chatgpt", "open-brief", "open-brain", "open-home"
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
    const exists = (state.missionHistory || []).some(item => item.id === mission.id && item.status === "COMPLETED");
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
    log(mission, "success", "Mission fullført og lagret i Project Brain.");
    persist(`Mission fullført: ${mission.title}`);
    notify("Mission fullført og lagret i Project Brain");
  }

  function nextPendingIndex(mission) {
    return mission.steps.findIndex(step => step.status !== "COMPLETED");
  }

  async function executeInternalAction(action, mission, step) {
    switch (action) {
      case "sync-project":
        if (typeof syncProjectBrain === "function") await syncProjectBrain();
        return "Project Brain, README og deploy-status ble synkronisert.";
      case "save-vision":
        document.getElementById("saveVision")?.click();
        return "Vision-notatet ble lagret i Project Brain.";
      case "copy-brief":
        if (typeof copyText === "function" && typeof buildRavenBrief === "function") {
          await copyText(buildRavenBrief());
        }
        return "Raven Brief ble kopiert til utklippstavlen.";
      case "create-project-task": {
        const title = step.detail || step.title;
        state.tasks = Array.isArray(state.tasks) ? state.tasks : [];
        if (!state.tasks.some(task => task.text === title && !task.done)) {
          state.tasks.push({ text: title, done: false, missionId: mission.id, createdAt: now() });
        }
        return `Oppgaven «${title}» ble lagt til i Project Brain.`;
      }
      case "save-mission-result": {
        const summary = buildMissionSummary(mission);
        appendBrainNote(mission, "Delresultat", summary);
        return "Mission-resultatet ble lagret i Project Brain.";
      }
      default:
        if (typeof executeMissionAction === "function") executeMissionAction(action);
        return MANUAL_ACTIONS.has(action)
          ? "Handlingen er åpnet. Fullfør den og trykk «Bekreft ferdig»."
          : "Handlingen ble utført.";
    }
  }

  async function startStep(index) {
    const mission = ensureMissionShape(state.activeMission);
    if (!mission || !mission.steps[index]) return;
    if (mission.status === "PAUSED") return notify("Mission er pauset");
    if (mission.status === "COMPLETED") return notify("Mission er allerede fullført");

    const step = mission.steps[index];
    if (step.status === "COMPLETED") return reopenStep(index);
    if (step.status === "WAITING") return completeStep(index);

    mission.status = "RUNNING";
    step.status = "RUNNING";
    step.startedAt = step.startedAt || now();
    step.attempts += 1;
    step.error = null;
    mission.currentStep = index;
    mission.updatedAt = now();
    log(mission, "info", `Starter: ${step.title}`, index);
    persist(`Mission-steg startet: ${step.title}`);
    renderMissions();

    try {
      const result = await executeInternalAction(step.action, mission, step);
      step.result = result;
      if (MANUAL_ACTIONS.has(step.action)) {
        step.status = "WAITING";
        mission.status = "WAITING";
        log(mission, "waiting", result, index);
        notify("Handlingen er åpnet — bekreft når den er ferdig");
      } else {
        completeStep(index, result);
        return;
      }
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

  function completeStep(index, explicitResult = "") {
    const mission = ensureMissionShape(state.activeMission);
    if (!mission || !mission.steps[index]) return;
    const step = mission.steps[index];
    step.status = "COMPLETED";
    step.done = true;
    step.completedAt = now();
    step.error = null;
    if (explicitResult) step.result = explicitResult;
    log(mission, "success", `Fullført: ${step.title}`, index);
    const next = nextPendingIndex(mission);
    mission.currentStep = next < 0 ? mission.steps.length : next;
    mission.status = next < 0 ? "COMPLETED" : "RUNNING";
    mission.updatedAt = now();
    if (next < 0) return finishMission(mission);
    persist(`Mission-steg fullført: ${step.title}`);
    renderMissions();
    notify("Steget er fullført");
  }

  function reopenStep(index) {
    const mission = ensureMissionShape(state.activeMission);
    if (!mission || !mission.steps[index]) return;
    const step = mission.steps[index];
    step.done = false;
    step.status = "PENDING";
    step.completedAt = null;
    mission.status = "RUNNING";
    mission.currentStep = index;
    mission.updatedAt = now();
    log(mission, "info", `Gjenåpnet: ${step.title}`, index);
    persist(`Mission-steg gjenåpnet: ${step.title}`);
    renderMissions();
  }

  function retryStep(index) {
    const mission = ensureMissionShape(state.activeMission);
    if (!mission || !mission.steps[index]) return;
    const step = mission.steps[index];
    step.status = "PENDING";
    step.error = null;
    mission.status = "RUNNING";
    startStep(index);
  }

  function runNext() {
    const mission = ensureMissionShape(state.activeMission);
    if (!mission) return notify("Velg en mission først");
    if (mission.status === "PAUSED") return notify("Mission er pauset");
    const waiting = mission.steps.findIndex(step => step.status === "WAITING");
    if (waiting >= 0) return completeStep(waiting);
    const next = nextPendingIndex(mission);
    if (next < 0) return finishMission(mission);
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
      `Opprettet fra RAH Raven Command Center v${VERSION}.`,
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
        : active ? "Kjør nå" : "Kjør";
      const handler = status === "FAILED" ? `window.rahMission.retry(${index})` : `window.rahMission.run(${index})`;
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
  window.renderMissions = function renderMissionsV15() {
    if (state.activeMission) ensureMissionShape(state.activeMission);
    oldRenderMissions?.();
    augmentMissionUI();
  };

  window.runMissionStep = startStep;
  window.runNextMissionStep = runNext;
  window.missionIssue = createIssueForMission;
  window.rahMission = {
    version: VERSION,
    run: startStep,
    next: runNext,
    complete: completeStep,
    reopen: reopenStep,
    retry: retryStep,
    issue: createIssueForMission,
    ensure: ensureMissionShape,
  };

  const nextButton = document.getElementById("runNextMissionStep");
  if (nextButton) nextButton.onclick = runNext;
  const issueButton = document.getElementById("missionToIssue");
  if (issueButton) issueButton.onclick = createIssueForMission;

  if (state.activeMission) {
    ensureMissionShape(state.activeMission);
    if (["RUNNING", "WAITING", "BLOCKED", "PAUSED"].includes(state.activeMission.status)) {
      log(state.activeMission, "info", "Mission gjenopprettet etter oppstart.");
      saveState();
    }
  }

  document.addEventListener("rah:cloud-sync-applied", () => {
    if (state.activeMission) ensureMissionShape(state.activeMission);
    window.renderMissions();
  });

  window.renderMissions();
  console.info(`RAH Mission Engine v${VERSION} ready`);
})();
