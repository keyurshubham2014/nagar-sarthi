# TASK-07: Sign-in, Languages and Demo Readiness

| Field | Value |
|---|---|
| Task ID | TASK-07 |
| Status | Not Started |
| Priority | P2 |
| Size | M |
| Depends On | TASK-03, TASK-04, TASK-05, TASK-06 |
| Blocks | None |
| Requirement IDs | REQ-F-035, REQ-F-036, REQ-F-037, REQ-F-038, REQ-N-008, REQ-S-004, REQ-S-005 |
| Primary Spec Refs | `docs/ideas/2026-11-21-nagar-sarthi-prd.md` (PRD §5 F8-F10, §7, §9, §13) |
| Last Updated | 2026-11-21 |

## 1. Objective

Users sign in with a phone number and a fixed demo code, see the views for their role in their language, and the whole demo script runs twice without touching code. Reporting a failed fix is added only if time remains.

## 2. Scope

### In Scope
- Phone plus fixed-code sign-in and sessions
- Role-based views and server-side role checks
- English, Hindi and Marathi interface for citizen views
- Fallbacks verified for all four live calls
- Two full rehearsals on emulator and web
- Stretch: report a failed fix with a photo

### Out of Scope
- Real SMS codes (deferred)
- Deployment (deferred)
- iOS build (deferred)

## 3. Prerequisites

TASK-03, TASK-04, TASK-05 and TASK-06 in a demonstrable state.

## 4. Dependencies

| Task | Why it is required |
|---|---|
| TASK-03 | Provides officer flow: money trail, flags, recovery notice, next rupee, which this task builds on |
| TASK-04 | Provides play the monsoon: time slider and complaints heat, which this task builds on |
| TASK-05 | Provides corporator flow: fair scorecards and ward brief, which this task builds on |
| TASK-06 | Provides citizen flow: raise, track, share, ask, which this task builds on |

## 5. Technical Context

### 5.1 Requirements Covered

| Req ID | Requirement | Source |
|---|---|---|
| REQ-F-035 | Sign in with phone number and a fixed demo code | PRD §5 F9 |
| REQ-F-036 | The signed-in role decides which views appear | PRD §5 F9 |
| REQ-F-037 | Citizen-facing interface is available in English, Hindi and Marathi | PRD §5 F10 |
| REQ-F-038 | Citizen reports a fix as held or failed with a photo (stretch, first cut) | PRD §5 F8, §9 |
| REQ-N-008 | The demo script runs end to end twice on emulator and web without code changes | PRD §13 |
| REQ-S-004 | Mutating endpoints require a signed-in user, checked server-side | PRD §5 F9 |
| REQ-S-005 | Recovery notice endpoints reject non-officer roles | PRD §5 F9 |

### 5.2 Data Contracts

Writes `users` and, for the stretch item, `verification_reports` (columns in TASK-02). Three seeded users, one per role.

### 5.3 API Contracts

`POST /api/auth/login` body `{phone, code}` returns a session token and role; 401 on a wrong code. Middleware: 401 without a session on mutating routes, 403 for non-officers on `POST /api/claude/notice`. Stretch: `POST /api/verifications` (multipart: work_order_id, outcome, photo).

### 5.4 UI Surfaces & States

Sign-in screen: default, invalid code, in-flight. Role-based navigation. Unauthorized state where a role lacks access. Language switch in settings. Stretch: held or failed sheet with photo picker and confirmation.

### 5.5 Permissions & Roles

Citizen: file complaints, verify fixes, read everything public. Corporator: adds scorecards and briefs. Officer: adds recovery notices and next-rupee. Unauthorized actors see an explanation, never a broken view.

### 5.6 Assumptions

- ASSUMPTION: the fixed demo code is read from server config, not hardcoded in the app
- ASSUMPTION: sessions are signed tokens held in memory on the client; they do not survive an app restart
- ASSUMPTION: officer views stay in English, per the PRD

## 6. Implementation Steps

1. Seed three users; add login with the configured code and a signed token
2. Add session and role middleware; protect mutating routes and the notice route
3. Build the sign-in screen and route guard
4. Show navigation and views by role, with an unauthorized state
5. Add Flutter localisation with English, Hindi and Marathi strings for citizen views
6. Run each live Claude call with the network off and confirm the fallback shows
7. Stretch, only if ahead of time: verification endpoint, sheet and photo picker
8. Rehearse the demo script twice on emulator and web; fix only what blocks it

## 7. Acceptance Criteria

### 7.1 Behavioral

**AC-1** — Sign in
- **Given** a seeded officer phone number and the demo code
- **When** sign-in is submitted
- **Then** the officer views open

**AC-2** — Wrong code
- **Given** a wrong code
- **When** sign-in is submitted
- **Then** an invalid code message shows and no session is created

**AC-3** — Role decides views
- **Given** a signed-in citizen
- **When** the app opens
- **Then** officer-only actions are absent

**AC-4** — Server enforces roles
- **Given** a citizen session
- **When** the notice endpoint is called directly
- **Then** the server responds 403

**AC-5** — Signed-out writes rejected
- **Given** no session
- **When** a complaint is posted
- **Then** the server responds 401

**AC-6** — Languages
- **Given** the citizen views
- **When** the language is switched to Hindi and to Marathi
- **Then** labels change to that language

**AC-7** — Demo holds
- **Given** the demo script in PRD section 7
- **When** it is run twice on emulator and web
- **Then** it completes both times without a code change

**AC-8** — Failed fix report (stretch)
- **Given** a completed repair
- **When** a citizen reports it failed with a photo
- **Then** the report is saved and confirmed

### 7.2 Non-Functional Checklist

- [ ] Validation: all inputs validated server-side; client validation mirrors it with field-level messages
- [ ] Error states: every failure path renders a recoverable state, no unhandled rejections
- [ ] Loading states: every async surface has a loading representation
- [ ] Authorization: every mutating endpoint enforces role checks server-side
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

- Sign-in and role guard
- Three-language strings
- Verified fallbacks
- Rehearsed demo

## 10. Files Expected to Change

An estimate, not a constraint.

- `app/lib/features/auth/` (new)
- `app/lib/l10n/` (new)
- `server/` (modified: auth, middleware)

## 11. Related Documentation

- `docs/ideas/2026-11-21-nagar-sarthi-prd.md` (PRD §5 F8-F10, §7, §9, §13): the features and decisions this task implements
- `docs/ideas/2026-11-21-nagar-sarthi-prd.md` (§9 Cut order): what gives way if this task overruns
- `DATA_DICTIONARY.md`: column meanings for every file in `data/`

## 12. Risks & Considerations

| Risk | Impact | Mitigation |
|---|---|---|
| This task is squeezed by earlier overruns | Sign-in or languages unfinished | Cut order: failed-fix report, then sign-in becomes a role picker, then translated interface |
| Rehearsal finds a blocking bug late | Broken demo | Rehearse the officer path as soon as TASK-03 lands, not only here |

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
