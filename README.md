# Nagar Sarthi

Nagar Sarthi ("the city's guide") follows Mumbai's monsoon road-repair money from complaint to work order to road, and shows where it did not add up.

> **Note:** All data here is synthetic and the contractors are fictional. This is not a BMC product and does not use BMC data. It was built at Claude Impact Lab Mumbai on the organisers' made-up dataset. Do not use it to judge any real person, contractor or department.

## Contents

- [About](#about)
- [Architecture](#architecture)
- [Getting started](#getting-started)
- [Usage](#usage)
- [API reference](#api-reference)
- [Database schema](#database-schema)
- [Project structure](#project-structure)
- [Development](#development)
- [Troubleshooting](#troubleshooting)
- [The dataset](#the-dataset)
- [License](#license)

---

## About

### What it found

Across 2,499 repair jobs in the 2025 monsoon season (figures from `engine/out/audit.json`):

| Check | Jobs | Amount |
|---|---:|---:|
| Spend against budget, city-wide | 2,499 | ₹13.43 Cr of ₹14.91 Cr; 6 of 24 wards over their own budget |
| Billed on roads still under warranty (Defect Liability Period) | 493 | ₹2.62 Cr |
| Repairs re-opened within 30 days | 611 | ₹3.07 Cr |
| Billed above 1.5x the rate card | 109 | ₹1.12 Cr |
| Repeat job on the same road within 5 days, no complaint linked | 45 | ₹25.9 L |

Each of these is "needs review" or "to be claimed and verified", not a finding of wrongdoing.

### What it does

**Ward officer**
- A money map: tap a ward for its spend, budget and flags, tap a road for every job and the evidence behind each flag.
- An audit list of every flag in the ward, biggest rupees first, filterable by flag type, contractor, work order id or road name.
- Drafts a recovery notice for a job billed under warranty or above the rate card.
- A "next rupee" list: where the ward should spend next, with the score parts shown, and a budget what-if (slider, quick chips or a typed amount) that moves the funding line live.
- A complaint trail: 6,501 raw complaints cleaned into 3,396 issues (noise and other agencies' roads set aside, 15% of categories corrected), each followed to its work order and outcome, with inferred links marked and the method's measured accuracy shown.

**Corporator**
- Contractor scorecards (speed, how long repairs held, pricing), adjusted for repair method, with the work orders behind every number.
- A one-page ward brief in English, Hindi or Marathi.

**Citizen**
- Report a problem in your own words (English, Hindi, Marathi or Hinglish); the app finds neighbours who already reported it and the work order that followed.
- Track a complaint from report to repair, and whether the fix held.
- Ask "what happened to my complaint?" and get a plain answer built only from the complaint's own facts.
- Share a ward report card, and ask questions about the ward.

**Everyone:** "Play the monsoon", a time slider from 1 June to 31 October with complaints and failed repairs on the map. The app runs in English, Hindi and Marathi.

### How it works

- **Rules in code for every flag.** `engine/audit.py` (Python standard library only) reads `data/` and writes `engine/out/audit.json`. The same data always gives the same flags, scores and totals.
- **Claude for language only:** recovery notices, ward briefs, understanding a citizen's complaint, and answering questions. For "what happened to my complaint?" the server picks the facts and rejects any rupee figure Claude adds. Claude never decides a flag or a number.
- **Every Claude feature has a saved fallback.** With no API key or no network, the server answers from `server/fallbacks/` and the app marks the result as a saved draft.
- **Real ward boundaries.** The 24 ward outlines come from OpenCity / Oorvani Foundation via bharatlas (CC0-1.0). About 1 in 10 synthetic road and complaint positions are moved inside their own ward for display only; scoring uses the original coordinates.

### Tech stack

| Part | Built with |
|---|---|
| Audit engine | Python 3, standard library only |
| API server | Node.js (>= 20.12), Express 5, `pg`, `@anthropic-ai/sdk`, `cors`, `compression` |
| Database | Postgres 17 (`postgres:17-alpine` in Docker Compose) |
| App | Flutter (Dart SDK `^3.13.1`) for Android and web: `flutter_riverpod`, `go_router`, `dio`, `flutter_map`, `latlong2`, `share_plus`, `shared_preferences` |
| Language model | Claude, default model `claude-sonnet-5-5` |

---

## Architecture

```mermaid
flowchart LR
  data["data/*.csv<br/>(synthetic dataset)"] --> engine["engine/audit.py<br/>flags, scores, linker"]
  engine --> audit["engine/out/audit.json<br/>(committed)"]
  audit --> server["server/ (Express)<br/>:8787"]
  server <--> pg[("Postgres :5435<br/>users, complaints,<br/>verification_reports")]
  server <--> claude["Claude API"]
  server -.no key / error.-> fb["server/fallbacks/*.json"]
  app["app/ (Flutter)<br/>Android + web"] <--> server
```

The server loads `audit.json` at start and serves every read view from it, so maps, audits and scorecards work even when Postgres is down. Postgres only holds sign-ins and complaints filed in the app.

---

## Getting started

### Prerequisites

- Python 3 (standard library only; no packages to install)
- Node.js 20.12 or later (`engines` in `server/package.json`)
- Docker Desktop (for Postgres)
- Flutter with a Dart SDK matching `^3.13.1` (`app/pubspec.yaml`)

Everything runs on one laptop; nothing is deployed.

### Install and run

1. **Build the audit** (optional: `engine/out/audit.json` is committed). Re-run after changing `data/`, then restart the server.
   ```bash
   python3 engine/audit.py
   ```
2. **Start Postgres.** The container is `nagar-sarthi-db` on host port 5435; `infra/init.sql` creates the tables on first start.
   ```bash
   docker compose -f infra/docker-compose.yml up -d --wait
   docker exec nagar-sarthi-db psql -U nagar -d nagar_sarthi -c '\dt'
   ```
3. **Start the server** on http://localhost:8787. It creates the three demo users on start.
   ```bash
   cd server
   cp .env.example .env    # add ANTHROPIC_API_KEY here to use Claude live; never commit .env
   npm install
   npm start
   curl localhost:8787/api/health
   ```
4. **Run the app in Chrome:**
   ```bash
   cd app
   flutter run -d chrome
   ```
5. **Or run it on the Android emulator** (the emulator reaches the laptop at `10.0.2.2`):
   ```bash
   flutter emulators --launch <emulator_id>
   cd app
   flutter run -d emulator-5554
   ```

### Server environment variables

Set these in `server/.env` (git-ignored) or the shell; real environment variables win over the file. All are optional.

| Variable | Required | Description | Example |
|---|---|---|---|
| `ANTHROPIC_API_KEY` | No | Claude API key. Without it every Claude feature answers from `server/fallbacks/`. | |
| `CLAUDE_MODEL` | No | Model for live Claude calls. | `claude-sonnet-5-5` |
| `CLAUDE_TIMEOUT_MS` | No | Timeout for a Claude call before falling back. | `20000` |
| `PORT` | No | Server port. | `8787` |
| `DATABASE_URL` | No | Postgres connection string. | `postgres://nagar:nagar@localhost:5435/nagar_sarthi` |
| `AUDIT_PATH` | No | Path to the engine output. Defaults to `engine/out/audit.json`. | `engine/out/audit.json` |
| `DEMO_LOGIN_CODE` | No | The sign-in code for every account. | `246810` |
| `AUTH_SECRET` | No | Signs session tokens. Has a dev-only default; set a long random value anywhere beyond a laptop demo. | |
| `DEMO_SHORTCUTS` | No | `on` lets `GET /api/auth/demo` hand the app the demo code; `off` disables it. | `on` |

### App build options

Pass these to `flutter run` or `flutter build` with `--dart-define=NAME=value`.

| Define | Description | Default |
|---|---|---|
| `API_BASE` | Server address. | `http://localhost:8787` (web), `http://10.0.2.2:8787` (Android) |
| `MAP_TILE_URL` | Map tile URL template. | `https://tile.openstreetmap.org/{z}/{x}/{y}.png` |

---

## Usage

### Demo sign-in

The sign-in code is `DEMO_LOGIN_CODE` (default `246810`). All three demo users are in Ward E.

| Persona | Phone |
|---|---|
| Citizen | 9000000001 |
| Corporator | 9000000002 |
| Ward officer | 9000000003 |

In the app, tap the account button on Home, then **Demo: Ward officer**, **Demo: Corporator** or **Demo: Citizen** to switch roles in two taps. The full 8 to 10 minute stage script, with the ids and example texts to use, is in [docs/DEMO.md](docs/DEMO.md).

### Calling the API

```bash
# Health: audit timestamp and Postgres status
curl localhost:8787/api/health

# Ward E jobs billed on roads under warranty, biggest first
curl 'localhost:8787/api/flags?ward=E&type=dlp_paid&limit=5'

# Sign in as the ward officer and keep the token
TOKEN=$(curl -s localhost:8787/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"phone":"9000000003","code":"246810"}' | python3 -c 'import sys, json; print(json.load(sys.stdin)["token"])')

# Claude relay check: "source" is "live" with a key, "fallback" without
curl -s localhost:8787/api/claude/ping -H 'Content-Type: application/json' -d '{"message":"hello"}'
```

---

## API reference

All routes are under `http://localhost:8787`. Send a token as `Authorization: Bearer <token>`; tokens last 12 hours. Errors come back as `{"error": {"code", "message", "fields"?}}` with status 400, 401, 403, 404, 500 or 503 (Postgres down when filing a complaint).

<details>
<summary>All routes</summary>

| Method | Path | Description | Auth |
|---|---|---|---|
| GET | `/api/health` | Status, audit timestamp, Postgres status | None |
| POST | `/api/auth/login` | `{phone, code}` → `{token, role, ward_code, phone}` | None |
| GET | `/api/auth/demo` | Demo code and phone numbers (404 when `DEMO_SHORTCUTS=off`) | None |
| GET | `/api/meta` | Audit metadata: thresholds, weights, city totals | None |
| GET | `/api/wards` | All wards with spend, budget and flag totals | None |
| GET | `/api/wards/:code` | One ward in full (URL-encode codes like `H%2FE`) | None |
| GET | `/api/roads` | All roads with warranty status and spend | None |
| GET | `/api/roads/:id` | One road with its work orders and linked issues | None |
| GET | `/api/contractors` | All contractors | None |
| GET | `/api/scorecards` | Contractor scorecards; `?ward=` scopes to one ward | None |
| GET | `/api/contractors/:id/work-orders` | Work orders behind a measure: `?metric=speed\|durability\|pricing&ward=` | None |
| GET | `/api/next-rupee/:ward` | Ranked spending list with nearby facilities and flood hotspots | None |
| GET | `/api/flags` | Flags, filter by `ward`, `road`, `contractor`, `type`, `q`; paged by `offset`, `limit` (max 100) | None |
| GET | `/api/issues` | Linked issues, filter by `ward`, `outcome`, `q`; paged | None |
| GET | `/api/issues/:id` | One issue's full trail | None |
| GET | `/api/linker` | Complaint-to-issue funnel; `?ward=` or city-wide | None |
| GET | `/api/timeline` | Per-day data for the monsoon slider | None |
| GET | `/api/complaints/heat` | Open and repeat complaints on a ~1 km grid; `?ward=` | None |
| GET | `/api/localities` | Locality gazetteer with aliases | None |
| POST | `/api/complaints` | File a complaint (201) | Signed in |
| GET | `/api/complaints` | Complaints at `?locality=` | None |
| GET | `/api/complaints/matches` | Matching complaints for `?locality=&category=` | None |
| GET | `/api/complaints/:id` | One complaint's full trail | None |
| POST | `/api/claude/intake` | Understand a free-text complaint and find matches | None |
| POST | `/api/claude/:feature` | Claude relay: `ping`, `notice`, `brief`, `question`, `answer` → `{text, source}` | `notice`: ward officer |

</details>

Example, `GET /api/health` (shape from `server/src/index.js` and `server/src/db.js`):

```json
{
  "ok": true,
  "audit_generated_at": "2026-11-21T14:15:14",
  "db": { "ok": true, "tables": ["complaints", "users", "verification_reports"] }
}
```

---

## Database schema

Defined in [`infra/init.sql`](infra/init.sql), which runs once on the container's first start. The audit data itself is not in Postgres; it comes from `engine/out/audit.json`.

| Table | Columns |
|---|---|
| `users` | `id`, `phone` (unique), `role` (`citizen` / `corporator` / `officer`), `ward_code`, `created_at` |
| `complaints` | `id`, `user_id` → `users`, `ward_code`, `locality`, `category`, `description`, `language`, `matched_complaint_id`, `status` (default `open`), `created_at` |
| `verification_reports` | `id`, `work_order_id`, `user_id` → `users`, `outcome` (`held` / `failed`), `photo_path`, `created_at` |

---

## Project structure

```
.
├── data/                  # Organisers' synthetic dataset (CSV and GeoJSON)
├── engine/
│   ├── audit.py           # Entry point: data/ -> out/audit.json; --check runs self-checks
│   ├── linker.py          # Complaint -> issue -> work order linker
│   ├── snap.py            # Display-only snapping of points into real ward polygons
│   ├── geo/               # Real BMC ward boundaries
│   └── out/               # audit.json and roads_display.geojson (committed)
├── server/
│   ├── src/index.js       # Express app and all routes
│   ├── src/config.js      # Environment variables and defaults
│   ├── src/claude.js      # Claude relay with fallbacks
│   ├── src/*.js           # Auth, scorecards, issues, citizen intake, notice, brief, answer
│   └── fallbacks/         # Saved replies used when Claude is unavailable
├── app/
│   ├── lib/core/          # API client, auth, i18n, map, theme, shared widgets
│   ├── lib/features/      # Screens: home, map, audit, officer, corporator, citizen, trail, ward
│   ├── assets/            # Ward and road GeoJSON, fonts
│   ├── android/  web/     # Platform targets
│   └── tool/              # Launcher icon generator (macOS)
├── infra/                 # docker-compose.yml and init.sql for Postgres
├── docs/                  # Stage demo script, PRD, design brief, task plans
├── DATA_DICTIONARY.md     # Every dataset column explained
└── STARTER_IDEAS.md       # Organisers' build ideas and judging rubric
```

---

## Development

### Server scripts

| Command (in `server/`) | What it does |
|---|---|
| `npm start` | Runs `node src/index.js` |
| `npm run dev` | Runs `node --watch src/index.js` (restarts on file changes) |

### Checks

There is no unit test suite. The engine has built-in self-checks: expected flag counts, score parts that add up, every in-scope complaint in exactly one issue, and every display point inside its own ward and inside Mumbai.

```bash
python3 engine/audit.py --check
```

The app uses `flutter_lints` (see `app/analysis_options.yaml`):

```bash
cd app
flutter analyze
```

### Builds for a smooth demo

Debug builds stutter on the budget slider. Use a release web build or a profile build on Android:

```bash
cd app
flutter build web
python3 -m http.server 5056 --directory build/web   # open http://localhost:5056

flutter run --profile -d emulator-5554
```

To regenerate the Android launcher icons (macOS only, needs Swift):

```bash
sh app/tool/make_icons.sh
```

---

## Troubleshooting

From the "If something fails" table in [docs/DEMO.md](docs/DEMO.md):

| Problem | What you see | What to do |
|---|---|---|
| Server down | "Could not reach the Nagar Sarthi server" with Retry | `cd server && npm start`, then Retry. On Android check the app uses `10.0.2.2:8787`. |
| Postgres down | Map, panels and drafts still work; filing shows "database is down" | `docker compose -f infra/docker-compose.yml up -d --wait`, then Retry. |
| No map tiles (no internet) | Banner "Map tiles could not load" | Ward and road shapes still show; carry on. |
| No Claude key or Claude unavailable | "Saved draft" or "Understood on device rules" badges | Nothing to do; saved drafts are by design. |
| Sign-in fails | "Could not sign in" | Check the server is up. With `DEMO_SHORTCUTS=off`, type the phone and the `DEMO_LOGIN_CODE`. |
| "Your session has ended" | Snackbar with Sign in | The server restarted with a new `AUTH_SECRET`; sign in again. |
| Extra matches from rehearsals | Parel shows 6 or more matches | `docker exec nagar-sarthi-db psql -U nagar -d nagar_sarthi -c "TRUNCATE complaints RESTART IDENTITY"` |
| Slider stutters | Debug build | Use the release web build or `--profile` on Android. |

---

## The dataset

The data comes from the organisers of **Claude Impact Lab Mumbai** (21 November 2026, ATLAS SkillTech University; theme: accountability and budgeting), from their [Follow the Rupee: Mumbai Monsoon Roads](https://github.com/SumeetGDoshi/Claude-Impact-Labs-data-2) repository. The event was organised by Sumeet Doshi, Claude Community Ambassador, and run by the Claude Community in Mumbai with support from Anthropic.

> **Note:** Everything in `data/` is synthetic. It is not BMC data, it has no real citizens in it, and all contractors are fictional. Ward codes, locality names, arterial roads, flooding spots and major hospitals are real names used only for realism; every coordinate, amount, date and record is made up.

| File | Rows | What it is |
|---|---:|---|
| `data/wards.csv` + `wards.geojson` | 24 | BMC wards (A to T), approximate boundaries, monsoon repair budget |
| `data/work_orders.csv` | 2,499 | Repair jobs: contractor, method, area, cost, SLA, re-opened |
| `data/rate_card.csv` | 10 | Standard rate per repair method |
| `data/contractors.csv` | 8 | Fictional contractors |
| `data/complaints.csv` | 6,501 | App, helpline, portal and walk-in complaints (June to early October 2025) |
| `data/complaints_sample_200.csv` | 200 | Complaints from a heavy-rain spell (7 to 8 July) |
| `data/social_posts.csv` | 650 | X, WhatsApp and Instagram posts in mixed languages, with noise |
| `data/roads.csv` + `roads.geojson` | 291 | Road segments, incl. last resurfaced date and Defect Liability Period status |
| `data/localities.csv` | 118 | Localities with lat/lon and aliases (incl. Devanagari) |
| `data/flood_hotspots.csv` | 28 | Chronic waterlogging spots |
| `data/rainfall_daily.csv` | 244 | Daily rainfall, Santacruz and Colaba |
| `data/tides.csv` | 244 | Daily high tides, big-tide flag (>= 4.5 m) |
| `data/traffic.csv` | 291 | Peak-hour volume, speed and congestion per road segment |
| `data/accidents.csv` | 420 | Road accidents (2024 to 2025) with probable cause |
| `data/facilities.csv` | 160 | Hospitals and municipal schools with their nearest road |

Every column is explained in [DATA_DICTIONARY.md](DATA_DICTIONARY.md). The organisers' build ideas and judging rubric are in [STARTER_IDEAS.md](STARTER_IDEAS.md).

---

## License

The organisers' dataset and docs are released under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). The ward boundaries in `engine/geo/` and `app/assets/wards_real.geojson` are CC0-1.0 (OpenCity / Oorvani Foundation via bharatlas). No licence has been chosen yet for the Nagar Sarthi code.
