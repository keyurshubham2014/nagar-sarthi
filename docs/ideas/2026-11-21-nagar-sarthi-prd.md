# Nagar Sarthi: PRD

**Date:** 2026-11-21 · **Mode:** Refine · **Depth:** Deep dive
**Event:** Claude Impact Lab Mumbai, "Follow the Rupee" · **Build window:** about 3 h 15 min left of 4 h, solo with Claude Code
**Verdict:** Go, on the condition that the cut order in section 9 is followed

All data is synthetic. Contractors are fictional. This is not BMC data and the product is not endorsed by BMC.

## 1. In one line

Nagar Sarthi shows every ward where its repair money went, whether the work lasted, what can be claimed back and where the next rupee should go, for the citizen, the corporator and the ward officer, from one audited set of numbers.

## 2. The problem

Every monsoon the city pays to fix the same roads. Nobody can easily answer: where did the money go, did the fix last, who is responsible.

Evidence from the dataset (computed with a standard-library Python script over `data/`):

| Signal | Jobs | Money |
|---|---:|---:|
| Total spend vs budget | 2,499 | ₹13.4 cr of ₹14.9 cr |
| Billed while the road was under Defect Liability Period (DLP) | 493 | ₹2.62 cr |
| Fix failed within 30 days | 611 | ₹3.07 cr |
| Billed above 1.5x the rate card | 109 | ₹1.12 cr billed, ₹60 lakh above standard |
| Repeat job, same road and method within 5 days, no complaint linked | 45 | ₹26 lakh |

- Normal jobs reach about 1.3x the rate card (95th percentile). The next cluster starts at 1.87x. The 1.5x line sits in the empty gap.
- 79 of the 109 over-rate jobs belong to two contractors.
- Re-open rate by contractor runs from 9% to 39%.
- SLA is met on 1 to 2% of excavation and manhole jobs for every contractor, so raw SLA scores are unfair.
- 617 complaints are open. 43% of complaints are Hinglish, Marathi or Hindi.

Assumption, not evidence: that the same pattern exists in real BMC data.

## 3. Who it's for

| Persona | What they need | What they do in the app |
|---|---|---|
| Ward officer | Know what to query, claim and fix next | Reviews flags, generates recovery notices, sees the next-rupee list |
| Corporator | A readable account to question the ward office | Reads the ward brief and contractor scorecards |
| Citizen | See what happened to their complaint and their ward | Raises and tracks complaints, shares the ward report card, asks the ward a question, reports a failed fix |

Not for: contractors, and not a replacement for the BMC's complaint system of record.

## 4. Product frame

- Name: **Nagar Sarthi** ("the city's guide"). Covers all municipal services, not only roads.
- Home screen lists departments. **Roads and monsoon repairs is live.** Other departments show "coming", with no invented data.
- Three closing lines, one per persona: money comes back (officer), repairs that last (corporator), citizens can see (citizen).
- Hero moment of the demo: **₹2.62 cr billed on roads under warranty, to be claimed and verified, with the notices drafted.**

## 5. Features

### F0. Money map (home screen for all three personas)
Everyone lands on a map of Mumbai. Lists, briefs and notices open from taps on it. Built on `flutter_map` with OpenStreetMap tiles, using the `CivicMap` widget borrowed from Saarthee. Shapes come from the local `wards.geojson` and `roads.geojson`, so the map still reads if tiles fail to load.

| Layer | What it shows | Tap opens |
|---|---|---|
| Wards | 24 wards shaded by share of spend needing review | Ward money trail (F2) |
| Road segments | 291 roads as lines: billed under warranty, fix failed, over rate, clean | That road's work orders and flags |
| Next-rupee pins | Numbered pins for where to spend next, with hospitals, schools and flood hotspots as the reason | The score breakdown (F4) |
| Complaints heat | Open and repeat complaints as clusters | Complaint list for that spot |

**Play the monsoon:** a time slider from June to October. Rain falls, complaints appear, repairs light up, failed fixes turn red. It shows the same road being paid for more than once.

