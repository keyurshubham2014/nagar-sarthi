# TASK-06: Citizen Flow: Raise, Track, Share, Ask

| Field | Value |
|---|---|
| Task ID | TASK-06 |
| Status | Not Started |
| Priority | P1 |
| Size | M |
| Depends On | TASK-02 |
| Blocks | TASK-07 |
| Requirement IDs | REQ-F-030, REQ-F-031, REQ-F-032, REQ-F-033, REQ-F-034, REQ-S-003 |
| Primary Spec Refs | `docs/ideas/2026-11-21-nagar-sarthi-prd.md` (PRD §5 F6, F8) |
| Last Updated | 2026-11-21 |

## 1. Objective

A citizen describes a problem in their own language and Claude classifies it, finds the place and shows whether it is already reported and what happened to it. They can also file through a plain form, track a complaint, share their ward's report card and send the ward an evidence-based question.

## 2. Scope

### In Scope
- Claude-assisted intake with matching
- Plain complaint form
- Track by id or locality
- Share ward report card
- Ask the ward a question

### Out of Scope
- Report a failed fix (TASK-07, stretch)
- Sign-in (TASK-07)
- Translated interface chrome (TASK-07)

## 3. Prerequisites

TASK-02 running with the complaints table.

## 4. Dependencies

| Task | Why it is required |
|---|---|
| TASK-02 | Provides backend, app shell and money map, which this task builds on |

## 5. Technical Context

### 5.1 Requirements Covered

| Req ID | Requirement | Source |
|---|---|---|
| REQ-F-030 | Claude-assisted intake classifies free text in four languages, finds the locality and shows matching complaints and their work order before filing | PRD §5 F6 |
| REQ-F-031 | Plain complaint form with category, locality and description | PRD §5 F6 |
| REQ-F-032 | Track a complaint by id or locality and see work order, contractor, cost, SLA result and whether the fix held | PRD §5 F6 |
| REQ-F-033 | Citizen shares a ward report card | PRD §5 F8 |
| REQ-F-034 | Citizen asks the ward a question drafted by Claude from the ward's data | PRD §5 F8 |
| REQ-S-003 | Complaint submissions are validated server-side | PRD §5 F6 |

### 5.2 Data Contracts

Writes `complaints` rows (see TASK-02 for columns). Reads dataset complaints and their linked work orders from the audit JSON.

### 5.3 API Contracts

`POST /api/claude/intake` body `{text}` returns `{category, locality, ward_code, language, matches[]}`; locality is resolved on the server against localities.csv aliases. `POST /api/complaints` (validated; 400 with field errors). `GET /api/complaints/:id` and `GET /api/complaints?locality=` return complaint, work order, contractor, cost, SLA result and whether the fix held. `POST /api/claude/question` body `{ward_code, topic}`.

### 5.4 UI Surfaces & States

Intake screen: typing, analysing, matches found, no match, error. Form: field validation, submitting disabled, success. Track screen: default, not found, never fixed. Report card: rendered card and share sheet. Question sheet: drafting, drafted, copy.

### 5.5 Permissions & Roles

Any user can read. Filing a complaint is open in this task and requires sign-in from TASK-07.

### 5.6 Assumptions

- ASSUMPTION: a match is an existing complaint of the same category in the same locality within the last 14 days — PRD says matching existing complaints without a rule
- ASSUMPTION: the report card is shared as a rendered image through share_plus on Android and as a download on web

## 6. Implementation Steps

1. Add locality resolution against localities.csv aliases, including Devanagari
2. Add the intake prompt and endpoint with matching and a saved fallback
3. Add complaint create, read and search endpoints with server-side validation
4. Build the intake screen with the match list and file-anyway action
5. Build the plain form with field validation
6. Build the track screen with the full trail
7. Build the report card and share action
8. Add the question prompt and sheet

## 7. Acceptance Criteria

### 7.1 Behavioral

**AC-1** — Intake understands Marathi
- **Given** a complaint typed in Marathi about a pothole
- **When** it is submitted to intake
- **Then** the category, locality and ward are identified

**AC-2** — Duplicates surface
- **Given** an issue already reported at that locality
- **When** intake finishes
- **Then** the matching complaints and their work order are shown before filing

**AC-3** — Plain form validates
- **Given** the form with an empty description
- **When** submit is pressed
- **Then** a field message appears and nothing is saved

**AC-4** — Tracking shows the trail
- **Given** a resolved complaint id
- **When** it is tracked
- **Then** the work order, contractor, cost, SLA result and whether the fix held are shown

**AC-5** — Never fixed
- **Given** an open complaint with no work order
- **When** it is tracked
- **Then** it is shown as not yet fixed

**AC-6** — Share
- **Given** a ward report card
- **When** share is pressed
- **Then** an image of the card is offered to share

**AC-7** — Question
- **Given** a ward
- **When** the citizen asks for a question on failed repairs
- **Then** a polite draft citing the ward's figures is shown and can be copied

**AC-8** — Server validation
- **Given** a complaint posted directly with a missing field
- **When** the server receives it
- **Then** it responds 400 with field errors

### 7.2 Non-Functional Checklist

- [ ] Validation: all inputs validated server-side; client validation mirrors it with field-level messages
- [ ] Error states: every failure path renders a recoverable state, no unhandled rejections
- [ ] Loading states: every async surface has a loading representation
- [ ] Empty states: every list or collection surface has a designed empty state
- [ ] Logging: failures logged with context, no secrets or personal data in logs
- [ ] Accessibility: labelled controls, visible focus, adequate contrast
- [ ] Responsive: verified on the Android emulator and at desktop web width
- [ ] No hardcoded values that belong in config
- [ ] Follows patterns introduced in earlier tasks

## 8. Validation & Testing

| Level | What to test | Where |
|---|---|---|
| Manual | Walk through AC-1 to AC-8 by hand in the running product | emulator and Chrome |

## 9. Deliverables

- Intake, form, track, share and question screens
- Complaint endpoints

## 10. Files Expected to Change

An estimate, not a constraint.

- `app/lib/features/citizen/` (new)
- `server/` (modified)

## 11. Related Documentation

- `docs/ideas/2026-11-21-nagar-sarthi-prd.md` (PRD §5 F6, F8): the features and decisions this task implements
- `docs/ideas/2026-11-21-nagar-sarthi-prd.md` (§9 Cut order): what gives way if this task overruns
- `DATA_DICTIONARY.md`: column meanings for every file in `data/`

## 12. Risks & Considerations

| Risk | Impact | Mitigation |
|---|---|---|
| Intake mislocates a place | Wrong ward on stage | Server resolves locality from the gazetteer; Claude only extracts the place text |
| Five features in one slice | Overrun | Order of build is intake, track, share, question, form; the form is fourth in the cut order |

## 13. Progress Status

**Current status:** Not Started

| Date | Progress | Commit |
|---|---|---|
| 2026-11-21 | Task file created | n/a |

## 14. Completion Checklist

- [ ] All implementation steps complete
- [ ] All behavioral acceptance criteria verified in the running application
- [ ] Non-functional checklist fully ticked
- [ ] Frontend and backend integrated end to end (no mocked data left in place)
- [ ] Error, loading, empty, and unauthorized states verified
- [ ] Code reviewed against the patterns established in earlier tasks
- [ ] Assumptions documented and, where possible, confirmed
- [ ] Task file progress log and status updated
- [ ] `00-task-summary.md` updated
- [ ] Validator passes
