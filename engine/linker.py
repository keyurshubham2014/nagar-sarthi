"""Complaint -> issue -> work order linker for the Nagar Sarthi audit engine. Standard library only.
Called from audit.py: run(complaints, work_orders, localities, roads, wards, social_posts)."""
import math, re
from collections import Counter, defaultdict
from datetime import datetime, timedelta

# ---- thresholds (justified from the data; see the task-8 linker report) ----
GPS_MAX_ACC_M = 100      # all reported accuracies are 5-60 m, so every GPS fix is usable
SAME_PLACE_M = 80        # GPS pairs BMC linked to one work order are at most 78 m apart; 150 m merged different jobs
WINDOW_DAYS = 3          # rolling: 90% of gaps between consecutive complaints on one work order are <= 3 days
INFER_BEFORE_H = 24      # work order assigned up to 1 day before the first complaint (5% of recorded links are)
INFER_AFTER_D = 6        # ... or up to 6 days after (95th percentile of recorded links: 5.8 days)
VAGUE = ("Road related", "Other")
OUT_OF_SCOPE_STATUS = ("Rejected - Not BMC road", "Forwarded to MMRDA/PWD")
NOISE_STATUS = ("Rejected - Not road issue", "Forwarded to SWM dept")
OUTCOMES = ("fixed_held", "fixed_failed", "in_progress", "never_fixed", "out_of_scope")

# Keyword lists, built by reading descriptions and photo notes per language and category.
# Order is priority: the first category with a hit wins, so specific problems beat water/potholes
# ("cracked manhole cover sunk below road level" is a manhole, "crater filled with muddy water" a pothole).
CATS = [
    ("Open or broken manhole", ["manhole", "dhakkan", "chamber", "मैनहोल", "ढक्कन", "झाकण"]),
    ("Road cave-in", ["cave-in", "caved in", "cave in", "sinkhole", "collapsed", "has sunk", "dhas", "धंस", "धस", "खचल"]),
    ("Broken paver blocks", ["paver", "पेवर", "पेव्हर"]),
    ("Choked drain / nullah overflow", ["nullah", "nalla", "drain", "gutter choked", "gutter overflow", "culvert",
                                        "नाला", "नाले", "गटार तुंब"]),
    ("Pothole", ["pothole", "crater", "khadd", "gadda", "gaddha", "गड्ढ", "खड्ड"]),
    ("Waterlogging", ["waterlogg", "flood", "not receding", "knee deep", "knee-deep", "till knee", "wading", "brown water",
                      "paani bhar", "itna paani", "paani hai", "swimming pool", "पानी भर", "पाणी साच", "जलभराव"]),
]
NON_ROAD = ["street light", "streetlight", "garbage not collected", "noise from", "hawker", "tree branch", "mosquito",
            "stray dog", "water supply", "kachra"]
THANKS = ["thank", "dhanyavad", "dhanyawad", "shukriya", "धन्यवाद", "आभार"]
ABUSE = ["useless bmc", "chor bmc", "shame on"]
GIBBERISH = {"test", "testing", "asdf", "asdfgh", "qwerty", "hello", "hi", "abc", "xyz", "na", "-"}
FORWARD = ["fwd", "forwarded", "share karo", "as received"]
UNVERIFIED = ["unverified", "fwd as received", "forwarded as received"]
SARCASM = ["😂", "🤦", "kya mast", "swimming pool", "khadde mein road"]
LANDMARK_MASK = ["shiv sena"]  # 'Shiv' is an alias of Sion; 'near Shiv Sena shakha' is a landmark, not Sion
DIR = {"east": "E", "e": "E", "(e)": "E", "पूर्व": "E", "west": "W", "w": "W", "(w)": "W", "पश्चिम": "W"}

B = r"(?<![\wऀ-ॿ])"   # word start that also respects Devanagari (vowel signs are not \w)
E = r"(?![\wऀ-ॿ])"