Acceptance: all four layers toggle, a tap on a ward or road opens its evidence, the slider plays the season without stutter on the Android emulator.

### F1. Audit engine (build first)
A script reads the CSVs and writes every flag, score and total. Rules live in code so results are reproducible and can be checked against the judges' answer key. Claude does not decide flags.

| Flag | Rule | Wording shown |
|---|---|---|
| Over rate card | `cost_inr` above 1.5x expected (`area_sqm` x rate for per-sqm methods, flat rate for per-job) | "Billed N times the standard rate. Needs review." |
| Possible double billing | Same `road_id` and `repair_method` assigned within 5 days of an earlier job, and no linked complaint | "Repeat job with no complaint linked. Needs review." |
| Paid under DLP | Road has `under_dlp = Y` and the job was billed | "Road is under warranty. To be claimed and verified." |
| Fix failed | `reopened_within_30d = Y` | "Repair failed within 30 days." |
| SLA missed | `sla_met = N`, shown against the average for the same method | "Slower than typical for this type of work." |

Every flag carries its work order id, road, contractor, amount and the numbers behind the rule.

Acceptance: counts match section 2 (109, 45, 493, 611). One assert-based self-check in the script.

### F2. Ward money trail
Per ward: budget vs spend, spend by contractor and by repair method, money in each flag type, and money spent on fixes that failed. A map of wards coloured by flagged share.

### F3. Fair contractor scorecard
Speed, durability, cost vs rate card, volume. Fairness rules, all four chosen:
- Like with like: SLA and re-open rates compared to the average for the same repair method.
- Ward and rain: jobs in low-lying wards (`low_lying_index`) and heavy-rain weeks (`rainfall_daily`) are discounted before a contractor is marked down.
- Strengths too: each card names one strength and one thing to improve.
- Minimum sample: no rating where a contractor has too few jobs in a ward.

Cards say "needs review", never accuse. Each number opens the work orders behind it.

### F4. Next rupee planner
Ranks open issues in a ward against the remaining budget using a **visible risk score**. Each row shows the parts of its score. Proposed default formula (not yet confirmed, see open questions):

`risk = severity + flood hotspot + traffic (congestion, bus route) + accident history on the road + hospital or school on the road`

Method recommendation prefers the method with the lowest re-open rate for that work type, not the cheapest. The list stops where the remaining budget runs out.

### F5. Recovery notices (live Claude)
Officer taps a flag or a group of flags. Claude drafts the DLP claim or billing query letter, citing work order ids, dates and amounts. Editable and copyable.

### F6. Complaints: raise and track
- **Claude-assisted intake:** free text in English, Hindi, Marathi or Hinglish. Claude classifies the issue, finds the locality from `localities.csv` (including Devanagari aliases) and shows matching existing complaints and their work order before filing.
- **Plain form:** category, locality, description, for people who prefer it.
- **Track:** by complaint id or locality. Shows work order, contractor, cost, SLA result and whether the fix held.

### F7. Ward brief in three languages (live Claude)
One page a citizen or corporator can read, in English, Hindi and Marathi. Built only from the audit engine's numbers.

### F8. Citizen actions
- Share a ward report card (image or link for WhatsApp).
- Ask the ward a question: Claude drafts a polite, evidence-based question from the ward's data.
- Report a failed fix: held or broke again, with a photo. **First to be cut.**

### F9. Sign-in and roles
Phone number plus a fixed demo code. Users and roles stored in Postgres. Role decides which views appear.

### F10. Languages
Interface and Claude answers in English, Hindi and Marathi for citizen views. Officer view in English.

## 6. Technical shape

| Part | Choice |
|---|---|
| App | Flutter, one codebase. Targets: Android (emulator) and web. iOS not built today: no Xcode on this Mac |
| Reuse | A new lean app. Copies Saarthee's design tokens (`core/theme`), core widgets (`core/widgets`, including scorecard bars and stat tiles) and `core/map/civic_map.dart`. No fork: Saarthee's Firebase auth, Prisma, PostGIS and Ahmedabad ward data are left behind |
| Map | `flutter_map` and `latlong2`, OpenStreetMap tiles, local GeoJSON for wards and roads |
| Backend | Node.js. Serves audit JSON, holds the Claude API key, relays Claude calls |
| Database | Postgres in Docker. Users, roles, new complaints, verification reports |
| Audit engine | Python, standard library only (pandas is not installed). Writes JSON the backend serves |
| Claude | Live calls for F5, F6, F7 and the citizen's question, each with saved output as fallback |
| Hosting | Laptop only |

