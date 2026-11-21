# Nagar Sarthi: design brief for all screens

This brief is self-contained. It describes the product, the visual direction, the design system and every
screen, with real sample content, so a designer can produce the full set of mobile screens without seeing
the code.

## 1. What to deliver

- High-fidelity mobile screens for every page in section 7, at **390 × 844** (also check 360 wide).
- Light theme for all screens. Dark theme for: Home (citizen), Map, Audit, Road page.
- For each screen: the default state, plus the loading (skeleton), empty and error states where the section
  lists them.
- A component sheet (section 5) and a token sheet (section 4).
- Motion notes or a short prototype for: tab change, page push, tile press, map ward selection, monsoon player,
  budget slider, report flow success.
- Desktop web (1440 wide) for: Home (officer), Map, Audit. Left rail instead of the bottom tab bar.
- Three languages exist: English, Hindi, Marathi. Design in English; also show Home (citizen), Report step 1 and
  the citizen bot in Marathi to prove Devanagari fits.

## 2. The product

**Nagar Sarthi** ("city guide") is a civic accountability app for Mumbai's municipal road repairs. During the
monsoon the city pays contractors to fix potholes, waterlogging and broken manholes. The app follows that money:
which repairs were billed on roads still under the contractor's warranty, which were billed above the standard
rate, which failed within 30 days, and where the next rupee should go.

It runs on a synthetic dataset. Contractor names are fictional. It is a prototype, not an official municipal
product. A short line saying so appears on Home and on About, not on every screen.

**Tone of voice:** calm, factual, neutral. Evidence, not verdicts. Always "needs review" and "to be claimed and
verified". Never "fraud", "scam", "corrupt" or "overcharged". Plain words; a citizen with no finance background
must understand every label.

### Who uses it

| Role | What they want | Centre tab |
|---|---|---|
| **Citizen** (also signed out) | Report a problem, see what happened to a complaint, understand their ward's spending | Report |
| **Corporator** (elected ward representative) | A brief on their ward, which contractors perform, what to raise | Audit |
| **Ward officer** (municipal staff) | The list of payments to review, recovery notices to send, where to spend next | Audit |

### Vocabulary

- **Ward**: one of Mumbai's 24 administrative areas, known by codes (A, B, C, D, E, F/N, F/S, G/N, G/S, H/E, H/W,
  K/E, K/W, L, M/E, M/W, N, P/N, P/S, R/C, R/N, R/S, S, T). The demo ward is **E (Byculla, Agripada, Mumbai Central)**.
- **Work order**: one paid repair job, id like `WO25-01942`.
- **Complaint**: a citizen report, id like `BMC25-001877` (city system) or `NS-000002` (filed in this app).
- **Issue**: several complaints about the same problem, grouped.
- **Flag**: a reason a work order needs review. Five types, each with a fixed colour (section 4):
  1. Billed while the road is under warranty
  2. Billed above the standard rate
  3. Repeat job with no complaint linked
  4. Repair failed within 30 days
  5. Slower than typical
- **Rupee formats**: `₹2.62 Cr` (crore), `₹41.8 L` (lakh), `₹85,657` (Indian digit grouping). Never truncate a number.

## 3. Visual direction

The feel of a modern on-demand service app: a white page, black type, big bold titles, soft grey rounded tiles,
a floating pill tab bar, a lot of air, quick and quiet motion. The reference is a "Services" screen with a large
bold title top-left, bold section headings, a grid of light-grey rounded tiles (label bottom-left, small
illustration top-right; two wide tiles, then rows of four square tiles), a thin grey band between sections and a
white floating pill tab bar whose active item sits in a grey pill.

Take the feel, not the brand: no third-party logos, names, illustrations or proprietary fonts.

Principles
1. **Black on white.** Colour is information, never decoration. It appears only for status, money that needs
   review, and the map.
2. **One idea per block.** Big type, generous space, few lines. Tiles are filled grey, not outlined. No card
   shadows on the page.
