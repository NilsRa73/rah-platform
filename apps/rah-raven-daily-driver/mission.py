import json
from datetime import datetime
from pathlib import Path


def build_report(chronicle, agents, agent_histories, device_snapshot, module_status):
    summaries = []
    for agent in agents:
        history = agent_histories.get(agent.agent_id, [])
        last = next(
            (x.get("msg", "") for x in reversed(history) if x.get("from") == agent.name),
            "(no response)",
        )
        summaries.append(
            {
                "agent": agent.name,
                "role": agent.role,
                "type": agent.agent_type,
                "status": agent.status(),
                "last_response": last,
            }
        )
    return {
        "product": "RAH Raven Daily Driver",
        "version": "1.0",
        "generated_at": datetime.now().isoformat(timespec="seconds"),
        "agents": summaries,
        "pending_accounts": chronicle.accounts(["Pending", "Lost"]),
        "closest_to_stable": chronicle.closest_to_stable(),
        "recent_decisions": chronicle.decisions_last_days(7),
        "devices": device_snapshot,
        "module_status": module_status,
    }


def save_report(report, reports_dir):
    reports_dir = Path(reports_dir)
    reports_dir.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    path = reports_dir / f"mission-report-{stamp}.json"
    path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    return path