The API key never ships inside the Flutter app.

## 7. Demo script (8 to 10 minutes)

1. Open on the money map. Play the monsoon for ten seconds. Then the hero number: ₹2.62 cr to be claimed and verified.
2. Officer: tap a shaded ward, money trail, tap a red road, its DLP flag and evidence, Claude drafts the notice live.
3. Officer: next-rupee list with the score parts visible.
4. Corporator: ward brief and a contractor scorecard with its fairness notes.
5. Citizen on Android: raise a complaint in Marathi, Claude finds the matching issue and its work order, share the ward report card.
6. Close: three lines, one per persona. Roads today, every department next.

## 8. Build order (about 3 h left)

| # | Block | Time | Rubric rows it serves |
|---|---|---:|---|
| 1 | Audit engine and JSON, with self-check | 35 min | Audit accuracy 25%, Connect 15% |
| 2 | Next-rupee score and fair scorecard maths | 20 min | Budget 20%, Fairness 20% |
| 3 | Node backend, Docker Postgres, Claude relay | 20 min | all |
| 4 | Flutter shell with borrowed Saarthee theme and widgets, money map with ward and road layers | 40 min | Usable 10%, Demo 10% |
| 5 | Officer panels from map taps: flags, recovery notice, next-rupee pins | 25 min | Audit 25%, Budget 20% |
| 6 | Play the monsoon slider, complaints heat layer | 25 min | Demo 10%, Connect 15% |
| 7 | Corporator views (F3, F7) | 15 min | Fairness 20% |
| 8 | Citizen views (F6, share, ask) | 20 min | Connect 15%, Usable 10% |
| 9 | Sign-in, three languages | 10 min | none directly |
| 10 | Saved fallbacks, rehearsal on emulator and web | 10 min | Demo 10% |

These blocks add up to 3 h 40 min against about 3 h available. The plan is about 40 minutes over before anything goes wrong, so the cut order below will be used, not held in reserve.

Fix verification is built only if block 10 finishes early.

## 9. Cut order when time runs short

1. Fix verification (agreed first cut)
2. Sign-in becomes a role picker
3. Hindi and Marathi interface (keep multilingual complaint reading)
4. Plain complaint form (keep Claude-assisted intake)

5. Complaints heat layer

Never cut: audit engine, money map with ward and road layers, recovery notices, next-rupee list.

## 10. Challenges and how they landed

| # | Challenge | Tag | Outcome |
|---|---|---|---|
| 1 | Four hours does not fit four steps, three personas and two platforms | [SERIOUS] | Keyur chose the full scope. Managed by build order and cut order |
| 2 | A failed live Claude call loses the demo | [SERIOUS] | Changed the idea: saved fallback for every live call |
| 3 | DLP total is 20% of spend and may not all be recoverable | [MINOR] | Changed the idea: worded "to be claimed and verified" |
| 4 | Public flags can read as accusation | [MINOR] | Changed the idea: evidence, not verdicts |
| 5 | No phone demo path | [SERIOUS] | Partly wrong: Android emulators exist. Android and web chosen, iOS not built |
| 6 | Fix verification needs a backend | [SERIOUS] | Holds up: Node and Postgres now exist anyway. Still first to be cut |
| 7 | Raising complaints duplicates MyBMC | [SERIOUS] | Changed the idea: intake de-duplicates and links to the work order |
| 8 | "BMC" in the name implies endorsement | [SERIOUS] | Changed the idea: Nagar Sarthi |
| 9 | Dataset covers roads only, product claims all services | [SERIOUS] | Changed the idea: roads live, other departments "coming" |
| 10 | Real sign-in and Postgres cost about an hour and score nothing | [SERIOUS] | Keyur chose both. Reduced to phone plus fixed code, placed late in the build |
| 11 | Saarthee already does raise, track and verify, so rebuilding them repeats old work | [SERIOUS] | Changed the idea: citizen flows stay thin, time goes to the money map and audit |
| 12 | Forking all of Saarthee means rewiring Firebase, PostGIS and Ahmedabad wards | [SERIOUS] | Changed the idea: borrow theme, widgets and map only |
| 13 | Map tiles need venue Wi-Fi | [MINOR] | Holds up: ward and road shapes draw from local GeoJSON |