def norm(t):
    t = (t or "").lower()
    t = re.sub(r"water[\s-]*logg", "waterlogg", t)
    t = re.sub(r"pot[\s-]+hole", "pothole", t)
    t = re.sub(r"man[\s-]+hole", "manhole", t)
    return re.sub(r"\s+", " ", t).strip()

KW_RE = [(cat, [(k, re.compile(B + re.escape(k))) for k in ks]) for cat, ks in CATS]

def classify(text):
    """(category, keyword) for the highest-priority category with a keyword hit, else (None, None)."""
    t = norm(text)
    for cat, ks in KW_RE:
        for k, rx in ks:
            if rx.search(t): return cat, k
    return None, None

def has_any(t, words): return any(w in t for w in words)

def dist_m(la1, lo1, la2, lo2):
    x = math.radians(lo2 - lo1) * math.cos(math.radians((la1 + la2) / 2))
    return 6371000 * math.hypot(x, math.radians(la2 - la1))

def dt(s): return datetime.strptime(s, "%Y-%m-%d %H:%M")
def r6(x): return round(x, 6) if x is not None else None


class Gazetteer:
    """Locality and road resolver over localities.csv (names + aliases) and roads.csv (road names)."""
    def __init__(self, locs, roads):
        self.loc = {l["locality"]: l for l in locs}
        self.keys = defaultdict(set)  # lower name/alias -> {locality}
        for l in locs:
            for n in [l["locality"]] + [a.strip() for a in l["aliases"].split(";") if a.strip()]:
                self.keys[n.lower()].add(l["locality"])
        self.base = defaultdict(dict)  # 'andheri' -> {'E': 'Andheri East', 'W': 'Andheri West'}
        for n in self.loc:
            m = re.match(r"(.+) (east|west)$", n.lower())
            if m: self.base[m.group(1)][DIR[m.group(2)]] = n
        for k, ns in self.keys.items():  # Devanagari base aliases ('अंधेरी', 'दादर') point at the same pair
            for n in ns:
                m = re.match(r"(.+) (east|west)$", n.lower())
                if m and " " not in k and not k.isascii(): self.base[k] = self.base[m.group(1)]
        self.key_re = re.compile(B + "(" + "|".join(re.escape(k) for k in sorted(self.keys, key=len, reverse=True)) + ")" + E)
        self.road_names = sorted({r["road_name"] for r in roads}, key=len, reverse=True)
        self.road_re = re.compile(B + "(" + "|".join(re.escape(n.lower()) for n in self.road_names) + ")" + E)
        self.road_by_lower = {n.lower(): n for n in self.road_names}
        self.segs = defaultdict(list)  # (road_name, ward) -> [road rows]
        for r in roads: self.segs[(r["road_name"], r["ward_code"])].append(r)

    def field(self, text):
        """Candidate localities for a typed locality field: exact name/alias, else names starting with it ('Vile')."""
        t = norm(text)
        if not t: return []
        c = self.keys.get(t) or {n for k, ns in self.keys.items() if k.startswith(t + " ") for n in ns}
        return sorted(c)

    def text(self, text):
        """(locality or None, road_name or None) from free text.
        Road names are found first; a locality inside a road name ('Sion' in 'Sion Trombay Road') is ignored, and a
        locality that is itself a road name ('Linking Road') only counts when no standalone locality is present."""
        t = norm(text)
        for lm in LANDMARK_MASK: t = t.replace(lm, "#" * len(lm))
        roads = [(m.start(), m.end(), m.group(1)) for m in self.road_re.finditer(t)]
        road = self.road_by_lower[roads[0][2]] if roads else None
        strong, weak = [], []
        for m in self.key_re.finditer(t):
            s, e, k = m.start(), m.end(), m.group(1)
            inside = [rs for rs in roads if rs[0] <= s and e <= rs[1]]
            if inside and any(rs[1] - rs[0] > e - s for rs in inside): continue  # part of a longer road name
            ns = sorted(self.keys[k])
            nxt = re.match(r"\s*(\(?[a-z]+\)?|[ऀ-ॿ]+)", t[e:])  # East/West after a name: 'दादर पूर्व'
            d = DIR.get(nxt.group(1)) if nxt else None
            if d and len(ns) == 1:
                b = self.base.get(k) or self.base.get(re.sub(r" (east|west)$", "", ns[0].lower()))
                if b and d in b: ns = [b[d]]
            if len(ns) != 1: continue
            (weak if inside or k in self.road_by_lower else strong).append(ns[0])
        cands = strong or weak
        if len({self.loc[n]["ward_code"] for n in cands}) > 1: cands = cands[:1] if strong else []
        return (cands[0] if cands else None), road

    def road_id(self, road, ward, pt):
        segs = self.segs.get((road, ward), []) if road and ward else []
        if len(segs) == 1: return segs[0]["road_id"]
        if segs and pt:
            return min(segs, key=lambda r: dist_m(*pt, (float(r["start_lat"]) + float(r["end_lat"])) / 2,
                                                  (float(r["start_lon"]) + float(r["end_lon"])) / 2))["road_id"]
        return None

    def road_wards(self, road): return sorted({w for (n, w) in self.segs if n == road})


