# TASK-02: Backend, App Shell and Money Map

| Field | Value |
|---|---|
| Task ID | TASK-02 |
| Status | Not Started |
| Priority | P0 |
| Size | L |
| Depends On | TASK-01 |
| Blocks | TASK-03, TASK-04, TASK-05, TASK-06 |
| Requirement IDs | REQ-F-016, REQ-F-017, REQ-F-018, REQ-F-019, REQ-F-020, REQ-D-002, REQ-D-003, REQ-D-004, REQ-D-005, REQ-N-002, REQ-N-003, REQ-N-004, REQ-N-005, REQ-S-001, REQ-S-002, REQ-O-001, REQ-O-002 |
| Primary Spec Refs | `docs/ideas/2026-11-21-nagar-sarthi-prd.md` (PRD §5 F0, §4, §6) |
| Last Updated | 2026-11-21 |

## 1. Objective

A Node.js backend serves the audit JSON, holds the Claude key and owns Postgres. A new Flutter app, styled with theme and widgets borrowed from Saarthee, opens on a map of Mumbai with wards shaded by rupees to review and roads coloured by status, on the Android emulator and on web.

## 2. Scope

### In Scope
- Node API serving audit data
- Postgres in Docker with all three tables
- Claude relay with timeout and saved fallback
- Flutter project targeting Android and web
- Copy Saarthee `core/theme`, needed `core/widgets` and `core/map/civic_map.dart`
- Map home with ward and road layers and layer toggles
- Departments entry and synthetic-data notice
- Run steps in a README section

### Out of Scope
- Detail panels opened from map taps (TASK-03)
- Heat layer and slider (TASK-04)
- Sign-in screens and role checks (TASK-07)
- Prompts for each Claude feature (TASK-03, TASK-05, TASK-06)

## 3. Prerequisites

TASK-01 output file. Docker Desktop running and the Postgres image pulled. Node 20. Flutter with an Android emulator. `ANTHROPIC_API_KEY` in the environment. A local clone of the Saarthee repo to copy from.

## 4. Dependencies

| Task | Why it is required |
|---|---|
| TASK-01 | Provides audit engine and scores, which this task builds on |

## 5. Technical Context

### 5.1 Requirements Covered

| Req ID | Requirement | Source |
|---|---|---|
| REQ-F-016 | The money map is the home screen for citizen, corporator and officer | PRD §5 F0 |
| REQ-F-017 | Ward layer shades all 24 wards by share of spend needing review | PRD §5 F0 |
| REQ-F-018 | Road layer draws 291 segments coloured by status | PRD §5 F0 |
| REQ-F-019 | Map layers can be toggled on and off | PRD §5 F0 |
| REQ-F-020 | Departments entry shows roads as live and other departments as coming, with no invented data | PRD §4 |
| REQ-D-002 | users table with phone and role | PRD §5 F9, §6 |
| REQ-D-003 | complaints table for complaints raised in the app | PRD §5 F6, §6 |
| REQ-D-004 | verification_reports table for held or failed reports | PRD §5 F8, §6 |
| REQ-D-005 | Ward and road GeoJSON are bundled with the app | PRD §5 F0 |
| REQ-N-002 | One Flutter codebase runs on the Android emulator and on web | PRD §6 |
| REQ-N-003 | The map stays readable when tiles fail to load | PRD §5 F0 |
| REQ-N-004 | Every live Claude call has a saved fallback returned on failure or timeout | PRD §6, §10 row 2 |
| REQ-N-005 | A notice that all data is synthetic and the product is not endorsed by BMC is visible in the app | PRD header, §4 |
| REQ-S-001 | The Claude API key is read from the server environment and never shipped in the app | PRD §6 |
| REQ-S-002 | Secrets and .env files are excluded from git | PRD §6 |
| REQ-O-001 | Postgres runs in Docker through a compose file | PRD §6 |
| REQ-O-002 | Documented run steps start engine, backend and app on the laptop with no deployment | PRD §6 |

### 5.2 Data Contracts

Tables: `users(id, phone unique, role check in citizen/corporator/officer, ward_code, created_at)`, `complaints(id, user_id, ward_code, locality, category, description, language, matched_complaint_id, status, created_at)`, `verification_reports(id, work_order_id, user_id, outcome check in held/failed, photo_path, created_at)`. One SQL init file run by compose.

### 5.3 API Contracts

`GET /api/health` · `GET /api/meta` · `GET /api/wards` (shading values) · `GET /api/wards/:code` · `GET /api/roads` (status per segment) · `GET /api/roads/:id` · `GET /api/contractors` · `GET /api/next-rupee/:ward` · `GET /api/timeline` · `POST /api/claude/:feature` (relay; returns `{text, source: live|fallback}`). Errors use `{error:{code,message}}` with 400, 404, 500.

### 5.4 UI Surfaces & States

Map home: default, loading (skeleton over map), error with retry, tiles-failed (shapes still drawn). Layer toggle chips. Departments sheet: roads live, others coming. Synthetic-data notice in the app bar menu.