## 11. Risks

1. Scope. Ten features solo in about three hours. If blocks 1 and 2 overrun, everything after is squeezed. The organisers' own advice is "go narrow and finish".
2. Docker or the Postgres image not available on venue Wi-Fi. Pull the image before anything else.
3. Venue Wi-Fi for live Claude calls. Fallbacks must be tested, not assumed.
4. Sign-in and Postgres were kept against the recommendation. They serve no rubric row.

## 12. Pre-mortem

"The demo failed." Most likely reasons:
1. The app looked wide but the flags did not match the answer key, because audit time went to screens.
2. Something half-built was shown on stage.
3. The live call hung and there was no rehearsed fallback.

## 13. How we'll know it worked

- Flag counts match section 2 and each flag opens its work orders.
- The demo script runs end to end twice on the emulator and web without touching code.
- A judge can repeat the hero number and what the officer does about it.

## 14. Decisions made

- Product: Ward Audit Brief with added features.
- Users: citizen, corporator and ward officer, all three.
- App: Flutter. Targets Android and web. Backend Node.js. Database Postgres in Docker. Laptop-only demo.
- Extras: recovery notices, track my complaint, citizen fix verification.
- Citizens can raise complaints (Claude-assisted and plain form), track them, share a ward report card, ask the ward a question, report a failed fix.
- Hero moment: recoverable crores, worded "to be claimed and verified".
- Contractors: evidence, not verdicts. All four fairness rules.
- Next rupee: transparent risk score, not Claude ranking.
- Languages: English, Hindi, Marathi.
- Live Claude: notices, intake, ward brief, citizen's question. Saved fallbacks for each.
- Sign-in: phone plus fixed demo code.
- First cut: fix verification.
- Name: Nagar Sarthi. Roads live, other departments "coming".
- Solo build with Claude Code, 8 to 10 minute live demo.
- Reuse from Saarthee: theme, widgets and map only. No fork.
- Map is the home screen for all three personas.
- Map layers: wards shaded by rupees to review, road segments by status, next-rupee pins, complaints heat.
- Wow moment: play the monsoon time slider.

## 15. Open questions

- Risk score, decided: safety first. Severity and hospital or school access weigh most, then accidents, flood hotspot, traffic. Exact numbers set in block 2.
- Claude API key, decided: available in Keyur's environment; the Node backend reads it from there.
- Time overrun, decided: follow the cut order.
- Minimum sample size for a scorecard rating: number not chosen.
- Does the complaint-to-issue step need its own de-duplication beyond BMC's `linked_complaint_ids`: decide after block 1, based on time left.

## 16. Verdict

**Go.** The data has four clear, checkable audit signals and a strong headline number, and the plan puts the scored work first. The scope is larger than four hours comfortably allows, so the verdict depends on following the build order and cutting in the agreed order instead of stretching every feature. If block 1 and 2 are not done by the 60 minute mark, drop to officer and corporator views only.

## 17. Next step

Start block 1, the audit engine. Pull the Postgres Docker image in the background at the same time.

## Sources

- `README.md`, `STARTER_IDEAS.md`, `DATA_DICTIONARY.md`: challenge, rubric, column meanings.
- `data/*.csv`: all figures in section 2.
- https://github.com/keyurshubham2014/saarthee-app: Keyur's earlier civic app. Source of the theme, widgets and `CivicMap`; shows raise, track and verify already exist there.
- Local toolchain check: Flutter and Docker present, three Android emulators, no Xcode, no Postgres, no pandas.
