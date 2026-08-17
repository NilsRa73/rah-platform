def generate_insights(chronicle, agents, devices, module_status):
    pending = chronicle.accounts(["Pending", "Lost"])
    project = chronicle.closest_to_stable()
    offline = [d for d in devices if not d.get("online")]
    online_agents = sum(1 for a in agents if a.status().get("online"))
    frozen = [name for name, item in module_status.items() if item.get("frozen")]
    return {
        "pending_recovery_accounts": len(pending),
        "next_stable_candidate": project,
        "offline_devices": [d.get("name") for d in offline],
        "agents_online_or_ready": online_agents,
        "frozen_components": frozen,
        "priority": (
            "Complete Windows runtime gate and real archive/LM Studio tests"
            if project
            else "Maintain stable/frozen components; add only explicit new work"
        ),
    }
