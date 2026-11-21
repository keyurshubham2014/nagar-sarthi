# TASK-04: Play the Monsoon: Time Slider and Complaints Heat

| Field | Value |
|---|---|
| Task ID | TASK-04 |
| Status | Not Started |
| Priority | P1 |
| Size | M |
| Depends On | TASK-02 |
| Blocks | TASK-07 |
| Requirement IDs | REQ-F-026, REQ-F-027, REQ-N-007 |
| Primary Spec Refs | `docs/ideas/2026-11-21-nagar-sarthi-prd.md` (PRD §5 F0) |
| Last Updated | 2026-11-21 |

## 1. Objective

Anyone on the map can drag or play a June to October slider and watch rain, complaints, repairs and failed fixes unfold, and can turn on a heat layer of open and repeat complaints.

## 2. Scope

### In Scope
- Time slider with play and pause
- Day-by-day map state: rain, complaints, repairs, failed fixes
- Complaints heat layer with clusters and a list on tap

### Out of Scope
- New audit rules (TASK-01)
- Complaint tracking screens (TASK-06)

## 3. Prerequisites

TASK-02 map home and `GET /api/timeline`.

## 4. Dependencies

| Task | Why it is required |
|---|---|
| TASK-02 | Provides backend, app shell and money map, which this task builds on |

## 5. Technical Context

### 5.1 Requirements Covered

| Req ID | Requirement | Source |
|---|---|---|
| REQ-F-026 | Complaints heat layer shows open and repeat complaints as clusters | PRD §5 F0 |
| REQ-F-027 | Play the monsoon: a June to October time slider animates rain, complaints, repairs and failed fixes | PRD §5 F0 |
| REQ-N-007 | The monsoon slider plays without stutter on the Android emulator | PRD §5 F0 |

### 5.2 Data Contracts

Not applicable — reads the timeline from the audit JSON.

### 5.3 API Contracts

Uses `GET /api/timeline` (per day: rainfall, alert, complaint points, completed repairs, re-opens). Adds `GET /api/complaints/heat?ward=` returning clustered open and repeat complaints.

### 5.4 UI Surfaces & States

Slider bar: idle, playing, paused, end reached. Rain indicator for the day. Heat layer: default, empty for a ward with no open complaints, error with retry. Cluster tap opens a complaint list.

### 5.5 Permissions & Roles

Public read; no role restriction.

### 5.6 Assumptions

- ASSUMPTION: a failed fix turns red on its completion date plus 30 days, since only the re-open flag is known, not the date — the animation timing is indicative
- ASSUMPTION: complaints without coordinates are placed at their locality's coordinates from localities.csv

## 6. Implementation Steps

1. Add the heat endpoint on the server with simple grid clustering
2. Load the timeline once and index it by day
3. Build the slider with play, pause and drag
4. Drive road colours and complaint dots from the selected day
5. Show the day's rain and alert level
6. Add the heat layer and its toggle chip
7. Open a complaint list on cluster tap
8. Profile on the Android emulator; cap redraws to keep it smooth

## 7. Acceptance Criteria

### 7.1 Behavioral

**AC-1** — Season plays
- **Given** the map home
- **When** play is pressed
- **Then** the date advances from June to October and the map changes with it

**AC-2** — Failed fixes show
- **Given** a road with a re-opened repair
- **When** the slider passes that period
- **Then** the road turns red

**AC-3** — Repeat spend is visible
- **Given** a road repaired more than once
- **When** the season plays
- **Then** each repair lights up in turn on the same segment

**AC-4** — Heat layer
- **Given** the map home
- **When** the heat layer is switched on
- **Then** open and repeat complaints appear as clusters and a tap lists them

**AC-5** — Smooth playback
- **Given** the Android emulator
- **When** the season plays end to end
- **Then** there is no visible stutter

### 7.2 Non-Functional Checklist

- [ ] Error states: every failure path renders a recoverable state, no unhandled rejections
- [ ] Loading states: every async surface has a loading representation
- [ ] Empty states: every list or collection surface has a designed empty state
- [ ] Accessibility: labelled controls, visible focus, adequate contrast
- [ ] Responsive: verified on the Android emulator and at desktop web width
- [ ] No hardcoded values that belong in config
- [ ] Follows patterns introduced in earlier tasks

## 8. Validation & Testing

| Level | What to test | Where |
|---|---|---|
| Manual | Walk through AC-1 to AC-5 by hand in the running product | emulator and Chrome |

## 9. Deliverables

- Slider
- Heat layer and endpoint

## 10. Files Expected to Change

An estimate, not a constraint.

- `app/lib/features/map/` (modified)
- `server/` (modified: heat endpoint)

## 11. Related Documentation

- `docs/ideas/2026-11-21-nagar-sarthi-prd.md` (PRD §5 F0): the features and decisions this task implements
- `docs/ideas/2026-11-21-nagar-sarthi-prd.md` (§9 Cut order): what gives way if this task overruns
- `DATA_DICTIONARY.md`: column meanings for every file in `data/`

## 12. Risks & Considerations

| Risk | Impact | Mitigation |
|---|---|---|
| Redrawing all layers per frame is slow | Stutter on stage | Step by day, not by frame; only recolour changed roads |
| Runs over its time box | Starves corporator and citizen flows | Fifth in the cut order: drop the heat layer first, keep the slider |

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
