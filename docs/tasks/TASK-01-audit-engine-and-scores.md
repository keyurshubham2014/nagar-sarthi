# TASK-01: Audit Engine and Scores

| Field | Value |
|---|---|
| Task ID | TASK-01 |
| Status | Not Started |
| Priority | P0 |
| Size | L |
| Depends On | None |
| Blocks | TASK-02 |
| Requirement IDs | REQ-F-001, REQ-F-002, REQ-F-003, REQ-F-004, REQ-F-005, REQ-F-006, REQ-F-007, REQ-F-008, REQ-F-009, REQ-F-010, REQ-F-011, REQ-F-012, REQ-F-013, REQ-F-014, REQ-F-015, REQ-D-001, REQ-N-001 |
| Primary Spec Refs | `docs/ideas/2026-11-21-nagar-sarthi-prd.md` (PRD §5 F1-F4, §2, §15) |
| Last Updated | 2026-11-21 |

## 1. Objective

A reproducible Python script turns the CSVs in `data/` into one JSON file holding every flag, ward money trail, contractor scorecard and next-rupee list. Everything later in the build reads this file, and it can be checked against the judges' answer key on its own.

## 2. Scope

### In Scope
- Five flag rules with evidence per flag
- Ward money trail totals
- Fair scorecard maths with all four fairness rules
- Safety-first risk score, method recommendation and budget cut-off
- Complaint to work order linkage and never-fixed list
- Assert-based self-check

### Out of Scope
- Serving the JSON over HTTP (TASK-02)
- Any screen (TASK-02 onward)
- Claude-written text (TASK-03, TASK-05)

## 3. Prerequisites

Python 3 standard library only (pandas is not installed). The 15 data files in `data/`.

## 4. Dependencies

Not applicable — this is the first task and depends on no other.

## 5. Technical Context

### 5.1 Requirements Covered

| Req ID | Requirement | Source |
|---|---|---|
| REQ-F-001 | Flag a work order billed above 1.5x the rate-card expected cost | PRD §5 F1 |
| REQ-F-002 | Flag a repeat job on the same road and method within 5 days with no linked complaint | PRD §5 F1 |
| REQ-F-003 | Flag a billed job on a road with under_dlp = Y | PRD §5 F1 |
| REQ-F-004 | Flag a job with reopened_within_30d = Y | PRD §5 F1 |
| REQ-F-005 | Flag a missed SLA and compare it to the average for the same repair method | PRD §5 F1 |
| REQ-F-006 | Every flag carries work order id, road, contractor, amount and the numbers behind the rule | PRD §5 F1 |
| REQ-F-007 | Per-ward money trail: budget vs spend, spend by contractor, by method and by flag type | PRD §5 F2 |
| REQ-F-008 | Scorecard compares SLA and re-open rates to the same-method average | PRD §5 F3 |
| REQ-F-009 | Scorecard discounts jobs in low-lying wards and heavy-rain weeks | PRD §5 F3 |
| REQ-F-010 | Scorecard names one strength and one thing to improve per contractor | PRD §5 F3 |
| REQ-F-011 | Scorecard shows no rating below a minimum sample size | PRD §5 F3 |
| REQ-F-012 | Next-rupee risk score is safety first and exposes each part of the score | PRD §5 F4, §15 |
| REQ-F-013 | Next-rupee recommends the method with the lowest re-open rate for the work type | PRD §5 F4 |
| REQ-F-014 | Next-rupee list stops where the ward's remaining budget runs out | PRD §5 F4 |
| REQ-F-015 | Complaints are linked to work orders and open issues with no work order are marked never fixed | PRD §5 F1, README Connect |
| REQ-D-001 | Audit engine writes one versioned JSON output with flags, ward trails, scorecards and next-rupee lists | PRD §6 |
| REQ-N-001 | Audit counts match the PRD evidence table (109, 45, 493, 611) and are asserted by a self-check | PRD §5 F1, §2 |

### 5.2 Data Contracts

Output `engine/out/audit.json` with top-level keys `meta`, `flags[]`, `wards{}`, `roads{}`, `contractors{}`, `next_rupee{}`, `timeline[]` (daily rain, complaints, repairs, re-opens for TASK-04). Flag row: `work_order_id, type, ward_code, road_id, contractor_id, cost_inr, expected_inr, ratio, reason, evidence{}`.

### 5.3 API Contracts

Not applicable — this task has no HTTP surface; TASK-02 serves the file.

### 5.4 UI Surfaces & States

Not applicable — no screens in this task.

### 5.5 Permissions & Roles

Not applicable — offline script, no users.

