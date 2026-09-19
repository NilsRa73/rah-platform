# RAH Raven AI Self-Check

This is the bounded self-heal companion to the read-only Raven Doctor.

It checks Bridge, elevated Job Executor, LM Studio with a real inference probe,
AnythingLLM, Project Memory, ready Council advisers and a real Council request.

Safe automatic repairs are deliberately limited to:
- starting known Raven scheduled tasks,
- waking LM Studio / AnythingLLM through the existing provider task,
- reloading only the already-pinned LM Studio model from C:\RAH\AI-Fabric\lmstudio-model.txt.

It never downloads a model, changes firewall rules, scrapes credentials, changes
the AnythingLLM token, or enables arbitrary shell execution.

The scheduled task writes:
- C:\RAH\Status\AI-SELF-CHECK-LATEST.txt
- timestamped reports under C:\RAH\Reports\AI-Self-Check\

Interactive entry point:
- C:\RAH\RAVEN-AI-SELF-CHECK.cmd