3. **One primary action per screen:** a full-width black pill button, pinned at the bottom where the screen has one.
4. **Numbers are the heroes.** Rupee figures are large, tight and tabular.
5. **Motion explains.** Things move from where they came from, fast, and never block input.
6. **Trust.** This is public money. The design must feel sober and precise, not playful or alarming. Red is
   used sparingly.

## 4. Design tokens

### Colour, light theme
| Token | Hex | Use |
|---|---|---|
| background | #FFFFFF | page |
| surface | #FFFFFF | sheets, floating cards |
| surfaceAlt | #F3F3F3 | tiles, inputs, resting chips, icon wells |
| surfacePressed | #E8E8E8 | pressed tile or row |
| border | #EEEEEE | hairlines |
| borderStrong | #D0D0D0 | outlines when needed |
| textPrimary | #0A0A0A | |
| textSecondary | #5E5E5E | |
| textDisabled | #A6A6A6 | |
| primary / onPrimary | #0A0A0A / #FFFFFF | primary button, active chip, user chat bubble |
| success / tint | #0E8345 / #E6F4EC | fixed and held, within budget |
| warning / tint | #B25E00 / #FFF2DC | slower than typical, in progress |
| error / tint | #C8102E / #FDECEE | repair failed, over budget |
| info / tint | #1F5FD0 / #E9F0FD | under warranty, inferred link |
| review / tint | #6B3FD4 / #F0EBFC | billed above rate, repeat job |

Flag colours: warranty = info, above rate = review, repeat job = review, failed = error, slower = warning.

Dark theme: background #000000, surfaceAlt #1C1C1C, pressed #2A2A2A, border #2A2A2A, text #FFFFFF / #A6A6A6,
primary #FFFFFF with black text on it. Status colours lightened to keep contrast.

All text meets WCAG AA (4.5:1, or 3:1 for text 24 px and larger).