def clean_category(c):
    """category_clean with its evidence. Trust: photo note > English text / helpline operator note > reported >
    vernacular citizen text (only used when the reported category is vague)."""
    rep = c["category_reported"]
    pc, pk = classify(c["photo_description"])
    if pc: return pc, f"photo: '{pk}'"
    dc, dk = classify(c["description"])
    trusted = c["language"] == "en" or c["channel"] == "1916 Helpline"
    if dc and trusted: return dc, f"text: '{dk}'"
    if dc and rep in VAGUE: return dc, f"text ({c['language']}): '{dk}'"
    return rep, None

def vernacular_override(c):
    """Same rule but letting vernacular citizen text override; computed only to report why we do not."""
    pc, _ = classify(c["photo_description"])
    return pc or classify(c["description"])[0] or c["category_reported"]

def complaint_scope(c):
    t = norm(c["description"])
    road_hit = classify(c["description"])[0] or classify(c["photo_description"])[0]
    if not road_hit:
        if has_any(t, NON_ROAD): return "noise", "not a road problem: '" + next(w for w in NON_ROAD if w in t) + "'"
        if t in GIBBERISH or (len(t.split()) == 1 and len(t) <= 8): return "noise", "test or empty text"
        if has_any(t, THANKS): return "noise", "thanks, no problem reported"
        if has_any(t, ABUSE): return "noise", "abuse, no problem reported"
    if c["status"] in NOISE_STATUS: return "noise", f"status: {c['status']}"
    if c["status"] in OUT_OF_SCOPE_STATUS: return "out_of_scope", f"status: {c['status']}"
    return "in_scope", None


def group(items):
    """items: in-scope complaint dicts sorted by (time, id). Returns list of member lists (deterministic).
    Joins an open issue with the same clean category and ward, seen within WINDOW_DAYS (rolling, from its latest
    complaint), at the same place: <= SAME_PLACE_M from the issue's GPS centre when both have GPS, else the same
    resolved locality and (when both name one) the same road. Ties go to the most recently active issue."""
    issues, open_by = [], defaultdict(list)
    for c in items:
        best = None
        for i in open_by[(c["cat"], c["ward"])]:
            g = issues[i]
            if (c["t"] - g["last"]).total_seconds() > WINDOW_DAYS * 86400: continue
            if c["gps"] and g["n_gps"]:
                ok = dist_m(*c["gps"], g["sla"] / g["n_gps"], g["slo"] / g["n_gps"]) <= SAME_PLACE_M
            else:
                ok = c["loc"] is not None and c["loc"] in g["locs"] and not (c["road"] and g["roads"] and c["road"] not in g["roads"])
            if ok and (best is None or g["last"] >= issues[best]["last"]): best = i
        if best is None:
            best = len(issues)
            issues.append({"m": [], "last": c["t"], "locs": set(), "roads": set(), "n_gps": 0, "sla": 0.0, "slo": 0.0})
            open_by[(c["cat"], c["ward"])].append(best)
        g = issues[best]
        g["m"].append(c); g["last"] = c["t"]
        if c["loc"]: g["locs"].add(c["loc"])
        if c["road"]: g["roads"].add(c["road"])
        if c["gps"]: g["n_gps"] += 1; g["sla"] += c["gps"][0]; g["slo"] += c["gps"][1]
    return [g["m"] for g in issues]

