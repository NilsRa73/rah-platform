# RAH Project Context

## Project
**Name:** RAH Platform  
**Repository:** https://github.com/NilsRa73/rah-platform  
**Owner:** Nils Ravnbø  
**Status:** Early working prototype

## Core Goal
RAH Platform is an AI-powered command center designed around goals and workflows instead of separate applications.

The user should be able to click one button such as **Continue RAH**, **Build Website**, **Create Video**, or **Open Project**, and Raven should coordinate the required tools, links, files, agents, and workspaces.

## Primary Modules
- RAH Raven Command Center
- RAH Raven Browser
- RAH Vision
- RAH Desktop Bridge
- RAH Project Brain
- RAH AI Agents
- RAH Studio
- RAH Social Media Automation
- RAH YouTube Automation
- RAH Workspace Restore
- RAH Plugin System
- RAH Task Engine
- RAH Memory Engine

## Current Working Prototype
The current repository contains a lightweight browser-based Raven Command Center with:

- Mouse-first dashboard
- Direct links to GitHub, Lovable, Firebase, YouTube Studio, and ChatGPT
- Project cards
- Task queue
- Local browser storage
- Windows launch helper
- No-install HTML version

## RAH Vision
RAH Vision is the visual understanding layer.

Planned capabilities:
- Read user-shared screenshots
- Understand the active browser tab
- Understand visible application windows
- Read GitHub repositories and project files
- Analyze VS Code, Lovable, GitHub, and browser state
- Detect errors and suggest the next action
- Never record the screen invisibly
- Require clear user permission for screen or window access

## RAH Desktop Bridge
The Desktop Bridge will connect Raven to the local computer.

Planned capabilities:
- Open applications and links
- Open project folders
- Open repositories in VS Code
- Restore workspaces
- Read Git status
- Read approved local files
- Start development servers
- Run approved automation
- Keep high-impact actions under user approval

## RAH Project Brain
The Project Brain should remember:

- Project goals
- Architecture decisions
- Current status
- Open tasks
- Completed tasks
- Known problems
- Important files
- GitHub repository
- Lovable project
- Previous Raven conversations
- Where work stopped
- What should happen next

## Interaction Principles
1. Mouse-first whenever possible.
2. One click should replace many manual steps.
3. Do not repeatedly explain already approved goals.
4. Continue should advance real implementation.
5. Give direct links whenever they save time.
6. Important actions such as publishing, deleting, spending money, or deploying require approval.
7. The repository is the source of truth for the code.
8. RAH Vision sees, Project Brain remembers, and Command Center acts.

## Current Repository Contents
At the time this file was created, the repository contained:

- `CLICK-LINKS/`
- `RAH Raven Command Center.html`
- `READ ME FIRST.txt`
- `README.md`
- `START RAH - CLICK HERE.vbs`
- `VALIDATION.txt`

## Immediate Next Steps
1. Add this file to the repository root.
2. Improve README with clear start instructions.
3. Add `docs/` for architecture and status files.
4. Create a GitHub issue list for real implementation tasks.
5. Add RAH Vision specification.
6. Add Desktop Bridge specification.
7. Replace the simple HTML prototype with a maintainable application when ready.
8. Keep the no-install version as the simple fallback launcher.

## Next Build Priority
**RAH Vision + Project Brain connection**

The next useful milestone is a safe system where the user can share a screenshot, browser page, or project file and Raven can:
- identify what is visible,
- understand the current project,
- detect the problem,
- recommend the next action,
- and update project context.

## Safety and Privacy
- No hidden screen capture.
- No secret monitoring.
- No publishing without approval.
- No deleting without approval.
- No storage of passwords or API keys in public GitHub files.
- Use environment variables or a secure local vault for secrets later.

## Approved Long-Term Direction
The overall RAH vision is approved. Future work should focus on implementation rather than repeatedly presenting the same vision.
