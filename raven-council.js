/* RAH Raven Council Core v0.1.0
 * Pure planning and handoff helpers for the local-first Raven Council.
 * No network, DOM or file-system access lives in this module.
 */
(function attachRavenCouncil(root, factory) {
  const api = factory();
  if (typeof module === "object" && module.exports) module.exports = api;
  root.RavenCouncilCore = api;
})(typeof globalThis !== "undefined" ? globalThis : this, function createRavenCouncilCore() {
  "use strict";

  const VERSION = "0.1.0";
  const ROLE_ORDER = ["archivist", "planner", "builder", "reviewer", "safety"];
  const ROLES = Object.freeze({
    archivist: {
      name: "Archivist Raven",
      icon: "🗄️",
      purpose: "Finn eksisterende arbeid, beslutninger, filer, versjoner og manglende kilder.",
      system: "Du er Archivist Raven. Finn hva som allerede finnes, hva som er gjeldende, hvilke antakelser som mangler kilde, og hva som ikke bør bygges på nytt. Svar kort på norsk. Skill tydelig mellom dokumentert, sannsynlig og ukjent."
    },
    planner: {
      name: "Planner Raven",
      icon: "🧭",
      purpose: "Bryt målet ned i riktig rekkefølge med avhengigheter og ferdigkriterier.",
      system: "Du er Planner Raven. Lag en liten gjennomførbar plan med avhengigheter, WIP-grense og tydelige ferdigkriterier. Maksimer gjenbruk og unngå nye parallelle prosjekter. Svar kort på norsk."
    },
    builder: {
      name: "Builder Raven",
      icon: "🛠️",
      purpose: "Foreslå konkret implementasjon med minst mulig ny kompleksitet.",
      system: "Du er Builder Raven. Foreslå den minste fungerende implementasjonen som kan testes nå. Gjenbruk eksisterende arkitektur. Oppgi berørte filer, grensesnitt og testpunkter. Ikke påstå at kode er kjørt når den ikke er kjørt. Svar på norsk."
    },
    reviewer: {
      name: "Reviewer Raven",
      icon: "🔎",
      purpose: "Finn feil, duplikater, svake antakelser og manglende tester.",
      system: "Du er Reviewer Raven. Gjennomgå planen og byggeforslaget kritisk. Finn duplikater, regressjonsfare, uklare ferdigkriterier, manglende tester og unødvendig kompleksitet. Prioriter de viktigste funnene. Svar på norsk."
    },
    safety: {
      name: "Safety Raven",
      icon: "🛡️",
      purpose: "Kontroller personvern, tillatelser, sikkerhet og handlinger som må godkjennes.",
      system: "Du er Safety Raven. Kontroller personvern, datatap, hemmeligheter, helseopplysninger, skjermfangst og lokale handlinger. Marker hva som kan automatiseres trygt og hva som krever eksplisitt menneskelig godkjenning. Svar på norsk."
    },
    chair: {
      name: "Chair Raven",
      icon: "🐦‍⬛",
      purpose: "Samle rådene til én beslutning og ett konkret neste steg.",
      system: "Du er Chair Raven. Samle Council-rådene uten å skjule uenighet. Lag én anbefalt beslutning, maksimalt fem nummererte gjennomføringstrinn, ferdigkriterier, risikoer og det aller første konkrete steget. Svar på norsk."
    }
  });

  const safeText = (value, max = 12000) => String(value ?? "").trim().slice(0, max);
  const cleanLine = value => safeText(value, 220)
    .replace(/^#{1,6}\s*/, "")
    .replace(/^\*\*(.*?)\*\*:?\s*/, "$1: ")
    .replace(/[`*_]/g, "")
    .replace(/\s+/g, " ")
    .trim();

  function requireRole(roleId) {
    const role = ROLES[roleId];
    if (!role || roleId === "chair") throw new Error(`Ukjent Council-rolle: ${roleId}`);
    return role;
  }

  function previousSummary(previous) {
    if (!previous || typeof previous !== "object") return "";
    return Object.entries(previous)
      .filter(([, value]) => safeText(value))
      .map(([key, value]) => {
        const role = ROLES[key];
        return `### ${role?.name || key}\n${safeText(value, 5000)}`;
      })
      .join("\n\n");
  }

  function buildRoleMessages(roleId, input = {}) {
    const role = requireRole(roleId);
    const goal = safeText(input.goal, 3000);
    if (!goal) throw new Error("Council trenger et mål.");
    const context = safeText(input.context, 12000) || "Ingen prosjektkontekst ble lagt ved.";
    const constraints = safeText(input.constraints, 5000) || "Ingen ekstra begrensninger oppgitt.";
    const prior = previousSummary(input.previous);
    const user = [
      `# Mål\n${goal}`,
      `# Prosjektkontekst\n${context}`,
      `# Begrensninger\n${constraints}`,
      prior ? `# Tidligere Council-råd\n${prior}` : "",
      `# Oppgave\n${role.purpose}`,
      "Gi anbefalinger som kan kontrolleres. Ikke dikt opp filer, tester eller resultater."
    ].filter(Boolean).join("\n\n");
    return [
      { role: "system", content: role.system },
      { role: "user", content: user }
    ];
  }

  function buildChairMessages(input = {}, outputs = {}) {
    const goal = safeText(input.goal, 3000);
    if (!goal) throw new Error("Council trenger et mål.");
    const councilText = ROLE_ORDER.map(roleId => {
      const role = ROLES[roleId];
      return `## ${role.name}\n${safeText(outputs[roleId], 7000) || "Ingen svar."}`;
    }).join("\n\n");
    const user = [
      `# Mål\n${goal}`,
      `# Begrensninger\n${safeText(input.constraints, 5000) || "Ingen ekstra begrensninger."}`,
      `# Council-råd\n${councilText}`,
      "# Leveranse",
      "1. Beslutning",
      "2. Uenighet eller usikkerhet som må bevares",
      "3. Maksimalt fem nummererte gjennomføringstrinn",
      "4. Ferdigkriterier",
      "5. Risiko og godkjenningsporter",
      "6. Første konkrete steg nå"
    ].join("\n\n");
    return [
      { role: "system", content: ROLES.chair.system },
      { role: "user", content: user }
    ];
  }

  function parseNumberedPlan(text, maxSteps = 5) {
    const limit = Math.max(1, Math.min(10, Number(maxSteps) || 5));
    const lines = safeText(text, 20000).split(/\r?\n/);
    const found = [];
    const seen = new Set();
    for (const raw of lines) {
      const match = raw.match(/^\s*(?:\d{1,2}[.)]|[-•])\s+(.+)$/);
      if (!match) continue;
      const line = cleanLine(match[1]);
      if (line.length < 5 || /^(beslutning|risiko|ferdigkriterier|usikkerhet|første konkrete steg)\s*:?$/i.test(line)) continue;
      const key = line.toLocaleLowerCase("no-NO");
      if (seen.has(key)) continue;
      seen.add(key);
      found.push(line);
      if (found.length >= limit) break;
    }
    if (found.length) return found;
    return safeText(text, 12000)
      .split(/(?<=[.!?])\s+/)
      .map(cleanLine)
      .filter(line => line.length >= 12)
      .slice(0, limit);
  }

  function createCouncilRecord(input = {}, outputs = {}, chair = "", model = "") {
    const createdAt = new Date().toISOString();
    return {
      id: `council-${Date.now()}`,
      version: VERSION,
      createdAt,
      goal: safeText(input.goal, 3000),
      project: safeText(input.project, 300),
      constraints: safeText(input.constraints, 5000),
      model: safeText(model, 300),
      roles: ROLE_ORDER.reduce((acc, roleId) => {
        acc[roleId] = safeText(outputs[roleId], 12000);
        return acc;
      }, {}),
      chair: safeText(chair, 16000),
      plan: parseNumberedPlan(chair, input.maxSteps || 5)
    };
  }

  function buildPlanningMission(record) {
    if (!record || !safeText(record.goal)) throw new Error("Ugyldig Council-resultat.");
    const createdAt = new Date().toISOString();
    const plan = Array.isArray(record.plan) && record.plan.length
      ? record.plan.slice(0, 7)
      : ["Gå gjennom Council-resultatet og definer første konkrete byggeoppgave."];
    const steps = [
      {
        id: `${record.id}-save`,
        title: "Lagre Council-beslutningen",
        detail: "Bevar beslutning, uenighet, risiko og ferdigkriterier i Project Brain.",
        action: "save-mission-result",
        done: false,
        status: "PENDING"
      },
      ...plan.map((item, index) => ({
        id: `${record.id}-task-${index + 1}`,
        title: `Opprett oppgave ${index + 1}`,
        detail: item,
        action: "create-project-task",
        done: false,
        status: "PENDING"
      })),
      {
        id: `${record.id}-review`,
        title: "Åpne Project Brain og velg første oppgave",
        detail: "Council-planen er gjort om til oppgaver. Kontroller prioriteten før bygging starter.",
        action: "open-brain",
        done: false,
        status: "PENDING"
      }
    ];
    return {
      id: `${record.id}-mission`,
      presetId: "raven-council-planning",
      councilId: record.id,
      title: `Council-plan: ${safeText(record.goal, 90)}`,
      description: "Raven Council v0.1 lager og overfører en kontrollert plan til Mission Control.",
      ravens: [...ROLE_ORDER.map(id => ROLES[id].name), ROLES.chair.name],
      status: "RUNNING",
      currentStep: 0,
      createdAt,
      updatedAt: createdAt,
      steps,
      logs: [],
      results: [{ title: "Council-beslutning", body: safeText(record.chair, 16000), time: createdAt }]
    };
  }

  function councilMarkdown(record) {
    if (!record) return "";
    const roleSections = ROLE_ORDER.map(roleId => {
      const role = ROLES[roleId];
      return `## ${role.icon} ${role.name}\n\n${safeText(record.roles?.[roleId], 12000) || "Ingen svar."}`;
    }).join("\n\n");
    return [
      "# RAH Raven Council",
      `Dato: ${record.createdAt || ""}`,
      `Modell: ${record.model || "ukjent"}`,
      `Prosjekt: ${record.project || "RAH"}`,
      `\n## Mål\n\n${record.goal || ""}`,
      roleSections,
      `## 🐦‍⬛ Chair Raven\n\n${record.chair || ""}`,
      "## Plan hentet ut til Mission Control",
      ...(record.plan || []).map((item, index) => `${index + 1}. ${item}`),
      "\n---\nCouncil v0.1 gir strukturerte råd. Det utfører ingen skjulte PC-handlinger."
    ].join("\n\n");
  }

  function applyRecordToRahState(currentState, record, options = {}) {
    const state = currentState && typeof currentState === "object" ? structuredClone(currentState) : {};
    state.brain = safeText(state.brain, 80000);
    state.activity = Array.isArray(state.activity) ? state.activity : [];
    state.councilHistory = Array.isArray(state.councilHistory) ? state.councilHistory : [];
    const block = [
      `## Raven Council: ${record.goal}`,
      `Dato: ${record.createdAt}`,
      record.project ? `Prosjekt: ${record.project}` : "",
      "",
      record.chair
    ].filter(Boolean).join("\n");
    state.brain = state.brain ? `${state.brain}\n\n${block}` : block;
    state.councilHistory.unshift(record);
    state.councilHistory = state.councilHistory.slice(0, 30);
    state.activity.unshift({ text: `Raven Council fullført: ${safeText(record.goal, 90)}`, time: record.createdAt });
    state.activity = state.activity.slice(0, 50);
    if (options.attachMission) state.activeMission = buildPlanningMission(record);
    return state;
  }

  return Object.freeze({
    VERSION,
    ROLE_ORDER: Object.freeze([...ROLE_ORDER]),
    ROLES,
    buildRoleMessages,
    buildChairMessages,
    parseNumberedPlan,
    createCouncilRecord,
    buildPlanningMission,
    councilMarkdown,
    applyRecordToRahState
  });
});
