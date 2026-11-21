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
6. Wait until Home shows the city figure and the ward tiles before the first tap. A fresh web load takes about 5 seconds. The app remembers the last role, ward and language: open the account button on Home and pick **Sign out** if you want to start signed out.
7. Android phone check: the emulator was set to a 360 dp wide screen with `adb shell wm density 480` for the screenshots; `adb shell wm density reset` puts it back.

## How the app is laid out

Five tabs along the bottom (a rail on the left on a wide browser): **Home**, **Map**, the centre tab (**Report** for citizens and visitors, **Audit** for the ward officer and corporator), **Contractors**, **My Ward**. Details (ward, road, contractor, complaint, next rupee, notice and brief drafts, About) open as full pages; the back arrow or Android back returns to the tab. Back on any tab other than Home goes to Home.

## Sign-in

| Persona | Phone | Ward |
|---|---|---|
| Citizen | 9000000001 | E |
| Corporator | 9000000002 | E |
| Ward officer | 9000000003 | E |

- The code is the server's `DEMO_LOGIN_CODE` (default `246810`, see `server/.env.example`). The app never stores it.
- **Fastest switch (two taps):** on **Home**, tap the round **account button** (top right), then **Ward officer**, **Corporator** or **Citizen** under "Demo: switch role in one tap". Home, the centre tab and the greeting line ("Nagar Sarthi · Ward officer") change at once.
- The full sign-in screen (**Sign in with a number…** or **Switch account…** in the same sheet) has the same three "Demo:" buttons. They fill the phone and code; then tap Sign in. A wrong code shows "That code is not right."
- The session, the chosen ward and the language are saved on the device and survive an app restart. Staff sign-in makes their ward (E) the chosen ward.

## The script

### 1. Open on Home and the map (about 1 minute)

1. Home, signed out: **Mumbai this monsoon · ₹2.62 Cr billed on roads under warranty — to be claimed and verified** (493 jobs). Below it, Ward E's three tiles: share of budget spent, rupees to review, repairs that failed within 30 days.
2. Tap the **Watch the 2025 monsoon** tile (under "Do something" on Home). The Map tab opens and the season plays, about 12 seconds, 1 Jun to 31 Oct.
3. It ends at **6,501 complaints · 2,499 repairs · 611 failed within 30 days · 183 roads repaired again after a failed fix**. Tap **Exit**; the bar folds back into the **Play the monsoon** pill.
4. Point at the map: the 24 real ward boundaries, each with its code label. Tap ward **E** (around Byculla): it zooms in, its outline turns black, its roads appear and a card rises with **₹41.8 L to review**, the share of budget spent and the failed repairs. Tap a road for its card (spend and work orders), then **Open road**. **Layers** (top right) holds the layer switches and the legend.

### 2. Officer: audit list, warranty flag, notice (about 2 minutes)

1. Home, account button, **Demo: Ward officer**. Home now shows **₹41.8 L to review in Ward E**, the warranty, failed-repair and next-rupee tiles, and **Needs your attention**.
2. Tap the centre tab **Audit**. It lists every flag in Ward E, biggest rupees first, with the count and the rupee total.
3. Tap the chip **Under warranty**. The line reads **41 flags · ₹25.0 L to be claimed and verified**.
4. Tap the first row (**WO25-01942 · Clare Road**). The road page opens on that work order with its evidence open (road under warranty Yes, billed, last resurfaced), in the road's **Work orders** timeline.
5. Tap **Draft recovery notice** (pinned at the bottom), then **Billed while the road is under warranty** if the road has two flag types. The notice page opens with a **Saved draft** badge (or "Drafted live by Claude"). It is editable; Copy works. Back arrow twice returns to the Audit list.

The search box takes a work order id or a road name; the contractor menu filters by contractor; **Load more** pages through long lists.

### 3. Officer: next rupee (about 1 minute)

1. Home, **Where should the next rupee go?** The page opens on **Where should the next rupee go?** with the budget to plan with. Ward E has ₹0 left: 3 of 13 items funded (the warranty items, ₹0 to the ward), then "Funding stops here".
2. Tap **+₹5 L**: the line drops below item 11, "11 of 13 items funded", and "+₹5.0 L funds 8 more items, including 4 near a hospital and 3 near a school". Drag the slider or type an amount in lakh (e.g. `2.2`); **Reset** goes back. Ranks never change; tap a row for its five score parts.
3. Tap **Show the pins on the map**: the Map tab opens on Ward E with the numbered pins. Tap a pin for its score breakdown, or tap a row in the list instead.

### 3b. The complaint trail (about 1 minute)

1. Home (officer or corporator), **Complaint trail**, or **My Ward**, **Complaint trail**. Ward E's funnel: **277 complaints became 152 issues**: 2 not about roads, 22 not BMC's road, 253 grouped; 124 reached a work order (8 inferred); 86 fixed and held (₹42.4 L), 38 fixed then failed (₹20.1 L), 5 in progress, 23 never fixed; 17% of categories corrected. **All Mumbai**: 6,501 → 3,396 issues.
2. **How we link, and how often it is right**: the six method lines and the measured accuracy (category 83% → 98%, grouping 68% precision, inferred links 80% right).
3. In All Mumbai, search `ISS-00069`: one complaint filed as Broken paver blocks, **corrected to Pothole**, and work order WO25-00027 with the **Inferred link** chip and its evidence.
4. Chip **Social media only** (scroll the chips): issues with no matching complaint, e.g. ISS-01134 Waterlogging · Mankhurd, three posts, no work order.
5. From a road page, each work order has **Complaint trail: ISS-…**; a tracked complaint shows **Part of issue … · See the full trail**.

