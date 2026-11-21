# Requirements Registry — Nagar Sarthi

**Last Updated:** 2026-11-21
**Total Requirements:** 58 — **Covered:** 58 — **Uncovered:** 0

ID prefixes: `REQ-F` functional · `REQ-D` data · `REQ-N` non-functional · `REQ-S` security · `REQ-O` operational

Source: `docs/ideas/2026-11-21-nagar-sarthi-prd.md`

## Functional

| Req ID | Requirement | Source | Priority | Covered By |
|---|---|---|---|---|
| REQ-F-001 | Flag a work order billed above 1.5x the rate-card expected cost | PRD §5 F1 | P0 | TASK-01 |
| REQ-F-002 | Flag a repeat job on the same road and method within 5 days with no linked complaint | PRD §5 F1 | P0 | TASK-01 |
| REQ-F-003 | Flag a billed job on a road with under_dlp = Y | PRD §5 F1 | P0 | TASK-01 |
| REQ-F-004 | Flag a job with reopened_within_30d = Y | PRD §5 F1 | P0 | TASK-01 |
| REQ-F-005 | Flag a missed SLA and compare it to the average for the same repair method | PRD §5 F1 | P0 | TASK-01 |
| REQ-F-006 | Every flag carries work order id, road, contractor, amount and the numbers behind the rule | PRD §5 F1 | P0 | TASK-01 |
| REQ-F-007 | Per-ward money trail: budget vs spend, spend by contractor, by method and by flag type | PRD §5 F2 | P0 | TASK-01 |
| REQ-F-008 | Scorecard compares SLA and re-open rates to the same-method average | PRD §5 F3 | P0 | TASK-01 |
| REQ-F-009 | Scorecard discounts jobs in low-lying wards and heavy-rain weeks | PRD §5 F3 | P0 | TASK-01 |
| REQ-F-010 | Scorecard names one strength and one thing to improve per contractor | PRD §5 F3 | P0 | TASK-01 |
| REQ-F-011 | Scorecard shows no rating below a minimum sample size | PRD §5 F3 | P0 | TASK-01 |
| REQ-F-012 | Next-rupee risk score is safety first and exposes each part of the score | PRD §5 F4, §15 | P0 | TASK-01 |
| REQ-F-013 | Next-rupee recommends the method with the lowest re-open rate for the work type | PRD §5 F4 | P0 | TASK-01 |
| REQ-F-014 | Next-rupee list stops where the ward's remaining budget runs out | PRD §5 F4 | P0 | TASK-01 |
| REQ-F-015 | Complaints are linked to work orders and open issues with no work order are marked never fixed | PRD §5 F1, README Connect | P0 | TASK-01 |
| REQ-F-016 | The money map is the home screen for citizen, corporator and officer | PRD §5 F0 | P0 | TASK-02 |
| REQ-F-017 | Ward layer shades all 24 wards by share of spend needing review | PRD §5 F0 | P0 | TASK-02 |
| REQ-F-018 | Road layer draws 291 segments coloured by status | PRD §5 F0 | P0 | TASK-02 |
| REQ-F-019 | Map layers can be toggled on and off | PRD §5 F0 | P1 | TASK-02 |
| REQ-F-020 | Departments entry shows roads as live and other departments as coming, with no invented data | PRD §4 | P1 | TASK-02 |
| REQ-F-021 | Tapping a ward opens its money trail | PRD §5 F0, F2 | P0 | TASK-03 |
| REQ-F-022 | Tapping a road opens its work orders and flags | PRD §5 F0 | P0 | TASK-03 |
| REQ-F-023 | Next-rupee pins are numbered and show hospitals, schools and flood hotspots as the reason, with the score breakdown | PRD §5 F0, F4 | P0 | TASK-03 |
| REQ-F-024 | Officer generates a recovery notice drafted by Claude that cites work order ids, dates and amounts | PRD §5 F5 | P0 | TASK-03 |
| REQ-F-025 | The recovery notice is editable and copyable | PRD §5 F5 | P1 | TASK-03 |
| REQ-F-026 | Complaints heat layer shows open and repeat complaints as clusters | PRD §5 F0 | P1 | TASK-04 |
| REQ-F-027 | Play the monsoon: a June to October time slider animates rain, complaints, repairs and failed fixes | PRD §5 F0 | P1 | TASK-04 |
| REQ-F-028 | Contractor scorecard screen shows speed, durability, cost and volume, and each number opens its work orders | PRD §5 F3 | P0 | TASK-05 |
| REQ-F-029 | Ward brief is generated in English, Hindi and Marathi only from audit engine numbers | PRD §5 F7 | P0 | TASK-05 |
| REQ-F-030 | Claude-assisted intake classifies free text in four languages, finds the locality and shows matching complaints and their work order before filing | PRD §5 F6 | P1 | TASK-06 |
| REQ-F-031 | Plain complaint form with category, locality and description | PRD §5 F6 | P2 | TASK-06 |
| REQ-F-032 | Track a complaint by id or locality and see work order, contractor, cost, SLA result and whether the fix held | PRD §5 F6 | P1 | TASK-06 |
| REQ-F-033 | Citizen shares a ward report card | PRD §5 F8 | P1 | TASK-06 |
| REQ-F-034 | Citizen asks the ward a question drafted by Claude from the ward's data | PRD §5 F8 | P1 | TASK-06 |
| REQ-F-035 | Sign in with phone number and a fixed demo code | PRD §5 F9 | P2 | TASK-07 |
| REQ-F-036 | The signed-in role decides which views appear | PRD §5 F9 | P2 | TASK-07 |
| REQ-F-037 | Citizen-facing interface is available in English, Hindi and Marathi | PRD §5 F10 | P2 | TASK-07 |
| REQ-F-038 | Citizen reports a fix as held or failed with a photo (stretch, first cut) | PRD §5 F8, §9 | P2 | TASK-07 |