### 5.5 Permissions & Roles

All GET endpoints are public in this task. Role enforcement arrives in TASK-07.

### 5.6 Assumptions

- ASSUMPTION: ward shade is flagged rupees divided by ward spend, in five steps — PRD says share of spend needing review — colours shift if a different base is wanted
- ASSUMPTION: a road's status is its most serious flag in the order DLP, failed, over rate, clean — PRD lists the statuses without a tie-break
- ASSUMPTION: the relay timeout is 20 seconds before the fallback is returned — PRD requires a fallback, not a number

## 6. Implementation Steps

1. Create `infra/docker-compose.yml` and the SQL init file; start Postgres
2. Scaffold `server/` with Express, config from environment, a single error handler and request logging
3. Load `audit.json` at start and implement the read endpoints
4. Implement the Claude relay with timeout, fallback lookup from `server/fallbacks/` and no key in responses
5. Add `.gitignore` entries for `.env` and build output
6. Run `flutter create` for Android and web in `app/`; add flutter_map, latlong2, flutter_riverpod, go_router, dio
7. Copy Saarthee theme, tokens, typography, needed widgets and CivicMap; remove Saarthee-specific imports
8. Bundle `wards.geojson` and `roads.geojson` as assets and parse them
9. Build the map home with ward polygons and road polylines coloured from the API
10. Add layer toggles, loading, error and tiles-failed states
11. Add the departments sheet and the synthetic-data notice
12. Write the run steps in the README

## 7. Acceptance Criteria

### 7.1 Behavioral

**AC-1** — Map is home
- **Given** the app is opened
- **When** it finishes loading
- **Then** the map of Mumbai is the first screen

**AC-2** — Ward shading
- **Given** the map home
- **When** ward data loads
- **Then** all 24 wards are drawn and shaded by share of spend needing review

**AC-3** — Road status
- **Given** the map home
- **When** road data loads
- **Then** 291 segments are drawn and coloured by status

**AC-4** — Layer toggles
- **Given** the map home
- **When** a layer chip is switched off
- **Then** that layer disappears and the others remain

**AC-5** — Tiles fail
- **Given** the device has no network for tiles
- **When** the map home opens
- **Then** ward and road shapes are still drawn

**AC-6** — Both targets
- **Given** the same code
- **When** it is run on the Android emulator and in Chrome
- **Then** the map home works on both

**AC-7** — Key stays on the server
- **Given** the built web app
- **When** its files are searched for the key
- **Then** the key is absent and Claude calls go through the relay

**AC-8** — Fallback
- **Given** the Claude call times out or fails
- **When** the relay responds
- **Then** it returns the saved text with source set to fallback

**AC-9** — Departments
- **Given** the departments sheet
- **When** it is opened
- **Then** roads is live and the others are marked coming with no figures

**AC-10** — Database
- **Given** docker compose is up
- **When** the server starts
- **Then** the three tables exist and health returns ok

### 7.2 Non-Functional Checklist

- [ ] Validation: all inputs validated server-side; client validation mirrors it with field-level messages
- [ ] Error states: every failure path renders a recoverable state, no unhandled rejections
- [ ] Loading states: every async surface has a loading representation
- [ ] Empty states: every list or collection surface has a designed empty state
- [ ] Logging: failures logged with context, no secrets or personal data in logs
- [ ] Accessibility: labelled controls, visible focus, adequate contrast
- [ ] Responsive: verified on the Android emulator and at desktop web width
- [ ] No hardcoded values that belong in config

## 8. Validation & Testing

| Level | What to test | Where |
|---|---|---|
| Manual | Walk through AC-1 to AC-10 by hand in the running product | emulator and Chrome |

## 9. Deliverables

- `server/` API and relay
- `infra/` compose and SQL
- `app/` Flutter project with map home
- Run steps

## 10. Files Expected to Change

An estimate, not a constraint.

- `server/` (new)
- `infra/` (new)
- `app/` (new)
- `.gitignore` (new)
- `README.md` (modified: run steps)

## 11. Related Documentation

- `docs/ideas/2026-11-21-nagar-sarthi-prd.md` (PRD §5 F0, §4, §6): the features and decisions this task implements
- `docs/ideas/2026-11-21-nagar-sarthi-prd.md` (§9 Cut order): what gives way if this task overruns
- `DATA_DICTIONARY.md`: column meanings for every file in `data/`

## 12. Risks & Considerations

| Risk | Impact | Mitigation |
|---|---|---|
| Copied Saarthee widgets pull in many dependencies | Lost time untangling imports | Copy theme and CivicMap first; copy a widget only when a screen needs it |
| Docker image pull fails on venue Wi-Fi | No database | Pull the image before starting; the read endpoints do not need Postgres |
| 291 polylines are slow on web | Janky map | Simplify to straight start-to-end lines, which is what roads.csv provides |

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
