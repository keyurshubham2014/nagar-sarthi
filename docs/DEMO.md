# Nagar Sarthi: stage demo

Eight to ten minutes. The script follows PRD section 7. All data is synthetic; contractors are fictional.

## Before the show (15 minutes ahead)

1. **Postgres** (container `nagar-sarthi-db`, port 5435):
   ```bash
   docker compose -f infra/docker-compose.yml up -d --wait
   ```
2. **Clear rehearsal complaints**, so Parel shows exactly the 5 dataset matches:
   ```bash
   docker exec nagar-sarthi-db psql -U nagar -d nagar_sarthi -c "TRUNCATE complaints RESTART IDENTITY"
   ```
   The first complaint filed on stage is then `NS-000001`.
3. **Server** (port 8787). The engine does not need to run; `engine/out/audit.json` is committed.
   ```bash
   cd server && npm start
   curl localhost:8787/api/health      # "ok":true and db.ok true
   ```
   The log says `no key, fallbacks only` when there is no `ANTHROPIC_API_KEY`. That is fine: every Claude feature answers from a saved draft.
   The server creates the three demo users on start.
4. **App in Chrome** (desktop width). Use a release build; debug builds stutter on the slider.
   ```bash
   cd app && flutter build web
   python3 -m http.server 5056 --directory build/web    # open http://localhost:5056
   ```
5. **App on the Android emulator.** Use a profile build. The emulator reaches the laptop at `10.0.2.2:8787`.
   ```bash
   cd app && flutter run --profile -d emulator-5554
   ```
6. Wait until the map has loaded (wards shaded, the "Play the 2025 monsoon" bar visible) before the first tap. A fresh web load takes about 5 seconds.

## Sign-in

| Persona | Phone | Ward |
|---|---|---|
| Citizen | 9000000001 | E |
| Corporator | 9000000002 | E |
| Ward officer | 9000000003 | E |

- The code is the server's `DEMO_LOGIN_CODE` (default `246810`, see `server/.env.example`). The app never stores it.
- **Fastest switch (two taps):** tap the role chip in the app bar (it says "Sign in" when signed out), then tap "Demo: Ward officer", "Demo: Corporator" or "Demo: Citizen".
- The full sign-in screen ("Sign in with a number…" or "Switch account…" in the same menu) has the same three "Demo:" buttons. They fill the phone and code fields; then tap Sign in. A wrong code shows "That code is not right."
- The session lives in memory. Restarting the app signs you out.

## The script

### 1. Open on the money map (about 1 minute)

1. The map opens signed out, on the money map.
2. Tap **Play** (the round button on the "Play the 2025 monsoon" bar). It runs about 12 seconds, 1 Jun to 31 Oct.
3. It ends at **6,501 complaints · 2,499 repairs · 611 failed within 30 days · 183 roads repaired again after a failed fix**. Tap **Exit**.
4. Point at the hero card: **₹2.62 Cr billed on roads under warranty — to be claimed and verified** (493 jobs).

### 2. Officer: money trail, warranty flag, notice (about 2 minutes)

1. Role chip, then **Demo: Ward officer**. The chip now reads "Ward officer".
2. Tap the **hero card**. The ranking opens. Tap **2. E · Byculla, Agripada, Mumbai Central**.
   (On the map, ward E is the dark red ward around Byculla, south of F/S. The ranking row is the reliable tap.)
3. Ward E panel: spent ₹63.2 L against ₹53.0 L, **₹41.8 L to review**.
4. Tap **Billed while the road is under warranty** (41 jobs, ₹25.0 L).
5. Tap the first row **WO25-00014 · ₹85,657** to show its evidence: road under warranty Yes, billed ₹85,657, last resurfaced 2024-04-20.
6. Tap **Open road**. Maulana Azad Road opens with the "Billed while the road is under warranty" and "Under warranty" tags.
7. Tap **Draft recovery notice · Under warranty**. The notice opens with a **Saved draft** badge (or no badge when Claude answers live). It is editable; Copy works.

### 3. Officer: next rupee (about 1 minute)

1. Close the notice. Tap the back arrow twice to return to the ward E panel.
2. Scroll down and tap **Where should the next rupee go?** The pins appear on the map (desktop) and the list opens: three items under warranty (₹0 to the ward), then "Budget ends here".
3. Tap **1 · Open or broken manhole · Byculla**. The score breakdown shows: Severity 30/30, Near a hospital or school 30/30, Accidents 4/20, Flood hotspot 4.29/10, Traffic 3.9/10. Score 72.19.