### 4. Corporator: brief and scorecard (about 2 minutes)

1. Home, account button, **Demo: Corporator**. Home leads with the **Ward brief** card, then the ward tiles, **Contractors in this ward** and **Top items to look at**. The centre tab still reads **Audit**; notice buttons are gone (officer only).
2. Tap **Ward brief**. Switch **English / हिंदी / मराठी** at the top of the page. Back.
3. Tap **My Ward** (last tab): change-ward card, budget against spend, rupees to review by type, then the tools (brief, next rupee, contractors in this ward, report card, ask my ward).
4. Tap the **Contractors** tab: contractors A to Z. Pick **Ward E** at the top to see only this ward. Tap **Arabian Sea Engineering**: the fairness note ("How this is kept fair"), then speed, durability and pricing against the typical value for the same kind of work. Tap a measure card to list the work orders behind that number; **See this contractor's flagged work orders** opens the Audit list filtered to that contractor.
5. In the Ward E list, **Deccan Paving Solutions** shows "Not rated in this ward" with no figures.

### 5. Citizen: Marathi complaint, matches, track, share (about 2 minutes, Android is best)

1. Home, account button, **Demo: Citizen**. Home shows the **Report a problem…** pill with a black **+**.
2. Optional: the round **EN** button at the top of Home, then **मराठी**, turns the citizen screens, tabs and sign-in into Marathi. Switch back the same way.
3. Tap **Report a problem** (or the centre **Report** tab), then the **मराठी** example chip. The text is:
   `रेल्वे स्टेशन जवळ रस्त्यावर मोठा खड्डा आहे, परळ. लवकर दुरुस्त करा.`
4. Tap **Continue**. "Here's what we understood" shows Pothole, **Parel**, **Ward F/S** and Marathi as rows you can change; the chip reads "Keyword rules, no AI" without a key, or "Understood by Claude" when live. Tap **Looks right**: "Others reported this" lists the 5 matches.
5. Point at **BMC25-006359**: Resolved, WO25-02448, late, repair failed within 30 days. And **BMC25-006228**: held.
6. Tap **Add my voice** (Demo: Citizen signs in from the sheet if needed). "Reported" shows **NS-000001** with a copy button. Tap **Track it** to see its timeline; **See the full trail** shows the repair trail of BMC25-006359.
7. **Track** (round search button top right of the Report tab, or **Track a complaint** on Home) also finds a complaint by id or by locality.
8. Home, **Ask about a complaint** (or the round chat button on the Report tab). Tap the chip **BMC25-006359**: a plain answer (work order WO25-02448, ₹13,566, failed within 30 days, needs review), the "Answered live by Claude" or "Saved answer" label, and cards to the complaint, the road and the issue. Tap **Why is my road still broken?** with no id: it answers from Ward E's figures and asks for the id. Type `BMC25-999999`: "could not find" with where to find the id. In हिंदी or मराठी the chips and answers follow the app language; a question typed in Hindi gets a Hindi answer.
9. Home, **My ward's report card**. Tap **Share image** (Android share sheet) or **Download image** (web).

### 6. Close

Three lines: money comes back (officer), repairs that last (corporator), citizens can see (citizen). Roads today, every department next.

## Other texts and ids

- Hinglish example chip: `Bhai Kurla West station road pe bahut bada khadda hai, roz koi na koi girta hai. Please jaldi theek karo` gives Pothole · Kurla West · Ward L.
- English example chip: `Open manhole near bus stop, Poisar. Covered with water, not visible. Very dangerous!` gives Open or broken manhole · Poisar · Ward R/S.
- Ids to track: `BMC25-006359` (failed within 30 days), `BMC25-000014` (held, on time), `BMC25-001877` (never fixed).
- Ask my ward: Home (citizen) or My Ward, **Ask my ward**, pick a topic. The question is drafted in the app language.

## If something fails

| Problem | What you see | What to do |
|---|---|---|
| Server down | "Could not reach the Nagar Sarthi server" with Retry | `cd server && npm start`, then tap Retry. On Android check the app uses `10.0.2.2:8787`. |
| Postgres down | Map, panels and drafts still work. Filing shows "database is down" with Retry. Sign-in still works for the three demo numbers. | `docker compose -f infra/docker-compose.yml up -d --wait`, then Retry. |
| No map tiles (no internet) | Banner "Map tiles could not load". Ward and road shapes still show. | Carry on; the shapes are enough. |
| Claude unavailable or no key | Notice, brief, question, intake and the complaint bot answer at once from saved drafts or templates, with a "Saved draft" / "Understood on device rules" badge. | Nothing to do. Say "this is the saved draft". |
| Sign-in fails | "Could not sign in" | Check the server is up. If `DEMO_SHORTCUTS=off` is set, type the phone and the code from `DEMO_LOGIN_CODE`. |
| "Your session has ended" | Snackbar with Sign in | The server restarted with a new `AUTH_SECRET`. Sign in again (account button on Home). |
| Parel shows 6 or more matches | Earlier rehearsal complaints | Run the TRUNCATE command above. |
| Slider stutters | Debug build | Use the release web build or `--profile` on Android. |