### 5.6 Assumptions

- ASSUMPTION: minimum sample size is 15 jobs per contractor per ward — PRD leaves the number open — ratings appear or disappear for small samples if wrong
- ASSUMPTION: heavy-rain week means a week containing an Orange or Red IMD alert day — PRD names heavy-rain weeks without a threshold — context discount shifts if wrong
- ASSUMPTION: risk weights are severity 30, hospital or school access 30, accidents 20, flood hotspot 10, traffic 10 — safety first was decided, exact numbers were left to this block — ranking order changes if wrong
- ASSUMPTION: remaining budget is ward budget minus spend, floored at zero — overspent wards get a ranked list with no funded items

## 6. Implementation Steps

1. Create `engine/` with a loader that reads all CSVs with the csv module and typed parsing
2. Compute expected cost per work order from the rate card (per sqm or per job) and the ratio
3. Implement the five flag rules as pure functions returning flag rows with evidence
4. Link complaints to work orders through `linked_complaint_ids`; list open complaints with no work order as never fixed
5. Aggregate the ward money trail
6. Compute method baselines, then scorecard metrics with ward and rain discounts, strengths, improvements and minimum sample
7. Build open issues per ward and score them with the safety-first weights, keeping each part of the score
8. Pick the method with the lowest re-open rate per work type and cut the list at remaining budget
9. Build the daily timeline for the monsoon slider
10. Write `audit.json` and run the self-check asserting 109, 45, 493 and 611

## 7. Acceptance Criteria

### 7.1 Behavioral

**AC-1** — Over-rate flags
- **Given** the full dataset
- **When** the engine runs
- **Then** exactly 109 work orders carry the over rate card flag and each has ratio above 1.5

**AC-2** — Double billing flags
- **Given** the full dataset
- **When** the engine runs
- **Then** exactly 45 work orders carry the possible double billing flag and none has a linked complaint

**AC-3** — DLP and failed-fix flags
- **Given** the full dataset
- **When** the engine runs
- **Then** 493 jobs carry the paid under DLP flag and 611 carry the fix failed flag

**AC-4** — Evidence on every flag
- **Given** any flag in the output
- **When** it is read
- **Then** it contains work order id, road, contractor, amount and the numbers behind the rule

**AC-5** — Fair SLA comparison
- **Given** a contractor with many excavation jobs
- **When** the scorecard is computed
- **Then** their SLA result is compared to the excavation average, not the overall average

**AC-6** — Minimum sample
- **Given** a contractor with fewer jobs in a ward than the minimum
- **When** the scorecard is computed
- **Then** no rating is produced for that ward and the reason is recorded

**AC-7** — Score is visible
- **Given** any next-rupee item
- **When** it is read
- **Then** it lists each part of its risk score and the parts add up to the total

**AC-8** — Budget cut-off
- **Given** a ward with remaining budget
- **When** the next-rupee list is built
- **Then** funded items stop where cumulative cost exceeds the remaining budget

**AC-9** — Never fixed
- **Given** an open complaint with no work order
- **When** the engine runs
- **Then** it appears in the ward's never-fixed list

### 7.2 Non-Functional Checklist

- [ ] Loading states: every async surface has a loading representation
- [ ] Logging: failures logged with context, no secrets or personal data in logs
- [ ] No hardcoded values that belong in config
- [ ] Follows patterns introduced in earlier tasks

## 8. Validation & Testing

| Level | What to test | Where |
|---|---|---|
| Self-check | Full run on `data/` asserting the four flag counts (AC-1 to AC-3) | engine/audit.py --check |
| Manual | Walk through AC-1 to AC-9 by hand in the running product | engine/out/audit.json |

## 9. Deliverables

- `engine/audit.py`
- `engine/out/audit.json`
- Self-check

## 10. Files Expected to Change

An estimate, not a constraint.

- `engine/` (new)

## 11. Related Documentation

- `docs/ideas/2026-11-21-nagar-sarthi-prd.md` (PRD §5 F1-F4, §2, §15): the features and decisions this task implements
- `docs/ideas/2026-11-21-nagar-sarthi-prd.md` (§9 Cut order): what gives way if this task overruns
- `DATA_DICTIONARY.md`: column meanings for every file in `data/`

## 12. Risks & Considerations

| Risk | Impact | Mitigation |
|---|---|---|
| Rules differ slightly from the answer key | Lost points on the 25% audit row | Keep thresholds as named constants at the top of the file so they can be changed in seconds |
| Scorecard maths overruns | Squeezes every later task | Time-box; ship like-with-like and minimum sample first, then discounts |

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