### 4. Corporator: brief and scorecard (about 2 minutes)

1. Role chip, then **Demo: Corporator**. The notice buttons disappear; "Ward brief" and "Contractors in this ward" become the main buttons.
2. Tap the back arrow twice to the ward E panel. Tap **Ward brief**. Switch **English / हिंदी / मराठी** at the top of the sheet.
3. Close it. Tap **Contractors in this ward**.
4. On **Arabian Sea Engineering**: Speed 42% (11 of 19 late), Durability 32% (6 of 19 re-opened), Pricing 16% (3 of 19 above rate). The percentages match the counts.
5. Tap **6 of 19 re-opened** to show the six work orders behind that number.
6. Back. Scroll to **Deccan Paving Solutions**: "Not rated in this ward. Only 14 jobs in this ward; minimum is 15." No figures are shown.

### 5. Citizen: Marathi complaint, matches, track, share (about 2 minutes, Android is best)

1. Role chip, then **Demo: Citizen**. The citizen hub opens.
2. Optional: the **⋮** menu, then **मराठी**, turns the citizen screens, sign-in, hero card and chips into Marathi. Switch back with **English** in the same menu.
3. Tap **Report a problem**, then the **मराठी** example chip. The text is:
   `रेल्वे स्टेशन जवळ रस्त्यावर मोठा खड्डा आहे, परळ. लवकर दुरुस्त करा.`
4. Tap **Understand**. The card shows Language मराठी, Pothole, **Parel · Ward F/S**, and "Already reported: 5 neighbours raised this". The badge reads "Understood on device rules" without a key, or "Understood by Claude" when live.
5. Point at **BMC25-006359**: Resolved, WO25-02448, late, repair failed within 30 days. And **BMC25-006228**: held.
6. Tap **Add my voice**. It shows "Filed as NS-000001 · Your voice is added to BMC25-006359". Tap **Track** to see the timeline. Tap **Track it** to see the repair trail of BMC25-006359.
7. Back to the hub. Tap **My ward's report card**, type `Byculla`, pick **Ward E**. Tap **Share image** (Android share sheet) or **Download image** (web).

### 6. Close

Three lines: money comes back (officer), repairs that last (corporator), citizens can see (citizen). Roads today, every department next.

## Other texts and ids

- Hinglish example chip: `Bhai Kurla West station road pe bahut bada khadda hai, roz koi na koi girta hai. Please jaldi theek karo` gives Pothole · Kurla West · Ward L.
- English example chip: `Open manhole near bus stop, Poisar. Covered with water, not visible. Very dangerous!` gives Open or broken manhole · Poisar · Ward R/S.
- Ids to track: `BMC25-006359` (failed within 30 days), `BMC25-000014` (held, on time), `BMC25-001877` (never fixed).
- Ask my ward: hub, **Ask my ward**, pick Ward E, pick a topic. The question is drafted in the app language.

## If something fails

| Problem | What you see | What to do |
|---|---|---|
| Server down | "Could not reach the Nagar Sarthi server" with Retry | `cd server && npm start`, then tap Retry. On Android check the app uses `10.0.2.2:8787`. |
| Postgres down | Map, panels and drafts still work. Filing shows "database is down" with Retry. Sign-in still works for the three demo numbers. | `docker compose -f infra/docker-compose.yml up -d --wait`, then Retry. |
| No map tiles (no internet) | Banner "Map tiles could not load". Ward and road shapes still show. | Carry on; the shapes are enough. |
| Claude unavailable or no key | Notice, brief, question and intake answer at once from saved drafts, with a "Saved draft" / "Understood on device rules" badge. | Nothing to do. Say "this is the saved draft". |
| Sign-in fails | "Could not sign in" | Check the server is up. If `DEMO_SHORTCUTS=off` is set, type the phone and the code from `DEMO_LOGIN_CODE`. |
| "Your session has ended" | Snackbar with Sign in | The server restarted with a new `AUTH_SECRET`. Sign in again (role chip). |
| Parel shows 6 or more matches | Earlier rehearsal complaints | Run the TRUNCATE command above. |
| Slider stutters | Debug build | Use the release web build or `--profile` on Android. |
