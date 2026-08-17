from datetime import datetime


class RavenCouncil:
    def __init__(self, agents, chronicle):
        self.agents = [a for a in agents if a.enabled]
        self.chronicle = chronicle
        self.histories = {a.agent_id: [] for a in self.agents}

    def send_all(self, message, context=None):
        output = []
        for agent in self.agents:
            history = self.histories[agent.agent_id]
            try:
                response = agent.send(message, history=history, context=context)
            except Exception as exc:
                response = f"[{agent.name} unavailable] {type(exc).__name__}: {exc}"
            history.append({"from": "user", "msg": message})
            history.append({"from": agent.name, "msg": response})
            output.append({"agent_id": agent.agent_id, "agent": agent.name, "response": response})
            self.chronicle.remember("agent_response", "Council", agent.name, response)
        return output

    def debate(self, topic, rounds=2, context=None):
        rounds = max(1, min(int(rounds), 8))
        first = self.send_all(topic, context)
        previous = {x["agent_id"]: x["response"] for x in first}
        record = [{"round": 0, "responses": first}]
        for number in range(1, rounds + 1):
            responses = []
            snapshot = "\n\n".join(
                f"{agent.name}: {previous.get(agent.agent_id, '(none)')}"
                for agent in self.agents
            )
            for agent in self.agents:
                prompt = (
                    f"RAH Raven Council round {number}. Topic: {topic}\n\n"
                    f"Other/latest answers:\n{snapshot}\n\n"
                    "Challenge weak assumptions, add missing considerations, and end with one recommendation."
                )
                try:
                    response = agent.send(
                        prompt,
                        history=self.histories[agent.agent_id],
                        context=context,
                    )
                except Exception as exc:
                    response = f"[{agent.name} unavailable] {type(exc).__name__}: {exc}"
                self.histories[agent.agent_id].append({"from": "council", "msg": prompt})
                self.histories[agent.agent_id].append({"from": agent.name, "msg": response})
                previous[agent.agent_id] = response
                responses.append({"agent_id": agent.agent_id, "agent": agent.name, "response": response})
            record.append({"round": number, "responses": responses})
        self.chronicle.remember(
            "decision",
            "Council",
            f"Council debate: {topic[:120]}",
            body=str(record[-1])[:8000],
            metadata={"rounds": rounds},
        )
        return {"topic": topic, "created_at": datetime.now().isoformat(timespec="seconds"), "rounds": record}
