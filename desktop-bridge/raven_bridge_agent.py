from __future__ import annotations

"""RAH Raven Bridge + queued Job Executor + AI Fabric + Council entrypoint.

Keeps the canonical raven_bridge module intact and layers Raven Jobs, the
local-first AI Fabric, and Raven Council orchestration on top.
"""

from raven_bridge import APP_VERSION, HOST, PORT, app
import raven_jobs
import raven_ai_fabric
import raven_council


if __name__ == "__main__":
    print(
        f"RAH Raven Desktop Bridge v{APP_VERSION} + "
        f"Job Executor v{raven_jobs.JOB_EXECUTOR_VERSION} + "
        f"AI Fabric v{raven_ai_fabric.AI_FABRIC_VERSION} + "
        f"Council v{raven_council.COUNCIL_VERSION}"
    )
    print(f"Agent capabilities: http://127.0.0.1:{PORT}/agent/capabilities")
    print(f"Agent jobs health: http://127.0.0.1:{PORT}/agent/jobs/health")
    print(f"Agent jobs:        http://127.0.0.1:{PORT}/agent/jobs")
    print(f"AI Fabric health:  http://127.0.0.1:{PORT}/ai/health")
    print(f"AI providers:      http://127.0.0.1:{PORT}/ai/providers")
    print(f"AI plan:           http://127.0.0.1:{PORT}/ai/plan")
    print(f"Council status:    http://127.0.0.1:{PORT}/ai/council/status")
    print(f"Council ask:       http://127.0.0.1:{PORT}/ai/council/ask")
    print(f"Council plan:      http://127.0.0.1:{PORT}/ai/council/plan")
    print(f"Listening on http://{HOST}:{PORT}")
    app.run(host=HOST, port=PORT, debug=False, threaded=True)
