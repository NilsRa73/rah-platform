# RAH Raven Case Center — Product Specification v0.1

## Product decision

RAH Raven Case Center is a local-first support and case-navigation module for people who may be mentally exhausted, cognitively overloaded, verbally uncertain, lonely, or unable to understand complex medical, legal, NAV, housing, banking, or administrative systems.

The user should not need to understand the system in order to receive help from the system.

## Core promise

**You tell your story. Raven organizes it. Humans verify it. Nothing important disappears.**

## Main workflow

1. Import documents, notes, correspondence, meeting records, decisions, test results, medication lists, agreements, and other user-controlled material.
2. Preserve original files and original user wording.
3. Build a chronological timeline.
4. Separate documented facts, user statements, professional interpretations, disputed information, and unknowns.
5. Detect missing responsibility, deadlines, receipts, case numbers, source documents, medication dates, measurements, appeal information, and unresolved promises.
6. Prepare simple explanations, meeting sheets, questions, summaries, and professional export packages.
7. Require human approval before anything is sent or treated as a professional conclusion.

## User modes

### Calm mode
- One question or next action at a time.
- Large controls and reduced text.
- Read-aloud support.
- Pause and continue later without losing work.

### Standard mode
- Document inbox, timeline, gaps, meetings, approvals, and report export.

### Professional mode
- More source detail, uncertainty labels, audit information, and review controls.

## Required modules

### Document Inbox
- Local file import.
- Drag and drop.
- Original file preservation.
- Manual notes that keep the user’s exact wording.
- Voice note support where the browser permits it.

### Universal Timeline
Every event should contain:
- date or date uncertainty
- area or case type
- event description
- source
- status: documented, user statement, interpretation, disputed, or unknown

### Evidence and Gap Finder
Examples:
- application mentioned without receipt or case number
- meeting without named responsibility or deadline
- medicine without start or stop date
- side effect mentioned without recorded measurement
- rejection without visible appeal deadline or appeal body
- important promise not found in the later minutes
- conflicting accounts that have not been separated

“Not found” must never be presented as “did not happen.”

### Meeting Companion
Before the meeting:
- maximum three important points
- simple language and read-aloud

During or immediately after the meeting:
- promises
- responsible person or service
- deadline
- unanswered questions

When official minutes arrive:
- compare with the user’s time-near account
- flag possible omissions or changed meaning
- state clearly that text comparison is not proof of misquotation

### Human Approval Desk
- User approval is required before sharing.
- Medical conclusions require qualified health-professional review.
- Legal conclusions require qualified legal review.
- Public decisions remain the responsibility of the competent authority.
- Every AI suggestion must show sources, uncertainties, and review status.

### Professional Export
Separate packages for:
- patient and personal overview
- doctor or specialist
- NAV or municipal service
- housing office
- NPE or patient-injury review
- lawyer
- bank, accountant, or financial adviser

Only necessary information should be included for each recipient.

## Faith and mental-health safety

The system must distinguish between:
1. ordinary personal faith or spiritual language
2. metaphor or explanatory language
3. unwanted voices, intrusive experiences, or perceived personal messages
4. the professional interpretation of those experiences

RAH Raven must neither pathologize ordinary faith nor confirm supernatural explanations as fact. It should preserve the user’s uncertainty, context, degree of conviction, distress, function, time period, and desire for treatment.

## Privacy and security

- Local storage first.
- No automatic upload.
- No advertising tracking.
- No model training on personal material.
- Explicit consent before sharing.
- Role-limited access for helpers and professionals.
- Immutable originals and an audit log for derived material.
- Easy export and deletion.
- Sensitive fields should be minimized and masked when not needed.

## Automation levels

### Green — safe preparation
- sorting files
- extracting dates and names
- building timelines
- identifying missing fields
- explaining difficult language
- creating drafts

### Yellow — user approval
- personal statements
- meeting summaries
- letters and complaint drafts
- document packages

### Red — professional or authority decision
- diagnosis
- medication changes
- legal liability
- compensation entitlement or amount
- public decisions

## Prototype v0.1

The first browser prototype includes:
- local document registration and text-file reading
- manual and voice notes
- timeline creation
- explainable rule-based gap checks
- meeting preparation and minute comparison
- user/professional approval states
- printable report and JSON export
- calm, standard, and professional display modes

The prototype deliberately does not claim direct access to Helsenorge, NAV, banks, or internal public systems. Approved integrations and RAH Desktop Bridge/local-AI document processing are later phases.

## Next technical milestone

Connect the module to RAH Desktop Bridge and a local language model for controlled PDF/text extraction, source-linked summaries, and deeper timeline analysis while preserving the same human-approval and privacy boundaries.
