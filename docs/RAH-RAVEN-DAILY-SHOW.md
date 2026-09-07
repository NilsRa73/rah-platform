# RAH Raven Daily Show

## Goal
Preserve the RAH Raven build story from the earliest available material until the system is finished, then turn each day into a private archive plus an optional publishable YouTube/TV episode package.

## Important rule
Do not depend on ChatGPT conversation history alone as the permanent source of truth. Raven should maintain its own local chronological archive.

## Two-layer archive

### 1. PRIVATE MASTER ARCHIVE
Stored locally and never uploaded publicly by default.

Suggested location:
`%LOCALAPPDATA%\RAH Raven\Chronicle\daily-show\`

Per day:
`YYYY-MM-DD\`
- `dialogue.md` — relevant user/assistant dialogue captured or imported for the project
- `timeline.jsonl` — timestamped Raven events
- `git.md` — commits, PRs, CI runs and important code changes
- `tests.md` — what worked, failed and was verified
- `screens\` — selected screenshots or Raven Vision captures
- `notes.md` — user notes and important decisions
- `private-summary.md` — full internal summary

Never publish the private master automatically.

### 2. PUBLISHABLE EPISODE PACK
Generated from the private archive only when requested.

Per day:
- `episode-title.txt`
- `hook.txt`
- `episode-script.md`
- `voiceover.txt`
- `shot-list.md`
- `chapters.txt`
- `youtube-description.md`
- `thumbnail-prompt.txt`
- `shorts.md`
- `privacy-review.md`

## Daily command
The intended user command is simply:

`lag dagens upload`

Raven should then:
1. Load today's Chronicle/events, relevant project dialogue, GitHub changes and verification results.
2. Build a chronological timeline.
3. Select the strongest story beats: mission, problem, frustration, insight, fix, proof, next challenge.
4. Remove passwords, tokens, personal identifiers, private family/legal/health information and unrelated private material.
5. Generate one coherent episode package.
6. Mark every statement as one of: observed, tested, inferred, or planned.
7. Never claim a feature worked unless a test or visible result supports it.
8. Keep the private master separate from the publishable version.

## Series command
The intended command is:

`lag tv-serien fra dag 1`

Raven should:
1. Read all available Daily Show archives in date order.
2. Build a season timeline.
3. Group events into episodes by story rather than by arbitrary date boundaries.
4. Prefer genuine turning points, failures, fixes and demonstrations.
5. Preserve continuity between episodes.
6. Produce a season index and episode packages.

## Story model
Every episode should try to contain:
- Mission
- Obstacle
- Escalation
- Build/fix
- Proof
- Consequence
- Next hook

## Editorial tone
Documentary build-in-public rather than polished corporate marketing. Keep the real technical drama, but do not exaggerate failures or invent conflict.

## RAH visual identity
- black / charcoal base
- warm gold accents
- raven and Yggdrasil motifs
- terminal and code overlays
- architecture diagrams
- screen recordings and Raven Vision captures

## Privacy gate
Before any public upload, Raven must create `privacy-review.md` listing:
- names or personal data found
- account/email addresses
- IP addresses and machine identifiers
- credentials/tokens/secrets
- legal/health/family material
- copyrighted third-party media
- anything requiring manual approval

Public publishing remains an explicit user action.

## First season arc
1. Two PCs, One Raven
2. Two Weeks of Wi-Fi Hell
3. Raven Vision
4. ChatGPT Gets Eyes
5. Local Agents That Actually Work
6. Raven Command Center
7. The First Raven Grid Job
8. No More Copy/Paste
9. Raven Learns to Recover
10. RAH Raven v1: Proof
