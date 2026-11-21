# TASK-03: Officer Flow: Money Trail, Flags, Recovery Notice, Next Rupee

| Field | Value |
|---|---|
| Task ID | TASK-03 |
| Status | Not Started |
| Priority | P0 |
| Size | M |
| Depends On | TASK-02 |
| Blocks | TASK-07 |
| Requirement IDs | REQ-F-021, REQ-F-022, REQ-F-023, REQ-F-024, REQ-F-025, REQ-N-006 |
| Primary Spec Refs | `docs/ideas/2026-11-21-nagar-sarthi-prd.md` (PRD §5 F0, F2, F4, F5, §7) |
| Last Updated | 2026-11-21 |

## 1. Objective

A ward officer taps a ward or road on the map and sees where the money went, the flags with their evidence, a recovery notice drafted live by Claude, and numbered pins for where to spend next.

## 2. Scope

### In Scope
- Ward money trail panel
- Road panel with work orders and flags
- Recovery notice generation, edit and copy
- Next-rupee pins with reason markers and score breakdown
- Needs-review wording on every flag

### Out of Scope
- Contractor scorecard screen (TASK-05)
- Officer-only enforcement on the notice endpoint (TASK-07)
- Heat layer and slider (TASK-04)

## 3. Prerequisites

TASK-02 running: API, relay and map home.

## 4. Dependencies

| Task | Why it is required |
|---|---|
| TASK-02 | Provides backend, app shell and money map, which this task builds on |

## 5. Technical Context

### 5.1 Requirements Covered

| Req ID | Requirement | Source |
|---|---|---|
| REQ-F-021 | Tapping a ward opens its money trail | PRD §5 F0, F2 |
| REQ-F-022 | Tapping a road opens its work orders and flags | PRD §5 F0 |
| REQ-F-023 | Next-rupee pins are numbered and show hospitals, schools and flood hotspots as the reason, with the score breakdown | PRD §5 F0, F4 |
| REQ-F-024 | Officer generates a recovery notice drafted by Claude that cites work order ids, dates and amounts | PRD §5 F5 |
| REQ-F-025 | The recovery notice is editable and copyable | PRD §5 F5 |
| REQ-N-006 | Flags and scorecards are worded as needing review, never as accusations | PRD §5 F1, F3 |

### 5.2 Data Contracts

Not applicable — reads the audit JSON only; no table is written.

### 5.3 API Contracts

Uses `GET /api/wards/:code`, `GET /api/roads/:id`, `GET /api/next-rupee/:ward`. Adds the `notice` feature to `POST /api/claude/notice` with body `{flag_ids[]}`; the server builds the prompt from audit data so the client cannot inject figures. Returns `{text, source}`.

### 5.4 UI Surfaces & States

Ward panel (bottom sheet on phone, side panel on web): default, loading, error with retry, empty when a ward has no flags. Road panel: same states. Notice sheet: drafting, drafted, fallback badge, copy confirmation, in-flight button disabled. Next-rupee pins and list: default, empty when no budget remains.

### 5.5 Permissions & Roles

Intended for the officer role. Enforced server-side in TASK-07; until then the panel is reachable by any role.

### 5.6 Assumptions

- ASSUMPTION: a notice covers the flags of one type on one road or one ward — PRD says a flag or a group of flags — grouping changes if officers want per-contractor notices

## 6. Implementation Steps

1. Add the notice prompt on the server, built only from audit rows, with a saved fallback per flag type
2. Build the ward panel: budget vs spend, by contractor, by method, rupees per flag type
3. Build the road panel: work orders, flags and the numbers behind each
4. Wire map taps on wards and roads to the panels
5. Build the notice sheet with draft, edit, copy and fallback badge
6. Add the next-rupee pin layer with hospital, school and hotspot markers
7. Build the score breakdown sheet and the funded and unfunded list
8. Apply needs-review wording from one shared strings file

## 7. Acceptance Criteria

### 7.1 Behavioral

**AC-1** — Ward tap
- **Given** the map home
- **When** a ward is tapped
- **Then** its money trail opens with budget, spend and rupees per flag type

**AC-2** — Road tap
- **Given** the map home
- **When** a road is tapped
- **Then** its work orders and flags open, each with its evidence

**AC-3** — Notice cites evidence
- **Given** a DLP flag
- **When** the officer requests a notice
- **Then** the draft cites the work order ids, dates and amounts of that flag

**AC-4** — Notice is usable
- **Given** a drafted notice
- **When** the officer edits and copies it
- **Then** the edited text is on the clipboard and a confirmation shows

**AC-5** — Next-rupee pins
- **Given** a ward with open issues
- **When** the next-rupee layer is on
- **Then** numbered pins appear with hospitals, schools and hotspots, and a tap shows the score parts

**AC-6** — Fair wording
- **Given** any flag shown
- **When** it is read
- **Then** it says needs review or to be claimed and verified and makes no accusation

### 7.2 Non-Functional Checklist

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
| Manual | Walk through AC-1 to AC-6 by hand in the running product | emulator and Chrome |

## 9. Deliverables

- Ward and road panels
- Notice sheet and prompt
- Next-rupee layer

## 10. Files Expected to Change

An estimate, not a constraint.

- `app/lib/features/officer/` (new)
- `server/` (modified: notice prompt, fallbacks)

## 11. Related Documentation

- `docs/ideas/2026-11-21-nagar-sarthi-prd.md` (PRD §5 F0, F2, F4, F5, §7): the features and decisions this task implements
- `docs/ideas/2026-11-21-nagar-sarthi-prd.md` (§9 Cut order): what gives way if this task overruns
- `DATA_DICTIONARY.md`: column meanings for every file in `data/`

## 12. Risks & Considerations

| Risk | Impact | Mitigation |
|---|---|---|
| Live notice is slow on stage | Dead air in the demo | Stream or show progress; fallback after the timeout |
| Claude restates figures wrongly | Loss of trust | Figures are passed as a table and the prompt forbids new numbers; test checks ids appear |

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
