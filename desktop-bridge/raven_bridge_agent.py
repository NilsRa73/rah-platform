from __future__ import annotations

"""RAH Raven Bridge + queued Job Executor entrypoint.

Keeps the canonical raven_bridge module intact and layers Raven Jobs on top.
"""

from raven_bridge import APP_VERSION, HOST, PORT, app
import raven_jobs


if __name__ == "__main__":
    print(f"RAH Raven Desktop Bridge v{APP_VERSION} + Job Executor v{raven_jobs.JOB_EXECUTOR_VERSION}")
    print(f"Agent capabilities: http://127.0.0.1:{PORT}/agent/capabilities")
    print(f"Agent jobs health: http://127.0.0.1:{PORT}/agent/jobs/health")
    print(f"Agent jobs:        http://127.0.0.1:{PORT}/agent/jobs")
    print(f"Listening on http://{HOST}:{PORT}")
    app.run(host=HOST, port=PORT, debug=False, threaded=True)
