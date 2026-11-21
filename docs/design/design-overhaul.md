# Nagar Sarthi design overhaul

Direction: the calm, monochrome, tile-based feel of modern service apps (the reference is a "Services" screen:
white page, big bold page title, bold section headings, soft grey rounded tiles with the label bottom-left and
an illustration top-right, hairline section breaks, a floating pill tab bar). We take the feel, not the brand:
no third-party names, logos, illustrations or fonts.

Principles
1. Black on white. Colour is information, never decoration: it appears only for status, money that needs
   review, and the map.
2. One idea per block. Big type, generous space, few borders. Tiles are filled grey, not outlined.
3. One primary action per screen: a full-width black pill button, pinned at the bottom where the screen has one.
4. Numbers are the heroes. Rupee figures are large, tabular and tight.
5. Motion explains: things move from where they came from, quickly, and never block input.

## 1. Tokens

Keep the existing token class and field names (`SaartheeColors`, spacing, radii, type styles) so screens keep
compiling. Change values; add the few new fields listed. Screens must not use raw `Color(0x…)`, raw `TextStyle`
sizes or magic paddings.

### Colour (light)
| Token | Value | Use |
|---|---|---|
| background | #FFFFFF | page |
| surface | #FFFFFF | sheets, cards on grey |
| surfaceAlt | #F3F3F3 | tiles, inputs, chips (resting) |
| surfacePressed (new) | #E8E8E8 | pressed tile |
| border | #EEEEEE | hairlines, section breaks |
| borderStrong | #D0D0D0 | input focus-off outline when needed |
| textPrimary | #0A0A0A | |
| textSecondary | #5E5E5E | |
| textDisabled | #A6A6A6 | |
| primary | #0A0A0A | primary button, active tab, selected chip |
| onPrimary | #FFFFFF | |
| primaryDark | #000000 | pressed primary |
| primaryContainer | #F3F3F3 | active tab pill, icon wells |
| onPrimaryContainer | #0A0A0A | |
| onPrimarySubtle | #C9C9C9 | secondary text on black |
| sunrise | #0A0A0A | (report action is now the black primary; keep the field) |
| success / successTint | #0E8345 / #E6F4EC | fixed and held, on budget |
| warning / warningTint | #B25E00 / #FFF2DC | needs review, slower than typical |
| error / errorTint | #C8102E / #FDECEE | failed repair, over budget |
| info / infoTint | #1F5FD0 / #E9F0FD | warranty, inferred, in progress |
| review (new) / reviewTint | #6B3FD4 / #F0EBFC | billed above rate, repeat job |
| focusRing | #0A0A0A | 2 px, 2 px offset |
| shadow | #000000 at 8% / 16% | floating elements only |