def pair_scores(groups):
    """Pairwise precision/recall of a grouping against work-order groups, on linked complaints only."""
    c2 = lambda n: n * (n - 1) // 2
    cell, pred, true = Counter(), Counter(), Counter()
    for gi, ms in enumerate(groups):
        for c in ms:
            if c["wo"]: cell[(gi, c["wo"])] += 1; pred[gi] += 1; true[c["wo"]] += 1
    tp = sum(c2(n) for n in cell.values())
    p, r = tp / max(1, sum(c2(n) for n in pred.values())), tp / max(1, sum(c2(n) for n in true.values()))
    return {"precision": round(p, 3), "recall": round(r, 3), "f1": round(2 * p * r / (p + r), 3) if p + r else 0}


def run(comps, wo, locs, roads, wards, posts):
    gz = Gazetteer(locs, roads)
    ward_c = {w["ward_code"]: (float(w["centroid_lat"]), float(w["centroid_lon"])) for w in wards}
    wo_of = {cid: w for w in wo for cid in w["linked"]}

    # ---- 1. clean every complaint ----
    C, per = [], {}
    geo, filled, loc_check = Counter(), Counter(), Counter()
    for r in comps:
        cat, why = clean_category(r)
        scope, scope_why = complaint_scope(r)
        acc = float(r["gps_accuracy_m"]) if r["gps_accuracy_m"] else None
        gps = (float(r["lat"]), float(r["lon"])) if r["lat"] and (acc is None or acc <= GPS_MAX_ACC_M) else None
        ward = r["ward_code"] or None
        if not ward and gps:  # ward polygons are Voronoi cells around ward centres: nearest centre = ward
            ward = min(ward_c, key=lambda k: dist_m(*gps, *ward_c[k])); filled["gps"] += 1
        d_loc, road = gz.text(r["description"])
        cands = gz.field(r["locality_text"])
        if len(cands) == 1 and r["ward_code"]:
            loc_check[gz.loc[cands[0]]["ward_code"] == r["ward_code"]] += 1
        if len(cands) > 1 and ward: cands = [n for n in cands if gz.loc[n]["ward_code"] == ward] or cands
        if len(cands) > 1 and d_loc in cands: cands = [d_loc]
        if len(cands) > 1 and gps: cands = [min(cands, key=lambda n: dist_m(*gps, float(gz.loc[n]["lat"]), float(gz.loc[n]["lon"])))]
        loc, src = (cands[0], "locality") if len(cands) == 1 else ((d_loc, "description") if d_loc else (None, None))
        if not ward and loc: ward = gz.loc[loc]["ward_code"]; filled[src] += 1
        if loc and ward and gz.loc[loc]["ward_code"] != ward: loc, src = None, None  # locality disagrees with ward/GPS
        if gps: pt, gsrc = gps, "gps"
        elif loc: pt, gsrc = (float(gz.loc[loc]["lat"]), float(gz.loc[loc]["lon"])), src
        elif ward: pt, gsrc = ward_c[ward], "ward_centroid"
        else: pt, gsrc = None, "none"
        geo[gsrc] += 1
        w = wo_of.get(r["complaint_id"])
        c = {"id": r["complaint_id"], "t": dt(r["received_at"]), "cat": cat, "why": why, "scope": scope, "scope_why": scope_why,
             "gps": gps, "pt": pt, "geo": gsrc, "ward": ward, "loc": loc, "road": road,
             "road_id": gz.road_id(road, ward, pt), "wo": w["work_order_id"] if w else None, "r": r}
        C.append(c)
        e = {"issue_id": None, "category_clean": cat, "category_corrected": cat != r["category_reported"],
             "geo_source": gsrc, "scope": scope}
        if cat != r["category_reported"]: e["category_reason"] = why
        if scope_why: e["scope_reason"] = scope_why
        per[r["complaint_id"]] = e

    # category validation where truth exists (the linked work order's work_type)
    wt = {w["work_order_id"]: w["work_type"] for w in wo}
    lk = [c for c in C if c["wo"]]
    agree = lambda f: round(sum(f(c) == wt[c["wo"]] for c in lk) / len(lk), 4)
    cat_val = {"linked_complaints": len(lk), "reported_vs_work_type": agree(lambda c: c["r"]["category_reported"]),
               "clean_vs_work_type": agree(lambda c: c["cat"]),
               "clean_if_vernacular_text_overrode_vs_work_type": agree(lambda c: vernacular_override(c["r"]))}
    cat_val["gain_points"] = round(100 * (cat_val["clean_vs_work_type"] - cat_val["reported_vs_work_type"]), 2)

    # ---- 2. group in-scope complaints into issues ----
    ins = sorted((c for c in C if c["scope"] == "in_scope"), key=lambda c: (c["t"], c["id"]))
    raw_groups = group(ins)  # blind: the rules alone over every in-scope complaint, used only to measure them
    # Output: complaints BMC linked to one work order are one issue (the explicit rule); complaints BMC never linked
    # (all Open / In Progress) are grouped by the rules among themselves and reach a work order only by an
    # 'inferred' link below. Merging rule-groups on top of work orders chained different jobs (precision 0.56).
    by_wo = defaultdict(list)
    for c in ins:
        if c["wo"]: by_wo[c["wo"]].append(c)
    groups = list(by_wo.values()) + group([c for c in ins if not c["wo"]])
    grp_val = {"without_work_order_rule": pair_scores(raw_groups), "with_work_order_rule": pair_scores(groups),
               "issues_without_rule": len(raw_groups),
               "note": "with the rule, linked complaints are grouped by their work order, so 1.0 is by construction; "
                       "the honest measure of the grouping rules is the 'without' number"}

    # ---- 3. social posts: classify, place ----
    P = []
    kinds, flags = Counter(), Counter()
    for p in sorted(posts, key=lambda p: (p["posted_at"], p["post_id"])):
        t = norm(p["text"])
        cat, _ = classify(p["text"])
        fwd, sar = has_any(t, FORWARD), has_any(t, SARCASM)
        if has_any(t, UNVERIFIED): kind = "noise"
        elif has_any(t, THANKS) and not has_any(t, ["back", "again", "phir se"]): kind = "thanks"
        elif cat: kind = "issue_report"
        else: kind = "noise"
        kinds[kind] += 1; flags["forward"] += fwd; flags["sarcasm"] += sar
        if kind != "issue_report": continue
        loc, road = gz.text(p["text"])
        if loc and road and gz.road_wards(road) and gz.loc[loc]["ward_code"] not in gz.road_wards(road):
            loc = None  # 'flooded on SV Road ... took 1.5 hrs from X': X is where they came from, not the place
        ward = gz.loc[loc]["ward_code"] if loc else (gz.road_wards(road)[0] if road and len(gz.road_wards(road)) == 1 else None)
        P.append({"id": p["post_id"], "t": dt(p["posted_at"]), "cat": cat, "loc": loc, "road": road, "ward": ward,
                  "reach": int(p["likes_or_forwards"] or 0)})

    # ---- 4. build issues (complaint-based first, then social-only) ----
    issues = []
    for ms in groups:
        issues.append({"src": "complaints", "m": ms, "posts": [], "cat": Counter(c["cat"] for c in ms).most_common(1)[0][0],
                       "first": ms[0]["t"], "last": ms[-1]["t"], "locs": {c["loc"] for c in ms if c["loc"]},
                       "roads": {c["road"] for c in ms if c["road"]}, "wards": {c["ward"] for c in ms if c["ward"]}})
    unlocated, attached = 0, 0
    W = timedelta(days=WINDOW_DAYS)
    by_cat = defaultdict(list)
    for i, g in enumerate(issues): by_cat[g["cat"]].append(i)
    for p in P:
        if not p["loc"] and not p["ward"]: unlocated += 1; continue
        best, gap = None, None
        for i in by_cat[p["cat"]]:
            g = issues[i]
            if not (g["first"] - W <= p["t"] <= g["last"] + W): continue
            if p["loc"]: ok = p["loc"] in g["locs"] and not (p["road"] and g["roads"] and p["road"] not in g["roads"])
            else: ok = p["road"] in g["roads"] and p["ward"] in g["wards"]
            d = 0 if g["first"] <= p["t"] <= g["last"] else min(abs((p["t"] - g["first"]).total_seconds()), abs((p["t"] - g["last"]).total_seconds()))
            if ok and (gap is None or d < gap): best, gap = i, d
        if best is None:
            best = len(issues)
            issues.append({"src": "social_only", "m": [], "posts": [], "cat": p["cat"], "first": p["t"], "last": p["t"],
                           "locs": {p["loc"]} if p["loc"] else set(), "roads": {p["road"]} if p["road"] else set(),
                           "wards": {p["ward"]}})
            by_cat[p["cat"]].append(best)
        elif issues[best]["src"] == "complaints": attached += 1
        g = issues[best]
        g["posts"].append(p)
        if g["src"] == "social_only": g["last"] = p["t"]  # complaint issues keep their complaint dates

    # ---- 5. money trail ----
    wo_id = {w["work_order_id"]: w for w in wo}
    wo_by_road = defaultdict(list)
    for w in wo: wo_by_road[w["road_id"]].append(w)
    rid_name = {r["road_id"]: (r["road_name"], r["ward_code"]) for r in roads}
    def infer(first, cat, road_id, road_name, ward):
        """Nearest-in-time work order on the same road segment (or same road name in the ward), same work type,
        assigned from INFER_BEFORE_H before to INFER_AFTER_D after the first report. (work order or None, candidates)"""
        if not ward: return None, 0
        roads_here = [road_id] if road_id else [rid for rid, (nm, wc) in rid_name.items() if nm == road_name and wc == ward]
        cand = [w for rid in roads_here for w in wo_by_road[rid] if w["work_type"] == cat
                and first - timedelta(hours=INFER_BEFORE_H) <= w["a"] <= first + timedelta(days=INFER_AFTER_D)]
        if not cand: return None, 0
        return min(cand, key=lambda w: (abs((w["a"] - first).total_seconds()), w["work_order_id"])), len(cand)
    blind = Counter()  # the same rule run on issues whose link BMC recorded, hiding that link
    out, n_infer = [], Counter()
    order = sorted(range(len(issues)), key=lambda i: (issues[i]["first"], (issues[i]["m"] or issues[i]["posts"])[0]["id"]))
    for n, i in enumerate(order, 1):
        g = issues[i]; ms = g["m"]; iid = f"ISS-{n:05d}"
        ward = Counter(c["ward"] for c in ms if c["ward"]).most_common(1)[0][0] if any(c["ward"] for c in ms) else (next(iter(g["wards"])) if g["wards"] else None)
        loc = Counter(c["loc"] for c in ms if c["loc"]).most_common(1)[0][0] if any(c["loc"] for c in ms) else (min(g["locs"]) if g["locs"] else None)
        rids = Counter(c["road_id"] for c in ms if c["road_id"])
        road_id = min(rids, key=lambda k: (-rids[k], k)) if rids else None
        road_name = min(g["roads"]) if g["roads"] else None
        gp = [c["gps"] for c in ms if c["gps"]]
        if gp: pt = (sum(x[0] for x in gp) / len(gp), sum(x[1] for x in gp) / len(gp))
        elif loc: pt = (float(gz.loc[loc]["lat"]), float(gz.loc[loc]["lon"]))
        elif ward: pt = ward_c[ward]
        else: pt = (None, None)
        wos = sorted({c["wo"] for c in ms if c["wo"]})
        link, evidence = ("recorded", None) if wos else ("none", None)
        w, cand = infer(g["first"], g["cat"], road_id, road_name, ward)
        if wos: blind[w is None and "no_candidate" or (w["work_order_id"] in wos and "right" or "wrong")] += 1
        elif w:
            wos, link = [w["work_order_id"]], "inferred"
            evidence = {"road_id": w["road_id"], "work_type": w["work_type"], "assigned_at": w["assigned_at"],
                        "hours_after_first_report": round((w["a"] - g["first"]).total_seconds() / 3600, 1),
                        "work_order_had_complaints": bool(w["linked"]), "candidates": cand}
            n_infer["with_complaints" if w["linked"] else "unlinked_work_order"] += 1
        ws = sorted((wo_id[x] for x in wos), key=lambda w: (w["a"], w["work_order_id"]))
        last = ws[-1] if ws else None
        if last: outcome = "fixed_failed" if last["reopened"] else "fixed_held"
        elif any(c["r"]["status"] == "In Progress" for c in ms): outcome = "in_progress"
        else: outcome = "never_fixed"
        for c in ms: per[c["id"]]["issue_id"] = iid
        out.append({"id": iid, "source": g["src"], "category": g["cat"], "ward_code": ward, "locality": loc, "road_id": road_id,
            "road_name": road_name, "lat": r6(pt[0]), "lon": r6(pt[1]),
            "first_seen": g["first"].strftime("%Y-%m-%d %H:%M"), "last_seen": g["last"].strftime("%Y-%m-%d %H:%M"),
            "complaint_ids": [c["id"] for c in ms], "channels": sorted({c["r"]["channel"] for c in ms}),
            "languages": sorted({c["r"]["language"] for c in ms}), "complaint_count": len(ms),
            "upvotes_total": sum(int(c["r"]["upvotes"] or 0) for c in ms),
            "social_post_ids": [p["id"] for p in g["posts"]], "social_reach": sum(p["reach"] for p in g["posts"]),
            "outcome": outcome, "link": link, "link_evidence": evidence, "work_order_ids": [w["work_order_id"] for w in ws],
            "contractor_name": last["contractor_name"] if last else None, "repair_method": last["repair_method"] if last else None,
            "cost_inr": round(sum(w["cost"] for w in ws), 2) if ws else None, "sla_met": (not last["missed"]) if last else None,
            "reopened": any(w["reopened"] for w in ws) if ws else None,
            "days_to_fix": round((last["c"] - g["first"]).total_seconds() / 86400, 1) if last else None,
            "corrected_categories": sum(per[c["id"]]["category_corrected"] for c in ms)})

    # ---- 6. headline numbers ----
    sc = Counter(c["scope"] for c in C)
    # rupees from recorded links only: an inferred work order usually already sits on a recorded issue (no double count)
    by_out = {o: {"count": sum(1 for x in out if x["outcome"] == o),
                  "inr": round(sum(x["cost_inr"] or 0 for x in out if x["outcome"] == o and x["link"] == "recorded"), 2)}
              for o in OUTCOMES}
    ci = [x for x in out if x["source"] == "complaints"]
    linker = {
        "raw_complaints": len(C), "noise": sc["noise"], "out_of_scope": sc["out_of_scope"], "in_issues": sc["in_scope"],
        "issues": len(out), "issues_from_complaints": len(ci), "social_only_issues": len(out) - len(ci),
        "avg_complaints_per_issue": round(sc["in_scope"] / len(ci), 2),
        "multi_complaint_issues": sum(1 for x in ci if x["complaint_count"] > 1),
        "categories_corrected": sum(e["category_corrected"] for e in per.values()),
        "categories_corrected_share": round(sum(e["category_corrected"] for e in per.values()) / len(C), 4),
        "geocoded_by_source": {k: geo[k] for k in ("gps", "locality", "description", "ward_centroid", "none")},
        "ward_codes_filled": sum(filled.values()), "ward_codes_filled_by": dict(sorted(filled.items())),
        "ward_codes_blank": sum(1 for c in C if not c["r"]["ward_code"]),
        "issues_by_outcome": by_out,
        "links": {"recorded": sum(1 for x in out if x["link"] == "recorded"), "inferred": sum(1 for x in out if x["link"] == "inferred"),
                  "none": sum(1 for x in out if x["link"] == "none"), "inferred_to": dict(sorted(n_infer.items())),
                  "inferred_inr": round(sum(x["cost_inr"] for x in out if x["link"] == "inferred"), 2)},
        "social": {"posts": len(posts), "issue_report": kinds["issue_report"], "thanks": kinds["thanks"], "noise": kinds["noise"],
                   "forwards": flags["forward"], "sarcasm": flags["sarcasm"], "attached_to_complaint_issues": attached,
                   "in_social_only_issues": sum(len(issues[i]["posts"]) for i in range(len(issues)) if issues[i]["src"] == "social_only"),
                   "unlocated": unlocated, "social_only_issues": len(out) - len(ci)},
        "validation": {"category": cat_val, "grouping": grp_val,
                       "inferred_link_rule_on_recorded_issues": {**{k: blind[k] for k in ("right", "wrong", "no_candidate")},
                           "accuracy_when_matched": round(blind["right"] / max(1, blind["right"] + blind["wrong"]), 3)},
                       "typed_locality_matches_given_ward": round(loc_check[True] / max(1, sum(loc_check.values())), 4)},
        "thresholds": {"gps_max_accuracy_m": GPS_MAX_ACC_M, "same_place_m": SAME_PLACE_M, "window_days": WINDOW_DAYS,
                       "infer_window_hours_before": INFER_BEFORE_H, "infer_window_days_after": INFER_AFTER_D},
        "method": [
            "We read every complaint's text and photo note in English, Hinglish, Hindi and Marathi and fixed the category when the photo or an English or helpline note clearly named a different problem.",
            "Complaints that were not about roads (street lights, garbage, tests) or were sent to another agency (MMRDA, PWD) are kept but set aside.",
            "Each complaint was placed on the map from its phone GPS, else from the area name it gave, else from the ward centre.",
            f"Complaints about the same kind of problem within {SAME_PLACE_M} m (or in the same area and road) and within {WINDOW_DAYS} days of each other became one issue; when unsure we kept them apart.",
            "Each issue was followed to BMC's work order, with contractor, cost and whether the repair lasted 30 days; a few links are our best match and are marked 'inferred'.",
            "Social media posts about the same problem, place and days were attached to the issue; posts that matched no complaint became their own issues.",
        ],
    }
    ward_issues = {code: {"total": 0, **{o: 0 for o in OUTCOMES[:4]}, "social_only": 0} for code in ward_c}
    for x in out:
        if not x["ward_code"]: continue
        if x["source"] == "social_only": ward_issues[x["ward_code"]]["social_only"] += 1; continue
        ward_issues[x["ward_code"]]["total"] += 1; ward_issues[x["ward_code"]][x["outcome"]] += 1
    return out, linker, per, ward_issues
