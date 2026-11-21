#!/usr/bin/env python3
"""Nagar Sarthi audit engine: data/*.csv -> engine/out/audit.json. Standard library only.
Usage: python3 engine/audit.py [--check]"""
import csv, json, math, statistics as st, sys
from collections import defaultdict, Counter
from datetime import datetime, date, timedelta
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA, OUT = ROOT / "data", ROOT / "engine" / "out" / "audit.json"

# ---- thresholds and weights (change here) ----
OVER_RATE_RATIO = 1.5            # cost / expected above this is flagged
DOUBLE_BILL_DAYS = 5             # repeat job within this many days (timedelta.days <=)
MIN_JOBS_PER_WARD = 15           # minimum sample for a contractor rating in a ward
LOW_LYING_MIN = 0.6              # ward low_lying_index at/above this counts as low-lying
HEAVY_ALERTS = ("Orange", "Red")  # a week with any such day is a heavy-rain week
CONTEXT_WEIGHT = 0.5             # a failure in a low-lying ward / heavy-rain week counts this much
MIN_METHOD_JOBS = 10             # min past jobs for a method to be recommended
DEFAULT_SEVERITY = 3
ACCESS_RADIUS_M = 500            # hospital/school and flood hotspot reach
ACCIDENT_CAP = 5                 # accidents on a road at which that part maxes out
W_SEVERITY, W_ACCESS, W_ACCIDENTS, W_FLOOD, W_TRAFFIC = 30, 30, 20, 10, 10
WEIGHTS = {"severity": W_SEVERITY, "access": W_ACCESS, "accidents": W_ACCIDENTS, "flood": W_FLOOD, "traffic": W_TRAFFIC}
SLA_TO_SEVERITY = {24: 5, 48: 4, 72: 3, 120: 2, 168: 1}
THRESHOLDS = {"over_rate_ratio": OVER_RATE_RATIO, "double_billing_days": DOUBLE_BILL_DAYS,
              "min_jobs_per_ward": MIN_JOBS_PER_WARD, "low_lying_min": LOW_LYING_MIN,
              "heavy_rain_alerts": list(HEAVY_ALERTS), "context_weight": CONTEXT_WEIGHT,
              "access_radius_m": ACCESS_RADIUS_M, "accident_cap": ACCIDENT_CAP}
DISCLAIMER = "Synthetic data. Not BMC data. Contractors are fictional."
NEEDS_REVIEW, TO_CLAIM = "Needs review.", "To be claimed and verified."
SERIOUS = ["dlp_paid", "fix_failed", "over_rate", "double_billing"]  # also the order for road status
FLAG_TYPES = SERIOUS + ["sla_missed"]
TL_START, TL_END = date(2025, 6, 1), date(2025, 10, 31)


def rows(name):
    with open(DATA / f"{name}.csv", newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))

def dt(s): return datetime.strptime(s, "%Y-%m-%d %H:%M")
def r2(x): return round(x, 2)
def r6(x): return round(x, 6)
def fl(s): return float(s) if s not in ("", None) else None

def dist_m(la1, lo1, la2, lo2):  # equirectangular, fine at city scale
    x = math.radians(lo2 - lo1) * math.cos(math.radians((la1 + la2) / 2))
    return 6371000 * math.hypot(x, math.radians(la2 - la1))

def mean(xs): return sum(xs) / len(xs) if xs else None
def med(xs): return st.median(xs) if xs else None


