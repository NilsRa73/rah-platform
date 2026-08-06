# RAH Raven OS — Memory, Vision and Consent Architecture

**Status:** Working architecture for the next Raven OS build  
**Goal:** One user-controlled AI layer that remembers projects, follows tasks, understands context and helps across desktop, mobile, watch and Raven Care.

## Product sentence

> Raven follows the work, not the person in secret. The user owns the memory, sees the recording state and decides what may be stored, analysed, shared or deleted.

## Core modules

### 1. Raven Chronicle — the memory
Creates a timestamped event stream from user-approved sources:

- active applications and project windows
- browser titles and domains, not passwords or form contents
- files opened, created or downloaded
- manual notes, ideas and decisions
- gaming, YouTube and other interests
- appointments, promises, deadlines and follow-up
- health entries explicitly added to Raven Care
- summaries from Raven Vision

Chronicle stores structured events. The LLM is not the database.

### 2. Raven Vision — the eyes
Understands screenshots or selected screen regions when enabled.

- reads visible application state
- recognises buttons, errors and progress
- links a screenshot summary to the active project
- proposes the next safe action
- never clicks, sends, buys, signs or changes treatment without approval

Default exclusions:

- password fields and one-time codes
- banking and payment screens
- private messages unless explicitly included
- health portals unless a Care session is explicitly started
- camera and microphone when their indicator is not visible

### 3. Raven Mobile — the companion
Provides:

- voice notes and reminders
- appointment detection from user-approved conversations or messages
- document capture
- medication and symptom check-ins
- location-based reminders only when enabled
- a large pause/privacy button

Conversation capture must be visible and consent-based. Raven is not a covert recorder.

### 4. Raven Watch — the quick sensor and reminder layer
Provides:

- sleep, pulse, activity and user-entered fatigue
- medication reminders
- one-tap voice notes
- meeting start/stop marker
- alerts for agreed follow-up items

Watch data is treated as observation, not diagnosis.

### 5. Raven Care — the health workspace
Links:

- documents and journal extracts
- laboratory results
- blood glucose and other measurements
- medication start, effect, side effects and stop reason
- fatigue, sleep and pulse
- referrals, binding deadlines and promised follow-up
- patient explanation, clinician assessment and unresolved questions

Health data is separated from ordinary activity data by default.

### 6. Raven Guard — permissions and safety
Every source has five states:

1. **Off** — no access
2. **Session only** — deleted when the session ends unless approved
3. **Local memory** — encrypted local storage
4. **Project memory** — available only inside the selected project
5. **Share approved** — user has approved a specific export or recipient

Guard must provide:

- permanent visible recording indicator
- pause button and keyboard shortcut
- private zones and excluded applications
- retention period per data type
- audit log of reads, writes, exports and deletions
- redaction before AI processing
- separate consent for microphone, camera, location and health data

## Main data flow

```text
Approved source
    ↓
Local collector
    ↓
Redaction and source label
    ↓
Structured Chronicle event
    ↓
Project memory / Care memory
    ↓
Local AI summary through LM Studio
    ↓
User review
    ↓
Optional approved action or export
```

## Event model

```json
{
  "id": "evt_20260806_001",
  "timestamp": "2026-08-06T06:30:00+02:00",
  "source": "manual|desktop|browser|vision|mobile|watch|care",
  "category": "project|interest|meeting|health|deadline|decision|error",
  "projectId": "rah-raven-care",
  "title": "Found UNN innovation page",
  "summary": "Possible pilot route for Raven Care",
  "evidence": {
    "type": "user_note|screen_summary|document|sensor",
    "reference": "optional-local-reference"
  },
  "privacy": "private|project|care|share-approved",
  "confidence": 0.95,
  "requiresApproval": false
}
```

## Memory layers

### Working memory
Current screen, current task and the last few events. Short-lived.

### Project memory
Decisions, files, errors, build history, open tasks and the next action for one project.

### Personal preference memory
Interests, preferred tools, UI style and routines. Editable by the user.

### Care memory
Health documents, measurements and patient-reported outcomes. Strictly separated and purpose-limited.

### Archive
Immutable source files and signed event history. AI summaries may be regenerated; original sources are not silently changed.

## Raven Command loop

```text
OBSERVE → CLASSIFY → CONNECT TO PROJECT → SUGGEST → APPROVE → ACT → VERIFY → LOG
```

Critical actions always require explicit approval:

- sending messages or documents
- medical or medication-related actions
- purchases or financial actions
- deleting files
- publishing code or personal information
- changing permissions

## Desktop Bridge API — planned

```text
GET  /health
GET  /chronicle/status
POST /chronicle/session/start
POST /chronicle/session/stop
POST /chronicle/event
GET  /chronicle/events
POST /chronicle/summary
GET  /chronicle/export
POST /vision/capture
POST /vision/analyze
GET  /guard/permissions
POST /guard/permissions
```

## First working phases

### Phase 1 — browser-local Chronicle
- session start/stop
- manual and simulated events
- interest, project, appointment and health categories
- local daily summary
- JSON export and reset
- permission matrix

### Phase 2 — Desktop Bridge collector
- active application and window title
- selected browser metadata
- file/download events
- explicit Raven Vision screenshot capture
- local SQLite event store

### Phase 3 — local AI
- LM Studio summaries
- project classification
- open-loop and deadline detection
- suggestions with source references
- no autonomous critical actions

### Phase 4 — mobile and watch
- voice notes, reminders and selected sensor data
- visible conversation-session mode
- encrypted sync to the user's own Raven instance

### Phase 5 — Care pilot
- separate Care consent
- measurements, medication follow-up and referral deadlines
- patient-approved clinician summary
- audit, privacy review and professional pilot

## Definition of success

Raven should answer these questions without the user searching through many versions and conversations:

- What was I working on?
- What did we decide?
- Which file is the newest trusted version?
- What remains unfinished?
- Who promised what, and by when?
- What information is documented, self-reported, interpreted or unresolved?
- What should I do next, using the least possible effort?

## Non-negotiable rule

> No hidden surveillance. No automatic external sending. No diagnosis from activity data. Every memory item can be inspected, corrected, exported and deleted by the user.