Dark theme: same structure inverted (background #000000, surfaceAlt #1C1C1C, pressed #2A2A2A, border #2A2A2A,
text #FFFFFF / #A6A6A6, primary #FFFFFF with onPrimary #000000). Status colours lighten to keep 4.5:1.
All text pairs meet WCAG AA (4.5:1; 3:1 for text 24 px and larger).

Map: basemap desaturated to light grey (colour filter on tiles). Ward fill is a single-hue ramp of the
"to review" share (#FDE9E7 → #C8102E at 55% opacity), white 1.5 px ward outlines, selected ward 2.5 px black
outline. Road lines: grey #8A8A8A normal, status colours when flagged. Labels: white pill, black text.

### Type
One family already bundled with the app (keep it; no new font files). Weights 400 / 500 / 700.
| Style | Size / line | Weight | Tracking | Use |
|---|---|---|---|---|
| display | 34 / 40 | 700 | −0.6 | page title on root tabs |
| headline | 24 / 30 | 700 | −0.3 | section heading, page title on detail pages |
| title | 18 / 24 | 700 | −0.1 | card title |
| body | 16 / 24 | 400 | 0 | default |
| bodyStrong | 16 / 24 | 500 | 0 | list row title |
| label | 14 / 20 | 500 | 0 | tile label, chip, button small |
| caption | 13 / 18 | 400 | 0 | secondary line |
| figureXL | 40 / 44 | 700 | −1.0, tabular | hero rupee figure |
| figure | 24 / 28 | 700 | −0.4, tabular | stat tile |
Devanagari: add 2 px to line height, never use negative tracking, never truncate a number.

### Space, shape, elevation
- Grid 4. Scale: 4, 8, 12, 16, 20, 24, 32, 40, 56. Page gutter 20. Section gap 32. Tile gap 12.
- Radii: tile 16, card 20, sheet top 28, input 14, chip and button full pill, map preview card 24.
- No card borders and no card shadows on the page. Elevation only for: floating tab bar, map controls,
  map preview card, bottom sheet, snackbar (y 8, blur 24, 12% black).
- Section break: 8 px tall #F3F3F3 band, full bleed, between major sections (as in the reference).
- Touch target 48 minimum; list rows 64; primary button height 56.

### Motion
| Token | Duration | Curve | Use |
|---|---|---|---|
| press | 90 ms in / 160 ms out | easeOut | tile and button scale to 0.97, surface → pressed |
| quick | 160 ms | easeOutCubic | chip select, tab pill slide, icon swap |
| standard | 260 ms | easeOutCubic | content fade-through, list reorder, expand |
| page | 320 ms | easeOutQuart in / 220 ms easeIn out | page push: slide 24 px from right + fade; shared-axis on tabs is fade-through only |
| sheet | 360 ms | spring-like easeOutBack(0.6) clamp | bottom sheet, map preview card rise |
| stagger | 40 ms per item, max 6 items | | first paint of tiles and list rows: fade + 12 px rise |
| count | 600 ms | easeOutCubic | rupee figures count up on first appearance only |
Rules: honour "reduce motion" (durations → 0, no scale, no count-up); never animate layout that the user is
reading; nothing longer than 400 ms except count-up and the monsoon player; skeletons shimmer at 1200 ms linear;
light haptic on primary button, tab change, filter chip, funding-line cross; no bounce on scroll (clamp, done).

## 2. Components (core/widgets)
- **PageTitle**: display-size title, left aligned, 20 gutter, 8 above first section; collapses into a 56 px top
  bar with the title at 18/700 centred as the page scrolls (large-title behaviour).
- **TopBar (detail)**: 56 px, round 40 px grey back button, title appears on scroll, optional trailing icon button.
- **FloatingTabBar**: white pill, 64 px high, 16 px from the bottom safe edge, max width 420, shadow; four to five
  items with icon above 12 px label; the active item sits in a grey pill that slides between items (quick);
  icon swaps outline → filled. Hides on scroll down and returns on scroll up on long lists; always visible on Map.
  Content gets bottom padding so nothing sits under it. Wide web (≥ 900): left rail, same visual language.
- **Tile**: grey rounded 16, label bottom-left (label style, max 2 lines), pictogram top-right in a 40 px area
  (two-tone line icon, black with one status accent at most); sizes: wide (2 columns, 104 high) and square
  (4 columns, 96 high). Press animation. Optional badge count top-left.
- **StatTile**: grey tile, figure on top, caption below, optional tiny trend/status dot; never coloured
  backgrounds; a status figure may use its status colour.
- **HeroFigure**: caption, figureXL, one-line explanation, optional chevron; plain on white, no card.
- **ListRow**: 64 min height, 40 px grey leading well with icon or initials, title + caption, trailing amount
  (bodyStrong, tabular) and chevron; hairline divider inset 76. Press state full-bleed grey.
- **StatusChip**: pill, tint background + status text, 12/500, optional 6 px dot; one per row at most (extra
  flags collapse to "+2").
- **FilterChip**: grey pill; selected = black with white text; horizontal scroller with 20 gutter and edge fade.
- **PrimaryButton**: black pill 56 high, full width, label 16/700; loading swaps label for a 3-dot pulse and
  keeps width; disabled = #E8E8E8 with grey text. **SecondaryButton**: grey pill. **TextButton**: black
  underlined-on-press text.
- **BottomActionBar**: white, hairline top, 16 padding + safe area, holds the primary button; rises with the
  keyboard.
- **SearchField**: grey pill 52 high, leading search icon, clear button; expands on focus.
- **Sheet**: 28 radius top, 36×4 grabber, drags to dismiss, scrim 40% black.
- **Timeline**: 2 px grey rail, 12 px nodes (filled black = done, ring = pending, status colour for outcome),
  each step: bodyStrong title, caption meta, optional chip and amount.
- **Skeleton**: grey blocks matching the final layout (no spinners on first load of a screen).
- **EmptyState / ErrorState**: pictogram, one sentence, one button; error keeps the retry.
- **DraftView** (Claude drafts): white page, letter in body 16/26 on a grey 16-radius panel, "Live" or "Saved"
  chip, copy and share as the bottom action bar; text reveals with a fade per paragraph, not a typewriter.
- **Snackbar**: black pill, white text, floats above the tab bar.
- **Pictograms**: one set of ~24 two-tone line icons drawn with `CustomPainter` or composed from Material
  Symbols outlined at 28 px with a single accent dot; consistent 2 px stroke. No stock 3D art.

## 3. Screens

### Shell
Floating tab bar: Home, Map, Report (citizen) / Audit (officer, corporator), Contractors, My Ward. Tab change
is a 160 ms fade-through; each tab keeps its scroll position. Back on a root tab goes Home, then exits.

### Home (all roles)
- White page, no coloured header. Row 1: ward selector as a grey pill ("Ward E · Byculla ▾") left, language
  pill and round account avatar right.
- Display title: "Namaste" with a one-line caption (role).
- Section break, then role blocks below. Sections stagger in on first load; figures count up once.
- **Citizen**: search-style pill "Report a problem…" (opens Report) with a black "+" circle; "Do something"
  tile grid (wide: Report a problem, Track a complaint; square: Ask about a complaint, My ward's report card,
  Ask my ward, Watch the monsoon, Complaint trail, About the data); break; HeroFigure "Mumbai this monsoon"
  (₹ billed on roads under warranty, to be claimed and verified) → ward comparison list; "Ward E this monsoon"
  three StatTiles; synthetic-data caption at the foot.
- **Ward officer**: HeroFigure "₹ to review in Ward E" with a black "Open audit" button; three StatTiles
  (warranty claims, failed repairs, next-rupee items); "Needs your attention" as ListRows (road, contractor
  caption, one StatusChip, amount) with "See all"; tile grid of tools (Next rupee, Complaint trail,
  Contractors, Ward brief, Map, About).
- **Corporator**: HeroFigure budget vs spend with a slim progress bar (black fill, red beyond 100%); "Ward
  brief" wide tile; StatTiles; "Contractors in this ward" as a horizontal scroller of compact cards; tools grid.

### Map
- Full-bleed grey basemap under a transparent status bar. Floating controls only: top-left round back-less
  title pill "Map · Ward E", top-right round "Layers" button, bottom-right "locate ward" button, the monsoon
  pill bottom-centre above the tab bar.
- Ward tap: camera eases to fit (500 ms), other wards dim to 30%, roads fade in, preview card rises from the
  bottom (sheet motion) with ward name, the "to review" figure, two mini stats and a black "Open ward" button;
  swipe down dismisses and restores the city view.
- Road tap: line thickens and pulses once; preview card shows road name, status chip, last work order, "Open road".
- Layers: bottom sheet with large toggle rows (icon, title, caption, switch) and the legend as a clean scale bar.
- Monsoon mode: the pill expands into a bottom panel: big date, rainfall chip, play/pause round black button,
  scrubber with tick marks per week, speed chip, running spend figure counting up; complaint dots pop in
  (scale 0 → 1, 200 ms) and fade; exit returns to the pill.
- Next-rupee pins: numbered black circles (rank), funded = filled, unfunded = outlined; pin tap → preview card.
  Pins never cover the ward label (offset the label).

### Report (citizen)
- Step flow with a thin 3-segment progress bar and a back button; one question per screen; primary button
  pinned in the BottomActionBar.
  1. "What's the problem?": large multi-line input on grey, language hint, example chips, optional category
     tiles (pothole, waterlogging, manhole, drain, failed repair) as square tiles.
  2. "Here's what we understood": category, place and ward as editable ListRows; "Live" chip when Claude read it;
     ambiguity shown as a choice of two tiles.
  3. "Others reported this": matching complaints as cards with status chip; primary "Add my voice", secondary
     "File as new".
  Success: check mark draws (400 ms), complaint id in figure style with copy, "Track it" primary.
- Sign-in gate appears as a sheet at the moment of filing, not before.

### Track a complaint / Complaint detail
SearchField at top (id or locality), recent ids as chips. Detail: status chip, id in title, Timeline (filed →
linked issue → work order with amount → outcome), facts as ListRows (road, contractor, cost, warranty), links
to the road and the trail, "Report the fix failed" as the bottom action when the outcome is fixed.

### Ask about a complaint (citizen bot)
Chat layout: user bubbles black right, answers plain on white left with a small "N" mark; suggestion chips
above the input; input is a grey pill with a round black send button; typing shows a 3-dot pulse; fact cards
under an answer are compact ListRows in a grey group; answers fade and rise in. Language follows the app.

### Audit (officer, corporator)
Display title "Audit" with a caption "N items · ₹X to review" that updates (cross-fade) as filters change.
Scope switch (Ward E / All Mumbai) as a two-segment grey control. FilterChips by flag type, contractor filter
as a chip that opens a sheet, SearchField that pins under the top bar. Rows: road name (bodyStrong), work
order id · contractor (caption), one StatusChip, amount right; one-line reason in caption. Sticky group headers
by road optional. Load more is automatic at the end with skeleton rows. Empty state per filter.

### Road page
TopBar; headline road name, caption ward and length; warranty banner (info tint) when under warranty with
the resurfacing date; three StatTiles (spent, jobs, failed); "Work orders" Timeline, each node expandable to
evidence rows (rate vs standard, dates, linked complaints) with chips; the focused work order (from Audit)
scrolls into view and flashes its background once. Officer: bottom action "Draft recovery notice".

### Ward page / My Ward
Display title is the ward name; ward selector pill beneath. HeroFigure spend vs budget with progress bar;
"To review" as a horizontal stacked bar by flag type with a legend of ListRows (type, jobs, amount) that open
Audit pre-filtered; tools as tiles (Ward brief, Report card, Ask my ward, Complaint trail, Next rupee,
Contractors here); "Never fixed" count row. Change ward opens the picker sheet: search + list with the
"to review" share as a small bar.

### Contractors / Scorecard
List: SearchField, alphabetical ListRows with initials well, jobs count caption and a three-dot mini rating
(speed, durability, pricing as small bars), "(synthetic)" in caption. Scorecard page: headline name, fairness
note as a collapsible info panel, three metric cards each with a horizontal bar against the peer median marker
and a plain-language sentence, strength and improve sentences as two tinted panels, by-ward table as ListRows,
work orders link to Audit filtered by contractor. Bars grow from zero on first view (standard motion).

### Next rupee + budget what-if
Headline "Where should the next rupee go?"; budget control at top: big remaining-budget figure, slider with
haptic ticks, quick chips (−25%, Now, +25%, +50%); summary line cross-fades as the value changes. Ranked list:
rank number in a black circle, issue title, place, factor chips (hospital, school, flood, traffic), cost right;
the "Funding stops here" divider slides between rows as the budget moves (rows below dim to 50%). Item page:
score breakdown as five horizontal bars with weights, method recommendation and why, warranty note (₹0 to the
ward) in an info panel.

### Complaint trail
Headline "Complaint trail"; funnel as five stacked full-width bars that narrow (raw → cleaned → issues → with
work order → held), each with its number, animating in sequence; outcome FilterChips; issue ListRows with
complaint count badge, corrected-category note and outcome chip. Issue page: Timeline with "reported as X →
corrected to Y", duplicates collapsed ("+6 same report"), social posts with a small source tag, work order,
outcome; "Inferred link" info chip; "How we link" collapsible panel with the measured accuracy.

### Drafts (notice, brief, question)
DraftView page; header chip Live or Saved; language switch for brief and question as a three-segment control;
bottom actions Copy and Share; regenerate as a top-right icon with a 260 ms cross-fade of the text.

### Sign in / Account / About
Sign in: display title "Sign in", phone field (grey, large digits), code field as six boxes, primary button
pinned; demo shortcuts as three tiles under "Demo accounts". Account sheet: avatar, role chip, switch account
rows, language, About, Sign out (red text). About: plain reading page, max width 600, sections with headline
and body; data sources and credits as ListRows.

## 4. Quality bar for every screen
- 360 dp wide phone first; no overflow, no clipped Devanagari, no horizontal scroll except chip rows.
- Wide web: content column max 720 (lists) / 1040 (grids), tiles reflow to 6–8 columns, rail navigation.
- Loading = skeleton, error = retry, empty = explanation, for every data block.
- Contrast AA, focus visible, semantics labels on icon buttons and tiles, text scale 1.3 without breakage.
- No behaviour changes: every feature, role gate and wording rule stays as it is.