## Data

| Req ID | Requirement | Source | Priority | Covered By |
|---|---|---|---|---|
| REQ-D-001 | Audit engine writes one versioned JSON output with flags, ward trails, scorecards and next-rupee lists | PRD §6 | P0 | TASK-01 |
| REQ-D-002 | users table with phone and role | PRD §5 F9, §6 | P1 | TASK-02 |
| REQ-D-003 | complaints table for complaints raised in the app | PRD §5 F6, §6 | P1 | TASK-02 |
| REQ-D-004 | verification_reports table for held or failed reports | PRD §5 F8, §6 | P2 | TASK-02 |
| REQ-D-005 | Ward and road GeoJSON are bundled with the app | PRD §5 F0 | P0 | TASK-02 |

## Non-Functional

| Req ID | Requirement | Source | Priority | Covered By |
|---|---|---|---|---|
| REQ-N-001 | Audit counts match the PRD evidence table (109, 45, 493, 611) and are asserted by a self-check | PRD §5 F1, §2 | P0 | TASK-01 |
| REQ-N-002 | One Flutter codebase runs on the Android emulator and on web | PRD §6 | P0 | TASK-02 |
| REQ-N-003 | The map stays readable when tiles fail to load | PRD §5 F0 | P1 | TASK-02 |
| REQ-N-004 | Every live Claude call has a saved fallback returned on failure or timeout | PRD §6, §10 row 2 | P0 | TASK-02 |
| REQ-N-005 | A notice that all data is synthetic and the product is not endorsed by BMC is visible in the app | PRD header, §4 | P1 | TASK-02 |
| REQ-N-006 | Flags and scorecards are worded as needing review, never as accusations | PRD §5 F1, F3 | P0 | TASK-03 |
| REQ-N-007 | The monsoon slider plays without stutter on the Android emulator | PRD §5 F0 | P1 | TASK-04 |
| REQ-N-008 | The demo script runs end to end twice on emulator and web without code changes | PRD §13 | P0 | TASK-07 |

## Security

| Req ID | Requirement | Source | Priority | Covered By |
|---|---|---|---|---|
| REQ-S-001 | The Claude API key is read from the server environment and never shipped in the app | PRD §6 | P0 | TASK-02 |
| REQ-S-002 | Secrets and .env files are excluded from git | PRD §6 | P0 | TASK-02 |
| REQ-S-003 | Complaint submissions are validated server-side | PRD §5 F6 | P1 | TASK-06 |
| REQ-S-004 | Mutating endpoints require a signed-in user, checked server-side | PRD §5 F9 | P2 | TASK-07 |
| REQ-S-005 | Recovery notice endpoints reject non-officer roles | PRD §5 F9 | P2 | TASK-07 |

## Operational

| Req ID | Requirement | Source | Priority | Covered By |
|---|---|---|---|---|
| REQ-O-001 | Postgres runs in Docker through a compose file | PRD §6 | P0 | TASK-02 |
| REQ-O-002 | Documented run steps start engine, backend and app on the laptop with no deployment | PRD §6 | P1 | TASK-02 |

## Deferred / Out of Scope

| Req ID | Requirement | Source | Reason | Decided by |
|---|---|---|---|---|
| REQ-O-003 | iOS build of the app | PRD §6 | No Xcode on this Mac; same codebase, not built today | Keyur, 2026-11-21 |
| REQ-F-039 | Live data for departments other than roads | PRD §4 | Dataset covers monsoon road repairs only | Keyur, 2026-11-21 |
| REQ-S-006 | Real SMS one-time passcode | PRD §5 F9 | Needs an SMS provider; fixed demo code chosen | Keyur, 2026-11-21 |
| REQ-O-004 | Public deployment | PRD §6 | Laptop-only demo chosen | Keyur, 2026-11-21 |