**Map palette:** basemap in light greys. Ward fill is a single red ramp showing the share of spend that needs
review (#FDE9E7 lowest to #C8102E highest, 55% opacity). Ward outlines white 1.5 px; the selected ward has a
2.5 px black outline and the rest dim to 30%. Roads are grey #8A8A8A, or their flag colour. Ward labels are white
pills with black text.

### Type
One grotesque sans family with good Devanagari support (for example Inter with Noto Sans Devanagari, or any
equivalent). Weights 400, 500, 700.

| Style | Size / line | Weight | Tracking | Use |
|---|---|---|---|---|
| display | 34 / 40 | 700 | −0.6 | page title on the five root tabs |
| headline | 24 / 30 | 700 | −0.3 | section heading, detail page title |
| title | 18 / 24 | 700 | −0.1 | card title |
| body | 16 / 24 | 400 | 0 | default |
| bodyStrong | 16 / 24 | 500 | 0 | list row title |
| label | 14 / 20 | 500 | 0 | tile label, chip |
| caption | 13 / 18 | 400 | 0 | secondary line |
| figureXL | 40 / 44 | 700 | −1.0, tabular | hero rupee figure |
| figure | 24 / 28 | 700 | −0.4, tabular | stat tile |

Devanagari: add 2 px line height, no negative tracking.

### Space, shape, elevation
- 4 px grid. Scale 4, 8, 12, 16, 20, 24, 32, 40, 56. Page gutter 20. Section gap 32. Tile gap 12.
- Radii: tile 16, card 20, sheet top 28, input 14, map preview card 24, chips and buttons full pill.
- Elevation only on floating things: tab bar, map controls, map preview card, sheets, snackbar
  (y 8, blur 24, 12% black).
- Section break: an 8 px tall #F3F3F3 band, full width.
- Touch target 48 minimum. List row 64. Primary button 56 high.

### Motion
| Name | Duration | Easing | Use |
|---|---|---|---|
| press | 90 ms in, 160 ms out | ease-out | tile or button scales to 0.97 and darkens |
| quick | 160 ms | ease-out cubic | chip select, tab pill slide, icon swap |
| standard | 260 ms | ease-out cubic | content cross-fade, expand, bars growing |
| page | 320 ms in, 220 ms out | ease-out quart | page push: 24 px slide from the right plus fade |
| sheet | 360 ms | soft overshoot | bottom sheet and map card rising |
| stagger | 40 ms per item, 6 items max | | first paint of tiles and rows: fade plus 12 px rise |
| count | 600 ms | ease-out cubic | rupee figures count up, first appearance only |

No bounce on scroll. Nothing over 400 ms except count-up and the monsoon player. Reduce-motion turns all of it
off. Light haptic on primary button, tab change, chip select and when the budget slider crosses an item.

## 5. Components

- **Page title**: display size, left aligned. On scroll it collapses into a 56 px top bar with the title at 18/700.
- **Top bar (detail pages)**: 56 px, a round 40 px grey back button, the title appears on scroll, optional icon
  button on the right.
- **Floating tab bar**: white pill, 64 high, 16 from the bottom safe edge, max width 420, shadow. Five items, icon
  above a 12 px label. The active item sits in a grey pill that slides between items; its icon changes from
  outline to filled. Hides on scroll down, returns on scroll up; always visible on Map.
- **Tile**: grey, radius 16, label bottom-left (max 2 lines), pictogram top-right. Two sizes: wide (half width,
  104 high) and square (quarter width, 96 high). Optional count badge top-left.
- **Stat tile**: grey tile, figure on top, caption below. Never a coloured background; the figure may take a
  status colour.
- **Hero figure**: small caption, figureXL number, one line of explanation, optional chevron. Plain on white.
- **List row**: 64 high, 40 px grey round well with an icon or initials, title and caption, amount and chevron on
  the right, hairline divider inset to the text.
- **Status chip**: pill, tinted background, coloured text 12/500, optional dot. One per row; extras collapse to "+2".
- **Filter chip**: grey pill; selected is black with white text. Horizontal scroller with fading edges.
- **Buttons**: primary (black pill, 56 high, full width; loading shows three pulsing dots), secondary (grey pill),
  text button.
- **Bottom action bar**: white, hairline on top, holds the primary button, rises with the keyboard.
- **Search field**: grey pill, 52 high, search icon, clear button.
- **Segmented control**: grey track, white selected segment.
- **Bottom sheet**: radius 28, a 36 × 4 grabber, 40% black scrim.
- **Timeline**: 2 px grey vertical rail, 12 px nodes (filled black for done, ring for pending, status colour for
  the outcome). Each step has a title, a meta line, optional chip and amount.
- **Progress bar**: 8 px, grey track, black fill, red beyond 100%.
- **Info panel**: tinted rounded panel with an icon and one or two sentences (warranty notes, fairness notes).
- **Skeleton**: grey blocks in the shape of the final layout, slow shimmer. No spinners on first load.
- **Empty and error states**: pictogram, one sentence, one button.
- **Draft view**: generated letter text on a grey rounded panel, a "Live" or "Saved" chip, Copy and Share in the
  bottom bar.
- **Snackbar**: black floating pill above the tab bar.
- **Pictograms**: one consistent set of about 24 two-tone line icons (2 px stroke, black with at most one accent):
  report, track, chat, report card, ask, monsoon, trail, about, audit, next rupee, contractors, ward, brief, map,
  pothole, waterlogging, manhole, drain, failed repair, warranty, hospital, school, flood, traffic. Simple small
  spot illustrations in the same style are welcome in place of icons on tiles.

## 6. Navigation

Five root tabs: **Home, Map, Report** (citizen and signed out) **or Audit** (ward officer and corporator),
**Contractors, My Ward**. Detail pages push over the tabs and hide the tab bar. Tab change is a 160 ms fade.
Each tab remembers its scroll position.

```
Home ─┬─ Ward comparison ── Ward page
      ├─ Report flow (3 steps) ── Filed ── Complaint detail
      ├─ Track a complaint ── Complaint detail ── Issue page / Road page
      ├─ Ask about a complaint (chat)
      ├─ Report card (share) · Ask my ward (draft) · Ward brief (draft)
      ├─ Complaint trail ── Issue page
      ├─ Next rupee ── Next-rupee item
      └─ Account sheet ── Sign in · About
Map ── Layers sheet · Ward preview ── Ward page · Road preview ── Road page · Monsoon player
Audit ── Road page (focused work order) ── Recovery notice (draft)
Contractors ── Scorecard ── Audit filtered by contractor
My Ward ── Ward picker sheet · all ward tools
```

## 7. Screens

Sample content below is real demo data; use it as written.

### 7.1 Home, citizen (also signed out)
Purpose: do something in one tap, and see the headline for the city and the ward.
1. Top row: ward selector as a grey pill "Ward E · Byculla ▾" on the left; language pill "EN" and a round account
   avatar on the right.
2. Display title "Namaste", caption "Nagar Sarthi · Citizen".
3. A search-style grey pill "Report a problem…" with a black round "+" at its end.
4. Section break. Heading "Do something". Tiles: wide "Report a problem", wide "Track a complaint"; square "Ask
   about a complaint", "Ward report card", "Ask my ward", "Watch the monsoon", "Complaint trail", "About the data".
5. Section break. Hero figure: caption "Mumbai this monsoon", figure "₹2.62 Cr", line "billed on roads under
   warranty, to be claimed and verified", footnote "493 jobs across Mumbai · see wards ›".
6. Heading "Ward E this monsoon". Three stat tiles: "119%" (red) "of the budget spent"; "₹41.8 L" "to review";
   "36" "repairs failed within 30 days".
7. Footer caption: "Synthetic data from a prototype. Not an official municipal product."
States: skeleton; error with retry on each data block. Marathi version of this screen.

### 7.2 Home, ward officer
1. Same top row; caption "Nagar Sarthi · Ward officer".
2. Hero figure: caption "To review in Ward E", figure "₹41.8 L", line "66% of this monsoon's road spend", black
   button "Open audit".
3. Three stat tiles: "₹25.0 L" "41 warranty claims to make"; "36" "repairs failed within 30 days"; "13" "items
   ranked for the next rupee".
4. Heading "Needs your attention" with "See all". Five list rows, for example:
   - "Clare Road" · "WO25-01942 · Deccan Paving Solutions" · chip "Billed above the standard rate" · "₹2.4 L"
   - "Maulana Azad Road" · "WO25-00014 · Western Coast Asphalt Co" · chip "Under warranty" · "₹85,657"
5. Section break. Heading "Tools". Tiles: wide "Where should the next rupee go?", wide "Complaint trail"; square
   "Contractors", "Ward brief", "Map", "About".

### 7.3 Home, corporator
1. Same top row; caption "Nagar Sarthi · Corporator".
2. Hero figure: caption "Ward E road budget", figure "₹63.2 L", line "spent of ₹53 L · ₹10.2 L over budget",
   progress bar at 119% with the overflow in red.
3. Wide tile "Ward brief" with caption "A one-page summary you can share".
4. Three stat tiles: "₹41.8 L to review", "31% repairs failed", "38 complaints never fixed".
5. Heading "Contractors in this ward": horizontal scroller of compact cards (name, spend, three small bars for
   speed, durability, pricing). Western Coast Asphalt Co ₹12.1 L; Arabian Sea Engineering ₹9.9 L; Deccan Paving
   Solutions ₹9.2 L.
6. Tools tiles as for the officer.

### 7.4 Ward comparison
Title "Wards this monsoon". Segmented control: "To review", "Over budget", "Failed repairs". 24 list rows ranked
by the chosen measure: ward code in the round well, ward name, a thin bar showing the measure, the amount on the
right. Tapping opens the ward page.

### 7.5 Map
Full-bleed grey map under the status bar. Only floating controls:
- Top-left title pill "Map · All Mumbai" (or "Map · Ward E").
- Top-right round "Layers" button.
- Bottom-centre black pill "▶ Play the monsoon", above the tab bar.
- Small attribution at the bottom edge.
Default: all 24 wards shaded by review share, with white pill labels. No roads at city zoom.
States to design:
a. **City view.**
b. **Ward selected**: camera fits the ward, others dim, roads appear, a preview card rises: "Ward E", "Byculla,
   Agripada, Mumbai Central", figure "₹41.8 L to review", mini stats "119% of budget" and "36 failed repairs",
   black button "Open ward".
c. **Road selected**: the line thickens; preview card: "Maulana Azad Road", chip "Under warranty", "9 work orders
   · ₹1.8 L", button "Open road".
d. **Layers sheet**: toggle rows with icon, title, caption and switch: Wards, Roads, Next rupee, Complaints; then
   the legend as a colour scale "Share of spend to review: low → high" and the five flag colours.
e. **Monsoon mode**: the pill expands into a bottom panel: big date "14 July 2025", chip "Rain 182 mm", a round
   black play/pause button, a scrubber with weekly ticks (June to October), speed chip "2×", running figure "₹4.1
   Cr spent so far", "Exit". Complaint dots appear on the map as the days pass.
f. **Next-rupee pins**: numbered black circles; funded items filled, unfunded outlined.

### 7.6 Report, step 1: describe
Thin three-segment progress bar and a back button. Headline "What's the problem?". A large grey multi-line input
with placeholder "Describe it in your own words. English, हिंदी or मराठी." Example chips under it. Heading "Or pick
one": square tiles Pothole, Waterlogging, Open manhole, Choked drain, Repair that failed. Bottom action "Continue".
Show also in Marathi with the sample text: "परळ मध्ये शाळेसमोर रस्त्यावर मोठा खड्डा पडला आहे, दुचाकी घसरतात".

### 7.7 Report, step 2: confirm
Headline "Here's what we understood" with a "Live" chip. Three editable list rows: Problem "Pothole"; Place
"Parel, near the school"; Ward "F/S · Parel, Lalbaug, Sewri". Variant: an ambiguous place shown as a choice of
two tiles "Kurla East" / "Kurla West". Bottom action "Looks right".

### 7.8 Report, step 3: matches
Headline "Others reported this". Caption "5 similar reports nearby in the last two weeks". Cards: complaint id,
date, short text, status chip (In progress / Fixed / Forwarded to another agency). Primary "Add my voice",
secondary "File as new". Empty variant: "No similar reports. Yours will be the first."
Sign-in appears here as a bottom sheet if the person is signed out.

### 7.9 Report, filed
A check mark that draws itself. Headline "Reported". Complaint id "NS-000002" in figure style with a copy icon.
Line "We'll show what happens to it here." Primary "Track it", text button "Done".

### 7.10 Track a complaint
Title "Track a complaint". Search field "Complaint id or locality". Chips of recent ids. Results as list rows:
id, locality, status chip. Empty and not-found states.

### 7.11 Complaint detail
Top bar. Status chip, headline "BMC25-001877", caption "Pothole · Byculla · filed 12 July 2025". Timeline: Filed →
Linked to an issue (6 reports) → Work order WO25-00671 "₹19,003 · Shivneri Construction" → Outcome "Fixed, then
failed within 30 days" (red node). Facts as list rows: Road, Contractor, Cost, Warranty status. Links "See the
road" and "See the full trail". Bottom action "Report the fix failed" when the outcome is fixed.

### 7.12 Ask about a complaint (chat)
Top bar "Ask about a complaint". Suggestion chips: "BMC25-001877", "Why is my road still broken?", "How much was
spent on my road?". User messages as black bubbles on the right. Answers as plain text on white on the left with
a small "N" mark and a "Live" chip, for example: "Your complaint about a pothole on Maulana Azad Road was grouped
with 5 similar reports. A repair was done on 13 July 2025 at a cost of ₹19,003. The repair was reported as failed
within 30 days, so the road needs another look. This road is under the contractor's warranty, so the cost is to be
claimed and verified." Under the answer, a grey group of compact fact rows (Complaint, Work order, Issue), each
tappable. Input: grey pill with a round black send button. Typing state: three pulsing dots. Show the same
exchange in Marathi. Not-found answer variant.

### 7.13 Audit (ward officer, corporator)
Display title "Audit", caption "128 items · ₹41.8 L to review" that updates with the filters. Segmented control
"Ward E" / "All Mumbai". Filter chips: All, Under warranty, Above standard rate, Repeat job, Failed within 30
days, Slower than typical. A "Contractor" chip that opens a sheet. Search field "Work order or road". Rows: road
name; "WO25-01942 · Deccan Paving Solutions"; one status chip; amount on the right; one reason line "Billed 2.67×
the standard rate (₹2.4 L vs ₹90,000)". Skeleton rows while loading more. Empty state per filter.

### 7.14 Road page
Top bar. Headline "Maulana Azad Road", caption "RD0050 · Ward E". Info panel: "Under contractor warranty.
Resurfaced 24 Feb 2024. Repairs in this period are to be claimed and verified." Three stat tiles: "₹1.8 L spent",
"9 jobs", "2 failed". Heading "Work orders" as a timeline, newest first; each node: date, "WO25-00014 · Western
Coast Asphalt Co", amount "₹85,657", chips. One node expanded to show evidence rows: "Billed ₹85,657", "Standard
rate ₹52,000", "Assigned 3 Jun · completed 5 Jun", "Linked complaints: 4". Bottom action for the officer: "Draft
recovery notice".

### 7.15 Ward page and My Ward tab
Display title "Ward E", caption "Byculla, Agripada, Mumbai Central", "Change ward" pill. Hero figure "₹63.2 L spent
of ₹53 L" with the progress bar. Heading "To review: ₹41.8 L": one horizontal stacked bar by flag type, then
legend rows: Under warranty "41 jobs · ₹25 L"; Above standard rate "9 jobs · ₹10 L"; Repeat job "2 jobs ·
₹69,926"; Failed within 30 days "36 jobs · ₹20.1 L". Caption "A job can carry more than one flag." Tools tiles:
Ward brief, Report card, Ask my ward, Complaint trail, Next rupee, Contractors here. Row "38 complaints never
fixed ›".

### 7.16 Ward picker (sheet)
Search field, then 24 rows: code in the well, ward name, a small bar for review share, check mark on the current one.

### 7.17 Contractors
Display title "Contractors", caption "Fictional names. Compared like for like." Search field. Alphabetical rows:
initials in the well, name, "212 jobs · 9 wards", three small bars (speed, durability, pricing).

### 7.18 Contractor scorecard
Top bar. Headline "Deccan Paving Solutions", caption "Synthetic contractor · 212 jobs". Collapsible info panel
"How this is kept fair": same repair method compared, low-lying wards and heavy-rain days discounted, at least 15
jobs before a ward counts. Three metric cards (Speed, Durability, Pricing), each with a horizontal bar, a marker
for the peer median, and one plain sentence, for example "Repairs hold up better than most: 12% failed within 30
days against a typical 19%." Two tinted panels: "Strength" and "To improve". Heading "By ward" as rows. Link "See
this contractor's flagged work orders".

### 7.19 Next rupee, with budget what-if
Headline "Where should the next rupee go?", caption "Ward E · ranked by risk, safety first". Budget block: caption
"Budget to plan with", figure "₹5.0 L", a slider, chips "−25%", "Now", "+25%", "+50%", and a summary line "+₹1.2 L
funds 3 more items, including 1 near a hospital". Ranked list: rank in a black circle; "Open manhole · Byculla";
factor chips "Hospital 120 m", "Flood spot", "Heavy traffic"; cost "₹18,000"; score "72". A divider "Funding stops
here" between rows; rows under it at 50% opacity. An item under warranty shows "₹0 to the ward · contractor's
warranty". Show three slider positions.

### 7.20 Next-rupee item
Top bar. Headline "Open manhole · Byculla". Score "72 of 100". Five horizontal bars with weights: Severity 30,
Access to hospitals and schools 30, Accidents 20, Flood risk 10, Traffic 10. Panel "Recommended method" with the
reason (lowest re-open rate for this repair type). Info panel for warranty where it applies. Mini map.

### 7.21 Complaint trail
Headline "Complaint trail", caption "From a citizen's report to a finished repair". Segmented control "Ward E" /
"All Mumbai". Funnel of five full-width bars that narrow: "6,501 complaints received" → "5,801 after removing
noise and out-of-scope" → "3,396 distinct issues" → "2,627 with a work order" → "1,983 fixed and held". Beside it:
"644 fixed, then failed · ₹3.04 Cr", "208 in progress", "561 never fixed". Stat line "14.9% of categories
corrected". Filter chips: All, Fixed and held, Failed, In progress, Never fixed, Social media only. Issue rows:
title "Pothole · Maulana Azad Road", badge "6 reports", note "2 categories corrected", outcome chip. Collapsible
panel "How we link".

### 7.22 Issue page
Top bar. Headline "Pothole · Maulana Azad Road", outcome chip. Timeline: complaints (one shows "Reported as
Waterlogging → corrected to Pothole"; duplicates collapsed as "+4 same report"), a social post with a source tag,
the work order with cost and contractor, the outcome. Chip "Inferred link" with a one-line explanation where the
link was not recorded.

### 7.23 Drafts: recovery notice, ward brief, question to the ward
One layout, three uses. Top bar with the document name and a regenerate icon. Chip "Live" or "Saved". For the
brief and the question, a segmented control EN / हिं / मरा. The letter on a grey rounded panel, body 16/26. A
caption "Draft made from synthetic data. Review before sending." Bottom bar: "Copy" (secondary) and "Share"
(primary). Loading state: skeleton lines. Sample opening for the notice: "Subject: Work on Maulana Azad Road
(RD0050), flagged as billed while under defect liability. … The total of these items is ₹1,79,863. The amount is
to be claimed and verified."

### 7.24 Ward report card (shareable)
A portrait card made to be shared as an image: "Ward E · Monsoon 2025", three big figures (spent vs budget, to
review, failed repairs), a mini ward map, the synthetic-data line, the app name. Below it the "Share" primary button.

### 7.25 Sign in
Display title "Sign in". Phone field (grey, large digits, "+91"). Then a six-box code field. Primary "Continue"
pinned. Heading "Demo accounts": three tiles "Citizen", "Corporator", "Ward officer". Error state for a wrong code.

### 7.26 Account sheet
Avatar, name or phone, role chip. Rows: Switch account, Language (EN / हिं / मरा), About the data, Sign out (red).

### 7.27 About the data
Reading page, comfortable measure. Sections: "This is a prototype", "Where the data comes from" (synthetic
dataset; real ward boundaries from OpenCity / Oorvani Foundation via bharatlas, CC0), "How we flag a payment"
(five short plain rules), "What we changed for display" (about 1 in 10 positions moved to sit inside their own
ward), "Credits".

## 8. Rules for every screen

- Every data block has loading (skeleton), error (retry) and empty states.
- No overflow or clipped text at 360 wide, including Devanagari and text scaled to 130%.
- Focus is visible; icon-only buttons have labels; colour is never the only signal (chips carry text).
- At most one status chip per row and one primary button per screen.
- Nothing sits under the floating tab bar; long pages end with enough space to clear it.
- Wide web: lists max 720 wide, grids max 1040, tiles reflow to 6 to 8 per row, left rail navigation.