def build():
    wards_t, roads_t, rate_t = rows("wards"), rows("roads"), rows("rate_card")
    wo, comps, locs = rows("work_orders"), rows("complaints"), rows("localities")
    fac, hot, rain, tides = rows("facilities"), rows("flood_hotspots"), rows("rainfall_daily"), rows("tides")
    traffic, acc = {r["road_id"]: r for r in rows("traffic")}, rows("accidents")
    ward_by = {w["ward_code"]: w for w in wards_t}
    road_by = {r["road_id"]: r for r in roads_t}
    rate = {r["repair_method"]: r for r in rate_t}
    for r in roads_t:
        r["mid"] = ((float(r["start_lat"]) + float(r["end_lat"])) / 2, (float(r["start_lon"]) + float(r["end_lon"])) / 2)

    # ---- work orders: typed fields, expected cost, ratio ----
    for w in wo:
        w["cost"], w["area"] = float(w["cost_inr"]), float(w["area_sqm"])
        rc = rate[w["repair_method"]]
        w["rate"] = float(rc["standard_rate_inr"])
        w["expected"] = w["area"] * w["rate"] if rc["unit"] == "per sqm" else w["rate"]
        w["unit"] = rc["unit"]
        w["ratio"] = w["cost"] / w["expected"]
        w["linked"] = [c for c in w["linked_complaint_ids"].split("|") if c]
        w["a"], w["c"] = dt(w["assigned_at"]), dt(w["completed_at"])
        w["missed"], w["reopened"] = w["sla_met"] == "N", w["reopened_within_30d"] == "Y"
        w["flags"] = []
    wo_by = {w["work_order_id"]: w for w in wo}

    # ---- method baselines (SLA miss and reopen rate per method) ----
    by_method = defaultdict(list)
    for w in wo: by_method[w["repair_method"]].append(w)
    method_miss = {m: mean([j["missed"] for j in js]) for m, js in by_method.items()}
    method_reopen = {m: mean([j["reopened"] for j in js]) for m, js in by_method.items()}

    # ---- flags ----
    flags = []
    def add(w, typ, reason, ev, expected=None):
        flags.append({"work_order_id": w["work_order_id"], "type": typ, "ward_code": w["ward_code"], "road_id": w["road_id"],
                      "contractor_id": w["contractor_id"], "contractor_name": w["contractor_name"], "cost_inr": r2(w["cost"]),
                      "expected_inr": r2(w["expected"]), "ratio": r2(w["ratio"]), "reason": reason, "evidence": ev})
        w["flags"].append(typ)
    last = {}
    for w in sorted(wo, key=lambda w: w["assigned_at"]):
        if w["ratio"] > OVER_RATE_RATIO:
            add(w, "over_rate", NEEDS_REVIEW, {"area_sqm": w["area"], "unit": w["unit"], "standard_rate_inr": w["rate"],
                "expected_inr": r2(w["expected"]), "billed_inr": r2(w["cost"]), "ratio": r2(w["ratio"]), "threshold": OVER_RATE_RATIO})
        key = (w["road_id"], w["repair_method"])
        prev = last.get(key)
        if prev and (w["a"] - prev["a"]).days <= DOUBLE_BILL_DAYS and not w["linked"]:
            add(w, "double_billing", NEEDS_REVIEW, {"previous_work_order_id": prev["work_order_id"],
                "previous_assigned_at": prev["assigned_at"], "assigned_at": w["assigned_at"],
                "days_apart": (w["a"] - prev["a"]).days, "linked_complaint_ids": [], "repair_method": w["repair_method"]})
        last[key] = w
        if road_by[w["road_id"]]["under_dlp"] == "Y":
            add(w, "dlp_paid", TO_CLAIM, {"under_dlp": "Y", "billed_inr": r2(w["cost"]),
                "last_resurfaced": road_by[w["road_id"]]["last_resurfaced"]})
        if w["reopened"]:
            add(w, "fix_failed", NEEDS_REVIEW, {"reopened_within_30d": "Y", "completed_at": w["completed_at"],
                "method_reopen_rate": r2(method_reopen[w["repair_method"]])})
        if w["missed"]:
            add(w, "sla_missed", NEEDS_REVIEW, {"sla_hours": int(w["sla_hours"]), "method_miss_rate": r2(method_miss[w["repair_method"]]),
                "repair_method": w["repair_method"]})

    # ---- context: low-lying ward or heavy-rain week ----
    heavy_weeks = set()
    for r in rain:
        if r["station"] == "Santacruz" and r["imd_alert"] in HEAVY_ALERTS:
            d = date.fromisoformat(r["date"]); heavy_weeks.add(d - timedelta(days=d.weekday()))
    def wk(d): return d.date() - timedelta(days=d.weekday())
    for w in wo:
        w["ctx"] = float(ward_by[w["ward_code"]]["low_lying_index"]) >= LOW_LYING_MIN or wk(w["a"]) in heavy_weeks or wk(w["c"]) in heavy_weeks
        k = CONTEXT_WEIGHT if w["ctx"] else 1.0  # failure weight
        w["sla_adj"], w["reo_adj"] = 1 - w["missed"] * k, 1 - w["reopened"] * k  # "good" scores, 1 = clean
        w["sla"], w["reo"] = 1 - w["missed"], 1 - w["reopened"]
    base = {}
    for m, js in by_method.items():
        base[m] = {k: mean([j[k] for j in js]) for k in ("sla", "reo", "sla_adj", "reo_adj")}

    def metrics(js):
        d = lambda k: mean([j[k] for j in js]) - mean([base[j["repair_method"]][k] for j in js])
        nc = [j["ratio"] for j in js if not j["ctx"]] or [j["ratio"] for j in js]
        return {"sla_rate": r2(mean([j["sla"] for j in js])), "sla_vs_method_avg": r2(d("sla")),
                "reopen_rate": r2(1 - mean([j["reo"] for j in js])),
                "reopen_vs_method_avg": r2(-d("reo")), "median_cost_ratio": r2(med([j["ratio"] for j in js])),
                "adjusted": {"sla_rate": r2(mean([j["sla_adj"] for j in js])), "sla_vs_method_avg": r2(d("sla_adj")),
                             "reopen_rate": r2(1 - mean([j["reo_adj"] for j in js])), "reopen_vs_method_avg": r2(-d("reo_adj")),
                             "median_cost_ratio": r2(med(nc))}}

    # ---- contractors ----
    contractors = {}
    byc = defaultdict(list)
    for w in wo: byc[w["contractor_id"]].append(w)
    # Strength/improve: three metrics, each oriented higher = better and turned into a z-score across contractors.
    # speed/durability = context-adjusted, same-method-relative; pricing = global over_rate share minus own share.
    g_over = mean(["over_rate" in w["flags"] for w in wo])
    raw = {cid: {"speed": metrics(js)["adjusted"]["sla_vs_method_avg"], "durability": -metrics(js)["adjusted"]["reopen_vs_method_avg"],
                 "pricing": g_over - mean(["over_rate" in j["flags"] for j in js])} for cid, js in byc.items()}
    z = {cid: {} for cid in raw}
    for k in ("speed", "durability", "pricing"):
        mu, sd = mean([r[k] for r in raw.values()]), st.pstdev([r[k] for r in raw.values()])
        for cid, r in raw.items(): z[cid][k] = r2((r[k] - mu) / sd) + 0.0 if sd else 0  # +0.0 avoids -0.0
    NAMES = {"speed": "Speed (SLA)", "durability": "Durability (repairs that last)", "pricing": "Pricing against the rate card"}
    for cid, js in byc.items():
        m = metrics(js)
        m["z"] = z[cid]
        best, worst = max(z[cid], key=z[cid].get), min(z[cid], key=z[cid].get)
        strength = (f"{NAMES[best]}: better than most contractors on the same kind of work." if z[cid][best] > 0
                    else f"Closest to typical on {NAMES[best].lower()}." if z[cid][best] >= -0.5
                    else "No area is above typical yet.")
        improve = (f"{NAMES[worst]}: below most contractors on the same kind of work. Needs review." if z[cid][worst] < 0
                   else "No area is below typical.")
        by_ward = {}
        for code, wj in sorted(defaultdict(list, {c: [j for j in js if j["ward_code"] == c] for c in {j["ward_code"] for j in js}}).items()):
            ok = len(wj) >= MIN_JOBS_PER_WARD
            by_ward[code] = {"jobs": len(wj), "rated": ok, "metrics": metrics(wj) if ok else None,
                             "reason_if_not_rated": None if ok else f"Only {len(wj)} jobs in this ward; minimum is {MIN_JOBS_PER_WARD}."}
        contractors[cid] = {"name": js[0]["contractor_name"], "jobs": len(js), "spend": r2(sum(j["cost"] for j in js)),
            "metrics": m, "strength": strength, "improve": improve,
            "by_ward": by_ward,
            "work_order_ids": {"all": [j["work_order_id"] for j in js], "sla_missed": [j["work_order_id"] for j in js if j["missed"]],
                               "reopened": [j["work_order_id"] for j in js if j["reopened"]],
                               "over_rate": [j["work_order_id"] for j in js if "over_rate" in j["flags"]]}}

    # ---- roads ----
    roads = {}
    for rid, r in road_by.items():
        roads[rid] = {"road_name": r["road_name"], "ward_code": r["ward_code"], "start_lat": r6(float(r["start_lat"])),
            "start_lon": r6(float(r["start_lon"])), "end_lat": r6(float(r["end_lat"])), "end_lon": r6(float(r["end_lon"])),
            "road_type": r["road_type"], "under_dlp": r["under_dlp"], "status": "clean", "spend": 0.0, "work_orders": []}
    for w in sorted(wo, key=lambda w: w["assigned_at"]):
        rd = roads[w["road_id"]]
        rd["spend"] = r2(rd["spend"] + w["cost"])
        rd["work_orders"].append({"id": w["work_order_id"], "method": w["repair_method"], "contractor_name": w["contractor_name"],
            "assigned_at": w["assigned_at"], "completed_at": w["completed_at"], "cost_inr": r2(w["cost"]), "sla_met": not w["missed"],
            "reopened": w["reopened"], "flags": w["flags"], "linked_complaint_ids": w["linked"]})
        for t in SERIOUS:
            if t in w["flags"]:
                if rd["status"] == "clean" or SERIOUS.index(t) < SERIOUS.index(rd["status"]): rd["status"] = t

    # ---- complaints: resolve ward, link ----
    loc_idx = defaultdict(list)  # lower name/alias -> [(ward, lat, lon)]
    for l in locs:
        for n in [l["locality"]] + [a.strip() for a in l["aliases"].split(";") if a.strip()]:
            loc_idx[n.lower()].append((l["ward_code"], float(l["lat"]), float(l["lon"])))
    def find_loc(text, ward=""):
        t = (text or "").strip().lower()
        c = loc_idx.get(t) or [v for k, vs in loc_idx.items() if t and (k.startswith(t) or t.startswith(k)) for v in vs]
        c = [v for v in c if not ward or v[0] == ward] or c
        return c[0] if c else None
    wo_of = {c: w for w in wo for c in w["linked"]}
    for c in comps:
        c["ward"] = c["ward_code"]
        c["lat_f"], c["lon_f"] = fl(c["lat"]), fl(c["lon"])
        if not c["ward"]:
            m = find_loc(c["locality_text"]); c["ward"] = m[0] if m else ""
    complaints = {}
    for c in comps:
        w = wo_of.get(c["complaint_id"])
        e = {"received_at": c["received_at"], "category": c["category_reported"], "description": c["description"],
             "language": c["language"], "locality": c["locality_text"], "ward_code": c["ward"] or None, "status": c["status"],
             "work_order_id": w["work_order_id"] if w else None}
        if w: e.update(contractor_name=w["contractor_name"], cost_inr=r2(w["cost"]), sla_met=not w["missed"], reopened=w["reopened"])
        complaints[c["complaint_id"]] = e

    # ---- wards ----
    open_c = [c for c in comps if c["status"] in ("Open", "In Progress")]
    wards = {}
    for code, w in ward_by.items():
        js = [j for j in wo if j["ward_code"] == code]
        budget, spend = float(w["monsoon_repair_budget_inr_2025"]), sum(j["cost"] for j in js)
        flagged = [j for j in js if any(t in SERIOUS for t in j["flags"])]
        fi = sum(j["cost"] for j in flagged)
        bc, bm = defaultdict(list), defaultdict(list)
        for j in js: bc[(j["contractor_id"], j["contractor_name"])].append(j); bm[j["repair_method"]].append(j)
        bft = {t: {"count": sum(1 for j in js if t in j["flags"]), "inr": r2(sum(j["cost"] for j in js if t in j["flags"]))} for t in FLAG_TYPES}
        never = [{"complaint_id": c["complaint_id"], "category": c["category_reported"], "locality": c["locality_text"],
                  "received_at": c["received_at"], "upvotes": int(c["upvotes"] or 0), "status": c["status"],
                  "lat": r6(c["lat_f"]) if c["lat_f"] is not None else None, "lon": r6(c["lon_f"]) if c["lon_f"] is not None else None}
                 for c in open_c if c["ward"] == code and c["complaint_id"] not in wo_of]
        wards[code] = {"name": w["ward_name"], "budget": r2(budget), "spend": r2(spend), "remaining": r2(budget - spend),
            "flagged_inr": r2(fi), "flagged_share": r2(fi / spend) if spend else 0,
            "by_contractor": [{"contractor_id": k[0], "name": k[1], "jobs": len(v), "inr": r2(sum(j["cost"] for j in v))}
                              for k, v in sorted(bc.items(), key=lambda kv: -sum(j["cost"] for j in kv[1]))],
            "by_method": [{"method": k, "jobs": len(v), "inr": r2(sum(j["cost"] for j in v))}
                          for k, v in sorted(bm.items(), key=lambda kv: -sum(j["cost"] for j in kv[1]))],
            "by_flag_type": bft, "never_fixed": never, "centroid_lat": r6(float(w["centroid_lat"])),
            "centroid_lon": r6(float(w["centroid_lon"])), "low_lying_index": float(w["low_lying_index"])}

    # ---- next rupee ----
    # Severity: from sla_hours (24h=5 ... 168h=1); open complaints have no work order, so use the median sla_hours seen for that work_type.
    typ_sev = {t: SLA_TO_SEVERITY.get(int(med([int(j["sla_hours"]) for j in js])), DEFAULT_SEVERITY)
               for t, js in ((t, [j for j in wo if j["work_type"] == t]) for t in {j["work_type"] for j in wo})}
    # Recommended method per work type = lowest reopen rate among methods with >= MIN_METHOD_JOBS jobs.
    # Categories with no work orders ("Road related", "Other") fall back to the best method across all jobs.
    def best_method(js):
        cs = [(mean([j["reopened"] for j in v]), m, v) for m, v in ((m, [j for j in js if j["repair_method"] == m]) for m in {j["repair_method"] for j in js}) if len(v) >= MIN_METHOD_JOBS]
        rr, m, v = min(cs, key=lambda x: (x[0], x[1]))  # ties: method name, so output is stable
        return m, rr, med([j["cost"] for j in v])
    typ_rec = {t: best_method([j for j in wo if j["work_type"] == t]) for t in typ_sev}
    fallback_rec = typ_rec["Pothole"]  # no work orders exist for 'Road related'/'Other'; treat as a pothole
    acc_by_road = defaultdict(list)
    for a in acc: acc_by_road[a["road_id"]].append(a)
    ward_roads = defaultdict(list)
    for r in roads_t: ward_roads[r["ward_code"]].append(r)
    issues = defaultdict(list)
    skipped = 0
    for c in open_c:
        if c["ward"]: issues[(c["ward"], c["locality_text"], c["category_reported"])].append(c)
        else: skipped += 1
    def score_issue(key, cs):
        ward, locality, cat = key
        rds = ward_roads.get(ward)
        if not rds: return None
        pts = [(c["lat_f"], c["lon_f"]) for c in cs if c["lat_f"] is not None]
        if pts: p = (mean([x[0] for x in pts]), mean([x[1] for x in pts]))
        else:
            m = find_loc(locality, ward)
            p = (m[1], m[2]) if m and m[0] == ward else (float(ward_by[ward]["centroid_lat"]), float(ward_by[ward]["centroid_lon"]))
        road = min(rds, key=lambda r: dist_m(*p, *r["mid"]))
        mid, reasons = road["mid"], []
        sev = typ_sev.get(cat, DEFAULT_SEVERITY)
        reasons.append(f"Severity {sev} of 5 for {cat}")
        best = (0, None)  # nearest hospital/school within radius; the ambulance entry road counts as distance 0
        for f in fac:
            d = 0 if f["ambulance_entry_road"] == road["road_id"] else dist_m(*mid, float(f["lat"]), float(f["lon"]))
            if d <= ACCESS_RADIUS_M and (1 - d / ACCESS_RADIUS_M >= best[0] or best[1] is None): best = (1 - d / ACCESS_RADIUS_M, f)
        access = W_ACCESS * best[0] if best[1] else 0
        if best[1]: reasons.append(f"Near {best[1]['type'].lower()}: {best[1]['name']}")
        na = len(acc_by_road.get(road["road_id"], []))
        if na: reasons.append(f"{na} recorded accidents on this road")
        hb = (0, None)
        for h in hot:
            d = dist_m(*mid, float(h["lat"]), float(h["lon"]))
            if d <= ACCESS_RADIUS_M and 1 - d / ACCESS_RADIUS_M >= hb[0]: hb = (1 - d / ACCESS_RADIUS_M, h)
        if hb[1]: reasons.append(f"Flood hotspot: {hb[1]['name']}")
        ci = float(traffic[road["road_id"]]["congestion_index_0_10"]) if road["road_id"] in traffic else 0
        if ci: reasons.append(f"Congestion index {ci:g} of 10")
        parts = {"severity": r2(W_SEVERITY * sev / 5), "access": r2(access), "accidents": r2(W_ACCIDENTS * min(1, na / ACCIDENT_CAP)),
                 "flood": r2(W_FLOOD * hb[0]), "traffic": r2(W_TRAFFIC * ci / 10)}
        m, rr, cost = typ_rec.get(cat, fallback_rec)
        dlp = road["under_dlp"] == "Y"  # warranty repair costs BMC nothing
        if dlp: reasons.append("Road under warranty: to be claimed from the original contractor")
        return {"issue": {"category": cat, "locality": locality, "complaint_ids": [c["complaint_id"] for c in cs],
                          "upvotes": sum(int(c["upvotes"] or 0) for c in cs)},
                "road_id": road["road_id"], "lat": r6(p[0]), "lon": r6(p[1]), "score": r2(sum(parts.values())), "parts": parts,
                "reasons": reasons, "recommended_method": m, "method_reopen_rate": r2(rr), "est_cost_inr": r2(cost),
                "claim_under_dlp": dlp, "cost_to_ward_inr": 0 if dlp else r2(cost)}
    next_rupee = {}
    for code in ward_by:
        items = [x for x in (score_issue(k, cs) for k, cs in issues.items() if k[0] == code) if x]
        items.sort(key=lambda x: (-x["score"], -x["issue"]["upvotes"]))
        remaining, cum, over = max(0.0, wards[code]["remaining"]), 0.0, False
        for i, x in enumerate(items, 1):
            cum += x["cost_to_ward_inr"]; over = over or cum > remaining  # list stops at the first item that busts the budget
            x["rank"], x["funded"] = i, x["claim_under_dlp"] or not over  # warranty items are always funded
        next_rupee[code] = {"remaining_budget": r2(remaining), "items": items}

    # ---- timeline (rain file covers Jun-Sep only; Oct rain is null) ----
    rn = {r["date"]: r for r in rain if r["station"] == "Santacruz"}
    big = {t["date"] for t in tides if t["big_tide_flag"] == "Y"}
    tl, days = {}, (TL_END - TL_START).days + 1
    for i in range(days):
        d = (TL_START + timedelta(days=i)).isoformat(); x = rn.get(d)
        tl[d] = {"date": d, "rainfall_mm": float(x["rainfall_mm"]) if x else None, "alert": x["imd_alert"] if x else None,
                 "big_tide": d in big, "complaints": [], "repairs": [], "reopens": []}
    for c in comps:
        d = c["received_at"][:10]
        if d not in tl: continue
        la, lo, approx = c["lat_f"], c["lon_f"], False
        if la is None:  # no GPS: place at the locality centre and say so
            m = find_loc(c["locality_text"], c["ward"])
            if m: la, lo, approx = m[1], m[2], True
        if la is None: continue
        e = {"id": c["complaint_id"], "lat": r6(la), "lon": r6(lo), "ward_code": c["ward"] or None, "category": c["category_reported"]}
        if approx: e["approx"] = True
        tl[d]["complaints"].append(e)
    for w in wo:
        d = w["c"].date().isoformat()
        if d in tl: tl[d]["repairs"].append({"work_order_id": w["work_order_id"], "road_id": w["road_id"]})
        if w["reopened"]:  # real re-open date unknown: place at completion + 30 days
            d = (w["c"].date() + timedelta(days=30)).isoformat()
            if d in tl: tl[d]["reopens"].append({"work_order_id": w["work_order_id"], "road_id": w["road_id"]})

    cnt = Counter(f["type"] for f in flags)
    inr = defaultdict(float)
    for f in flags: inr[f["type"]] += f["cost_inr"]
    meta = {"generated_at": datetime.now().isoformat(timespec="seconds"), "disclaimer": DISCLAIMER, "thresholds": THRESHOLDS, "weights": WEIGHTS,
            "totals": {"spend": r2(sum(w["cost"] for w in wo)), "budget": r2(sum(float(w["monsoon_repair_budget_inr_2025"]) for w in wards_t)),
                       "work_orders": len(wo), "flags": {t: {"count": cnt[t], "inr": r2(inr[t])} for t in FLAG_TYPES},
                       "open_complaints_skipped_no_ward": skipped}}
    def pt(rs): return [{**r, **{k: r6(float(r[k])) for k in ("lat", "lon")}} for r in rs]
    return {"meta": meta, "flags": flags, "wards": wards, "roads": roads, "contractors": contractors, "next_rupee": next_rupee,
            "timeline": list(tl.values()), "complaints": complaints, "facilities": pt(fac), "hotspots": pt(hot)}


def main():
    out = build()
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(out, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    t = out["meta"]["totals"]
    print(f"wrote {OUT} ({OUT.stat().st_size // 1024} KB); spend {t['spend'] / 1e5:.1f} lakh, budget {t['budget'] / 1e5:.1f} lakh")
    if "--check" in sys.argv:
        got = {k: v["count"] for k, v in t["flags"].items()}
        want = {"over_rate": 109, "double_billing": 45, "dlp_paid": 493, "fix_failed": 611}
        for k, n in want.items(): assert got[k] == n, f"{k}: got {got[k]}, want {n}"
        assert all(abs(sum(i["parts"].values()) - i["score"]) < 0.011 for n in out["next_rupee"].values() for i in n["items"]), "score parts"
        print("check OK:", {**got})


if __name__ == "__main__":
    main()
